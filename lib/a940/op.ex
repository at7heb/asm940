defmodule A940.Op do
  defstruct value: 0,
            # :maybe_address, :yes_address, :no_address
            class: :maybe_address,
            # 0, 9 or 14, but 14 if :yes_address with indirect bit
            address_length: 14,
            special_process: nil

  def new(value, class \\ :yes_address, address_length \\ 14, special_process \\ nil) do
    %__MODULE__{
      value: value,
      class: class,
      address_length: address_length,
      special_process: special_process
    }
  end

  def opcode_table do
    t =
      %{}
      |> Map.put("IDENT", new(0, :no_address, 0, &A940.Directive.ident/1))
      |> Map.put("BSS", new(0, :no_address, 0, &A940.Directive.bss/1))
      |> Map.put("ZRO", new(0, :no_address, 0, &A940.Directive.zro/1))
      |> Map.put("LDA", new(0o7600000))
      |> Map.put("STA", new(0o3500000))

    t
  end
end
