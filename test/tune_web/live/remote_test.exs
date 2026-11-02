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
    |> stub(:library, fn _, _, _ -> {:ok, %{items: [F.playlist()], total: 1, next: nil}} end)
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

  test "playback errors expose an automatic timeout and a working close button", %{conn: conn} do
    expect(Mock, :next, fn _ -> {:error, 404} end)
    {:ok, view, _} = live(conn, "/now-playing")
    render_click(view, "next")
    assert has_element?(view, "#error-flash[phx-hook=DismissibleAlert]", "No available devices")

    view |> element("#error-flash button[aria-label='Dismiss error']") |> render_click()
    refute has_element?(view, "#error-flash")
  end

  for playback <- [:item, :context, :resume] do
    test "#{playback} playback restores this browser's saved device", %{conn: conn} do
      playback = unquote(playback)
      conn = put_connect_params(conn, %{"preferred_device" => "saved-speaker"})
      {:ok, view, _} = live(conn, "/now-playing")
      saved = %{F.device() | id: "saved-speaker"}
      expect(Mock, :refresh_devices, fn "remote-user" -> :ok end)
      expect(Mock, :get_devices, fn "remote-user" -> [F.device(), saved] end)
      expect(Mock, :transfer_playback, fn "remote-user", "saved-speaker" -> :ok end)

      params = expect_playback_retry(playback)
      event = if playback == :resume, do: "toggle_play_pause", else: "play"
      render_click(view, event, params)
      refute has_element?(view, "#error-flash")
    end
  end

  test "an unavailable remembered device does not switch to a different speaker", %{conn: conn} do
    conn = put_connect_params(conn, %{"preferred_device" => "offline-speaker"})
    {:ok, view, _} = live(conn, "/now-playing")
    expect(Mock, :play, fn _, "spotify:track:track1" -> {:error, 404} end)
    expect(Mock, :refresh_devices, fn _ -> :ok end)
    expect(Mock, :get_devices, fn _ -> [F.device()] end)
    render_click(view, "play", %{"uri" => F.track().uri})
    assert has_element?(view, "#error-flash", "No available devices")
  end

  test "a chosen device is remembered immediately and sent to browser storage", %{conn: conn} do
    {:ok, view, _} = live(conn, "/now-playing")
    expect(Mock, :transfer_playback, fn _, "chosen-speaker" -> :ok end)
    render_click(view, "transfer_playback", %{"device" => "chosen-speaker"})
    assert_push_event(view, "remember_device", %{device: "chosen-speaker"})

    expect(Mock, :refresh_devices, fn _ -> :ok end)
    expect(Mock, :get_devices, fn _ -> [F.device(), %{F.device() | id: "chosen-speaker"}] end)
    expect(Mock, :transfer_playback, fn _, "chosen-speaker" -> :ok end)
    params = expect_playback_retry(:item)
    render_click(view, "play", params)
    refute has_element?(view, "#error-flash")
  end

  test "a fresh browser still selects an available device", %{conn: conn} do
    {:ok, view, _} = live(conn, "/now-playing")
    expect(Mock, :refresh_devices, fn _ -> :ok end)
    expect(Mock, :get_devices, fn _ -> [F.device()] end)
    expect(Mock, :transfer_playback, fn _, "echo1" -> :ok end)
    params = expect_playback_retry(:item)
    render_click(view, "play", params)
    refute has_element?(view, "#error-flash")
  end

  defp expect_playback_retry(:resume) do
    expect(Mock, :toggle_play, fn _ -> {:error, 404} end)
    expect(Mock, :toggle_play, fn _ -> :ok end)
    %{}
  end

  defp expect_playback_retry(:item) do
    expect(Mock, :play, fn _, "spotify:track:track1" -> {:error, 404} end)
    expect(Mock, :play, fn _, "spotify:track:track1" -> :ok end)
    %{"uri" => F.track().uri}
  end

  defp expect_playback_retry(:context) do
    expect(Mock, :play, fn _, "spotify:track:track1", "spotify:album:album1" -> {:error, 404} end)
    expect(Mock, :play, fn _, "spotify:track:track1", "spotify:album:album1" -> :ok end)
    %{"uri" => F.track().uri, "context-uri" => F.album().uri}
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

  test "now playing keeps one persistent player with live progress and playback controls", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/now-playing")
    assert has_element?(view, "h1", "Let It Happen")
    assert has_element?(view, ".jukebox-player")
    assert length(view |> render() |> Floki.parse_document!() |> Floki.find("progress")) == 1
    assert has_element?(view, "#progress_bar-bar[value='192000']")
    expect(Mock, :set_shuffle, fn "remote-user", true -> :ok end)
    view |> element("#mini-player button[phx-click=toggle_shuffle]") |> render_click()
    expect(Mock, :set_repeat, fn "remote-user", "context" -> :ok end)
    view |> element("#mini-player button[phx-click=toggle_repeat]") |> render_click()
    send(view.pid, {:now_playing, %{F.player() | progress_ms: 193_000}})
    assert render(view) =~ "193000"
    assert has_element?(view, "#progress_bar-bar[value='193000']")
  end

  test "player exposes queue and playlist controls without a cog menu", %{conn: conn} do
    {:ok, view, _} = live(conn, "/now-playing")
    assert has_element?(view, "#mini-player button[aria-label='Open queue']")
    assert has_element?(view, "#mini-player button[aria-label='Add to playlist']:not([disabled])")
    refute has_element?(view, "#mini-player details")

    assert length(
             view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find(".touch-player-controls button")
           ) == 7
  end

  test "playlist picker filters destinations and keeps the selected track when playback changes",
       %{conn: conn} do
    owned = %{F.playlist() | id: "owned", owner_id: "remote-user"}

    shared = %{
      F.playlist()
      | id: "shared",
        name: "Shared music",
        owner_id: "friend",
        collaborative: true
    }

    readonly = %{F.playlist() | id: "readonly", name: "Read only", owner_id: "friend"}
    {:ok, view, _} = live(conn, "/now-playing")

    expect(Mock, :library, fn "remote-user", :playlists, [offset: 0, after: nil] ->
      {:ok, %{items: [owned, shared, readonly], total: 3, next: nil}}
    end)

    view |> element("#mini-player button[phx-click=open_add_to_playlist]") |> render_click()
    assert has_element?(view, ".playlist-choice[phx-value-playlist=owned]")
    assert has_element?(view, ".playlist-choice[phx-value-playlist=shared]")
    refute has_element?(view, ".playlist-choice[phx-value-playlist=readonly]")
    render_click(view, "add_to_playlist", %{"playlist" => "readonly"})
    assert has_element?(view, "#playback-panel")

    send(
      view.pid,
      {:now_playing,
       %{F.player() | item: %{F.track() | uri: "spotify:track:track2", name: "Nangs"}}}
    )

    assert render(view) =~ "Nangs"
    assert has_element?(view, ".playlist-target", "Let It Happen")
    expect(Mock, :add_to_playlist, fn "remote-user", "owned", "spotify:track:track1" -> :ok end)
    view |> element(".playlist-choice[phx-value-playlist=owned]") |> render_click()
    assert render(view) =~ "Added Let It Happen to Chilled Vibes"
    refute has_element?(view, "#playback-panel")
    render_click(view, "add_to_playlist", %{"playlist" => "owned"})
  end

  test "playlist picker can reach editable destinations on later pages", %{conn: conn} do
    {:ok, view, _} = live(conn, "/now-playing")

    expect(Mock, :library, fn _, :playlists, [offset: 0, after: nil] ->
      {:ok,
       %{items: [], total: 25, next: "https://api.spotify.com/v1/me/playlists?offset=24&limit=24"}}
    end)

    view |> element("#mini-player button[phx-click=open_add_to_playlist]") |> render_click()

    expect(Mock, :library, fn _, :playlists, [offset: 24, after: nil] ->
      {:ok, %{items: [%{F.playlist() | owner_id: "remote-user"}], total: 25, next: nil}}
    end)

    view |> element("button[phx-click=more_playlist_choices]") |> render_click()
    assert has_element?(view, ".playlist-choice", "Chilled Vibes")
    refute has_element?(view, "button[phx-click=more_playlist_choices]")
  end

  test "playlist loading can be retried without switching the target track", %{conn: conn} do
    {:ok, view, _} = live(conn, "/now-playing")
    expect(Mock, :library, fn _, :playlists, _ -> {:error, 403} end)
    view |> element("#mini-player button[phx-click=open_add_to_playlist]") |> render_click()
    assert has_element?(view, "#playback-panel a[href='/auth/spotify']")
    send(view.pid, {:now_playing, %{F.player() | item: %{F.track() | name: "Next song"}}})
    render(view)

    expect(Mock, :library, fn _, :playlists, _ ->
      {:ok, %{items: [%{F.playlist() | owner_id: "remote-user"}], total: 1, next: nil}}
    end)

    view |> element("button[phx-click=retry_playlist_choices]") |> render_click()
    assert has_element?(view, ".playlist-target", "Let It Happen")
    assert has_element?(view, ".playlist-choice")
  end

  test "playlist write permission failures keep the picker open and offer reconnection", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/now-playing")

    expect(Mock, :library, fn _, :playlists, _ ->
      {:ok, %{items: [%{F.playlist() | owner_id: "remote-user"}], total: 1, next: nil}}
    end)

    view |> element("#mini-player button[phx-click=open_add_to_playlist]") |> render_click()
    expect(Mock, :add_to_playlist, fn _, _, _ -> {:error, 403} end)
    view |> element(".playlist-choice") |> render_click()
    assert has_element?(view, "#playback-panel a[href='/auth/spotify']", "Reconnect Spotify")
    refute render(view) =~ "Added Let It Happen"
  end

  test "empty playback still lets the user choose a device", %{conn: conn} do
    stub(Mock, :now_playing, fn _ -> %Player{} end)
    {:ok, view, _} = live(conn, "/now-playing")
    assert has_element?(view, "h1", "Nothing playing yet")
    refute has_element?(view, "#now_progress-bar")
    assert has_element?(view, "#mini-player button[aria-label='Add to playlist'][disabled]")
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

    view |> element("#mini-player button[phx-click=open_queue]") |> render_click()
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

  test "home shows recent albums and actual saved playlists", %{
    conn: conn
  } do
    stub(Mock, :search, fn _, _, _ -> {:ok, %{playlist: %{items: [], total: 0}}} end)
    stub(Mock, :top_tracks, fn _, _ -> {:error, 403} end)
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#recently-played .name", "Currents")

    assert has_element?(
             view,
             "#home-playlists button[phx-value-uri='spotify:playlist:playlist1']",
             "Chilled Vibes"
           )

    expect(Mock, :play, fn "remote-user", "spotify:playlist:playlist1" -> :ok end)

    view
    |> element("#home-playlists button[phx-value-uri='spotify:playlist:playlist1']")
    |> render_click()

    expect(Mock, :play, fn "remote-user", "spotify:album:album1" -> :ok end)

    view
    |> element("#recently-played button[phx-value-uri='spotify:album:album1']")
    |> render_click()
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

  test "home keeps recent music available when playlist access is missing", %{conn: conn} do
    stub(Mock, :library, fn _, :playlists, _ -> {:error, 403} end)
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#recently-played button[aria-label='Play Currents']")
    assert has_element?(view, "#home-playlists a[href='/auth/spotify']", "Reconnect Spotify")
  end

  test "home keeps playlists available when recent history fails", %{conn: conn} do
    stub(Mock, :recently_played_tracks, fn _, _ -> {:error, 403} end)
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#recently-played", "Recently played is unavailable")
    assert has_element?(view, "#home-playlists button[aria-label='Play Chilled Vibes']")
  end

  test "quota failure during mount renders the existing page and recovers", %{conn: conn} do
    stub(Mock, :get_profile, fn _ -> {:error, {:quota_exceeded, 3600}} end)
    stub(Mock, :get_player_token, fn _ -> {:error, :not_authenticated} end)
    stub(Mock, :now_playing, fn _ -> {:error, :not_authenticated} end)
    stub(Mock, :get_devices, fn _ -> {:error, :not_authenticated} end)
    {:ok, view, html} = live(conn, "/library")
    assert html =~ "quota is exhausted"
    assert has_element?(view, "nav[aria-label='Main navigation']")

    expect(Mock, :library, fn _, :playlists, _ ->
      {:ok, %{items: [F.playlist()], total: 1, next: nil}}
    end)

    send(view.pid, {:session_ready, F.user()})
    assert render(view) =~ "Chilled Vibes"
  end

  test "invalid credentials redirect to sign-in without an HTTP 500", %{conn: conn} do
    stub(Mock, :get_profile, fn _ -> {:error, :not_authenticated} end)
    assert {:error, {:redirect, %{to: "/auth/login"}}} = live(conn, "/library")
  end

  test "a playback authentication failure redirects instead of crashing", %{conn: conn} do
    {:ok, view, _} = live(conn, "/now-playing")
    expect(Mock, :next, fn _ -> {:error, :not_authenticated} end)
    view |> element("#mini-player button[phx-click=next]") |> render_click()
    assert_redirect(view, "/auth/logout")
  end
end
