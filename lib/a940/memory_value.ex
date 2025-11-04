defmodule A940.MemoryValue do
  import Bitwise

  defstruct value: 0,
            # list of tokens or empty; most of the time
            address_expression: [],
            relocation_value: 0

  def new(value, relocation)
      when is_integer(value) and is_integer(relocation) and value >= 0 and value <= 0o77777777,
      do: %__MODULE__{value: value, relocation_value: relocation}

  def new(value, address_expression_tokens)
      when is_integer(value) and is_list(address_expression_tokens) and value >= 0 and
             value <= 0o77777777,
      do: %__MODULE__{
        value: value,
        relocation_value: 0,
        address_expression: address_expression_tokens
      }

  def merge_value(%__MODULE__{value: content} = memory_value, merge_value),
    do: %{memory_value | value: content ||| merge_value}
end
