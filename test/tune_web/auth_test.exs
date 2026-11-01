defmodule TuneWeb.AuthTest do
  use TuneWeb.ConnCase

  test "authorization sends valid parameters and binds state to the session", %{conn: conn} do
    conn = get(conn, "/auth/spotify")
    params = conn |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    assert params["show_dialog"] == "false"
    assert params["scope"] =~ "user-modify-playback-state"
    assert params["scope"] =~ "user-library-read"
    assert params["scope"] =~ "user-library-modify"
    assert params["scope"] =~ "playlist-modify-public"
    assert params["scope"] =~ "playlist-modify-private"
    refute params["scope"] =~ ","
    assert byte_size(params["state"]) >= 32
    assert params["state"] == get_session(conn, :spotify_oauth_state)
  end

  test "callback without a matching state returns to login before token exchange", %{conn: conn} do
    conn = get(conn, "/auth/spotify/callback", code: "unused", state: "wrong")
    assert redirected_to(conn) == "/auth/login"
  end
end
