defmodule A940.Directive do
  import Bitwise

  alias A940.State

  def bes(%State{} = state, :first_call),
    do: state

  def bes(%State{} = state, :second_call) do
    {val, relocation} = A940.Address.eval(state)

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
    {val, relocation} = A940.Address.eval(state)

    cond do
      not (is_integer(val) and is_integer(relocation)) ->
        raise "BSS on line #{state.line_number} - illegal operand"

      # val < 1 or  ... BSS 0 is legal???
      val > 16383 ->
        raise("BSS on line #{state.line_number} of #{val} words is illegal")

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
    State.add_memory(state, word, 0)
  end

  def data(%State{} = state, :first_call),
    do: state

  def data(%State{} = state, :second_call) do
    {val, relocation} = A940.Address.eval(state)

    cond do
      not (is_integer(val) and is_integer(relocation)) ->
        raise "DATA on line #{state.line_number} - illegal operand"

      true ->
        State.add_memory(state, val, relocation)
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
    {val, relocation} = A940.Address.eval(state)

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

  def f_end(%State{} = state, :first_call) do
    if state.ident == "" do
      raise "No IDENT directive"
    end

    new_flags = %{state.flags | done: true}
    %{state | flags: new_flags}
  end

  def f_end(%State{} = state, :second_call) do
    state
  end

  def ident(%State{} = state, :first_call) do
    # IO.puts("ident 1st-----------------------------------------------------------")

    state =
      cond do
        state.ident != "" ->
          raise "Multiple IDENT directives"

        length(state.label_tokens) != 1 ->
          raise "IDENT directive must have simple lable line #{state.line_number}"

        {:symbol, _} = hd(state.label_tokens) ->
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

  def asc(%State{} = state, :first_call) do
    state
  end

  def asc(%State{} = state, :second_call) do
    f = ~r/^(\$?[A-Z0-9:]+){0,1} +ASC +(\'(.+)\')|(\"(.+)\")$/
    asc_string = Regex.run(f, Map.get(state.lines, state.line_number)) |> List.last()
    line_data = A940.Tokenizer.decode_string_8(asc_string)
    Enum.reduce(line_data, state, fn word, stt -> State.add_memory(stt, word) end)
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

    State.add_memory(state, 0, 0)
  end

  # helpers

  def b(n) when is_integer(n) and n >= 0 and n <= 23, do: 0o40000000 >>> n

  def copy_token([{:symbol, copy_mnemonic}], field) do
    case copy_mnemonic do
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
