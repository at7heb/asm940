defmodule A940.Op do
  defstruct value: 0,
            # :maybe_address, :yes_address, :no_address
            address_class: :maybe_address,
            # 0, 9 or 14, but 14 if :yes_address with indirect bit
            address_length: 14,
            processing_function: nil

  def new(value, class \\ :yes_address, address_length \\ 14, processing_function \\ nil) do
    %__MODULE__{
      value: value,
      address_class: class,
      address_length: address_length,
      processing_function: processing_function
    }
  end

  def opcode_table do
    %{}
    |> Map.put("IDENT", new(0, :no_address, 0, &A940.Directive.ident/1))
    |> Map.put("BSS", new(0, :no_address, 0, &A940.Directive.bss/1))
    |> Map.put("ZRO", new(0, :no_address, 0, &A940.Directive.zro/1))
    |> Map.put("DATA", new(0, :no_address, 0, &A940.Directive.data/1))
    |> Map.put("END", new(0, :no_address, 0, &A940.Directive.f_end/1))
    |> Map.put("BRU", new(0o0100000))
    |> Map.put("STA", new(0o3500000))
    |> Map.put("LDA", new(0o7600000))
    |> Map.put("NOP", new(0o2000000, :maybe_address))
    |> Map.put("XXA", new(0o4600600, :no_address))
  end

  def handle_direct_op(%A940.State{} = state, symbol_name) when is_binary(symbol_name) do
    op = get_op(state, symbol_name)

    cond do
      op == nil ->
        raise "Undefined opcode #{symbol_name}"

      op.processing_function != nil ->
        op.processing_function.(state)

      true ->
        A940.State.add_memory(state, op.value)
        |> update_flags(op.address_class, op.address_length)
    end
  end

  def handle_indirect_op(%A940.State{} = state, symbol_name) when is_binary(symbol_name) do
    state
  end

  defp get_op(%A940.State{ops: ops} = _state, op_name), do: Map.get(ops, op_name)

  defp update_flags(%A940.State{} = state, address_class, address_length) do
    new_flags = %{state.flags | address_class: address_class, address_length: address_length}
    %{state | flags: new_flags}
  end
end
