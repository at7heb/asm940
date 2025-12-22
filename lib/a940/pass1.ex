defmodule A940.Pass1 do
  alias A940.{State, Op, Tokens}

  @address_terminators [{:spaces, " "}, {:eol, ""}]
  @addresses_terminators [{:delimiter, ","}, {:spaces, " "}, {:eol, ""}]

  @debug_line nil

  def run(%A940.State{} = state) do
    infinite_enumerable = Stream.cycle([:a, :b])

    Enum.reduce_while(
      infinite_enumerable,
      state,
      fn _a, current_state ->
        case Tokens.next() do
          {:ok, line_number, tokens_list} ->
            {:cont,
             (
               expanded = A940.Macro.expand_dummy(state, tokens_list)

               if state.line_number == @debug_line do
                 {expanded.label_tokens, expanded.op_tokens, expanded.address_tokens_list} |> dbg
               end

               assemble_statement(
                 A940.Macro.expand_dummy(state, tokens_list),
                 update_state_for_next_statement(current_state, line_number)
               )
             )}

          {:error, "no more tokens"} ->
            {:halt, current_state}
        end
      end
    )
  end

  def assemble_statement([eol: ""], %A940.State{} = state),
    # :blank_line |> dbg
    do: state

  def assemble_statement([{:comment, _} | _], %A940.State{} = state),
    do: state

  # must recognize [spaces: " ", delimiter: "*", spaces: " ", symbol: "ABC", eol: ""]

  def assemble_statement([{:spaces, _}, {:delimiter, "*"} | _], %A940.State{} = state),
    # :indented_comment3 |> dbg
    do: state

  def assemble_statement(tokens, %A940.State{} = state) do
    {_label_part, opcode, _address_part} = quick_parse_statement(tokens)

    if not state.assembling and not is_actionable_conditional(opcode) do
      IO.puts(
        "Not assembling line #{state.line_number}: #{Map.get(state.lines, state.line_number)} -------------------------------"
      )

      state
    else
      IO.puts(
        "    Assembling line #{state.line_number}: #{Map.get(state.lines, state.line_number)} -------------------------------"
      )

      tokens =
        A940.Macro.expand_macro_tokens(tokens, state)

      if state.line_number == @debug_line do
        tokens |> dbg
      end

      {label_tokens, _terminator, tokens} = get_address(tokens, state, @address_terminators)
      # it might be tempting to compare label_tokens with _label_part from the quick_parse/1,
      # but that would not work if the label part changed due to macro expansion or rpt
      state = %{state | label_tokens: label_tokens}

      if not state.flags.done do
        # will return     {remaining, list-of-list-of-tokens}
        {opcode_tokens, _terminator, tokens} = get_address(tokens, state, @address_terminators)
        # state = %{state | opcode_tokens: Enum.reverse(opcode_tokens)}
        state = %{state | opcode_tokens: opcode_tokens}
        # {"processing opcode", state.line_number} |> dbg

        state = Op.process_opcode(state)
        # state.operation |> dbg

        address_tokens_list =
          if state.operation.address_class == :no_address do
            [[]]
            # tokens |> dbg
            # will return     {remaining, list-of-list-of-tokens}
          else
            {_, tokens} = get_tokens_list(tokens, state)

            if state.line_number == @debug_line do
              tokens |> dbg()
            end

            {tokens, _terminator, _remaining_tokens} =
              get_address(tokens, state, @addresses_terminators)

            if state.line_number == @debug_line do
              tokens |> dbg()
            end

            tokens
          end

        # if state.line_number == @debug_line do
        #   address_tokens_list |> dbg()
        # end

        state = %{state | address_tokens_list: address_tokens_list}

        Op.process_opcode_again(state)
      else
        state
      end
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

  def get_label_tokens(tokens, %A940.State{} = state) do
    IO.puts(
      "Cannot parse tokens at begining of statement \##{state.line_number}: #{inspect(Enum.take(tokens, 5))}"
    )

    raise "cannot parse tokens at beginning of statment"
  end

  def done_with_statement(%State{} = state) do
    new_flags = %{state.flags | done: true}
    {[], %{state | flags: new_flags}}
  end

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
    {addresses, terminator, remaining} = get_address1(tokens, state, [], terminator)
    {Enum.reverse(addresses), terminator, remaining}
  end

  def get_address1([], %State{} = _state, address, _terminator) do
    rv = {address, {:eol, ""}, []}
    # {"nill remaining", rv} |> dbg
    rv
  end

  def get_address1([first | rest] = _tokens, %State{} = state, address, terminator) do
    rv =
      cond do
        first in terminator ->
          {address, first, rest}

        first == {:delimiter, "("} ->
          {balanced, remaining} = A940.Address.get_balanced_tokens(rest)
          # put back parentheses (backwards since this will be reversed)
          balanced = [{:delimiter, "("}, balanced, {:delimiter, ")"}] |> List.flatten()
          get_address1(remaining, state, [balanced | address], terminator)

        true ->
          get_address1(rest, state, [first | address], terminator)
      end

    if state.line_number == @debug_line do
      rv |> dbg
    end

    rv
  end

  def strip_outer_parens([] = _address), do: []

  def strip_outer_parens([first | rest] = address) when is_list(address) do
    cond do
      first != {:delimiter, "("} -> address
      Enum.slice(rest, -1..-1//1) == {:delimiter, ")"} -> Enum.slice(rest, 0..-2//1)
      true -> raise("expression that should be balanced isn't #{inspect(address)}")
    end
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

  def quick_parse_statement([]), do: {[], [], []}

  def quick_parse_statement(tokens) when is_list(tokens) do
    cond do
      match?({:comment, _}, hd(tokens)) ->
        {[], [], []}

      match?([{:spaces, _}, {:comment, _}], Enum.slice(tokens, 0, 2)) ->
        {[], [], []}

      match?({:spaces, _}, hd(tokens)) ->
        quick_parse_statements_opcode(tl(tokens), [], [])

      true ->
        quick_parse_statements_label(tl(tokens), [hd(tokens)])
    end
  end

  def quick_parse_statements_label(tokens, label_tokens) do
    cond do
      match?({:comment, _}, hd(tokens)) ->
        quick_parse_statements_opcode(tl(tokens), [], label_tokens)

      match?({:spaces, _}, hd(tokens)) ->
        quick_parse_statements_opcode(tl(tokens), [], label_tokens)

      match?({:eol, _}, hd(tokens)) ->
        {label_tokens, [], []}

      true ->
        quick_parse_statements_label(tl(tokens), label_tokens ++ [hd(tokens)])
    end
  end

  def quick_parse_statements_opcode(tokens, opcode_tokens, label_tokens) do
    cond do
      match?({:spaces, _}, hd(tokens)) ->
        quick_parse_statements_address(tl(tokens), [], opcode_tokens, label_tokens)

      match?({:eol, _}, hd(tokens)) ->
        {label_tokens, opcode_tokens, []}

      match?({:comment, _}, hd(tokens)) ->
        {label_tokens, opcode_tokens, []}

      true ->
        quick_parse_statements_opcode(tl(tokens), opcode_tokens ++ [hd(tokens)], label_tokens)
    end
  end

  def quick_parse_statements_address(tokens, address_tokens, opcode_tokens, label_tokens) do
    cond do
      match?({:comment, _}, hd(tokens)) or match?({:spaces, _}, hd(tokens)) or
          match?({:eol, _}, hd(tokens)) ->
        {label_tokens, opcode_tokens, address_tokens}

      true ->
        quick_parse_statements_address(
          tl(tokens),
          address_tokens ++ [hd(tokens)],
          opcode_tokens,
          label_tokens
        )
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
end
