defmodule Tune.RemoteFixtures do
  @moduledoc false
  alias Tune.Spotify.Schema.{Album, Artist, Track, Playlist, Device, User, Player}

  def user,
    do: %User{name: "Paulo", avatar_url: "/images/demo/short-sweet.jpg", product: "premium"}

  def credentials,
    do: %Ueberauth.Auth.Credentials{token: "test-token", refresh_token: "test-refresh"}

  def artist do
    struct(Artist,
      id: "artist1",
      uri: "spotify:artist:artist1",
      name: "Tame Impala",
      spotify_url: "https://open.spotify.com/artist/artist1",
      albums: [],
      total_albums: 1,
      genres: [],
      thumbnails: %{large: "/images/demo/tame-impala.jpg"}
    )
  end

  def album do
    struct(Album,
      id: "album1",
      uri: "spotify:album:album1",
      name: "Currents",
      spotify_url: "https://open.spotify.com/album/album1",
      album_type: "album",
      album_group: "album",
      artists: [artist()],
      release_date: "2015-07-17",
      release_date_precision: "day",
      thumbnails: %{large: "/images/demo/currents.jpg", small: "/images/demo/currents.jpg"},
      genres: [],
      copyrights: [],
      tracks: []
    )
  end

  def track do
    struct(Track,
      id: "track1",
      uri: "spotify:track:track1",
      name: "Let It Happen",
      spotify_url: "https://open.spotify.com/track/track1",
      duration_ms: 468_000,
      track_number: 1,
      disc_number: 1,
      artists: [artist()],
      album: album()
    )
  end

  def playlist(tracks \\ :not_fetched) do
    struct(Playlist,
      id: "playlist1",
      uri: "spotify:playlist:playlist1",
      name: "Chilled Vibes",
      spotify_url: "https://open.spotify.com/playlist/playlist1",
      description: "Your evening soundtrack",
      thumbnails: %{large: "/images/demo/slow-rush.jpg"},
      tracks: tracks
    )
  end

  def device do
    struct(Device,
      id: "echo1",
      name: "This Echo Show",
      type: "Speaker",
      is_active: true,
      is_private_session: false,
      is_restricted: false,
      volume_percent: 80
    )
  end

  def player, do: %Player{status: :playing, item: track(), progress_ms: 192_000, device: device()}
end
