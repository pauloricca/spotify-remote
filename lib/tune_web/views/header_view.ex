defmodule TuneWeb.HeaderView do
  @moduledoc false
  use TuneWeb, :view

  defp user_avatar(user) do
    case user.avatar_url do
      nil -> fallback_avatar(user.name)
      url -> url
    end
  end

  defp fallback_avatar(_name), do: "/images/music-placeholder.svg"
end
