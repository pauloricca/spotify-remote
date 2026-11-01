defmodule TuneWeb.RemoteView do
  @moduledoc false
  use TuneWeb, :view

  alias Tune.Spotify.Schema.{Track, Episode, Playlist}
  alias TuneWeb.{HeaderView, PlayerView, SearchView}

  def playlist_item?(%{uri: uri}) when is_binary(uri),
    do: Regex.match?(~r/^spotify:(track|episode):[A-Za-z0-9]+$/, uri)

  def playlist_item?(_), do: false

  def artwork(%Track{album: album}), do: artwork(album)

  def artwork(%{thumbnails: images}) when is_map(images),
    do: images[:large] || images[:medium] || images[:small] || "/images/music-placeholder.svg"

  def artwork(_), do: "/images/music-placeholder.svg"

  def byline(%{artists: artists}) when is_list(artists),
    do: Enum.map_join(artists, ", ", & &1.name)

  def byline(%Episode{show: %{name: name}}), do: name
  def byline(%{publisher: %{name: name}}), do: name || "Podcast"
  def byline(%Playlist{}), do: "Playlist"
  def byline(_), do: "Artist"

  def context(%Track{album: %{id: id} = album}) when is_binary(id), do: album
  def context(%Episode{show: %{id: id} = show}) when is_binary(id), do: show
  def context(_), do: nil

  def saved?(saved_items, item), do: Map.get(saved_items, item.uri, false)

  def library_url(socket, kind, next) do
    params =
      next
      |> URI.parse()
      |> Map.get(:query)
      |> case do
        nil -> %{}
        query -> URI.decode_query(query)
      end

    Routes.explorer_path(
      socket,
      :library,
      Map.take(params, ["offset", "after"]) |> Map.put("type", kind)
    )
  end

  def error_message(403), do: "Reconnect Spotify to allow access to your library."

  def error_message({:quota_exceeded, seconds}),
    do: "Spotify's API quota is exhausted. Try again in #{seconds} seconds."

  def error_message({:rate_limited, seconds}),
    do: "Spotify is receiving too many requests. Try again in #{seconds} seconds."

  def error_message(429), do: "Spotify is receiving too many requests. Please try again shortly."
  def error_message(_), do: "Spotify is unavailable right now. Please try again."
end
