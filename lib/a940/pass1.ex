defmodule A940.Pass1 do
  alias A940.State
  alias A940.Op

  import Bitwise

  def run(%A940.State{} = state) do
    Enum.reduce(state.tokens_list, state, fn %A940.Tokenizer{line_number: linenum, tokens: tokens},
                                             state ->
      handle_statement(tokens, update_state_for_next_statement(state, linenum))
    end)
  end

  def handle_statement(tokens, %A940.State{} = state) do
    {tokens, state} = get_label_tokens(tokens, state)
    {state.label_tokens, tokens}
    #  |> dbg
    {tokens, state} = get_opcode_tokens(tokens, state)
    {state.opcode_tokens, tokens}
    #  |> dbg
    state = Op.process_opcode(state)
    # state

    {_, state} =
      if state.operation.address_class == :no_address,
        do: {[], state},
        else: get_address_tokens(tokens, state)

    {state.label_tokens, state.opcode_tokens, state.flags.address_class,
     state.flags.address_length, state.address_tokens_list}
    |> dbg

    state
  end

  def update_state_for_next_statement(%A940.State{} = state, linenumber)
      when is_integer(linenumber) and linenumber > 0 do
    %{
      state
      | flags: A940.Flags.default(),
        line_number: linenumber,
        agent_during_address_processing: nil,
        label_tokens: [],
        opcode_tokens: [],
        # two token lists for indexed;
        # one token list for simple address
        # empty list for :no_address ops
        # many lists of tokens for macro calls
        address_tokens_list: [[]]
    }
  end

  def get_label_tokens([{:spaces, _} | rest], %A940.State{} = state) do
    # label tokens already set to empty list
    {rest, state}
  end

  def get_label_tokens([{:eol, _}], %A940.State{} = state) do
    done_with_statement(state)
  end

  def get_label_tokens([], %A940.State{} = state) do
    done_with_statement(state)
  end

  def get_label_tokens([{:delimiter, "*"}], %A940.State{} = _state) do
    raise "* delimiter instead of comment"
    # done_with_statement(state)
  end

  def get_label_tokens([{:comment, _}], %A940.State{} = state) do
    done_with_statement(state)
  end

  def get_label_tokens(
        tokens,
        %A940.State{} = state
      )
      when is_list(tokens) do
    {label_tokens, rest, {:spaces, _}} = tokens_up_to(tokens, [{:spaces, " "}])
    {rest, %{state | label_tokens: label_tokens}}
  end

  def get_label_tokens(tokens, %A940.State{} = state) do
    IO.puts(
      "Cannot parse tokens at begining of statement \##{state.line_number}: #{inspect(Enum.take(tokens, 5))}"
    )

    raise "cannot parse tokens at beginning of statment"
  end

  def tokens_up_to(tokens, stop_tokens_list) when is_list(tokens) and is_list(stop_tokens_list) do
    rv_tokens =
      Enum.reduce_while(tokens, [], fn token, token_list ->
        cond do
          token in stop_tokens_list -> {:halt, token_list}
          true -> {:cont, [token | token_list]}
        end
      end)
      |> Enum.reverse()

    cond do
      length(rv_tokens) == length(tokens) ->
        {rv_tokens, [], {:eol, ""}}

      true ->
        [stop_token | rest_of_tokens] = Enum.slice(tokens, length(rv_tokens)..-1//1)
        {rv_tokens, rest_of_tokens, stop_token}
    end
  end

  def done_with_statement(%State{} = state) do
    new_flags = %{state.flags | done: true}
    {[], %{state | flags: new_flags}}
  end

  def get_opcode_tokens(tokens, %State{} = state) do
    {opcode_tokens, rest, terminating_token} = tokens_up_to(tokens, [{:spaces, " "}, {:eol, ""}])

    cond do
      terminating_token == {:spaces, " "} or terminating_token == {:eol, ""} ->
        {rest, %{state | opcode_tokens: opcode_tokens}}

      true ->
        raise "badly formed opcode or terminator #{opcode_tokens} #{terminating_token} in statement #{state.line_number}"
    end
  end

  def get_address_tokens(tokens, %State{} = state) do
    {[], %{state | address_tokens_list: Enum.reverse(get_address_tokens([], tokens, state))}}
  end

  # def get_address_tokens(addresses_tokens_list, [], %State{} = state) do
  #   %{state | address_tokens_list: Enum.reverse(addresses_tokens_list)}
  # end

  def get_address_tokens(addresses_tokens_list, tokens, %State{} = state) do
    {address_field, rest, terminating_token} =
      tokens_up_to(tokens, [{:delimiter, ","}, {:spaces, " "}, {:eol, ""}])

    cond do
      {:delimiter, ","} == terminating_token ->
        get_address_tokens([address_field | addresses_tokens_list], rest, state)

      {:spaces, " "} == terminating_token ->
        [address_field | addresses_tokens_list]

      {:eol, ""} == terminating_token ->
        [address_field | addresses_tokens_list]

      true ->
        raise "addresses terminated with unrecognized token: #{terminating_token}"
    end
  end

  def handle_address_fields(
        [{:spaces, _} | tokens],
        %State{agent_during_address_processing: agent} = state
      )
      when agent != nil and is_list(tokens) do
    # tokens |> dbg

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

  def handle_address_fields([{:eol, _}], %State{} = state) do
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
        %State{} = state
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

          State.merge_address(state, address_field, state.location_relative - 1)
          |> State.merge_tag(tag &&& 7, state.location_relative - 1)
      end

    {[], new_state}
  end

  def handle_address_fields(
        [{:spaces, _}, {:number, val} | _rest],
        %State{} = state
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

          State.merge_address(state, address_field, state.location_relative - 1)
      end

    {[], new_state}
  end

  def handle_address_fields([], %State{} = state) do
    {[], state}
  end

  def handle_address_fields(tokens, %State{} = state) do
    IO.puts(
      "Cannot parse tokens in address fields statement \##{state.line_number}: \n#{inspect(Enum.take(tokens, 5))}"
    )

    raise "cannot parse tokens in address fields"
  end

  # defp check_symbols(%State{} = state, tokens_list) do
  #   syms = state.symbols
  #   keys = Map.keys(syms)

  #   bad_keys =
  #     Enum.filter(keys, fn key -> not (is_binary(key) and Regex.match?(~r/^[0-9A-Z:]+$/, key)) end)

  #   if length(bad_keys) > 0 do
  #     IO.puts("line #{state.line_number}, ")
  #     tokens_list |> dbg
  #     raise "extra stuff in state.symbols"
  #   end

  #   Enum.each(bad_keys, fn key -> IO.puts("Bad key: #{inspect(key)}") end)
  #   state
  # end
end
