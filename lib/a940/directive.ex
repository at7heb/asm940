defmodule A940.Directive do
  alias A940.State

  def bss(%State{} = state),
    do: %{state | agent_during_address_processing: &A940.Directive.bss_post_agent/2}

  def bss_post_agent(%State{} = state, address_tokens) do
    {val, relocation} = A940.Address.eval(state, address_tokens)

    if val < 1 or val > 16383,
      do: raise("BSS on line #{state.line_number} of #{val} words is illegal")

    if relocation != 0,
      do: raise("BSS on line #{state.line_number} has illegal relocation=#{relocation}")

    Enum.reduce(1..val, state, fn _n, state -> zro(state) end)
  end

  def data(%State{} = state),
    do: %{state | agent_during_address_processing: &A940.Directive.data_post_agent/2}

  def data_post_agent(%State{} = state, address_tokens) do
    {val, relocation} = A940.Address.eval(state, address_tokens)

    State.add_memory(state, val, relocation)
  end

  def equ(%State{} = state),
    do: %{state | agent_during_address_processing: &A940.Directive.equ_post_agent/2}

  def equ_post_agent(%State{} = state, address_tokens) do
    {address_tokens, state.line_number} |> dbg
    {val, relocation} = A940.Address.eval(state, address_tokens)

    State.redefine_symbol_value(state, state.flags.label, val, relocation)
  end

  def f_end(%State{} = state) do
    if state.ident == "" do
      raise "No IDENT directive"
    end

    new_flags = %{state.flags | done: true}
    %{state | flags: new_flags}
  end

  def ident(%State{} = state) do
    if state.ident != "" do
      raise "Multiple IDENT directives"
    end

    new_state = State.remove_symbol(state, state.flags.label)
    %{new_state | ident: state.flags.label, flags: %{state.flags | done: true}}
  end

  def zro(%State{} = state) do
    %{state | flags: %{state.flags | done: true}}
    |> State.add_memory(0, 0)
  end
end
