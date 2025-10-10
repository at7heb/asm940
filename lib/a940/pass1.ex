defmodule A940.Pass1 do
  alias A940.State

  import Bitwise

  def run(%A940.State{} = state) do
    Enum.reduce(state.tokens_list, state, fn %A940.Tokenizer{line_number: linenum, tokens: tokens},
                                             state ->
      handle_statement(tokens, update_state_for_next_statement(state, linenum))
    end)
  end

  def handle_statement(tokens, %A940.State{} = state) do
    {new_tokens_0, new_state_0} = handle_beginning_of_statement(tokens, state)
    {new_tokens_1, new_state_1} = handle_opcode_in_statement(new_tokens_0, new_state_0)

    {_new_tokens_2, new_state_2} =
      if new_state_1.flags.done,
        do: {[], new_state_1},
        else: handle_address_fields(new_tokens_1, new_state_1)

    new_state_2
  end

  def update_state_for_next_statement(%A940.State{} = state, linenumber)
      when is_integer(linenumber) and linenumber > 0 do
    %{
      state
      | flags: A940.Flags.default(),
        line_number: linenumber,
        agent_during_address_processing: nil
    }
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

  def handle_beginning_of_statement([{:comment, _} | _rest], %A940.State{} = state) do
    new_flags = %{state.flags | done: true}
    {[], %{state | flags: new_flags}}
  end

  def handle_beginning_of_statement(tokens, %A940.State{} = state) do
    IO.puts(
      "Cannot parse tokens at begining of statement \##{state.line_number}: #{inspect(Enum.take(tokens, 5))}"
    )

    raise "cannot parse tokens at beginning of statment"
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

  def handle_opcode_in_statement(tokens, %A940.State{} = state) do
    IO.puts(
      "Cannot parse tokens in opcode of statement \##{state.line_number}: #{inspect(Enum.take(tokens, 5))}"
    )

    raise "cannot parse tokens in opcode of statment"
  end

  def handle_address_fields(
        [{:spaces, _} | tokens],
        %A940.State{agent_during_address_processing: agent} = state
      )
      when agent != nil and is_list(tokens) do
    tokens |> dbg

    address_tokens =
      Enum.reduce_while(tokens, [], fn token, token_list ->
        cond do
          elem(token, 0) == :spaces -> {:halt, token_list}
          elem(token, 0) == :delimiter and elem(token, 1) == "," -> {:halt, token_list}
          elem(token, 0) == :eol -> {:halt, token_list}
          true -> {:cont, [token | token_list]}
        end
      end)
      |> Enum.reverse()

    rest_of_tokens = Enum.slice(tokens, length(address_tokens)..-1//1)
    {rest_of_tokens, agent.(state, address_tokens)}
  end

  def handle_address_fields([{:eol, _}], %A940.State{} = state) do
    {[], state}
  end

  def handle_address_fields(
        [
          {:spaces, _},
          {:number, val},
          {:delimiter, ","},
          {:number, tag_val}
          | _rest
        ],
        %A940.State{} = state
      ) do
    address =
      cond do
        is_tuple(val) ->
          {_, representation} = val
          String.to_integer(representation, state.flags.default_base)

        is_integer(val) ->
          val

        true ->
          "unexpected number value:#{val}" |> dbg
      end

    tag =
      cond do
        is_tuple(tag_val) ->
          {val, _representation} = tag_val
          val

        is_integer(tag_val) ->
          tag_val

        true ->
          "unexpected tag value:#{tag_val}" |> dbg
      end

    new_state =
      cond do
        # the number is a comment...
        state.flags.address_class == :no_address ->
          state

        true ->
          address_field = address &&& 2 ** state.flags.address_length - 1

          A940.State.merge_address(state, address_field, state.location_relative - 1)
          |> A940.State.merge_tag(tag &&& 7, state.location_relative - 1)
      end

    {[], new_state}
  end

  def handle_address_fields(
        [{:spaces, _}, {:number, val} | _rest],
        %A940.State{} = state
      ) do
    address =
      cond do
        is_tuple(val) ->
          {_, representation} = val
          String.to_integer(representation, state.flags.default_base)

        is_integer(val) ->
          val

        true ->
          "unexpected number value:#{val}" |> dbg
      end

    new_state =
      cond do
        # the number is a comment...
        state.flags.address_class == :no_address ->
          state

        true ->
          address_field = address &&& 2 ** state.flags.address_length - 1

          A940.State.merge_address(state, address_field, state.location_relative - 1)
      end

    {[], new_state}
  end

  def handle_address_fields([], %A940.State{} = state) do
    {[], state}
  end

  def handle_address_fields(tokens, %A940.State{} = state) do
    IO.puts(
      "Cannot parse tokens in address fields statement \##{state.line_number}: \n#{inspect(Enum.take(tokens, 5))}"
    )

    raise "cannot parse tokens in address fields"
  end
end
