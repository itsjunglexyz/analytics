defmodule Plausible.SegmentCollaborator do
  @moduledoc """
  Schema for linking users with the segments they are collaborating on.
  """
  use Plausible
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @primary_key false
  @roles [:owner]

  @derive {Jason.Encoder, only: [:role]}

  schema "segment_collaborators" do
    field :role, Ecto.Enum, values: @roles, default: :owner

    belongs_to :user, Plausible.Auth.User
    belongs_to :segment, Plausible.Segment

    timestamps()
  end

  def changeset(segment_collaborator, attrs) do
    segment_collaborator
    |> cast(attrs, [:user_id, :segment_id])
    |> validate_required([:user_id, :segment_id])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:user_id, :segment_id])
  end
end
