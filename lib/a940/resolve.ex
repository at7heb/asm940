defmodule A940.Resolve do
  alias A940.{Memory, MemoryAddress, MemoryValue, State}

  def resolve_symbols(%State{} = state) do
    scan_symbols(state)
  end

  def scan_symbols(%State{} = state) do
    symbols = Map.keys(state.symbols) |> Enum.sort()

    values =
      Enum.map(symbols, fn symbol ->
        [symbol, "-->", Map.get(state.symbols, symbol) |> inspect()]
      end)

    Enum.each(values, fn v -> IO.puts(v) end)

    state
  end
end
