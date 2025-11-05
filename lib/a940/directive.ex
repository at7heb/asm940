defmodule A940.Directive do
  import Bitwise

  alias A940.{State, Memory, MemoryValue}

  @magic_end_of_program 0o31_062_144

  def bes(%State{} = state, :first_call),
    do: state

  def bes(%State{} = state, :second_call) do
    {val, relocation} = A940.Expression.evaluate(state)

    cond do
      not (is_integer(val) and is_integer(relocation)) ->
        raise "BSS on line #{state.line_number} - illegal operand"

      # val < 1 or  ... BSS 0 is legal???
      val > 16383 ->
        raise("BSS on line #{state.line_number} of #{val} words is illegal")

      relocation != 0 ->
        raise("BSS on line #{state.line_number} has illegal relocation=#{relocation}")

      true ->
        save_label_tokens = state.label_tokens
        state = %{state | label_tokens: []}
        state = Enum.reduce(1..val, state, fn _n, state -> zro(state, :second_call) end)
        A940.Op.handle_label_symbol_definition(%{state | label_tokens: save_label_tokens})
    end
  end

  def bss(%State{} = state, :first_call),
    do: state

  def bss(%State{} = state, :second_call) do
    # if state.line_number == 84 do
    #   {state.label_tokens, Map.keys(state.symbols) |> Enum.sort()} |> dbg
    # end

    {val, relocation} = A940.Expression.evaluate(state)

    cond do
      not (is_integer(val) and is_integer(relocation)) ->
        raise "BSS on line #{state.line_number} - illegal operand"

      val > 16383 ->
        raise("BSS on line #{state.line_number} of #{val} words is illegal")

      val == 0 ->
        state

      relocation != 0 ->
        raise("BSS on line #{state.line_number} has illegal relocation=#{relocation}")

      true ->
        Enum.reduce(1..val, state, fn _n, state -> zro(state, :second_call) end)
    end
  end

  def copy(%State{} = state, :first_call),
    do: state

  @rch_instruction 0o04600000
  def copy(%State{} = state, :second_call) do
    address_field =
      Enum.reduce(state.address_tokens_list, 0, fn token, field -> copy_token(token, field) end)

    word = @rch_instruction ||| address_field

    # State.addzz_memory(state, word, 0)
    Memory.set_memory(State.get_current_location(state), MemoryValue.new(word, 0))
    State.increment_current_location(state)
  end

  def data(%State{} = state, :first_call),
    do: state

  def data(%State{} = state, :second_call) do
    # TODO - make this handle " DATA 1,2,3"
    # {val, relocation} = A940.Expression.evaluate(state)
    address = A940.Expression.evaluate(state)
    {val, relocation} = address
    {qualifier, tokens_list} = address

    cond do
      qualifier == :external_expression or qualifier == :literal_expression ->
        Memory.set_memory(State.get_current_location(state), MemoryValue.new(tokens_list))

      # State.addzz_memory(state, 0, tokens_list)

      is_integer(val) and is_integer(relocation) ->
        Memory.set_memory(State.get_current_location(state), MemoryValue.new(val, relocation))

        State.increment_current_location(state)

      true ->
        raise "DATA on line #{state.line_number} - illegal operand"
    end
  end

  def dec(%State{} = _state, _),
    do: raise("DEC operative is not implemented")

  def delsym(%State{} = state, _) do
    %{state | output_symbols: false}
  end

  def equ(%State{} = state, :first_call),
    do: state

  def equ(%State{} = state, :second_call) do
    {val, relocation} = A940.Expression.evaluate(state)

    # {val, relocation} = A940.Address.eval(state)

    # okay to re-define a symbol
    # state, symbol_name, value, ?, relocation, exported)
    State.redefine_symbol_value(
      state,
      A940.Pass1.label_name(state.label_tokens),
      val,
      relocation,
      A940.Pass1.label_global(state.label_tokens)
    )
  end

  def ext(%State{} = state, :first_call),
    do: state

  def ext(%State{} = state, :second_call) do
    label = A940.Pass1.label_name(state.label_tokens)

    cond do
      label == nil ->
        raise "EXT must have label line in statement \##{state.line_number}"

      state.address_tokens_list != [[]] ->
        # value to be assigned; just make it exportable
        {val, relocation} = A940.Address.eval(state)

        State.redefine_symbol_value(
          state,
          label,
          val,
          relocation,
          true
        )

      Map.get(state.symbols, label) != nil ->
        # symbol previously defined, make exported
        address = Map.get(state.symbols, label)

        State.redefine_symbol_value(
          state,
          label,
          address.value,
          address.relocation,
          true
        )

      true ->
        # undefined - an error.
        raise "Symbol #{label} in EXT directive line #{state.line_number} must be previously defined"
    end
  end

  def f2lib(%State{} = state, :first_call), do: state

  def f2lib(%State{} = state, :second_call) do
    # add program separator word, 0o31_062_144 after each end statement
    %{state | f2lib?: true}
  end

  def freeze(%State{} = state, :first_call), do: state

  def freeze(%State{} = state, :second_call) do
    :ets.new(:symbols, [:set, :protected, :named_table])
    Enum.map(Map.to_list(state.symbols), &:ets.insert(:symbols, &1))
    :ets.insert(:symbols, {:keys, Map.keys(state.symbols)})
    :ets.new(:macros, [:set, :protected, :named_table])
    Enum.map(Map.to_list(state.macros), &:ets.insert(:macros, &1))
    :ets.insert(:macros, {:keys, Map.keys(state.macros)})
    state
  end

  def frgt(%State{} = state, :first_call), do: state

  def frgt(%State{} = state, :second_call) do
    Enum.reduce(state.address_tokens_list, state, fn symbol_name, state ->
      frgt_symbol(state, symbol_name)
    end)
  end

  def frgtop(%State{} = state, :first_call), do: state

  def frgtop(%State{} = state, :second_call) do
    raise "FRGTOP not implemented (line #{state.line_number})"
  end

  def frgt_symbol(%State{} = state, [symbol: symbol_name] = _symbol) do
    address = Map.get(state.symbols, symbol_name)
    new_address = %{address | forgotten?: true}
    new_symbols = Map.put(state.symbols, symbol_name, new_address)
    %{state | symbols: new_symbols}
  end

  def f_end(%State{} = state, :first_call) do
    if state.ident == "" do
      raise "No IDENT directive"
    end

    new_flags = %{state.flags | done: true}
    %{state | flags: new_flags}
  end

  def f_end(%State{} = state, :second_call) do
    cond do
      state.f2lib? ->
        # State.addzz_memory(state, @magic_end_of_program, 0)

        Memory.set_memory(
          State.get_current_location(state),
          MemoryValue.new(@magic_end_of_program, 0)
        )

        State.increment_current_location(state)

      true ->
        state
    end
  end

  def ident(%State{} = state, :first_call) do
    # IO.puts("ident 1st-----------------------------------------------------------")

    state =
      cond do
        state.ident != "" ->
          raise "Multiple IDENT directives"

        length(state.label_tokens) != 1 ->
          raise "IDENT directive must have simple lable line #{state.line_number}"

        :symbol == hd(state.label_tokens) |> elem(0) ->
          ident_name = elem(hd(state.label_tokens), 1)
          %{state | ident: ident_name, flags: %{state.flags | done: true}}

        true ->
          raise "IDENT directive label fault line #{state.line_number}"
      end

    {"ident first call", state.ident}
    state
  end

  def ident(%State{} = state, :second_call) do
    # nothing to do
    # IO.puts("ident 2nd-----------------------------------------------------------")
    state
  end

  def opdef(%State{} = state, :first_call) do
    state
  end

  def opdef(%State{} = state, :second_call) do
    if length(state.address_tokens_list) != 2 do
      raise("OPD directive must have 2 address fields (line #{state.line_number})")
    end

    [word_expression, type_expression] = state.address_tokens_list
    [{:symbol, op_code}] = state.label_tokens
    {op_word, 0} = A940.Address.eval(state, word_expression)
    {address_type, 0} = A940.Address.eval(state, type_expression)

    address_class =
      case address_type do
        0 -> :maybe_address
        1 -> :no_address
        2 -> :yes_address
        _ -> raise("Illegal address type in OPDEF line #{state.line_number}")
      end

    op_value = A940.Op.new(op_word, address_class, 14, nil, true, true)
    A940.Op.update_opcode_table(op_code, op_value)
    # {"opdef", op_code, Integer.to_string(op_word, 8)} |> dbg()
    # {"opdef1", op_value} |> dbg
    state
  end

  def popdef(%State{} = state, :first_call) do
    state
  end

  def popdef(%State{} = state, :second_call) do
    if length(state.address_tokens_list) != 2 do
      raise("POPD directive must have 2 address fields (line #{state.line_number})")
    end

    [word_expression, type_expression] = state.address_tokens_list
    [{:symbol, op_code}] = state.label_tokens
    {op_word, 0} = A940.Address.eval(state, word_expression)

    if op_word < 0o10000000 or op_word > 0o17700000 do
      raise(
        "POPD must define a POP code 10000000B <= POP <= 17700000B (line #{state.line_number})"
      )
    end

    {address_type, 0} = A940.Address.eval(state, type_expression)

    address_class =
      case address_type do
        0 -> :maybe_address
        1 -> :no_address
        2 -> :yes_address
        _ -> raise("Illegal address type in OPDEF line #{state.line_number}")
      end

    op_value = A940.Op.new(op_word, address_class, 14, nil, true, true)
    A940.Op.update_opcode_table(op_code, op_value)
    # {"popdef", op_code, Integer.to_string(op_word, 8)} |> dbg()
    # {"popdef1", op_value} |> dbg
    state
  end

  def not_implemented(%State{} = state, _) do
    {:symbol, directive} = hd(state.opcode_tokens)
    raise "Illegal directive #{directive} on line #{state.line_number}"
  end

  def ignored(%State{} = state, phase) do
    {:symbol, directive} = hd(state.opcode_tokens)

    if phase == :first_call do
      IO.puts("Ignoring directive #{directive} on line #{state.line_number}")
    end

    state
  end

  def asc(%State{} = state, :first_call) do
    state
  end

  def asc(%State{} = state, :second_call) do
    f = ~r/^(\$?[A-Z0-9:]+){0,1} +ASC +(\'(.+)\')|(\"(.+)\")/
    asc_string = Regex.run(f, Map.get(state.lines, state.line_number)) |> List.last()
    line_data = A940.Tokenizer.decode_string_8(asc_string)

    Enum.reduce(line_data, state, fn word, stt ->
      Memory.set_memory(
        State.get_current_location(stt),
        MemoryValue.new(word, 0)
      )

      State.increment_current_location(stt)
      # State.addzz_memory(stt, word, 0)
    end)
  end

  def oct(%State{} = _state, _),
    do: raise("OCT operative is not implemented")

  def zro(%State{} = state, :first_call) do
    state
  end

  def zro(%State{} = state, :second_call) do
    # handle both ZRO and ZRO ADDRSS
    # IO.puts("ZRO ------------------------------------------------")
    # IO.puts("ZRO #{inspect(state.label_tokens)} -----------------")

    # cond do
    #   length(state.label_tokens) != 1 ->
    #     nil

    #   [{:symbol, label_name}] = state.label_tokens ->
    #     IO.puts("ZRO has address #{label_name}")
    #     IO.puts("Symbol value: #{Map.get(state.symbols, label_name) |> inspect}")
    # end

    # State.addzz_memory(state, 0, 0)
    Memory.set_memory(
      State.get_current_location(state),
      MemoryValue.new(0, 0)
    )

    State.increment_current_location(state)
  end

  # helpers

  def b(n) when is_integer(n) and n >= 0 and n <= 23, do: 0o40000000 >>> n

  def copy_token([{:symbol, copy_mnemonic}], field), do: copy_token(copy_mnemonic, field)

  def copy_token(copy_mnemonic, field) do
    mnemonic =
      cond do
        is_tuple(copy_mnemonic) -> elem(copy_mnemonic, 1)
        is_binary(copy_mnemonic) -> copy_mnemonic
        true -> raise "Illegal register change mnemonic #{inspect(copy_mnemonic)}"
      end

    case mnemonic do
      "A" -> b(23)
      "B" -> b(22)
      "AB" -> b(21)
      "BA" -> b(20)
      "BX" -> b(19)
      "XB" -> b(18)
      "E" -> b(17)
      "XA" -> b(16)
      "AX" -> b(15)
      "N" -> b(14)
      "X" -> b(1)
      _ -> raise "Illegal register change mnemonic #{copy_mnemonic}"
    end ||| field
  end
end
