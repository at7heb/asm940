defmodule A940.Op do
  alias A940.State
  alias A940.Address

  # import Bitwise

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
    |> Map.put("IDENT", new(0, :no_address, 0, &A940.Directive.ident/2))
    |> Map.put("BSS", new(0, :yes_address, 0, &A940.Directive.bss/2))
    |> Map.put("ZRO", new(0, :no_address, 0, &A940.Directive.zro/2))
    |> Map.put("DATA", new(0, :yes_address, 0, &A940.Directive.data/2))
    |> Map.put("END", new(0, :no_address, 0, &A940.Directive.f_end/2))
    |> Map.put("EQU", new(0, :yes_address, 0, &A940.Directive.equ/2))
    |> Map.put("BRU", new(0o0100000))
    |> Map.put("STA", new(0o3500000))
    |> Map.put("STB", new(0o3600000))
    |> Map.put("STX", new(0o3700000))
    |> Map.put("LDX", new(0o7100000))
    |> Map.put("LDB", new(0o7500000))
    |> Map.put("LDA", new(0o7600000))
    |> Map.put("EAX", new(0o7700000))
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

  def handle_direct_op(%State{} = state, {opcode_token_flag, opcode} = _symbol_name) do
    op_structure =
      cond do
        opcode_token_flag == :number -> new(opcode, :yes_address, 14)
        opcode_token_flag == :symbol -> get_op(state, opcode)
        true -> raise "unknown opcode #{opcode} line #{state.line_number}"
      end

    # ensure indirect only if 14 bit address.
    # does this apply to macro calls?
    # the value of this cond is immaterial and ignored; it is used only for the *raise* side effect
    state = %{state | operation: op_structure}

    cond do
      op_structure.processing_function != nil ->
        op_structure.processing_function.(state, :first_call)

      true ->
        state
    end
  end

  def update_opcode_memory(%State{} = state) do
    address_value = Address.eval(state, hd(state.address_tokens_list))

    tag_value =
      cond do
        length(state.address_tokens_list) == 1 ->
          0

        length(state.address_tokens_list) == 2 ->
          tag_tokens = Enum.at(state.address_tokens_list, 1)
          Address.eval(state, tag_tokens)
      end

    {address_value, tag_value} |> dbg
    State.add_memory(state, state.operation.value, 0)
  end

  def handle_indirect_op(%State{} = state, opcode_token) do
    handle_direct_op(set_indirect_flag(state), opcode_token)
  end

  defp get_op(%A940.State{} = _state, op_name), do: Map.get(opcode_table(), op_name)

  defp set_indirect_flag(%State{} = state) do
    new_flags = %{state.flags | indirect: true}
    %{state | flags: new_flags}
  end

  def process_opcode_again(%State{} = state) do
    state =
      cond do
        state.operation.processing_function != nil ->
          state.operation.processing_function.(state, :second_call)

        true ->
          process_op_not_directive(state)
      end

    state.operation
    |> dbg

    state.code
    |> dbg

    state.address_tokens_list
    |> dbg

    state
  end

  def process_op_not_directive(%State{} = state) do
    tag =
      cond do
        length(state.address_tokens_list) == 2 ->
          Address.eval(state, Enum.at(state.address_tokens_list, 1))

        true ->
          {0, 0}
      end

    address =
      cond do
        length(state.address_tokens_list) > 1 ->
          Address.eval(state, hd(state.address_tokens_list))

        true ->
          {0, 0}
      end

    mask =
      cond do
        state.operation.address_length == 14 -> 0o37777
        state.operation.address_length == 9 -> 0o777
        true -> 0
      end

    {address, tag, mask} |> dbg
    state
    # state.update_opcode_memory(state)
  end
end
