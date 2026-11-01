defmodule Tune.Spotify.Client.HTTP do
  @moduledoc """
  This module implements the `Tune.Spotify.Client` behaviour and interacts with the actual Spotify API.

  Reference docs are available at: <https://developer.spotify.com/documentation/web-api/>
  """

  @behaviour Tune.Spotify.Client

  alias Tune.Spotify.Schema.{
    Album,
    Artist,
    Copyright,
    Device,
    Episode,
    Player,
    Playlist,
    Publisher,
    Show,
    Track,
    User
  }

  alias Tune.Spotify.Auth
  alias Ueberauth.Auth.Credentials

  require Logger

  @base_url "https://api.spotify.com/v1"
  @refresh_url "https://accounts.spotify.com/api/token"

  @json_headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]
  @form_headers [
    {"Content-Type", "application/x-www-form-urlencoded"}
  ]
  @default_limit 20
  @default_offset 0

  ################################################################################
  ################################ AUTH/PROFILE ##################################
  ################################################################################

  @impl true
  def get_profile(token) do
    case json_get(base_url() <> "/me", auth_headers(token)) do
      {:ok, %{status: 200} = response} ->
        user =
          response.body
          |> Jason.decode!()
          |> parse_profile()

        {:ok, user}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def get_token(refresh_token) do
    headers = [
      {"Authorization", "Basic #{Auth.base64_encoded_credentials()}"}
    ]

    case form_post(
           Application.get_env(:tune, :spotify_token_url, @refresh_url),
           %{grant_type: "refresh_token", refresh_token: refresh_token},
           headers
         ) do
      {:ok, %{status: 200} = response} ->
        auth_data =
          response.body
          |> Jason.decode!()
          |> parse_auth_data(refresh_token)

        {:ok, auth_data}

      other_response ->
        handle_errors(other_response)
    end
  end

  ################################################################################
  #################################### PLAYER ####################################
  ################################################################################

  @impl true
  def get_devices(token) do
    case json_get(base_url() <> "/me/player/devices", auth_headers(token)) do
      {:ok, %{status: 200} = response} ->
        devices =
          response.body
          |> Jason.decode!()
          |> Map.get("devices")
          |> Enum.map(&parse_device/1)

        {:ok, devices}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def next(token) do
    case post(base_url() <> "/me/player/next", <<>>, auth_headers(token)) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def now_playing(token) do
    case json_get(base_url() <> "/me/player?additional_types=episode", auth_headers(token)) do
      {:ok, %{status: 204}} ->
        {:ok, %Player{}}

      {:ok, %{status: 200} = response} ->
        {:ok,
         response.body
         |> Jason.decode!()
         |> parse_now_playing()}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def pause(token) do
    case json_put(base_url() <> "/me/player/pause", %{}, auth_headers(token)) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def play(token) do
    case json_put(base_url() <> "/me/player/play", %{}, auth_headers(token)) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def play(token, uri) do
    payload =
      if uri =~ "track" or uri =~ "episode" do
        %{uris: [uri]}
      else
        %{context_uri: uri}
      end

    case json_put(base_url() <> "/me/player/play", payload, auth_headers(token)) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def play(token, uri, context_uri) do
    payload = %{
      context_uri: context_uri,
      offset: %{
        uri: uri
      }
    }

    case json_put(base_url() <> "/me/player/play", payload, auth_headers(token)) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def prev(token) do
    case post(base_url() <> "/me/player/previous", <<>>, auth_headers(token)) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def seek(token, position_ms) do
    params = %{
      position_ms: position_ms
    }

    case put(
           base_url() <> "/me/player/seek?" <> URI.encode_query(params),
           <<>>,
           auth_headers(token)
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def set_volume(token, volume_percent) do
    params = %{
      volume_percent: volume_percent
    }

    case put(
           base_url() <> "/me/player/volume?" <> URI.encode_query(params),
           <<>>,
           auth_headers(token)
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def transfer_playback(token, device_id) do
    params = %{
      device_ids: [device_id]
    }

    case json_put(base_url() <> "/me/player", params, auth_headers(token)) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      other_response ->
        handle_errors(other_response)
    end
  end

  ################################################################################
  ################################### CONTENT ####################################
  ################################################################################

  @impl true
  def get_album(token, album_id) do
    params = %{
      market: "from_token"
    }

    case json_get(
           base_url() <> "/albums/" <> album_id <> "?" <> URI.encode_query(params),
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        album =
          response.body
          |> Jason.decode!()
          |> parse_album()

        {:ok, album}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def get_artist(token, artist_id) do
    case json_get(
           base_url() <> "/artists/" <> artist_id,
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        artist =
          response.body
          |> Jason.decode!()
          |> parse_artist()

        {:ok, artist}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def get_artist_albums(token, artist_id, opts) do
    limit = opts |> Keyword.get(:limit, 10) |> max(1) |> min(10)
    offset = Keyword.get(opts, :offset, @default_offset)
    album_group = Keyword.get(opts, :album_group, :all)

    params = %{
      market: "from_token",
      limit: limit,
      offset: offset
    }

    params =
      case album_group do
        :all -> params
        other_group -> Map.put(params, :include_groups, other_group)
      end

    case json_get(
           base_url() <> "/artists/" <> artist_id <> "/albums" <> "?" <> URI.encode_query(params),
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        albums =
          response.body
          |> Jason.decode!()
          |> parse_artist_albums()

        {:ok, albums}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def get_episodes(token, show_id) do
    params = %{
      market: "from_token"
    }

    case json_get(
           base_url() <> "/shows/" <> show_id <> "/episodes" <> "?" <> URI.encode_query(params),
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        episodes =
          response.body
          |> Jason.decode!()
          |> Map.get("items")
          |> Enum.map(&parse_episode/1)

        {:ok, episodes}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def get_playlist(token, playlist_id) do
    params = %{
      market: "from_token"
    }

    case json_get(
           base_url() <> "/playlists/" <> playlist_id <> "?" <> URI.encode_query(params),
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        playlist =
          response.body
          |> Jason.decode!()
          |> parse_playlist()

        {:ok, playlist}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def get_recommendations_from_artists(token, artist_ids) do
    params = %{
      seed_artists: Enum.join(artist_ids, ","),
      market: "from_token"
    }

    case json_get(
           base_url() <> "/recommendations" <> "?" <> URI.encode_query(params),
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        tracks =
          response.body
          |> Jason.decode!()
          |> Map.get("tracks")
          |> Enum.map(&parse_track/1)

        {:ok, tracks}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def get_show(token, show_id) do
    params = %{
      market: "from_token"
    }

    case json_get(
           base_url() <> "/shows/" <> show_id <> "?" <> URI.encode_query(params),
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        show =
          response.body
          |> Jason.decode!()
          |> parse_show()

        {:ok, show}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def get_episode(token, episode_id) do
    params = %{
      market: "from_token"
    }

    case json_get(
           base_url() <> "/episodes/" <> episode_id <> "?" <> URI.encode_query(params),
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        episode =
          response.body
          |> Jason.decode!()
          |> parse_episode_with_metadata()

        {:ok, episode}

      other_response ->
        handle_errors(other_response)
    end
  end

  @default_limit 20
  @impl true
  def recently_played_tracks(token, opts) do
    params = %{
      limit: Keyword.get(opts, :limit, @default_limit)
    }

    params =
      case Keyword.get(opts, :before) do
        nil -> params
        before_time -> Map.put(params, :before, DateTime.to_unix(before_time, :millisecond))
      end

    params =
      case Keyword.get(opts, :after) do
        nil -> params
        after_time -> Map.put(params, :after, DateTime.to_unix(after_time, :millisecond))
      end

    case json_get(
           base_url() <> "/me/player/recently-played?" <> URI.encode_query(params),
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        results =
          response.body
          |> Jason.decode!()
          |> get_in(["items", Access.all(), "track"])
          |> Enum.map(&parse_track/1)

        {:ok, results}

      other_response ->
        handle_errors(other_response)
    end
  end

  @default_types [:track]

  @impl true
  def search(token, q, opts) do
    limit = opts |> Keyword.get(:limit, 10) |> max(1) |> min(10)
    offset = Keyword.get(opts, :offset, @default_offset)
    types = Keyword.get(opts, :types, @default_types)

    params = %{
      q: q,
      type: Enum.join(types, ","),
      market: "from_token",
      limit: limit,
      offset: offset
    }

    case json_get(base_url() <> "/search?" <> URI.encode_query(params), auth_headers(token)) do
      {:ok, %{status: 200} = response} ->
        results =
          response.body
          |> Jason.decode!()
          |> parse_search_results(types)

        {:ok, results}

      other_response ->
        handle_errors(other_response)
    end
  end

  @default_time_range "medium_term"
  @impl true
  def top_tracks(token, opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    offset = Keyword.get(opts, :offset, @default_offset)
    time_range = Keyword.get(opts, :time_range, @default_time_range)

    params = %{
      limit: limit,
      offset: offset,
      time_range: time_range
    }

    case json_get(
           base_url() <> "/me/top/tracks?" <> URI.encode_query(params),
           auth_headers(token)
         ) do
      {:ok, %{status: 200} = response} ->
        results =
          response.body
          |> Jason.decode!()
          |> Map.get("items")
          |> Enum.map(&parse_track/1)

        {:ok, results}

      other_response ->
        handle_errors(other_response)
    end
  end

  @impl true
  def library(token, kind, opts) do
    {path, wrapper, parser} =
      case kind do
        :playlists -> {"/me/playlists", nil, &parse_playlist/1}
        :albums -> {"/me/albums", "album", &parse_album/1}
        :tracks -> {"/me/tracks", "track", &parse_track/1}
        :shows -> {"/me/shows", "show", &parse_show/1}
        :artists -> {"/me/following", nil, &parse_artist/1}
      end

    params = %{limit: 24}

    params =
      if kind == :artists,
        do: Map.merge(params, %{type: "artist", after: Keyword.get(opts, :after)}),
        else: Map.put(params, :offset, Keyword.get(opts, :offset, 0))

    params = params |> Enum.reject(fn {_key, value} -> is_nil(value) end) |> Map.new()

    with {:ok, body} <- get_json(token, path, params) do
      page = if kind == :artists, do: Map.get(body, "artists", %{}), else: body
      items = page |> Map.get("items", []) |> Enum.reject(&is_nil/1)
      items = if wrapper, do: Enum.map(items, &Map.get(&1, wrapper)), else: items

      {:ok,
       %{
         items: items |> Enum.reject(&is_nil/1) |> Enum.map(parser),
         total: Map.get(page, "total", 0),
         next: Map.get(page, "next")
       }}
    end
  end

  @impl true
  def queue(token) do
    with {:ok, body} <- get_json(token, "/me/player/queue", %{}) do
      {:ok,
       %{
         currently_playing: parse_playable(Map.get(body, "currently_playing")),
         queue:
           body |> Map.get("queue", []) |> Enum.map(&parse_playable/1) |> Enum.reject(&is_nil/1)
       }}
    end
  end

  @impl true
  def saved_items(token, uris),
    do: get_json(token, "/me/library/contains", %{uris: Enum.join(uris, ",")})

  @impl true
  def set_saved(token, uri, saved) when is_boolean(saved) do
    method = if saved, do: :put, else: :delete

    Finch.build(
      method,
      base_url() <> "/me/library?" <> URI.encode_query(%{uris: uri}),
      auth_headers(token)
    )
    |> Tune.Spotify.Transport.request()
    |> mutation_result()
  end

  @impl true
  def set_shuffle(token, enabled) when is_boolean(enabled),
    do: playback_setting(token, "shuffle", %{state: enabled})

  @impl true
  def set_repeat(token, mode) when mode in ["off", "context", "track"],
    do: playback_setting(token, "repeat", %{state: mode})

  defp playback_setting(token, setting, params) do
    put(
      base_url() <> "/me/player/" <> setting <> "?" <> URI.encode_query(params),
      <<>>,
      auth_headers(token)
    )
    |> mutation_result()
  end

  defp mutation_result({:ok, %{status: status}}) when status in 200..299, do: :ok
  defp mutation_result(error), do: handle_errors(error)

  defp get_json(token, path, params) do
    case json_get(base_url() <> path <> "?" <> URI.encode_query(params), auth_headers(token)) do
      {:ok, %{status: 200, body: body}} -> Jason.decode(body)
      {:ok, %{status: 204}} -> {:ok, %{}}
      error -> handle_errors(error)
    end
  end

  defp parse_playable(%{"type" => "episode"} = item), do: parse_episode_with_metadata(item)
  defp parse_playable(%{"type" => "track"} = item), do: parse_track(item)
  defp parse_playable(_), do: nil

  defp base_url, do: Application.get_env(:tune, :spotify_api_base_url, @base_url)

  defp auth_headers(token) do
    [{"Authorization", "Bearer #{token}"}]
  end

  defp json_get(url, headers) do
    get(url, @json_headers ++ headers)
  end

  defp json_put(url, params, headers) do
    put(url, Jason.encode!(params), @json_headers ++ headers)
  end

  defp form_post(url, params, headers) do
    post(url, URI.encode_query(params), @form_headers ++ headers)
  end

  defp get(url, headers) do
    Finch.build(:get, url, headers)
    |> Tune.Spotify.Transport.request()
  end

  defp post(url, body, headers) do
    Finch.build(:post, url, headers, body)
    |> Tune.Spotify.Transport.request()
  end

  defp put(url, body, headers) do
    Finch.build(:put, url, headers, body)
    |> Tune.Spotify.Transport.request()
  end

  defp parse_profile(data) do
    %User{
      name: Map.get(data, "display_name") || Map.get(data, "id") || "Spotify",
      avatar_url: get_in(data, ["images", Access.at(0), "url"]),
      product: Map.get(data, "product")
    }
  end

  defp handle_errors(response) do
    case response do
      {:ok, %{status: 401 = status, body: body}} ->
        if body =~ "expired" do
          track_error(:expired_token, status)
          {:error, :expired_token}
        else
          track_error(:invalid_token, status)
          {:error, :invalid_token}
        end

      {:ok, %{status: status, body: body}} ->
        track_error(:error_response, status, body)
        {:error, status}

      {:error, reason} = error ->
        track_connection_error(reason)
        error
    end
  end

  defp track_error(type, status) do
    Logger.warn(fn ->
      "Spotify HTTP Api error: #{type}"
    end)

    :telemetry.execute([:tune, :spotify, :api_error], %{count: 1}, %{
      error_type: type,
      status: status
    })
  end

  defp track_error(type, status, body) do
    Logger.warn(fn ->
      "Spotify HTTP Api error: #{status}, #{body}"
    end)

    :telemetry.execute([:tune, :spotify, :api_error], %{count: 1}, %{
      error_type: type,
      status: status
    })
  end

  defp track_connection_error(reason) do
    Logger.warn(fn ->
      "Spotify HTTP Api connection error: #{inspect(reason)}"
    end)

    :telemetry.execute([:tune, :spotify, :api_error], %{count: 1}, %{
      error_type: :connection_error
    })
  end

  defp parse_auth_data(data, refresh_token) do
    %Credentials{
      expires: true,
      expires_at: OAuth2.Util.unix_now() + data["expires_in"],
      refresh_token: data["refresh_token"] || refresh_token,
      scopes: [data["scope"]],
      token: data["access_token"],
      token_type: data["token_type"]
    }
  end

  defp parse_now_playing(%{"item" => nil}), do: %Player{}

  defp parse_now_playing(data) do
    case Map.get(data, "currently_playing_type") do
      # Spotify reports "unknown" while queueing a new album or show.
      type when type in [nil, "unknown", "ad"] ->
        %Player{}

      "track" ->
        parse_player(data, parse_track(Map.get(data, "item")))

      "episode" ->
        parse_player(data, parse_episode_with_metadata(Map.get(data, "item")))
    end
  end

  defp parse_player(data, item) do
    %Player{
      status: if(Map.get(data, "is_playing"), do: :playing, else: :paused),
      item: item,
      progress_ms: Map.get(data, "progress_ms") || 0,
      device: parse_device(Map.get(data, "device")),
      shuffle_state: Map.get(data, "shuffle_state", false),
      repeat_state: Map.get(data, "repeat_state", "off")
    }
  end

  defp parse_track(item) do
    %Track{
      id: Map.get(item, "id"),
      uri: Map.get(item, "uri"),
      name: Map.get(item, "name"),
      spotify_url: parse_spotify_url(item),
      duration_ms: Map.get(item, "duration_ms"),
      track_number: Map.get(item, "track_number"),
      disc_number: Map.get(item, "disc_number"),
      artists:
        item
        |> Map.get("artists", [])
        |> Enum.map(&parse_artist/1),
      album:
        item
        |> Map.get("album")
        |> parse_album()
    }
  end

  defp parse_album_track(item) do
    %Track{
      id: Map.get(item, "id"),
      uri: Map.get(item, "uri"),
      name: Map.get(item, "name"),
      spotify_url: parse_spotify_url(item),
      duration_ms: Map.get(item, "duration_ms"),
      track_number: Map.get(item, "track_number"),
      disc_number: Map.get(item, "disc_number"),
      artists: :not_fetched,
      album: :not_fetched
    }
  end

  defp parse_artist(item) do
    %Artist{
      id: Map.get(item, "id"),
      uri: Map.get(item, "uri"),
      name: Map.get(item, "name"),
      spotify_url: parse_spotify_url(item),
      albums: :not_fetched,
      total_albums: :not_fetched,
      genres: Map.get(item, "genres") || [],
      thumbnails:
        if Map.has_key?(item, "images") do
          item
          |> Map.get("images")
          |> parse_thumbnails()
        else
          :not_fetched
        end
    }
  end

  defp parse_album(nil), do: :not_fetched

  defp parse_album(item) do
    %Album{
      id: Map.get(item, "id"),
      uri: Map.get(item, "uri"),
      name: Map.get(item, "name"),
      spotify_url: parse_spotify_url(item),
      album_type: Map.get(item, "album_type"),
      album_group: Map.get(item, "album_group", "album"),
      release_date: Map.get(item, "release_date"),
      release_date_precision: Map.get(item, "release_date_precision"),
      artists:
        item
        |> Map.get("artists", [])
        |> Enum.map(&parse_artist/1),
      thumbnails:
        item
        |> Map.get("images")
        |> parse_thumbnails(),
      genres: Map.get(item, "genres"),
      copyrights:
        if Map.has_key?(item, "copyrights") do
          item
          |> Map.get("copyrights")
          |> Enum.map(&parse_copyright/1)
        else
          :not_fetched
        end,
      tracks:
        if Map.has_key?(item, "tracks") do
          item
          |> get_in(["tracks", "items"])
          |> Enum.map(&parse_album_track/1)
        else
          :not_fetched
        end
    }
  end

  defp parse_artist_albums(results) do
    total = Map.get(results, "total")

    albums =
      results
      |> Map.get("items")
      |> Enum.map(&parse_album/1)

    %{albums: albums, total: total}
  end

  defp parse_episode_with_metadata(item) do
    %Episode{
      id: Map.get(item, "id"),
      uri: Map.get(item, "uri"),
      name: Map.get(item, "name"),
      spotify_url: parse_spotify_url(item),
      description: Map.get(item, "description"),
      duration_ms: Map.get(item, "duration_ms"),
      thumbnails:
        item
        |> Map.get("images")
        |> parse_thumbnails(),
      show:
        item
        |> Map.get("show")
        |> parse_show(),
      publisher: %Publisher{
        name: get_in(item, ["show", "publisher"])
      }
    }
  end

  defp parse_episode(item) do
    %Episode{
      id: Map.get(item, "id"),
      uri: Map.get(item, "uri"),
      name: Map.get(item, "name"),
      spotify_url: parse_spotify_url(item),
      description: Map.get(item, "description"),
      duration_ms: Map.get(item, "duration_ms"),
      thumbnails:
        item
        |> Map.get("images")
        |> parse_thumbnails(),
      show: :not_fetched,
      publisher: :not_fetched
    }
  end

  defp parse_show(nil), do: :not_fetched

  defp parse_show(item) do
    %Show{
      id: Map.get(item, "id"),
      uri: Map.get(item, "uri"),
      name: Map.get(item, "name"),
      spotify_url: parse_spotify_url(item),
      description: Map.get(item, "description"),
      episodes: :not_fetched,
      publisher: %Publisher{
        name: Map.get(item, "publisher")
      },
      thumbnails:
        item
        |> Map.get("images")
        |> parse_thumbnails(),
      total_episodes: Map.get(item, "total_episodes")
    }
  end

  defp parse_thumbnails(nil), do: %{}

  defp parse_thumbnails(images) do
    Enum.into(images, %{}, fn
      %{"height" => height, "url" => url} when height in 0..199 -> {:small, url}
      %{"height" => height, "url" => url} when height in 200..449 -> {:medium, url}
      %{"height" => height, "url" => url} when height >= 450 -> {:large, url}
      %{"url" => url} -> {:large, url}
    end)
  end

  defp present_items(items) when is_list(items), do: Enum.filter(items, &is_map/1)
  defp present_items(_), do: []

  defp parse_search_results(results, types) do
    Enum.reduce(types, %{}, fn
      :album, acc ->
        albums =
          results
          |> get_in(["albums", "items"])
          |> present_items()
          |> Enum.map(&parse_album/1)

        total = get_in(results, ["albums", "total"])

        Map.put(acc, :album, %{items: albums, total: total})

      :artist, acc ->
        artists =
          results
          |> get_in(["artists", "items"])
          |> present_items()
          |> Enum.map(&parse_artist/1)

        total = get_in(results, ["artists", "total"])

        Map.put(acc, :artist, %{items: artists, total: total})

      :track, acc ->
        tracks =
          results
          |> get_in(["tracks", "items"])
          |> present_items()
          |> Enum.map(&parse_track/1)

        total = get_in(results, ["tracks", "total"])

        Map.put(acc, :track, %{items: tracks, total: total})

      :show, acc ->
        shows =
          results
          |> get_in(["shows", "items"])
          |> present_items()
          |> Enum.map(&parse_show/1)

        total = get_in(results, ["shows", "total"])

        Map.put(acc, :show, %{items: shows, total: total})

      :episode, acc ->
        episodes =
          results
          |> get_in(["episodes", "items"])
          |> present_items()
          |> Enum.map(&parse_episode/1)

        total = get_in(results, ["episodes", "total"])

        Map.put(acc, :episode, %{items: episodes, total: total})

      :playlist, acc ->
        playlists =
          results
          |> get_in(["playlists", "items"])
          |> present_items()
          |> Enum.map(&parse_playlist/1)

        total = get_in(results, ["playlists", "total"])

        Map.put(acc, :playlist, %{items: playlists, total: total})
    end)
  end

  defp parse_playlist(item) do
    %Playlist{
      id: Map.get(item, "id"),
      uri: Map.get(item, "uri"),
      name: Map.get(item, "name"),
      spotify_url: parse_spotify_url(item),
      description: Map.get(item, "description"),
      thumbnails:
        item
        |> Map.get("images")
        |> parse_thumbnails(),
      tracks:
        case get_in(item, ["items", "items"]) || get_in(item, ["tracks", "items"]) do
          nil ->
            :not_fetched

          items ->
            items
            |> Enum.map(fn entry -> Map.get(entry, "item") || Map.get(entry, "track") end)
            |> Enum.reject(&is_nil/1)
            |> Enum.map(&parse_track/1)
        end
    }
  end

  defp parse_device(nil), do: nil

  defp parse_device(device) do
    %Device{
      id: Map.get(device, "id"),
      is_active: Map.get(device, "is_active"),
      is_private_session: Map.get(device, "is_private_session"),
      is_restricted: Map.get(device, "is_restricted"),
      name: Map.get(device, "name"),
      type: Map.get(device, "type"),
      volume_percent: Map.get(device, "volume_percent")
    }
  end

  defp parse_spotify_url(item) do
    get_in(item, ["external_urls", "spotify"])
  end

  defp parse_copyright(copyright) do
    %Copyright{
      text: Map.get(copyright, "text"),
      type: Map.get(copyright, "type")
    }
  end
end
