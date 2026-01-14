defmodule A940.MemoryValue do
  import Bitwise
  alias A940.Listing

  @moduledoc """
  represent the value of a memory word emitted by the assembler
  If dummy is true, this is no memory. It might be used when
  there is a directive that doesn't generate code.

  if address_expression is not empty, then it is the expression
  from which the address will be calculated "in the fullness of time".
  This is the case when a symbol is used before definition, such as a literal.

  the mask may be 0o777 in the case of a shift instruction.
  the mask may be 0o37777 in the case of an opcode addressing memory
  the mask may be 0o77777777 in the case of a DATA directive

  otherwise, value and relocation_value define the content.
  If the relocation value is 1, then the address will be incremented
  with the location of the firs word
  """

  defstruct value: 0,
            # list of tokens or empty; most of the time
            address_expression: [],
            relocation_value: 0,
            mask: 0o37777,
            dummy: false

  @doc """
  create a memory value with given conttent, relocation value, and mask
  """
  def new(value, address_expression_tokens, mask \\ 0o37777)

  def new(value, relocation, mask)
      when is_integer(value) and is_integer(relocation) and value >= 0 and value <= 0o77777777 and
             (mask == 0o777 or mask == 0o37777 or mask == 0o77777777),
      do: %__MODULE__{value: value &&& mask, relocation_value: relocation, mask: mask}

  def new(value, address_expression_tokens, mask)
      when is_integer(value) and is_list(address_expression_tokens) and value >= 0 and
             value <= 0o77777777 and
             (mask == 0o777 or mask == 0o37777 or mask == 0o77777777),
      do: %__MODULE__{
        value: value,
        relocation_value: 0,
        address_expression: address_expression_tokens
      }

  def new(address_expression_tokens)
      when is_list(address_expression_tokens),
      do: %__MODULE__{
        value: 0,
        relocation_value: 0,
        address_expression: address_expression_tokens
      }

  def new_dummy(), do: %__MODULE__{dummy: true}

  def merge_value(%__MODULE__{value: content} = memory_value, merge_value),
    do: %{memory_value | value: content ||| merge_value}

  #   %A940.MemoryValue{value: 2064385, address_expression: [], relocation_value: 0},

  defimpl Inspect, for: __MODULE__ do
    def inspect(memory_value, _opts) do
      "<MemoryValue: #{Integer.to_string(memory_value.value, 8)}, address_expression: " <>
        "#{inspect(memory_value.address_expression)}, relocation_value: #{memory_value.relocation_value}>"
    end
  end

  # Empty value field for comments
  def format_for_listing(%__MODULE__{dummy: true}), do: ["        "]

  def format_for_listing(%__MODULE__{} = memory_value) do
    [
      Listing.fmt_int(memory_value.value, 8, 8, "0"),
      " ",
      case memory_value.relocation_value do
        0 -> " "
        1 -> "R"
        _ -> ["-R", Integer.to_string(memory_value.relocation_value, 16)]
      end
    ]
  end

  def format_for_listing(unk), do: ["unk: ", inspect(unk)]
end
