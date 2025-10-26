defmodule A940.Op do
  alias A940.State
  alias A940.Address

  import Bitwise

  defstruct value: 0,
            # :maybe_address, :yes_address, :no_address
            address_class: :maybe_address,
            # 0, 9 or 14, but 14 if :yes_address with indirect bit
            address_length: 14,
            processing_function: nil,
            define_location?: true

  def new(
        value,
        class \\ :yes_address,
        address_length \\ 14,
        processing_function \\ nil,
        define_location \\ true
      ) do
    %__MODULE__{
      value: value,
      address_class: class,
      address_length: address_length,
      processing_function: processing_function,
      define_location?: define_location
    }
  end

  defp opcode_table do
    %{}
    |> Map.put("IDENT", new(0, :no_address, 0, &A940.Directive.ident/2, false))
    |> Map.put("ASC", new(0, :special_address, 0, &A940.Directive.asc/2))
    |> Map.put("BES", new(0, :yes_address, 0, &A940.Directive.bes/2, false))
    |> Map.put("BSS", new(0, :yes_address, 0, &A940.Directive.bss/2))
    |> Map.put("COPY", new(0, :yes_address, 24, &A940.Directive.copy/2))
    |> Map.put("DATA", new(0, :yes_address, 24, &A940.Directive.data/2))
    |> Map.put("DEC", new(0, :yes_address, 24, &A940.Directive.dec/2, false))
    |> Map.put("DELSYM", new(0, :no_address, 0, &A940.Directive.delsym/2, false))
    |> Map.put("END", new(0, :no_address, 0, &A940.Directive.f_end/2, false))
    |> Map.put("EQU", new(0, :yes_address, 24, &A940.Directive.equ/2, false))
    |> Map.put("EXT", new(0, :maybe_address, 24, &A940.Directive.ext/2, false))
    |> Map.put("FIILIB", new(0, :no_address, 24, &A940.Directive.f2lib/2, false))
    |> Map.put("FREEZE", new(0, :no_address, 24, &A940.Directive.freeze/2, false))
    |> Map.put("FRGT", new(0, :special_address, 0, &A940.Directive.frgt/2, false))
    |> Map.put("FRGTOP", new(0, :special_address, 0, &A940.Directive.frgtop/2, false))
    |> Map.put("OCT", new(0, :maybe_address, 14, &A940.Directive.oct/2, false))
    |> Map.put("ZRO", new(0, :maybe_address, 14, &A940.Directive.zro/2))
    |> Map.put("HLT", new(0o0000000, :no_address))
    |> Map.put("BRU", new(0o0100000))
    |> Map.put("ETR", new(0o1400000))
    |> Map.put("MRG", new(0o1600000))
    |> Map.put("EOR", new(0o1700000))
    |> Map.put("NOP", new(0o2000000, :maybe_address))
    |> Map.put("EXU", new(0o2300000))
    |> Map.put("STA", new(0o3500000))
    |> Map.put("STB", new(0o3600000))
    |> Map.put("STX", new(0o3700000))
    |> Map.put("SKS", new(0o4000000))
    |> Map.put("BRX", new(0x4100000))
    |> Map.put("BRM", new(0x4300000))
    |> Map.put("SKE", new(0o5000000))
    |> Map.put("BRR", new(0o5100000))
    |> Map.put("SKB", new(0o5200000))
    |> Map.put("SKN", new(0o5300000))
    |> Map.put("SUB", new(0o5400000))
    |> Map.put("ADD", new(0o5500000))
    |> Map.put("SUC", new(0o5600000))
    |> Map.put("ADC", new(0o5700000))
    |> Map.put("SKR", new(0o6000000))
    |> Map.put("MIN", new(0o6100000))
    |> Map.put("XMA", new(0o6200000))
    |> Map.put("ADM", new(0o6300000))
    |> Map.put("MUL", new(0o6400000))
    |> Map.put("DIV", new(0o6500000))
    |> Map.put("SKM", new(0o7000000))
    |> Map.put("LDX", new(0o7100000))
    |> Map.put("SKA", new(0o7200000))
    |> Map.put("SKG", new(0o7300000))
    |> Map.put("SKD", new(0o7400000))
    |> Map.put("LDB", new(0o7500000))
    |> Map.put("LDA", new(0o7600000))
    |> Map.put("EAX", new(0o7700000))
    |> Map.put("XXA", new(0o4600600, :no_address))
    |> Map.put("RCH", new(0o4600000, :yes_address, 9))
    |> Map.put("CLA", new(0o4600001, :no_address))
    |> Map.put("CLB", new(0o4600002, :no_address))
    |> Map.put("CLX", new(0o24600000, :no_address))
    |> Map.put("CLR", new(0o24600003, :no_address))
    |> Map.put("CAB", new(0o4600004, :no_address))
    |> Map.put("CBA", new(0o4600010, :no_address))
    |> Map.put("XAB", new(0o4600014, :no_address))
    |> Map.put("RSH", new(0, :yes_address, 9))
    |> Map.put("RCY", new(0, :yes_address, 9))
    |> Map.put("LRSH", new(0, :yes_address, 9))
    |> Map.put("LSH", new(0, :yes_address, 9))
    |> Map.put("LCY", new(0, :yes_address, 9))
    |> Map.put("NOD", new(0, :yes_address, 9))
    |> Map.put("OVT", new(0, :no_address))
    |> Map.put("ROV", new(0, :no_address))
    |> Map.put("REO", new(0, :no_address))
    |> Map.put("OTO", new(0, :no_address))
  end

  def process_opcode(%State{} = state) do
    cond do
      state.flags.done ->
        state

      length(state.opcode_tokens) == 2 ->
        [opcode_token, {:delimiter, "*"}] = state.opcode_tokens

        handle_indirect_op(state, opcode_token)

      length(state.opcode_tokens) == 1 ->
        handle_direct_op(state, hd(state.opcode_tokens))

      true ->
        raise "Illegal opcode tokens #{state.opcode_tokens}"
    end
  end

  def handle_direct_op(%State{} = state, {opcode_token_flag, opcode} = _symbol_name) do
    op_structure =
      cond do
        opcode_token_flag == :number -> new(opcode, :yes_address, 14)
        opcode_token_flag == :symbol -> get_op(state, opcode)
        true -> raise "unknown opcode #{opcode} line #{state.line_number}"
      end

    # ensure indirect only if 14 bit address.
    # does this apply to macro calls?
    # the value of this cond is immaterial and ignored; it is used only for the *raise* side effect
    state = %{state | operation: op_structure}

    state =
      cond do
        op_structure.define_location? -> handle_label_symbol_definition(state)
        true -> state
      end

    cond do
      op_structure.processing_function != nil ->
        op_structure.processing_function.(state, :first_call)

      true ->
        # do nothing here; it all happens when this is called "again"
        state
    end
  end

  def update_opcode_memory(%State{} = state, address, tag, mask, indirect)
      when is_tuple(address) and is_integer(tag) and is_integer(mask) and is_integer(indirect) do
    {address_value, relocation} = address
    # would like to assert that relocation is zero if mask is other that 0o37777
    word =
      state.operation.value ||| (tag &&& 7) <<< 21 ||| (address_value &&& mask) |||
        indirect <<< 14

    State.add_memory(state, word, relocation)
  end

  def handle_indirect_op(%State{} = state, opcode_token) do
    handle_direct_op(set_indirect_flag(state), opcode_token)
  end

  defp get_op(%A940.State{} = _state, op_name), do: Map.get(opcode_table(), op_name)

  defp set_indirect_flag(%State{} = state) do
    new_flags = %{state.flags | indirect: true}
    %{state | flags: new_flags}
  end

  def process_opcode_again(%State{} = state) do
    state =
      cond do
        state.operation.processing_function != nil ->
          state.operation.processing_function.(state, :second_call)

        true ->
          process_op_not_directive(state)
      end

    state
  end

  def process_op_not_directive(%State{} = state) do
    # TODO update to handle cases where address_tokens_list evaluates to an expression instead
    # of a nmber.
    tag_tuple =
      cond do
        length(state.address_tokens_list) == 2 ->
          Address.eval(state, Enum.at(state.address_tokens_list, 1))

        true ->
          {0, 0}
      end

    {tag, 0} =
      tag_tuple

    address =
      cond do
        length(state.address_tokens_list) >= 1 ->
          Address.eval(state, hd(state.address_tokens_list))

        true ->
          {0, 0}
      end

    mask =
      cond do
        state.operation.address_length == 24 -> 0o77777777
        state.operation.address_length == 14 -> 0o37777
        state.operation.address_length == 9 -> 0o777
        true -> 0
      end

    indirect =
      cond do
        state.flags.indirect -> 1
        true -> 0
      end

    update_opcode_memory(state, address, tag, mask, indirect)
  end

  def handle_label_symbol_definition(%State{} = state) do
    cond do
      length(state.label_tokens) == 0 ->
        state

      length(state.label_tokens) == 1 ->
        {:symbol, label_name} = state.label_tokens |> hd()
        State.update_symbol_table(state, label_name, false)

      length(state.label_tokens) == 2 ->
        {:symbol, label_name} = state.label_tokens |> Enum.at(1)
        {:delimiter, "$"} = state.label_tokens |> Enum.at(0)
        State.update_symbol_table(state, label_name, true)
    end
  end
end
