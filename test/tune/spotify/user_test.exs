defmodule Tune.Spotify.Schema.UserTest do
  use ExUnit.Case, async: true
  alias Tune.Spotify.Schema.User

  test "missing subscription metadata allows Spotify to enforce playback eligibility" do
    assert User.premium?(%User{name: "Listener", avatar_url: nil, product: nil})
  end

  test "explicit free subscription still disables controls" do
    refute User.premium?(%User{name: "Listener", avatar_url: nil, product: "free"})
  end
end
