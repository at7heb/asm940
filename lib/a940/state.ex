defmodule A940.State do
  alias A940.{Address, MemoryAddress}

  defstruct lines: %{},
            # tokens_list: [],
            used_tokens: [],
            label_tokens: [],
            opcode_tokens: [],
            address_tokens_list: [[]],
            operation: %A940.Op{},
            symbols: %{},
            macros: %{},
            current_macro: nil,
            macro_stack: [],
            flags: %A940.Flags{},
            # this keeps counting up with each instruction or data word(s)
            # default relocation value of 1 (implicit, not stored)
            location_relative: 0,
            # this starts at value of RELORG and counts up until RETREL
            location_absolute: 0,
            ident: "",
            line_number: 0,
            output_symbols: true,
            f2lib?: false,
            assembling: true,
            if_stack: [],
            rpt_state: %A940.Rpt{}

  def new(lines) do
    {_count, line_map} =
      Enum.reduce(lines, {1, %{}}, fn line, {count, map} ->
        {count + 1, Map.put(map, count, line)}
      end)

    %__MODULE__{lines: line_map}
  end

  def update_symbol_table(%__MODULE__{} = state, symbol_name, exported? \\ false)
      when is_binary(symbol_name) do
    # {"Symbol---------------------- Set", Process.info(self(), :current_stacktrace)} |> dbg

    address_value =
      if state.flags.relocating, do: state.location_relative, else: state.location_absolute

    address_relocation = if state.flags.relocating, do: 1, else: 0
    new_address = Address.new(address_value, address_relocation, exported?)
    old_address = Map.get(state.symbols, symbol_name)

    if nil != old_address do
      IO.puts("MD #{Map.get(state.lines, state.line_number)}")
      IO.puts("MD sym #{inspect(old_address)}")
      raise("multiply defined symbol: #{symbol_name} ")
    end

    new_symbols = Map.put(state.symbols, symbol_name, new_address)
    %{state | symbols: new_symbols}
  end

  def define_symbol_value(
        %__MODULE__{} = state,
        label_name,
        label_global?,
        value,
        relocation
      )
      when is_binary(label_name) and is_boolean(label_global?) and is_integer(value) and
             is_integer(relocation) do
    # {"Symbol---------------------- Set", Process.info(self(), :current_stacktrace)} |> dbg
    address = Address.new(value, relocation, label_global?)
    # {"define symbol value", address}
    # |> dbg
    old_symbol = Map.get(state.symbols, label_name)

    if old_symbol != nil do
      IO.puts("MD #{Map.get(state.lines, state.line_number)}")
      IO.puts("MD sym #{inspect(old_symbol)}")
      raise "Duplicate symbol definition symbol #{label_name} line #{state.line_number}"
    end

    new_symbols = Map.put(state.symbols, label_name, address)
    %{state | symbols: new_symbols}
  end

  # def redefine_symbol_value(%__MODULE__{} = state, symbol_name) do
  #   {value, relocation} = current_location(state)
  #   redefine_symbol_value(state, symbol_name, value, relocation)
  # end

  def redefine_symbol_value(%__MODULE__{} = state, symbol_name, value, relocation, exported?)
      when is_binary(symbol_name) do
    # {"Symbol---------------------- Set", Process.info(self(), :current_stacktrace)} |> dbg
    old_address_value = Map.get(state.symbols, symbol_name)

    new_address_value =
      cond do
        old_address_value == nil ->
          # "redefine_symbol_value first definition" |> dbg
          Address.new(value, relocation, exported?)

        true ->
          # "redefine_symbol_value subsequent definition" |> dbg

          Address.new(
            value,
            relocation,
            old_address_value.exported? or exported?,
            old_address_value.forgotten?
          )
      end

    new_symbols = Map.put(state.symbols, symbol_name, new_address_value)

    %{state | symbols: new_symbols}
  end

  def set_local_absolute_symbol(%__MODULE__{} = state, symbol_name, value)
      when is_binary(symbol_name) and is_integer(value) do
    address_struct = Address.new(value, 0, false, false)
    %{state | symbols: Map.put(state.symbols, symbol_name, address_struct)}
  end

  # This is used when the label isn't for an address, like if it is a macro
  def remove_symbol(%__MODULE__{} = state, symbol_name)
      when is_binary(symbol_name) do
    # {"Symbol---------------------- Removal", Process.info(self(), :current_stacktrace)} |> dbg
    new_symbols = Map.delete(state.symbols, symbol_name)
    %{state | symbols: new_symbols}
  end

  def current_location(%__MODULE__{} = state) do
    address_value =
      if state.flags.relocating, do: state.location_relative, else: state.location_absolute

    address_relocation = if state.flags.relocating, do: 1, else: 0
    {address_value, address_relocation}
  end

  def get_current_location(%__MODULE__{} = state, offset \\ 0) do
    cond do
      state.flags.relocating -> MemoryAddress.new_relocatable(state.location_relative + offset)
      true -> MemoryAddress.new_absolute(state.location_absolute + offset)
    end
  end

  def increment_current_location(%__MODULE__{} = state, increment \\ 1) do
    {new_location_relative, new_location_absolute} =
      cond do
        state.flags.relocating ->
          {state.location_relative + increment, state.location_absolute}

        not state.flags.relocating ->
          {state.location_relative, state.location_absolute + increment}
      end

    if new_location_relative > 16383 or new_location_absolute > 16383 do
      raise(
        "illegal increment_current_location {r,a,i} = " <>
          "#{new_location_relative}, #{new_location_absolute}, #{increment}"
      )
    end

    %{state | location_absolute: new_location_absolute, location_relative: new_location_relative}
  end
end
