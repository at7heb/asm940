defmodule A940.Address do
  alias A940.State

  import Bitwise

  @moduledoc """
  This module defines the data for an address, also an expresion.
  For ```LOOP1 LDA TABLE,2```, for example, ```value``` would be the
  value of the current location, ```relocation``` would be 1, ```expression_tokens```
  would be the empty list, and ```b14?``` would be ```true```.

  For ```$GC EAX HEAPST```, this would be just like ```LOOP1``` except ```exported?``` would be true.

  For ```ENV1 EQU 176B5```, this would be ```176B5, 0, [], and false```.

  For ```SPTR1 EQU 3*WELCOM```, this would be ```0, 0, [{:number,3}, {:delimiter,"*"}, {:symbol, "WELCOM"}], false```.
  """
  defstruct value: 0,
            relocation: 1,
            expression_tokens: [],
            b14?: true,
            exported?: false,
            external?: false

  def new(value, relocation, exported \\ false, b14? \\ false)
      when is_integer(value) and is_integer(relocation) and is_boolean(exported) and
             is_boolean(b14?) do
    mask =
      cond do
        b14? -> 0o37777
        true -> 0o77777777
      end

    %__MODULE__{value: value &&& mask, relocation: relocation, exported?: exported}
  end

  def new_expression(expression, exported \\ false) when is_list(expression),
    do: %__MODULE__{
      value: 0,
      relocation: 0,
      expression_tokens: expression,
      exported?: exported,
      b14?: false
    }

  def eval(%State{} = state), do: eval(state, hd(state.address_tokens_list))

  # eval can return any number, not just one that fits into a 14-bit address field
  # it is in this A940.Address module because the number is in the address field of
  # each instruction.
  def eval(%State{} = _state, [{:number, num}] = _address_tokens) when is_integer(num),
    do: {num &&& 0o7777777, 0}

  def eval(%State{} = state, [{:number, {_num, representation}}] = _address_tokens)
      when is_binary(representation),
      do: {String.to_integer(representation, state.flags.default_base) &&& 0o7777777, 0}

  def eval(%State{} = state, [{:symbol, address_part_symbol}] = _address_token) do
    address_part_address = Map.get(state.symbols, address_part_symbol, nil)
    # |> dbg()
    {address_part_address.value, address_part_address.relocation}
  end

  def eval(%State{} = state, [{:delimiter, "*"}] = _address_token) do
    if state.flags.relocating do
      {state.location_relative, 1}
      # |> dbg
    else
      {state.location_absolute, 0}
      # |> dbg
    end
  end
end
