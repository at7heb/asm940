defmodule LE940.Resolver do
  def process(%LinkEdit{} = state) do
    LE940.Loader.get_locations_to_resolve(state.memory)
    # |> Enum.take_random(10)
    |> Enum.reduce(state, fn {addr, val}, temp_state ->
      resolve_one_location(temp_state, addr, val)
    end)

    state
  end

  defp resolve_one_location(%LinkEdit{} = state, addr, %A940.MemoryValue{
         address_expression: [{:symbol, name}]
       }) do
    # {:resolve0, name} |> dbg
    symbol_value = Map.get(state.exported_symbols, name)

    if symbol_value != nil do
      %A940.Address{value: value, relocation: 0, expression_tokens: []} = symbol_value
      {:resolve1, addr, name, value} |> dbg
    else
      IO.puts(
        "!!!!!!!!!!!!!!!!!!!!!need non-exported symbol #{name} at #{Integer.to_string(addr, 8)}"
      )
    end

    state
  end

  defp resolve_one_location(%LinkEdit{} = state, _addr, %A940.MemoryValue{
         address_expression: address_expr
       }) do
    value = A940.Expression.evaluate(address_expr, state.exported_symbols, 0, 0, 10)
    {:resolve1, address_expr, value} |> dbg
    state
  end

  @doc """
  resolve local symbols
  """
  def resolve_local_symbols(%A940.MakeElixirBinary{} = assembly_info, %{} = relocated_symbols) do
    Enum.take_random(assembly_info.mem, 5) |> dbg()
    Map.to_list(relocated_symbols) |> Enum.take_random(5)
    assembly_info
  end
end
