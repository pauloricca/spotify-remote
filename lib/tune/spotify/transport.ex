defmodule Tune.Spotify.Transport do
  @moduledoc """
  App-wide Spotify request gate. A 429 blocks every session until Retry-After
  expires. Quota exhaustion without a reset hint pauses for an hour. Requests
  have bounded network timeouts and are never automatically replayed here.
  """
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def request(request) do
    GenServer.call(
      __MODULE__,
      {:request, request, System.monotonic_time(:millisecond) + 10_000},
      20_000
    )
  catch
    :exit, _ -> {:error, :transport_unavailable}
  end

  @impl true
  def init(_), do: {:ok, %{until: nil, kind: nil}}

  @impl true
  def handle_call({:request, request, deadline}, _from, state) do
    now = System.monotonic_time(:millisecond)

    cond do
      deadline < now ->
        {:reply, {:error, :timeout}, state}

      state.until && state.until > now ->
        seconds = div(state.until - now + 999, 1000)
        {:reply, {:error, {state.kind, seconds}}, state}

      true ->
        result = Finch.request(request, Tune.Finch, pool_timeout: 2_000, receive_timeout: 5_000)

        case result do
          {:ok, %{status: 429} = response} ->
            kind = if response.body =~ "QUOTA_EXCEEDED", do: :quota_exceeded, else: :rate_limited
            fallback = if kind == :quota_exceeded, do: 3600, else: 60
            seconds = retry_after(response.headers, fallback)
            state = %{until: System.monotonic_time(:millisecond) + seconds * 1000, kind: kind}
            {:reply, {:error, {kind, seconds}}, state}

          _ ->
            {:reply, validate_json(result, request), %{until: nil, kind: nil}}
        end
    end
  end

  defp retry_after(headers, fallback) do
    value =
      Enum.find_value(headers, fn {key, value} ->
        if String.downcase(key) == "retry-after", do: value
      end)

    case Integer.parse(value || "") do
      {seconds, ""} when seconds >= 0 -> max(seconds, 1)
      _ -> fallback
    end
  end

  # Existing endpoint decoders can safely decode successful JSON responses.
  # A proxy's HTML error page must not crash a user session.
  defp validate_json({:ok, %{status: 200, body: body}} = response, request) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) ->
        response

      {:ok, decoded} when is_list(decoded) ->
        if String.ends_with?(request.path, "/contains"),
          do: response,
          else: {:error, :invalid_response}

      _ ->
        {:error, :invalid_response}
    end
  end

  defp validate_json(response, _request), do: response
end
