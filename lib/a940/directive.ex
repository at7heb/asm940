defmodule A940.Directive do
  def ident(%A940.State{} = state), do: state
  def bss(%A940.State{} = state), do: state
  def zro(%A940.State{} = state), do: state
end
