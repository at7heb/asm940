defmodule A940.State do
  import Bitwise

  alias A940.Address

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
            location_absolute: 0,
            ident: "",
            line_number: 0,
            agent_during_address_processing: nil

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
    new_address = Address.new(address_value, address_relocation, exported?)
    old_address = Map.get(state.symbols, symbol_name)
    if nil != old_address, do: raise("multiply defined symbol: #{symbol_name} ")
    new_symbols = Map.put(state.symbols, symbol_name, new_address)
    %{state | symbols: new_symbols}
  end

  def redefine_symbol_value(%__MODULE__{} = state, symbol_name, value, relocation)
      when is_binary(symbol_name) do
    old_address_value = Map.get(state.symbols, symbol_name)
    {value, relocation} |> dbg
    new_address_value = Address.new(value, relocation, old_address_value.exported?) |> dbg
    new_symbols = Map.put(state.symbols, symbol_name, new_address_value)
    %{state | symbols: new_symbols}
  end

  # This is used when the label isn't for an address, like if it is a macro
  def remove_symbol(%__MODULE__{} = state, symbol_name)
      when is_binary(symbol_name) do
    new_symbols = Map.delete(state.symbols, symbol_name)
    %{state | symbols: new_symbols}
  end

  def add_memory(%__MODULE__{} = state, value, relocation \\ 0) do
    memory_value = A940.MemoryValue.new(value, relocation)
    new_code = Map.put(state.code, state.location_relative, memory_value)
    new_location = state.location_relative + 1

    new_abs_location =
      if state.flags.relocating, do: state.location_absolute, else: state.location_absolute + 1

    %{
      state
      | code: new_code,
        location_relative: new_location,
        location_absolute: new_abs_location
    }
  end

  def merge_address(%__MODULE__{} = state, address_value, location)
      when address_value >= 0 and address_value <= 16383 and location >= 0 and location <= 16383 do
    current_word = Map.get(state.code, location, :illegal)
    # don't change the relocation
    %{
      state
      | code:
          Map.put(state.code, location, A940.MemoryValue.merge_value(current_word, address_value))
    }
  end

  def merge_tag(%__MODULE__{} = state, tag_value, location)
      when tag_value >= 0 and tag_value <= 7 and location >= 0 and location <= 16383 do
    current_word = Map.get(state.code, location, :illegal)

    %{
      state
      | code:
          Map.put(
            state.code,
            location,
            A940.MemoryValue.merge_value(current_word, tag_value <<< 21)
          )
    }
  end
end
