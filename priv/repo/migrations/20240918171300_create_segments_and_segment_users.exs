defmodule Plausible.Repo.Migrations.CreateSegmentsAndSegmentUsers do
  use Ecto.Migration

  def change do
    create table(:segments) do
      add :name, :string, null: false
      add :segment_data, :map, null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false

      add :description, :text

      timestamps()
    end

    create index(:segments, [:segment_data], using: :gin)
    create index(:segments, [:site_id])

    create table(:segment_collaborators, primary_key: false) do
      add :role, :string, null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :segment_id, references(:segments, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:segment_collaborators, [:user_id, :segment_id])
  end
end
