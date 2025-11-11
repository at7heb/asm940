defmodule A940.Op do
  alias A940.{State, Address, Memory, MemoryValue}

  import Bitwise

  defstruct value: 0,
            # :maybe_address, :yes_address, :no_address
            address_class: :maybe_address,
            # 0, 9 or 14, but 14 if :yes_address with indirect bit
            address_length: 14,
            processing_function: nil,
            define_location?: true,
            assembly_defined?: false

  def new(
        value,
        class \\ :yes_address,
        address_length \\ 14,
        processing_function \\ nil,
        define_location \\ true,
        assembly_defined \\ false
      )
      when is_integer(value) and value >= 0 and value <= 0o77777777 do
    %__MODULE__{
      value: value,
      address_class: class,
      address_length: address_length,
      processing_function: processing_function,
      define_location?: define_location,
      assembly_defined?: assembly_defined
    }
  end

  def opcode_table do
    %{}
    |> Map.put("IDENT", new(0, :no_address, 0, &A940.Directive.ident/2, false))
    |> Map.put("ASC", new(0, :special_address, 0, &A940.Directive.asc/2))
    |> Map.put("BES", new(0, :yes_address, 0, &A940.Directive.bes/2, false))
    |> Map.put("BSS", new(0, :yes_address, 0, &A940.Directive.bss/2))
    |> Map.put("COPY", new(0, :yes_address, 24, &A940.Directive.copy/2))
    |> Map.put("DATA", new(0, :yes_address, 24, &A940.Directive.data/2))
    |> Map.put("DEC", new(0, :yes_address, 24, &A940.Directive.dec/2, false))
    |> Map.put("DELSYM", new(0, :no_address, 0, &A940.Directive.delsym/2, false))
    |> Map.put("ELSE", new(0, :no_address, 0, &A940.If.f_else/2, false))
    |> Map.put("ELSF", new(0, :special_address, 0, &A940.If.elsf/2, false))
    |> Map.put("END", new(0, :no_address, 0, &A940.Directive.f_end/2, false))
    |> Map.put("ENDF", new(0, :no_address, 0, &A940.If.endf/2, false))
    |> Map.put("EQU", new(0, :yes_address, 24, &A940.Directive.equ/2, false))
    |> Map.put("EXT", new(0, :maybe_address, 24, &A940.Directive.ext/2, false))
    |> Map.put("FIILIB", new(0, :no_address, 24, &A940.Directive.f2lib/2, false))
    |> Map.put("FREEZE", new(0, :no_address, 24, &A940.Directive.freeze/2, false))
    |> Map.put("FRGT", new(0, :special_address, 0, &A940.Directive.frgt/2, false))
    |> Map.put("FRGTOP", new(0, :special_address, 0, &A940.Directive.frgtop/2, false))
    |> Map.put("GLOBAL", new(0, :special_address, 0, &A940.Directive.not_implemented/2, false))
    |> Map.put("IF", new(0, :special_address, 0, &A940.If.f_if/2, false))
    |> Map.put("LIST", new(0, :special_address, 0, &A940.Directive.ignored/2, false))
    |> Map.put("NOLIST", new(0, :special_address, 0, &A940.Directive.ignored/2, false))
    |> Map.put("LOCAL", new(0, :special_address, 0, &A940.Directive.not_implemented/2, false))
    |> Map.put("OCT", new(0, :maybe_address, 14, &A940.Directive.oct/2, false))
    |> Map.put("OPD", new(0, :yes_address, 0, &A940.Directive.opdef/2, false))
    |> Map.put("POPD", new(0, :yes_address, 0, &A940.Directive.popdef/2, false))
    |> Map.put("RPT", new(0, :yes_address, 0, &A940.Rpt.rpt/2, false))
    |> Map.put("ENDR", new(0, :yes_address, 0, &A940.Rpt.endr/2, false))
    |> Map.put("ZRO", new(0, :maybe_address, 14, &A940.Directive.zro/2))
    |> Map.put("HLT", new(0o0000000, :no_address, 0))
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
    |> Map.put("BRX", new(0o4100000))
    |> Map.put("BRM", new(0o4300000))
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
    |> Map.put("XXA", new(0o4600600, :no_address, 0))
    |> Map.put("RCH", new(0o4600000, :yes_address, 9))
    |> Map.put("CLA", new(0o4600001, :no_address, 0))
    |> Map.put("CLB", new(0o4600002, :no_address, 0))
    |> Map.put("CLAB", new(0o4600003, :no_address, 0))
    |> Map.put("CLX", new(0o24600000, :no_address, 0))
    |> Map.put("CLR", new(0o24600003, :no_address, 0))
    |> Map.put("CLEAR", new(0o24600003, :no_address, 0))
    |> Map.put("CNA", new(0o04601000, :no_address, 0))
    |> Map.put("CAB", new(0o4600004, :no_address, 0))
    |> Map.put("CBA", new(0o4600010, :no_address, 0))
    |> Map.put("ABC", new(0o4600005, :no_address, 0))
    |> Map.put("BAC", new(0o4600012, :no_address, 0))
    |> Map.put("XAB", new(0o4600014, :no_address, 0))
    |> Map.put("CBX", new(0o4600020, :no_address, 0))
    |> Map.put("CXB", new(0o4600040, :no_address, 0))
    |> Map.put("XXB", new(0o4600060, :no_address, 0))
    |> Map.put("CAX", new(0o4600400, :no_address, 0))
    |> Map.put("CXA", new(0o4600200, :no_address, 0))
    |> Map.put("XXA", new(0o4600600, :no_address, 0))
    |> Map.put("AXC", new(0o4600401, :no_address, 0))
    |> Map.put("RSH", new(0o6600000, :yes_address, 9))
    |> Map.put("RCY", new(0o6620000, :yes_address, 9))
    |> Map.put("LRSH", new(0o6624000, :yes_address, 9))
    |> Map.put("LSH", new(0o6700000, :yes_address, 9))
    |> Map.put("LCY", new(0o6720000, :yes_address, 9))
    |> Map.put("NOD", new(0o6710000, :yes_address, 9))
    |> Map.put("OVT", new(0o2200101, :no_address, 0))
    |> Map.put("ROV", new(0o2200001, :no_address, 0))
    |> Map.put("REO", new(0o2200010, :no_address, 0))
    |> Map.put("OTO", new(0o2200100, :no_address, 0))
    |> Map.put("STE", new(0o4600122, :no_address, 0))
    |> Map.put("LDE", new(0o4600140, :no_address, 0))
    |> Map.put("BIO", new(0o57600000, :yes_address, 14))
    |> Map.put("BRS", new(0o57300000, :yes_address, 14))
    |> Map.put("CIO", new(0o56100000, :yes_address, 14))
    |> Map.put("CIT", new(0o53400000, :yes_address, 14))
    |> Map.put("CTRL", new(0o57210000, :yes_address, 14))
    |> Map.put("DBI", new(0o54200000, :yes_address, 14))
    |> Map.put("DBO", new(0o54300000, :yes_address, 14))
    |> Map.put("DWI", new(0o54400000, :yes_address, 14))
    |> Map.put("DWO", new(0o54500000, :yes_address, 14))
    |> Map.put("EXS", new(0o55200000, :yes_address, 14))
    |> Map.put("EXSYM", new(0o51500000, :yes_address, 14))
    |> Map.put("FAD", new(0o55600000, :yes_address, 14))
    |> Map.put("FDV", new(0o55300000, :yes_address, 14))
    |> Map.put("FFAD", new(0o52600000, :yes_address, 14))
    |> Map.put("FFADD", new(0o52000000, :yes_address, 14))
    |> Map.put("FFDI", new(0o53100000, :yes_address, 14))
    |> Map.put("FFDID", new(0o51400000, :yes_address, 14))
    |> Map.put("FFDV", new(0o53000000, :yes_address, 14))
    |> Map.put("FFDVD", new(0o52200000, :yes_address, 14))
    |> Map.put("FFMP", new(0o52700000, :yes_address, 14))
    |> Map.put("FFMPD", new(0o52100000, :yes_address, 14))
    |> Map.put("FFSB", new(0o53200000, :yes_address, 14))
    |> Map.put("FFSBD", new(0o52300000, :yes_address, 14))
    |> Map.put("FFSI", new(0o53300000, :yes_address, 14))
    |> Map.put("FFSID", new(0o51300000, :yes_address, 14))
    |> Map.put("FMP", new(0o55400000, :yes_address, 14))
    |> Map.put("FSB", new(0o55500000, :yes_address, 14))
    |> Map.put("GCD", new(0o53700000, :yes_address, 14))
    |> Map.put("GCI", new(0o56500000, :yes_address, 14))
    |> Map.put("ISC", new(0o54000000, :yes_address, 14))
    |> Map.put("IST", new(0o55000000, :yes_address, 14))
    |> Map.put("LAS", new(0o54600000, :yes_address, 14))
    |> Map.put("LDP", new(0o56600000, :yes_address, 14))
    |> Map.put("LDFM", new(0o52400000, :yes_address, 14))
    |> Map.put("LDFMD", new(0o51600000, :yes_address, 14))
    |> Map.put("OST", new(0o55100000, :yes_address, 14))
    |> Map.put("SAS", new(0o54700000, :yes_address, 14))
    |> Map.put("SBRM", new(0o57000000, :yes_address, 14))
    |> Map.put("SBRR", new(0o05140000, :yes_address, 14))
    |> Map.put("SIC", new(0o54100000, :yes_address, 14))
    |> Map.put("SKSE", new(0o56300000, :yes_address, 14))
    |> Map.put("SKSG", new(0o56200000, :yes_address, 14))
    |> Map.put("STFM", new(0o52500000, :yes_address, 14))
    |> Map.put("STFMD", new(0o51700000, :yes_address, 14))
    |> Map.put("STI", new(0o53600000, :yes_address, 14))
    |> Map.put("STP", new(0o56700000, :yes_address, 14))
    |> Map.put("TCI", new(0o57400000, :yes_address, 14))
    |> Map.put("TCO", new(0o57500000, :yes_address, 14))
    |> Map.put("WCD", new(0o53500000, :yes_address, 14))
    |> Map.put("WCH", new(0o56400000, :yes_address, 14))
    |> Map.put("WCI", new(0o55700000, :yes_address, 14))
    |> Map.put("WIO", new(0o56000000, :yes_address, 14))
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
        opcode_token_flag == :symbol -> get_op(opcode)
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

    # State.addzz_memory(state, word, relocation)
    Memory.set_memory(
      State.get_current_location(state),
      MemoryValue.new(word, relocation)
    )

    State.increment_current_location(state)
  end

  def update_opcode_memory(%State{} = state, address_expression_tokens, tag, indirect)
      when is_list(address_expression_tokens) and is_integer(tag) and is_integer(indirect) do
    word =
      state.operation.value ||| (tag &&& 7) <<< 21 ||| indirect <<< 14

    # State.addzz_memory(state, word, address_expression_tokens)
    Memory.set_memory(
      State.get_current_location(state),
      MemoryValue.new(word, address_expression_tokens)
    )

    State.increment_current_location(state)
  end

  def handle_indirect_op(%State{} = state, opcode_token) do
    handle_direct_op(set_indirect_flag(state), opcode_token)
  end

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

    indirect =
      cond do
        state.flags.indirect -> 1
        true -> 0
      end

    address =
      cond do
        state.operation.address_class == :maybe_address and state.address_tokens_list == [[]] ->
          {0, 0}

        state.operation.address_class != :no_address and state.address_tokens_list != [[]] ->
          A940.Expression.evaluate(state)

        true ->
          {0, 0}
      end

    cond do
      elem(address, 0) == :external_expression or elem(address, 0) == :literal_expression ->
        {_, expression_tokens} = address
        update_opcode_memory(state, expression_tokens, tag, indirect)

      true ->
        mask =
          cond do
            state.operation.address_length == 24 -> 0o77777777
            state.operation.address_length == 14 -> 0o37777
            state.operation.address_length == 9 -> 0o777
            true -> 0
          end

        update_opcode_memory(state, address, tag, mask, indirect)
    end
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

  def get_op(op_name), do: :ets.lookup(:opcodes, op_name) |> hd |> elem(1)

  @opcode_table :opcodes
  def new_opcode_table() do
    case :ets.whereis(@opcode_table) do
      :undefined -> nil
      _ -> :ets.delete(@opcode_table)
    end

    :ets.new(@opcode_table, [:set, :protected, :named_table])
    opcode_tbl = opcode_table()
    Enum.map(Map.to_list(opcode_tbl), &:ets.insert(@opcode_table, &1))
    :ets.insert(@opcode_table, {:keys, Map.keys(opcode_tbl)})
    :ets.insert(@opcode_table, {:opdefs, []})
  end

  def update_opcode_table(opcode, %__MODULE__{} = op) when is_binary(opcode) do
    :ets.insert(@opcode_table, {opcode, op})
    :ets.lookup(@opcode_table, opcode)
    [{:opdefs, defs}] = :ets.lookup(@opcode_table, :opdefs)
    :ets.insert(@opcode_table, {:opdefs, [opcode | defs]})
    :ok
  end
end
