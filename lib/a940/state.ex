defmodule A940.State do
  defstruct lines: %{},
            tokens_list: [],
            used_tokens: [],
            symbols: %{},
            macros: %{},
            ops: %{},
            # keys are the relocatable location, value is a MemoryValue
            # should this be a genserver??
            code: %{},
            flags: %A940.Flags{},
            # this keeps counting up with each instruction or data word(s)
            # default relocation value of 1 (implicit, not stored)
            location_relative: 0,
            # this starts at value of RELORG and counts up until RETREL
            location_absolute: 0

  def new(lines) do
    {_count, line_map} =
      Enum.reduce(lines, {1, %{}}, fn line, {count, map} ->
        {count + 1, Map.put(map, count, line)}
      end)

    %__MODULE__{lines: line_map, ops: A940.Op.opcode_table()}
  end

  def update_symbol_table(%__MODULE__{} = state, symbol_name, exported? \\ false)
      when is_binary(symbol_name) do
    address_value =
      if state.flags.relocating, do: state.location_relative, else: state.location_absolute

    address_relocation = if state.flags.relocating, do: 1, else: 0
    new_address = A940.Address.new(address_value, address_relocation, exported?)
    old_address = Map.get(state.symbols, symbol_name)
    if nil != old_address, do: raise("multiply defined symbol: #{symbol_name} ")
    new_symbols = Map.put(state.symbols, symbol_name, new_address)
    %{state | symbols: new_symbols}
  end

  # This is used when the label isn't for an address, like if it is a macro
  def remove_symbol(%__MODULE__{} = state, symbol_name)
      when is_binary(symbol_name) do
    new_symbols = Map.delete(state.symbols, symbol_name)
    %{state | symbols: new_symbols}
  end
end
