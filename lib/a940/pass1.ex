defmodule A940.Pass1 do
  alias A940.State

  def run(%A940.State{} = state) do
    Enum.reduce(state.tokens_list, state, fn %A940.Tokenizer{line_number: linenum, tokens: tokens},
                                             state ->
      handle_statement(tokens, update_state_for_next_statement(state, linenum))
    end)
  end

  def handle_statement(tokens, %A940.State{} = state) do
    {new_tokens_0, new_state_0} = handle_beginning_of_statement(tokens, state)
    {new_tokens_1, new_state_1} = handle_opcode_in_statement(new_tokens_0, new_state_0)
    {_new_tokens_2, new_state_2} = handle_address_fields(new_tokens_1, new_state_1)
    new_state_2
  end

  def update_state_for_next_statement(%A940.State{} = state, linenumber)
      when is_integer(linenumber) and linenumber > 0 do
    %{state | flags: A940.Flags.default(), linenumber: linenumber}
  end

  def handle_beginning_of_statement([{:spaces, _} | rest], %A940.State{} = state) do
    {rest, state}
  end

  def handle_beginning_of_statement([{:eol, _}], %A940.State{} = state) do
    {[], state}
  end

  def handle_beginning_of_statement(
        [{:symbol, symbol} | [{:spaces, _} | rest]],
        %A940.State{} = state
      ) do
    new_flags = %{state.flags | label: symbol}
    new_state = State.update_symbol_table(state, symbol)
    {rest, %{new_state | flags: new_flags}}
  end

  def handle_beginning_of_statement(
        [{:delimiter, "$"} | [{:symbol, symbol} | [{:spaces, _} | rest]]],
        %A940.State{} = state
      ) do
    new_flags = %{state.flags | label: symbol}
    new_state = State.update_symbol_table(state, symbol, true)
    {rest, %{new_state | flags: new_flags}}
  end

  def handle_opcode_in_statement(
        [{:symbol, symbol_name} | [{_, "*"} | rest]],
        %A940.State{} = state
      ) do
    new_state = A940.Op.handle_indirect_op(state, symbol_name)

    if(state.flags.done) do
      {[], new_state}
    else
      {rest, new_state}
    end
  end

  def handle_opcode_in_statement([{:symbol, symbol_name} | rest], %A940.State{} = state) do
    new_state = A940.Op.handle_direct_op(state, symbol_name)
    {rest, new_state}
  end

  # def handle_opcode_in_statement([{:sym, _} | rest], %A940.State{} = state) do
  #   {[], state}
  # end
  # def handle_opcode_in_statement([{:eol, _}], %A940.State{} = state) do
  #   {[], state}
  # end

  def handle_opcode_in_statement([], %A940.State{} = state) do
    {[], state}
  end

  def handle_address_fields([{:eol, _}], %A940.State{} = state) do
    {[], state}
  end

  def handle_address_fields([], %A940.State{} = state) do
    {[], state}
  end
end
