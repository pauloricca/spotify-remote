defmodule Tune.Spotify.Schema.User do
  @moduledoc """
  Represents a Spotify user.
  """

  @enforce_keys [:name, :avatar_url, :product]
  defstruct [:name, :avatar_url, :product]

  @type t :: %__MODULE__{
          name: String.t(),
          avatar_url: String.t() | nil,
          product: String.t() | nil
        }

  @spec premium?(t()) :: boolean()
  # Development-mode Spotify apps require Premium, but /me no longer
  # includes product. Let the playback API enforce eligibility in that case.
  def premium?(%__MODULE__{product: nil}), do: true
  def premium?(%__MODULE__{product: product}), do: product == "premium"
end
