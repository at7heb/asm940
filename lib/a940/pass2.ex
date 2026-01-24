defmodule A940.Pass2 do
  def run(%A940.State{} = state) do
    state
    # |> A940.Memory.dump_memory("first")
    |> A940.Resolve.resolve_symbols()
    # |> A940.Memory.dump_memory("second")
    |> A940.Resolve.update_symbol_references()
    # |> A940.Memory.dump_memory("third")
    |> A940.Listing.make_listing()
  end
end
