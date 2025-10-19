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
    {state.address_tokens_list, state.line_number} |> dbg
    {val, relocation} = A940.Address.eval(state)

    State.redefine_symbol_value(state, state.flags.label, val, relocation)
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
    state.ident |> dbg
    IO.puts("ident 1st-----------------------------------------------------------")

    state =
      cond do
        state.ident != "" ->
          raise "Multiple IDENT directives"

        length(state.label_tokens) != 1 ->
          raise "IDENT directive must have simple lable line #{state.line_number}"

        {:symbol, _} = hd(state.label_tokens) ->
          ident_name = elem(hd(state.label_tokens), 1) |> dbg
          %{state | ident: ident_name, flags: %{state.flags | done: true}}

        true ->
          raise "IDENT directive label fault line #{state.line_number}"
      end

    {"ident first call", state.ident} |> dbg
    state
  end

  def ident(%State{} = state, :second_call) do
    # nothing to do
    IO.puts("ident 2nd-----------------------------------------------------------")
    state
  end

  def zro(%State{} = state, :first_cal) do
    %{state | flags: %{state.flags | done: true}}
    |> State.add_memory(0, 0)
  end

  def zro(%State{} = state, :second_call) do
    state
  end
end
