defmodule LE940.Loader do
  def process(%LinkEdit{} = state) do
    raise "is this called?"
    state
  end

  def load(%LinkEdit{} = state, {path} = _parameters) do
    _assembly_info = File.read!(path) |> :erlang.binary_to_term([:unsafe]) |> Map.keys() |> dbg
    state
  end

  def load(%LinkEdit{} = state, {stash_addr, execution_addr, path} = _parameters) do
    new_state = %{state | memory_lc: stash_addr, relocation_lc: execution_addr}
    assembly_info = File.read!(path) |> :erlang.binary_to_term([:safe])
    Map.keys(assembly_info) |> dbg()
    sample("Memory Sample", assembly_info.mem)
    sample("Symbol Sample", assembly_info.symb)
    new_state
  end

  defp sample(label, map) when is_binary(label) and is_map(map) do
    sample = Map.to_list(map) |> Enum.shuffle() |> Enum.take(10)
    IO.puts(label)
    dbg(sample)
    # map |> dbg
  end

  defp sample(label, alist) when is_binary(label) and is_list(alist) do
    sample = Enum.shuffle(alist) |> Enum.take(10)
    IO.puts(label)
    dbg(sample)
  end
end
