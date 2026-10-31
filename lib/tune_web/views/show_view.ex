defmodule TuneWeb.ShowView do
  @moduledoc false
  use TuneWeb, :view

  alias Tune.Spotify.Schema.Show
  alias TuneWeb.EpisodeView

  @spec artwork(Show.t()) :: String.t()
  defp artwork(%Show{} = item), do: TuneWeb.RemoteView.artwork(item)

  @spec total_episodes(pos_integer()) :: String.t()
  defp total_episodes(total_episodes) do
    ngettext(
      "1 episode",
      "%{count} episodes",
      total_episodes
    )
  end

  @spec rich_description(Show.t()) :: Phoenix.HTML.safe()
  defp rich_description(%Show{description: description}) do
    description
    |> ExAutolink.link(args: %{rel: "nofollow noreferrer", target: "_blank"})
    |> raw()
  end
end
