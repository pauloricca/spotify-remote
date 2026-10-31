defmodule Tune.Spotify.Client.RemoteHTTPTest.Server do
  @moduledoc false
  import Plug.Conn
  def init(agent), do: agent

  def call(conn, agent) do
    conn = fetch_query_params(conn)
    {owner, status, body} = Agent.get(agent, & &1)

    send(
      owner,
      {:spotify_request, conn.method, conn.request_path, conn.query_params,
       get_req_header(conn, "authorization")}
    )

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, if(status == 204, do: "", else: Jason.encode!(body)))
  end
end

defmodule Tune.Spotify.Client.RemoteHTTPTest do
  use ExUnit.Case, async: false
  alias Tune.Spotify.Client.HTTP
  alias Tune.Spotify.Schema.{Album, Playlist, Track}

  setup do
    owner = self()
    agent = start_supervised!({Agent, fn -> {owner, 200, %{}} end})
    ref = make_ref()

    start_supervised!(
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: {__MODULE__.Server, agent},
        options: [port: 0, ref: ref]
      )
    )

    previous = Application.get_env(:tune, :spotify_api_base_url)

    Application.put_env(
      :tune,
      :spotify_api_base_url,
      "http://127.0.0.1:#{:ranch.get_port(ref)}/v1"
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:tune, :spotify_api_base_url, previous),
        else: Application.delete_env(:tune, :spotify_api_base_url)
    end)

    {:ok, agent: agent}
  end

  defp respond(agent, body, status \\ 200),
    do: Agent.update(agent, fn {owner, _, _} -> {owner, status, body} end)

  defp album_json,
    do: %{
      "id" => "a1",
      "uri" => "spotify:album:a1",
      "name" => "Currents",
      "artists" => [],
      "images" => [],
      "release_date" => "2015"
    }

  defp track_json,
    do: %{
      "id" => "t1",
      "uri" => "spotify:track:t1",
      "type" => "track",
      "name" => "Let It Happen",
      "duration_ms" => 468_000,
      "artists" => [],
      "album" => album_json()
    }

  defp playlist_json,
    do: %{"id" => "p1", "uri" => "spotify:playlist:p1", "name" => "My music", "images" => []}

  test "saved albums unwrap the paginated response and preserve the next page", %{agent: agent} do
    respond(agent, %{
      items: [%{album: album_json()}],
      total: 30,
      next: "https://api.spotify.com/v1/me/albums?offset=24"
    })

    assert {:ok, %{items: [%Album{name: "Currents"}], total: 30, next: next}} =
             HTTP.library("token", :albums, offset: 0)

    assert next =~ "offset=24"

    assert_receive {:spotify_request, "GET", "/v1/me/albums", %{"limit" => "24", "offset" => "0"},
                    ["Bearer token"]}
  end

  test "followed artists use cursor pagination rather than an offset", %{agent: agent} do
    respond(agent, %{artists: %{items: [], total: 0, next: nil}})
    assert {:ok, %{items: []}} = HTTP.library("token", :artists, after: "artist0")

    assert_receive {:spotify_request, "GET", "/v1/me/following",
                    %{"after" => "artist0", "type" => "artist"} = params, _}

    refute Map.has_key?(params, "offset")
  end

  test "queue parses current and next tracks and ignores unsupported items", %{agent: agent} do
    respond(agent, %{
      currently_playing: track_json(),
      queue: [nil, %{"type" => "ad"}, track_json()]
    })

    assert {:ok, %{currently_playing: %Track{name: "Let It Happen"}, queue: [%Track{id: "t1"}]}} =
             HTTP.queue("token")

    assert_receive {:spotify_request, "GET", "/v1/me/player/queue", _, _}
  end

  test "saved state and mutations use Spotify URI library endpoints", %{agent: agent} do
    respond(agent, [true])
    assert {:ok, [true]} = HTTP.saved_items("token", ["spotify:track:t1"])

    assert_receive {:spotify_request, "GET", "/v1/me/library/contains",
                    %{"uris" => "spotify:track:t1"}, _}

    respond(agent, %{}, 204)
    assert :ok = HTTP.set_saved("token", "spotify:track:t1", false)

    assert_receive {:spotify_request, "DELETE", "/v1/me/library", %{"uris" => "spotify:track:t1"},
                    _}

    assert :ok = HTTP.set_saved("token", "spotify:track:t1", true)
    assert_receive {:spotify_request, "PUT", "/v1/me/library", %{"uris" => "spotify:track:t1"}, _}
  end

  test "shuffle and repeat send Spotify's setting values", %{agent: agent} do
    respond(agent, %{}, 204)
    assert :ok = HTTP.set_shuffle("token", true)
    assert_receive {:spotify_request, "PUT", "/v1/me/player/shuffle", %{"state" => "true"}, _}
    assert :ok = HTTP.set_repeat("token", "track")
    assert_receive {:spotify_request, "PUT", "/v1/me/player/repeat", %{"state" => "track"}, _}
  end

  test "playlists parse both current and legacy item responses", %{agent: agent} do
    for {container, field} <- [{"items", "item"}, {"tracks", "track"}] do
      respond(
        agent,
        Map.put(playlist_json(), container, %{
          "items" => [%{field => track_json()}, %{field => nil}]
        })
      )

      assert {:ok, %Playlist{tracks: [%Track{id: "t1"}]}} = HTTP.get_playlist("token", "p1")
    end

    respond(agent, playlist_json())
    assert {:ok, %Playlist{tracks: :not_fetched}} = HTTP.get_playlist("token", "p1")
  end

  test "playback parses shuffle, repeat, and unavailable volume", %{agent: agent} do
    respond(agent, %{
      currently_playing_type: "track",
      item: track_json(),
      is_playing: true,
      progress_ms: 1200,
      shuffle_state: true,
      repeat_state: "context",
      device: %{id: "echo", name: "Echo", volume_percent: nil}
    })

    assert {:ok, %{shuffle_state: true, repeat_state: "context", device: %{volume_percent: nil}}} =
             HTTP.now_playing("token")
  end

  test "search ignores null playlist entries returned by Spotify", %{agent: agent} do
    respond(agent, %{playlists: %{items: [nil, playlist_json(), nil], total: 3}})

    assert {:ok, %{playlist: %{items: [%Playlist{id: "p1"}], total: 3}}} =
             HTTP.search("token", "Release Radar", types: [:playlist], limit: 1)
  end

  @tag capture_log: true
  test "missing permission is returned for an actionable library error", %{agent: agent} do
    respond(agent, %{error: %{message: "Insufficient scope"}}, 403)
    assert {:error, 403} = HTTP.library("token", :playlists, [])
  end
end
