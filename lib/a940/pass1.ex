defmodule A940.Pass1 do
  alias A940.{State, Op, Memory, Tokens}

  import Bitwise

  @address_terminators [{:spaces, " "}, {:eol, ""}]
  @addresses_terminators [{:delimiter, ","}, {:spaces, " "}, {:eol, ""}]

  def run(%A940.State{} = state) do
    infinite_enumerable = Stream.cycle([:a, :b])

    Enum.reduce_while(
      infinite_enumerable,
      state,
      fn _a, current_state ->
        case Tokens.next() do
          {:ok, line_number, tokens_list} ->
            {:cont,
             assemble_statement(
               A940.Macro.expand_dummy(state, tokens_list),
               update_state_for_next_statement(current_state, line_number)
             )}

          {:error, "no more tokens"} ->
            {:halt, current_state}
        end
      end
    )
  end

  def assemble_statement([eol: ""], %A940.State{} = state),
    do: state

  def assemble_statement(tokens, %A940.State{} = state) do
    tokens =
      A940.Macro.expand_macro_tokens(tokens, state)

    # state = %{state | operation: nil}
    # will return     {remaining, list-of-list-of-tokens}

    {tokens, label_tokens} = get_address(tokens, state, @address_terminators)
    state = %{state | label_tokens: label_tokens}

    if not state.flags.done do
      # will return     {remaining, list-of-list-of-tokens}
      {tokens, opcode_tokens} = get_address(tokens, state, @address_terminators)
      state = %{state | opcode_tokens: opcode_tokens}
      # {"processing opcode", state.line_number} |> dbg
      if not state.assembling and not is_actionable_conditional(state.opcode_tokens) do
        IO.puts("Not assembling line #{state.line_number} -------------------------------")
        state
      else
        IO.puts(
          "    Assembling line #{state.line_number}: #{Map.get(state.lines, state.line_number)} -------------------------------"
        )

        state = Op.process_opcode(state)
        # state.operation |> dbg

        address_tokens_list =
          if state.operation.address_class == :no_address do
            [[]]
            # tokens |> dbg
            # will return     {remaining, list-of-list-of-tokens}
          else
            {[], tokens} = get_tokens_list(tokens, state)
            tokens
          end

        {[], %{state | address_tokens_list: address_tokens_list}}

        Op.process_opcode_again(state)
      end
    else
      state
    end
  end

  def update_state_for_next_statement(%A940.State{} = state, linenumber)
      when is_integer(linenumber) and linenumber > 0 do
    %{
      state
      | flags: A940.Flags.default(),
        line_number: linenumber,
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

  def get_label_tokens([{:comment, _}, {:eol, ""}], %A940.State{} = state) do
    done_with_statement(state)
  end

  # def get_label_tokens(
  #       tokens,
  #       %A940.State{} = state
  #     )
  #     when is_list(tokens) do
  #   {rest, label_tokens} = get_address(tokens, state, @address_terminators)
  #   {rest, %{state | label_tokens: label_tokens}}
  # end

  def get_label_tokens(tokens, %A940.State{} = state) do
    IO.puts(
      "Cannot parse tokens at begining of statement \##{state.line_number}: #{inspect(Enum.take(tokens, 5))}"
    )

    raise "cannot parse tokens at beginning of statment"
  end

  # def tokens_up_to(tokens, stop_tokens_list) when is_list(tokens) and is_list(stop_tokens_list) do
  #   rv_tokens =
  #     if hd(tokens) == {:delimiter, "("} do
  #       get_balanced_tokens(tokens, tl(tokens), 1, state)
  #     else
  #       Enum.reduce_while(tokens, [], fn token, token_list ->
  #         cond do
  #           token in stop_tokens_list -> {:halt, token_list}
  #           true -> {:cont, [token | token_list]}
  #         end
  #       end)
  #       |> Enum.reverse()
  #     end

  #   cond do
  #     length(rv_tokens) == length(tokens) ->
  #       {rv_tokens, [], {:eol, ""}}

  #     true ->
  #       [stop_token | rest_of_tokens] = Enum.slice(tokens, length(rv_tokens)..-1//1)
  #       {rv_tokens, rest_of_tokens, stop_token}
  #   end
  # end

  def done_with_statement(%State{} = state) do
    new_flags = %{state.flags | done: true}
    {[], %{state | flags: new_flags}}
  end

  # def get_opcode_tokens(tokens, %State{} = state) do
  #   {opcode_tokens, rest, terminating_token} = tokens_up_to(tokens, [{:spaces, " "}, {:eol, ""}])

  #   cond do
  #     state.flags.done ->
  #       {[], state}

  #     terminating_token == {:spaces, " "} or terminating_token == {:eol, ""} ->
  #       {rest, %{state | opcode_tokens: opcode_tokens}}

  #     true ->
  #       raise "badly formed opcode or terminator #{opcode_tokens} #{terminating_token} in statement #{state.line_number}"
  #   end
  # end

  def get_tokens_list([], %State{} = _state) do
    {[], [[]]}
  end

  def get_tokens_list(tokens, %State{} = state) do
    get_addresses(tokens, state, [])
  end

  # this is called get_addresses(), but it can also get the tokens in the opcode
  # returns: {remaining, tokens_of_one_address_field}
  def get_addresses([], %State{} = _state, addresses)
      when is_list(addresses), do: {[], addresses}

  def get_addresses(tokens, %State{} = state, addresses) when is_list(addresses) do
    {address, terminator, remaining_tokens} = get_address(tokens, state, @addresses_terminators)

    if terminator not in @addresses_terminators do
      raise "Invalid address terminator : #{inspect(terminator)}, line #{state.line_number}"
    end

    addresses = addresses ++ [strip_outer_parens(address)]

    if terminator == {:spaces, " "} do
      {remaining_tokens, addresses}
    else
      get_addresses(remaining_tokens, state, addresses)
    end
  end

  # return {tokens, state, remaining}, without the terminator
  def get_address(tokens, state, terminator) do
    {tokens, state.line_number} |> dbg
    get_address1(tokens, state, [], terminator)
  end

  def get_address1([first | rest] = _tokens, %State{} = state, address, terminator) do
    cond do
      first in terminator ->
        {Enum.reverse(address), first, rest}

      first == {:delimiter, "("} ->
        {balanced, remaining} = A940.Address.get_balanced_tokens(rest)
        # put back parentheses (backwards since this will be reversed)
        balanced = [{:delimiter, ")"}, balanced, {:delimiter, "("}] |> List.flatten()
        get_address1(remaining, state, [balanced | address], terminator)

      true ->
        get_address1(rest, state, [first | address], terminator)
    end
  end

  def strip_outer_parens([first | rest] = address) when is_list(address) do
    cond do
      first != {:delimiter, "("} -> address
      Enum.slice(rest, -1..-1//1) == {:delimiter, ")"} -> Enum.slice(rest, 0..-2//1)
      true -> raise("expression that should be balanced isn't #{inspect(address)}")
    end
  end

  # def get_address_tokens(addresses_tokens_list, tokens, %State{} = state) do
  #   cond do
  #     hd(tokens) == {:delimiter, "("} ->
  #       a + 1

  #     true ->
  #       get_comma_delimited_tokens(addresses_tokens_list, tokens, state)
  #   end
  # end

  # def get_comma_delimited_tokens(addresses_tokens_list, tokens, %State{} = state) do
  #   {address_field, rest, terminating_token} =
  #     tokens_up_to(tokens, [{:delimiter, ","}, {:spaces, " "}, {:eol, ""}])

  #   cond do
  #     {:delimiter, ","} == terminating_token ->
  #       get_address_tokens([address_field | addresses_tokens_list], rest, state)

  #     {:spaces, " "} == terminating_token ->
  #       [address_field | addresses_tokens_list]

  #     {:eol, ""} == terminating_token ->
  #       [address_field | addresses_tokens_list]

  #     true ->
  #       raise "addresses terminated with unrecognized token: #{terminating_token}"
  #   end
  # end

  # def get_balanced_tokens(_addresses_tokens_list, [], _, %State{} = state) do
  #   raise "Unbalanced parentheses in address field, line #{state.line_number}"
  # end

  # def get_balanced_tokens(addresses_tokens_list, tokens, 0, %State{} = state) do
  #   # The close {:delimiter ")"} was just added, so remove it
  #   tl(addresses_tokens_list)
  # end

  # def get_balanced_tokens(addresses_tokens_list, tokens, count, %State{} = state)
  #     when is_integer(count) do
  #   # the leading ( has been swallowed;
  #   first_token = hd(tokens)

  #   cond do
  #     first_token == {:delimiter, ")"} ->
  #       get_balanced_tokens([first_token | addresses_tokens_list], tl(tokens), count - 1, state)

  #     first_token == {:delimiter, "("} ->
  #       get_balanced_tokens([first_token | addresses_tokens_list], tl(tokens), count + 1, state)

  #     true ->
  #       get_balanced_tokens([first_token | addresses_tokens_list], tl(tokens), count, state)
  #   end
  # end

  def handle_address_fields(
        [{:spaces, _} | tokens],
        %State{} = state
      )
      when is_list(tokens) do
    {"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", tokens} |> dbg

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
    {rest_of_tokens, state.operation.agent.(state, address_tokens)}
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

          # State.mergezz_address(state, address_field, state.location_relative - 1)
          # |> State.mergezz_tag(tag &&& 7, state.location_relative - 1)

          location = State.get_current_location(state, -1)

          Memory.merge_address(location, address_field, state.flags.address_length)
          Memory.merge_tag(location, tag)
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
          # address_field = address &&& 2 ** state.flags.address_length - 1
          # State.mergezz_address(state, address_field, state.location_relative - 1)
          Memory.merge_address(
            State.get_current_location(state, -1),
            address,
            state.flags.address_length
          )
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

  def label_name(label_tokens) do
    cond do
      length(label_tokens) == 0 ->
        nil

      length(label_tokens) == 1 ->
        [{:symbol, label_name}] = label_tokens
        label_name

      length(label_tokens) == 2 ->
        [_, {:symbol, label_name}] = label_tokens
        label_name

      true ->
        nil
    end
  end

  def label_global(label_tokens) do
    cond do
      # should true case check for {:delimiter, "$"}, {:symbol, _} ???
      length(label_tokens) == 0 -> false
      length(label_tokens) == 1 -> false
      length(label_tokens) == 2 -> true
      true -> false
    end
  end

  # def is_actionable_conditional(opcode_tokens) when is_list(opcode_tokens) do
  def is_actionable_conditional(opcode_tokens) do
    # opcode_tokens |> dbg

    cond do
      length(opcode_tokens) != 1 ->
        false

      :symbol == hd(opcode_tokens) |> elem(0) ->
        (hd(opcode_tokens) |> elem(1)) in ["IF", "ELSE", "ELSF", "ENDF"]

      true ->
        false
    end
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
