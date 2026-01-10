defmodule A940.MemoryValue do
  import Bitwise
  alias A940.Listing

  defstruct value: 0,
            # list of tokens or empty; most of the time
            address_expression: [],
            relocation_value: 0,
            dummy: false

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
      "<value: #{Integer.to_string(memory_value.value, 8)}, address_expression: " <>
        "#{inspect(memory_value.address_expression)}, relocation_value: #{memory_value.relocation_value}>"
    end
  end

  # Empty value field for comments
  def format_for_listing(%__MODULE__{dummy: true}), do: ["        "]

  def format_for_listing(%__MODULE__{} = memory_value) do
    [
      Listing.fmt_int(memory_value.value, 8, 8, "0"),
      " "
      # case memory_value.relocation_value do
      #   0 -> "A "
      #   1 -> "  "
      #   _ -> ["-R", Integer.to_string(memory_value.relocation_value, 16)]
      # end
    ]
  end

  def format_for_listing(unk), do: ["unk: ", inspect(unk)]
end
