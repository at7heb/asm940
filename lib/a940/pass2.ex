defmodule A940.Pass2 do
  def run(%A940.State{} = state) do
    state
    |> A940.Resolve.resolve_symbols()
    |> A940.Resolve.update_symbol_references()
    |> A940.Listing.make_listing()
  end
end
