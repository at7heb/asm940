defmodule A940.Directive do
  alias A940.State

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

  def equ(%State{} = state, :first_call),
    do: state

  def equ(%State{} = state, :second_call) do
    {state.address_tokens_list, state.line_number}
    # |> dbg
    {val, relocation} = A940.Address.eval(state)

    State.define_symbol_value(
      state,
      A940.Pass1.label_name(state.label_tokens),
      A940.Pass1.label_global(state.label_tokens),
      val,
      relocation
    )
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
    IO.puts("ASC first -----------------------------------------------------------")
    state
  end

  def asc(%State{} = state, :second_call) do
    IO.puts("ASC second ------------------------------------------------------")
    f = ~r/^(\$?[A-Z0-9:]+){0,1} +ASC +(\'(.+)\')|(\"(.+)\")$/
    asc_string = Regex.run(f, Map.get(state.lines, state.line_number)) |> List.last()
    line_data = A940.Tokenizer.decode_string_8(asc_string)
    {asc_string, line_data} |> dbg
    Enum.reduce(line_data, state, fn word, stt -> State.add_memory(stt, word) end)
  end

  def zro(%State{} = state, :first_call) do
    state
  end

  def zro(%State{} = state, :second_call) do
    # handle both ZRO and ZRO ADDRSS
    # IO.puts("ZRO ------------------------------------------------")
    # IO.puts("ZRO #{inspect(state.label_tokens)} -----------------")

    cond do
      length(state.label_tokens) != 1 ->
        nil

      [{:symbol, label_name}] = state.label_tokens ->
        IO.puts("ZRO has address #{label_name}")
        IO.puts("Symbol value: #{Map.get(state.symbols, label_name) |> inspect}")
    end

    State.add_memory(state, 0, 0)
  end
end
