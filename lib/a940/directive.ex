defmodule A940.Directive do
  def bss(%A940.State{} = state), do: state

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

  def zro(%A940.State{} = state), do: state
end
