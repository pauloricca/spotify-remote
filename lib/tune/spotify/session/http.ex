defmodule Tune.Spotify.Session.HTTP do
  @moduledoc """
  One session process per Spotify user. Serializes token refresh and commands,
  caches reads, and polls only while a browser is subscribed. Network failures
  back off; quota failures use the app-wide transport cooldown.
  """
  use GenServer, restart: :temporary
  @behaviour Tune.Spotify.Session

  alias Tune.Spotify.{Schema, Session, SessionRegistry}
  alias Phoenix.PubSub

  @default_timeouts %{refresh: 10_000, devices: 60_000, retry: 5_000, inactivity: 30_000}
  defstruct [
    :session_id,
    :credentials,
    :user,
    :error,
    :poll_timer,
    :device_timer,
    now_playing: %Schema.Player{},
    devices: [],
    subscribers: MapSet.new(),
    failures: 0,
    cache: %{},
    timeouts: @default_timeouts
  ]

  @type start_opts :: keyword()

  @spec start_link({Session.id(), Session.credentials()}) ::
          {:ok, pid()} | {:error, term()}
  def start_link({session_id, credentials}),
    do: start_link(session_id, credentials, timeouts: @default_timeouts)

  @spec start_link({Session.id(), Session.credentials(), start_opts()}) ::
          {:ok, pid()} | {:error, term()}
  def start_link({session_id, credentials, start_opts}),
    do: start_link(session_id, credentials, start_opts)

  @spec start_link(Session.id(), Session.credentials(), start_opts()) ::
          {:ok, pid()} | {:error, term()}
  def start_link(session_id, credentials, start_opts) do
    GenServer.start_link(__MODULE__, {session_id, credentials, start_opts}, name: via(session_id))
  end

  @impl true
  def setup(session_id, credentials) do
    Tune.Spotify.Supervisor.ensure_session(session_id, credentials)
  end

  @impl true
  def subscribe(session_id) do
    PubSub.subscribe(Tune.PubSub, session_id)
    caller = self()
    call(session_id, {:subscribe, caller})
  end

  @impl true
  def subscribers_count(session_id) do
    call(session_id, :subscribers_count)
  end

  @impl true
  def broadcast(session_id, message) do
    PubSub.broadcast(Tune.PubSub, session_id, message)
  end

  @impl true
  def get_profile(session_id) do
    call(session_id, :get_profile)
  end

  @impl true
  def now_playing(session_id) do
    call(session_id, :now_playing)
  end

  @impl true
  def toggle_play(session_id) do
    call(session_id, :toggle_play)
  end

  @impl true
  def play(session_id, uri) do
    call(session_id, {:play, uri})
  end

  @impl true
  def play(session_id, uri, context_uri) do
    call(session_id, {:play, uri, context_uri})
  end

  @impl true
  def next(session_id) do
    call(session_id, :next)
  end

  @impl true
  def prev(session_id) do
    call(session_id, :prev)
  end

  @impl true
  def recently_played_tracks(session_id, opts) do
    call(session_id, {:recently_played_tracks, opts})
  end

  @impl true
  def seek(session_id, position_ms) do
    call(session_id, {:seek, position_ms})
  end

  @impl true
  def search(session_id, q, opts) do
    call(session_id, {:search, q, opts})
  end

  @impl true
  def top_tracks(session_id, opts) do
    call(session_id, {:top_tracks, opts})
  end

  @impl true
  def get_album(session_id, album_id) do
    call(session_id, {:get_album, album_id})
  end

  @impl true
  def get_artist(session_id, artist_id) do
    call(session_id, {:get_artist, artist_id})
  end

  @impl true
  def get_artist_albums(session_id, artist_id, opts) do
    call(session_id, {:get_artist_albums, artist_id, opts})
  end

  @impl true
  def get_show(session_id, show_id) do
    call(session_id, {:get_show, show_id})
  end

  @impl true
  def get_episode(session_id, episode_id) do
    call(session_id, {:get_episode, episode_id})
  end

  @impl true
  def get_episodes(session_id, show_id) do
    call(session_id, {:get_episodes, show_id})
  end

  @impl true
  def get_playlist(session_id, playlist_id) do
    call(session_id, {:get_playlist, playlist_id})
  end

  @impl true
  def get_devices(session_id) do
    call(session_id, :get_devices)
  end

  @impl true
  def refresh_devices(session_id) do
    call(session_id, :refresh_devices)
  end

  @impl true
  def get_recommendations_from_artists(session_id, artist_ids) do
    call(session_id, {:get_recommendations_from_artists, artist_ids})
  end

  @impl true
  def transfer_playback(session_id, device_id) do
    call(session_id, {:transfer_playback, device_id})
  end

  @impl true
  def set_volume(session_id, volume_percent) do
    call(session_id, {:set_volume, volume_percent})
  end

  @impl true
  def library(session_id, kind, opts) do
    call(session_id, {:library, kind, opts})
  end

  @impl true
  def queue(session_id) do
    call(session_id, :queue)
  end

  @impl true
  def saved_items(session_id, uris) do
    call(session_id, {:saved_items, uris})
  end

  @impl true
  def add_to_playlist(session_id, playlist_id, uri),
    do: call(session_id, {:add_to_playlist, playlist_id, uri})

  @impl true
  def set_saved(session_id, uri, saved) do
    call(session_id, {:set_saved, uri, saved})
  end

  @impl true
  def set_shuffle(session_id, enabled) do
    call(session_id, {:set_shuffle, enabled})
  end

  @impl true
  def set_repeat(session_id, mode) do
    call(session_id, {:set_repeat, mode})
  end

  @impl true
  def get_player_token(session_id) do
    call(session_id, :get_player_token)
  end

  @impl true
  def init({id, credentials, opts}) do
    timeouts = Keyword.get(opts, :timeouts, @default_timeouts)
    # Tests and callers can provide a single refresh interval for both resources.
    timeouts = Map.put_new(timeouts, :devices, timeouts.refresh)
    Process.send_after(self(), :inactivity, timeouts.inactivity)

    {:ok,
     %__MODULE__{
       session_id: id,
       credentials: credentials,
       timeouts: timeouts
     }, {:continue, :authenticate}}
  end

  @impl true
  def handle_continue(:authenticate, data), do: {:noreply, authenticate(data)}

  @impl true
  def handle_call({:subscribe, pid}, _from, data) do
    unless MapSet.member?(data.subscribers, pid), do: Process.monitor(pid)
    if data.user, do: send(pid, {:session_ready, data.user})
    send(pid, {:player_token, if(data.user, do: data.credentials.token)})
    send(pid, {:now_playing, data.now_playing})
    send(pid, {:devices, data.devices})
    {:reply, :ok, %{data | subscribers: MapSet.put(data.subscribers, pid)}}
  end

  def handle_call(:subscribers_count, _from, data),
    do: {:reply, MapSet.size(data.subscribers), data}

  def handle_call(:get_profile, _from, data),
    do: {:reply, data.user || {:error, data.error || :not_authenticated}, data}

  def handle_call(:now_playing, _from, data), do: {:reply, data.now_playing, data}
  def handle_call(:get_devices, _from, data), do: {:reply, data.devices, data}

  def handle_call(:get_player_token, _from, %{user: nil} = data),
    do: {:reply, {:error, data.error || :not_authenticated}, data}

  def handle_call(:get_player_token, _from, data),
    do: {:reply, {:ok, data.credentials.token}, data}

  def handle_call(_msg, _from, %{user: nil} = data),
    do: {:reply, {:error, data.error || :not_authenticated}, data}

  def handle_call(:refresh_devices, _from, data) do
    {result, data} = fetch(:get_devices, :devices, data)
    {:reply, result, data}
  end

  def handle_call(:toggle_play, _from, data) do
    case data.now_playing.status do
      :playing -> command(:pause, [], data)
      :paused -> command(:play, [], data)
      _ -> {:reply, :ok, data}
    end
  end

  def handle_call(message, _from, data) do
    [fun | args] = if is_tuple(message), do: Tuple.to_list(message), else: [message]

    if fun in [
         :play,
         :next,
         :prev,
         :seek,
         :set_volume,
         :transfer_playback,
         :set_shuffle,
         :set_repeat,
         :set_saved,
         :add_to_playlist
       ] do
      command(fun, args, data)
    else
      key = {fun, args}

      case Map.get(data.cache, key) do
        {until, result} ->
          if until > now(), do: {:reply, result, data}, else: read(fun, args, key, data)

        _ ->
          read(fun, args, key, data)
      end
    end
  end

  @impl true
  def handle_info(:authenticate, data), do: {:noreply, authenticate(data)}

  def handle_info(:poll, data) do
    data = %{data | poll_timer: nil}

    {result, data} =
      if data.user && MapSet.size(data.subscribers) > 0,
        do: fetch(:now_playing, :now_playing, data),
        else: {:ok, data}

    {:noreply, schedule_poll(data, delay(result, data))}
  end

  def handle_info(:devices, data) do
    data = %{data | device_timer: nil}

    {result, data} =
      if data.user && MapSet.size(data.subscribers) > 0,
        do: fetch(:get_devices, :devices, data),
        else: {:ok, data}

    {:noreply, schedule_devices(data, max(data.timeouts.devices, delay(result, data)))}
  end

  def handle_info(:inactivity, data) do
    if MapSet.size(data.subscribers) == 0 do
      {:stop, :normal, data}
    else
      Process.send_after(self(), :inactivity, data.timeouts.inactivity)
      {:noreply, data}
    end
  end

  def handle_info({:DOWN, _, :process, pid, _}, data),
    do: {:noreply, %{data | subscribers: MapSet.delete(data.subscribers, pid)}}

  defp authenticate(data) do
    case request(:get_profile, [], data) do
      {{:ok, user}, data} ->
        data = %{data | user: user, error: nil, failures: 0}
        broadcast(data.session_id, {:player_token, data.credentials.token})
        broadcast(data.session_id, {:session_ready, user})
        {result, data} = fetch(:now_playing, :now_playing, data)
        {_, data} = fetch(:get_devices, :devices, data)
        data |> schedule_poll(delay(result, data)) |> schedule_devices(data.timeouts.devices)

      {{:error, reason} = error, data} ->
        data = %{data | error: reason, failures: data.failures + 1}

        unless reason in [:invalid_token, :invalid_refresh_token] do
          Process.send_after(self(), :authenticate, delay(error, data))
        end

        data
    end
  end

  defp read(fun, args, key, data) do
    {result, data} = request(fun, args, data)
    cache = data.cache |> Enum.filter(fn {_, {until, _}} -> until > now() end) |> Map.new()
    # Keep the cache bounded even when a browser searches many distinct terms.
    cache = if map_size(cache) >= 100, do: %{}, else: cache

    ttl = if fun == :queue, do: 2_000, else: 30_000

    cache =
      case result do
        {:ok, _} -> Map.put(cache, key, {now() + ttl, result})
        _ -> cache
      end

    {:reply, result, %{data | cache: cache}}
  end

  defp command(fun, args, data) do
    {result, data} = request(fun, args, data)
    data = if result == :ok, do: %{data | cache: %{}}, else: data

    data =
      if result == :ok and fun not in [:set_saved, :add_to_playlist] do
        {_, updated} = fetch(:now_playing, :now_playing, data)
        updated
      else
        data
      end

    {:reply, result, data}
  end

  defp fetch(fun, field, data) do
    case request(fun, [], data) do
      {{:ok, value}, data} ->
        if Map.fetch!(data, field) != value, do: broadcast(data.session_id, {field, value})
        {:ok, data |> Map.put(field, value) |> Map.put(:failures, 0)}

      {{:error, reason} = error, data} ->
        if data.failures == 0, do: broadcast(data.session_id, {:session_error, reason})
        {error, %{data | failures: data.failures + 1}}
    end
  end

  # Refresh at most once per operation. A failed command is never replayed for
  # network errors or 5xx responses, as it may already have reached Spotify.
  defp request(fun, args, data) do
    result = apply(spotify_client(), fun, [data.credentials.token | args])

    if result in [{:error, :expired_token}, {:error, :invalid_token}] do
      case spotify_client().get_token(data.credentials.refresh_token) do
        {:ok, credentials} ->
          credentials = %{
            credentials
            | refresh_token: credentials.refresh_token || data.credentials.refresh_token
          }

          data = %{data | credentials: credentials}
          broadcast(data.session_id, {:player_token, credentials.token})
          result = apply(spotify_client(), fun, [credentials.token | args])
          {result, auth_error(result, data)}

        {:error, reason} ->
          reason = if reason in [400, 401], do: :invalid_refresh_token, else: reason
          error = {:error, reason}
          {error, auth_error(error, data)}
      end
    else
      {result, data}
    end
  end

  defp auth_error({:error, reason}, data)
       when reason in [:invalid_token, :expired_token, :invalid_refresh_token] do
    broadcast(data.session_id, {:session_error, :not_authenticated})
    %{data | user: nil, error: :not_authenticated, cache: %{}}
  end

  defp auth_error(_, data), do: data

  defp delay({:error, {kind, seconds}}, _data) when kind in [:rate_limited, :quota_exceeded],
    do: max(seconds * 1000, 1000)

  defp delay({:error, _}, data),
    do: min(data.timeouts.retry * round(:math.pow(2, min(data.failures, 6))), 300_000)

  defp delay(_, data), do: data.timeouts.refresh

  defp schedule_poll(%{poll_timer: nil} = data, delay),
    do: %{data | poll_timer: Process.send_after(self(), :poll, delay)}

  defp schedule_poll(data, _), do: data

  defp schedule_devices(%{device_timer: nil} = data, delay),
    do: %{data | device_timer: Process.send_after(self(), :devices, delay)}

  defp schedule_devices(data, _), do: data

  defp call(id, message) do
    GenServer.call(via(id), message, 30_000)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, _ -> {:error, :not_authenticated}
  end

  defp now, do: System.monotonic_time(:millisecond)
  defp via(id), do: {:via, Registry, {SessionRegistry, id}}
  defp spotify_client, do: Application.fetch_env!(:tune, :spotify_client)
end
