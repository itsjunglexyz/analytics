defmodule Plausible.Stats.Segment do
  @spec validate_segment(map()) :: {:ok, map()} | {:error, binary()}
  def validate_segment(segment) do
    {:ok, segment}
  end
end
