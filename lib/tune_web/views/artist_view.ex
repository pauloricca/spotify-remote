defmodule TuneWeb.ArtistView do
  @moduledoc false
  use TuneWeb, :view

  alias Tune.Spotify.Schema.{Album, Artist}
  alias Tune.Link
  alias TuneWeb.PaginationView

  @spec artwork(Artist.t()) :: String.t()
  defp artwork(%Artist{} = item), do: TuneWeb.RemoteView.artwork(item)

  @spec thumbnail(Album.t()) :: String.t()
  defp thumbnail(album), do: TuneWeb.RemoteView.artwork(album)

  @spec total_albums(Artist.t()) :: String.t()
  defp total_albums(artist) do
    ngettext("1 album", "%{count} albums", artist.total_albums)
  end

  defp album_groups do
    [
      all: gettext("All"),
      album: gettext("Album"),
      single: gettext("Single"),
      appears_on: gettext("Appears On"),
      compilation: gettext("Compilation")
    ]
  end

  @spec genre(Artist.t()) :: nil | String.t()
  defp genre(%Artist{genres: genres}) when genres in [nil, []], do: nil

  defp genre(%Artist{genres: genres}) do
    content_tag :h3, class: "genre" do
      Enum.join(genres, ", ")
    end
  end
end
