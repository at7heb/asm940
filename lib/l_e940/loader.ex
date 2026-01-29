defmodule LE940.Loader do
  def process(%LinkEdit{} = state) do
    state
  end

  def load(%LinkEdit{} = state, {path} = _parameters) do
    _assembly_info = File.read!(path) |> :erlang.binary_to_term([:safe]) |> Map.keys() |> dbg
    state
  end

  def load(%LinkEdit{} = state, {stash_addr, execution_addr, path} = _parameters) do
    new_state = %{state | memory_lc: stash_addr, relocation_lc: execution_addr}
    assembly_info = File.read!(path) |> :erlang.binary_to_term([:safe])
    Map.keys(assembly_info) |> dbg()
    new_state
  end
end
