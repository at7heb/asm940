defmodule LE940.Loader do
  import Bitwise

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
    sample("Memory Sample", assembly_info.mem)
    sample("Symbol Sample", assembly_info.symb)

    sample(
      "Expression Sample",
      Map.filter(assembly_info.symb, fn {_key, val} -> val.expression_tokens != [] end)
    )

    new_state = relocate_symbols(new_state, assembly_info.symb)
    sample("relocated symbols", new_state.symbols)
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

  defp relocate_symbols(%LinkEdit{} = state, %{} = symb) do
    state_symbols =
      Map.to_list(symb)
      |> Enum.reduce(%{}, fn {name, value}, new_symbol_map ->
        Map.put(new_symbol_map, name, relocate_symbol(state.relocation_lc, value))
      end)

    %{state | symbols: state_symbols}
  end

  # to relocate, must not be defined by an expression.
  defp relocate_symbol(
         execution_lc,
         %A940.Address{expression_tokens: [], relocation: relocation} = addr
       ) do
    %{addr | value: addr.value + relocation * execution_lc &&& addr.mask, relocation: 0}
  end

  # otherwise return the symbol, and a later phase will resolve the values.
  # the expression probably involves a symbol from another assembly.
  defp relocate_symbol(_execution_lc, %A940.Address{} = addr), do: addr
end
