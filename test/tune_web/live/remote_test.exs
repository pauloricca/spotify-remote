defmodule TuneWeb.RemoteTest do
  use TuneWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mox
  alias Tune.RemoteFixtures, as: F
  alias Tune.Spotify.Session.Mock
  alias Tune.Spotify.Schema.Player

  setup :verify_on_exit!

  setup %{conn: conn} do
    Mock
    |> stub(:setup, fn _, _ -> :ok end)
    |> stub(:get_profile, fn _ -> F.user() end)
    |> stub(:get_player_token, fn _ -> {:ok, "test-token"} end)
    |> stub(:get_devices, fn _ -> [F.device()] end)
    |> stub(:now_playing, fn _ -> F.player() end)
    |> stub(:subscribe, fn _ -> :ok end)
    |> stub(:saved_items, fn _, uris -> {:ok, Enum.map(uris, fn _ -> true end)} end)
    |> stub(:recently_played_tracks, fn _, _ -> {:ok, [F.track()]} end)

    {:ok,
     conn:
       init_test_session(conn, spotify_id: "remote-user", spotify_credentials: F.credentials())}
  end

  test "the real library displays Spotify playlists and preserves pagination", %{conn: conn} do
    parent = self()

    stub(Mock, :library, fn _, kind, opts ->
      send(parent, {:library_request, kind, opts})

      {:ok,
       %{
         items: [F.playlist()],
         total: 25,
         next: "https://api.spotify.com/v1/me/playlists?offset=24&limit=24"
       }}
    end)

    {:ok, view, _} = live(conn, "/library")
    assert has_element?(view, ".result .name", "Chilled Vibes")
    assert has_element?(view, "a[href='/playlists/playlist1']")
    assert has_element?(view, "a[href='/library?offset=24&type=playlists']", "Next page")
    assert_received {:library_request, :playlists, [offset: 0, after: nil]}
  end

  test "library filters and cursor paging request the matching content", %{conn: conn} do
    parent = self()

    stub(Mock, :library, fn _, kind, opts ->
      send(parent, {:library_request, kind, opts})
      {:ok, %{items: [F.artist()], total: 1, next: nil}}
    end)

    {:ok, view, _} = live(conn, "/library?type=artists&after=artist0")
    assert has_element?(view, ".result .name", "Tame Impala")
    assert_received {:library_request, :artists, [offset: 0, after: "artist0"]}
  end

  test "a previous login without library scopes offers reconnection", %{conn: conn} do
    stub(Mock, :library, fn _, _, _ -> {:error, 403} end)
    {:ok, view, _} = live(conn, "/library?type=albums")
    assert has_element?(view, "a[href='/auth/spotify']", "Reconnect Spotify")
    refute has_element?(view, ".result")
  end

  test "now playing uses live metadata, distinct progress bars and real playback controls", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/now-playing")
    assert has_element?(view, "h1", "Let It Happen")
    assert has_element?(view, "#now_progress-bar[value='192000']")
    assert has_element?(view, "#progress_bar-bar[value='192000']")
    expect(Mock, :set_shuffle, fn "remote-user", true -> :ok end)
    view |> element("button[phx-click=toggle_shuffle]") |> render_click()
    expect(Mock, :set_repeat, fn "remote-user", "context" -> :ok end)
    view |> element("button[phx-click=toggle_repeat]") |> render_click()
    send(view.pid, {:now_playing, %{F.player() | progress_ms: 193_000}})
    assert render(view) =~ "193000"
    assert has_element?(view, "#now_progress-bar[value='193000']")
    assert has_element?(view, "#progress_bar-bar[value='193000']")
  end

  test "empty playback still lets the user choose a device", %{conn: conn} do
    stub(Mock, :now_playing, fn _ -> %Player{} end)
    {:ok, view, _} = live(conn, "/now-playing")
    assert has_element?(view, "h1", "Nothing playing yet")
    refute has_element?(view, "#now_progress-bar")
    assert has_element?(view, ".empty-state button[phx-click=open_devices]")
  end

  test "queue comes from Spotify and can play an actual queued URI", %{conn: conn} do
    {:ok, view, _} = live(conn, "/now-playing")

    expect(Mock, :queue, fn "remote-user" ->
      {:ok,
       %{
         currently_playing: F.track(),
         queue: [%{F.track() | id: "track2", uri: "spotify:track:track2", name: "Nangs"}]
       }}
    end)

    view |> element(".now-tools button[phx-click=open_queue]") |> render_click()
    assert has_element?(view, "[role=dialog] h2", "Queue")
    expect(Mock, :play, fn "remote-user", "spotify:track:track2" -> :ok end)
    view |> element("#playback-panel [data-test-queue-item=track2]", "Nangs") |> render_click()
    view |> element("button[phx-click=close_panel]") |> render_click()
    refute has_element?(view, "#playback-panel")
  end

  test "device picker transfers playback to Spotify device IDs", %{conn: conn} do
    {:ok, view, _} = live(conn, "/now-playing")
    expect(Mock, :refresh_devices, fn "remote-user" -> :ok end)
    view |> element("#device-button") |> render_click()
    assert has_element?(view, ".device-row[aria-pressed=true]", "This Echo Show")
    refute has_element?(view, ".device-row[disabled]")
    expect(Mock, :transfer_playback, fn "remote-user", "echo1" -> :ok end)
    view |> element(".device-row") |> render_click()
    expect(Mock, :set_volume, fn "remote-user", 35 -> :ok end)
    view |> element(".panel-volume") |> render_change(%{"volume" => "35"})
  end

  test "saving reads the current library state before toggling", %{conn: conn} do
    {:ok, view, _} = live(conn, "/now-playing")
    expect(Mock, :saved_items, fn "remote-user", ["spotify:track:track1"] -> {:ok, [true]} end)
    expect(Mock, :set_saved, fn "remote-user", "spotify:track:track1", false -> :ok end)
    view |> element(".now-title button[phx-click=toggle_saved]") |> render_click()
    assert has_element?(view, ".now-title button[aria-pressed=false]")
    assert render(view) =~ "Removed from your library"
  end

  test "playlist metadata remains playable when Spotify withholds its tracks", %{conn: conn} do
    stub(Mock, :get_playlist, fn _, "playlist1" -> {:ok, F.playlist()} end)
    {:ok, view, _} = live(conn, "/playlists/playlist1")
    assert has_element?(view, "h1", "Chilled Vibes")
    assert render(view) =~ "You can still play this playlist"
    expect(Mock, :play, fn "remote-user", "spotify:playlist:playlist1" -> :ok end)
    view |> element("button[aria-label='Play playlist']") |> render_click()
  end

  test "a missing Release Radar does not prevent recently played albums from loading", %{
    conn: conn
  } do
    stub(Mock, :search, fn _, _, _ -> {:ok, %{playlist: %{items: [], total: 0}}} end)
    stub(Mock, :top_tracks, fn _, _ -> {:error, 403} end)
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#recently-played .name", "Currents")
    refute render(view) =~ "Cannot display Release Radar"
  end

  test "all search shows artists, songs and playlists using their real routes", %{conn: conn} do
    stub(Mock, :search, fn _,
                           "tame impala",
                           [types: [:artist, :track, :album, :playlist], limit: 10, offset: 0] ->
      {:ok,
       %{
         artist: %{items: [F.artist()], total: 1},
         track: %{items: [F.track()], total: 1},
         album: %{items: [F.album()], total: 1},
         playlist: %{items: [F.playlist()], total: 1}
       }}
    end)

    {:ok, view, _} = live(conn, "/search?q=tame+impala&type=all")
    assert has_element?(view, ".top-result[href='/artists/artist1']", "Tame Impala")
    assert has_element?(view, ".search-columns .song-row", "Let It Happen")
    assert has_element?(view, "a[href='/playlists/playlist1']")
  end
end
