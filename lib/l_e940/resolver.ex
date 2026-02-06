defmodule LE940.Resolver do
  def process(%LinkEdit{} = state) do
    "Hello, Resolver here" |> dbg

    LE940.Loader.get_locations_to_resolve(state.memory)
    |> Enum.take_random(10)
    |> Enum.reduce(state, fn {addr, val}, temp_state ->
      resolve_one_location(temp_state, addr, val)
    end)

    state
  end

  defp resolve_one_location(%LinkEdit{} = state, addr, %A940.MemoryValue{
         address_expression: [{:symbol, name}]
       }) do
    {:resolve0, name, state.symbols} |> dbg
    symbol_value = Map.get(state.symbols, name)
    %A940.Address{value: value, relocation: 0, expression_tokens: []} = symbol_value
    {:resolve1, addr, name, value} |> dbg
    state
  end

  #   defp relocate_symbol(
  #        execution_lc,
  #        %A940.Address{expression_tokens: [], relocation: relocation} = addr
  #      ) do
  #   %{addr | value: addr.value + relocation * execution_lc &&& addr.mask, relocation: 0}
  # end
end
