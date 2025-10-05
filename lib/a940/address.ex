defmodule A940.Address do
  @moduledoc """
  This module defines the data for an address, also an expresion.
  For ```LOOP1 LDA TABLE,2```, for example, ```value``` would be the
  value of the current location, ```relocation``` would be 1, ```expression_tokens```
  would be the empty list, and ```b14?``` would be ```true```.

  For ```$GC EAX HEAPST```, this would be just like ```LOOP1``` except ```exported?``` would be true.

  For ```ENV1 EQU 176B5```, this would be ```176B5, 0, [], and false```.

  For ```SPTR1 EQU 3*WELCOM```, this would be ```0, 0, [{:number,3}, {:delimiter,"*"}, {:symbol, "WELCOM"}], false```.
  """
  defstruct value: 0, relocation: 1, expression_tokens: [], b14?: true, exported?: false

  def new(value, relocation, exported)
      when is_integer(value) and is_integer(relocation) and is_boolean(exported),
      do: %__MODULE__{value: value, relocation: relocation, exported?: exported}

  def new(expression, exported) when is_list(expression),
    do: %__MODULE__{
      value: 0,
      relocation: 0,
      expression_tokens: expression,
      exported?: exported,
      b14?: false
    }
end
