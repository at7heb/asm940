defmodule A940.Pass2 do
  def run(%A940.State{} = state) do
    A940.Listing.make_listing(state)
  end
end
