defmodule A940.Op do
  alias A940.State

  import Bitwise

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

  defp opcode_table do
    %{}
    |> Map.put("IDENT", new(0, :no_address, 0, &A940.Directive.ident/1))
    |> Map.put("BSS", new(0, :yes_address, 0, &A940.Directive.bss/1))
    |> Map.put("ZRO", new(0, :no_address, 0, &A940.Directive.zro/1))
    |> Map.put("DATA", new(0, :yes_address, 0, &A940.Directive.data/1))
    |> Map.put("END", new(0, :no_address, 0, &A940.Directive.f_end/1))
    |> Map.put("EQU", new(0, :yes_address, 0, &A940.Directive.equ/1))
    |> Map.put("BRU", new(0o0100000))
    |> Map.put("STA", new(0o3500000))
    |> Map.put("LDA", new(0o7600000))
    |> Map.put("NOP", new(0o2000000, :maybe_address))
    |> Map.put("XXA", new(0o4600600, :no_address))
  end

  def process_opcode(%State{} = state) do
    cond do
      length(state.opcode_tokens) == 2 ->
        [opcode_token, {:delimiter, "*"}] = state.opcode_tokens
        handle_indirect_op(state, opcode_token)

      length(state.opcode_tokens) == 1 ->
        handle_direct_op(state, hd(state.opcode_tokens))

      true ->
        raise "Illegal opcode tokens #{state.opcode_tokens}"
    end
  end

  def handle_direct_op(%A940.State{} = state, {opcode_token_flag, opcode} = _symbol_name) do
    op =
      cond do
        opcode_token_flag == :number -> new(opcode, :yes_address, 14)
        opcode_token_flag == :symbol -> get_op(state, opcode)
      end

    op_structure =
      cond do
        op == nil ->
          raise "Undefined opcode #{opcode}"

        true ->
          op
          # A940.State.add_memory(state, op.value)
          # |> update_flags(op.address_class, op.address_length)
      end

    # ensure indirect only if 14 bit address.
    # does this apply to macro calls?
    # the value of this cond is immaterial and ignored; it is used only for the *raise* side effect
    cond do
      false == state.flags.indirect ->
        nil

      # indirect flag is set; address must be required and must be 14 bits
      op_structure.address_class != :yes_address ->
        raise "illegal indirect for opcode #{opcode}"

      op_structure.address_length != 14 ->
        raise "illegal indirect for opcode #{opcode} with address_length #{op_structure.address_length}"

      true ->
        nil
    end

    %{state | operation: op_structure}
  end

  def handle_indirect_op(%A940.State{} = state, opcode_token) do
    handle_direct_op(set_indirect_flag(state), opcode_token)
  end

  defp get_op(%A940.State{} = _state, op_name), do: Map.get(opcode_table(), op_name)

  defp set_indirect_flag(%A940.State{} = state) do
    new_flags = %{state.flags | indirect: true}
    %{state | flags: new_flags}
  end
end
