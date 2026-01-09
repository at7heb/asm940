defmodule A940.Pass2 do
  def run(%A940.State{} = state) do
    state
    |> A940.Listing.make_listing()
    |> A940.Resolve.resolve_symbols()
  end
end
