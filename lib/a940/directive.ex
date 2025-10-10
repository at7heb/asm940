defmodule A940.Directive do
  import Bitwise

  def bss(%A940.State{} = state),
    do: %{state | agent_during_address_processing: &A940.Directive.bss_post_agent/2}

  def bss_post_agent(%A940.State{} = state, address_tokens) do
    val = A940.Address.eval(state, address_tokens)

    if val < 1 or val > 16383 do
      raise "BSS on line #{state.line_number} of #{val} words is illegal"
    end

    Enum.reduce(1..val, state, fn _n, state -> zro(state) end)
  end

  def data(%A940.State{} = state),
    do: %{state | agent_during_address_processing: &A940.Directive.data_post_agent/2}

  def data_post_agent(%A940.State{} = state, address_tokens) do
    val = A940.Address.eval(state, address_tokens) &&& 8_388_607

    A940.State.add_memory(state, val, 0)
  end

  def f_end(%A940.State{} = state) do
    if state.ident == "" do
      raise "No IDENT directive"
    end

    new_flags = %{state.flags | done: true}
    %{state | flags: new_flags}
  end

  def ident(%A940.State{} = state) do
    if state.ident != "" do
      raise "Multiple IDENT directives"
    end

    ident_label = state.flags.label
    new_symbols = A940.State.remove_symbol(state, ident_label)
    new_flags = %{state.flags | done: true}
    %{state | symbols: new_symbols, ident: ident_label, flags: new_flags}
  end

  def zro(%A940.State{} = state) do
    %{state | flags: %{state.flags | done: true}}
    |> A940.State.add_memory(0, 0)
  end
end
