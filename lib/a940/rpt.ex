defmodule A940.Rpt do
  alias A940.{Expression, State}

  defstruct starting_statement_number: 0,
            ending_statement_number: 0,
            level: 0,
            counter: 0,
            maximum: 0,
            increment: 1,
            increment_list: [],
            nested_repeats: [],
            first_time: false,
            iteration_symbol: ""

  def rpt(%State{} = state, :first_call) do
    state
  end

  def rpt(%State{} = state, :second_call) do
    # first_address_count = length(state.address_tokens_list |> hd)
    first_address = state.address_tokens_list |> hd

    rpt_state =
      case Enum.slice(first_address, 0..2) do
        [{:delimiter, "("}, {:symbol, _}, {:delimiter, "="}] ->
          if_increment(state, first_address)

        _ ->
          {maximum_count, 0} = Expression.evaluate(state, first_address)
          %__MODULE__{counter: 1, maximum: maximum_count}
      end

    if rpt_state.counter > rpt_state.maximum do
      raise "Illegal RPT statement at line #{state.line_number} - MUST repeat at least once"
    end

    rpt_state = %{
      rpt_state
      | starting_statement_number: state.line_number + 1,
        nested_repeats: [state.rpt_state | rpt_state.nested_repeats],
        first_time: true
    }

    %{state | rpt_state: rpt_state}
    |> update_repeat_symbol()
  end

  def endr(%State{} = state, :first_call) do
    state
  end

  def endr(%State{} = state, :second_call) do
    endr(state, state.rpt_state)
  end

  def endr(%State{} = state, %__MODULE__{first_time: true} = rpt) do
    new_counter = rpt.counter + rpt.increment

    if new_counter <= rpt.maximum do
      new_rpt = %{
        rpt
        | counter: new_counter,
          ending_statement_number: state.line_number,
          first_time: false
      }

      # IO.puts("ENDR 1st cont ---- #{inspect(new_rpt)}")
      A940.Tokens.push_range(rpt.starting_statement_number, state.line_number)

      %{state | rpt_state: new_rpt, line_number: rpt.starting_statement_number}
      |> update_repeat_symbol()
    else
      next_rpt_state = hd(rpt.nested_repeats)
      # IO.puts("ENDR 1st term ---- #{inspect(next_rpt_state)}")
      %{state | rpt_state: next_rpt_state}
      |> update_repeat_symbol()
    end
  end

  def endr(%State{} = state, %__MODULE__{first_time: false} = rpt) do
    new_counter = rpt.counter + rpt.increment

    if new_counter <= rpt.maximum do
      new_rpt = %{rpt | counter: new_counter}
      # IO.puts("ENDR 2nd cont ---- #{inspect(new_rpt)}")
      A940.Tokens.rewind()

      %{state | rpt_state: new_rpt, line_number: rpt.starting_statement_number}
      |> update_repeat_symbol()
    else
      next_rpt_state = hd(rpt.nested_repeats)
      # IO.puts("ENDR 2nd term ---- #{inspect(next_rpt_state)}")
      A940.Tokens.pop_range()

      %{state | rpt_state: next_rpt_state}
      |> update_repeat_symbol()
    end
  end

  # state.address_tokens_list #=> [
  #   [delimiter: "(", symbol: "I", delimiter: "=", number: 1],
  #   [number: 5, delimiter: ")"]
  # ]

  # state.address_tokens_list #=> [
  # [
  #   delimiter: "(",
  #   symbol: "I",
  #   delimiter: "=",
  #   number: 1,
  #   delimiter: "-",
  #   number: 1
  # ],
  # [number: 1, delimiter: "+", number: 0],
  # [symbol: "LL", delimiter: "/", number: 2, delimiter: ")"]
  # ]

  # first_address #=> [delimiter: "(", symbol: "I", delimiter: "=", number: 1]

  def if_increment(%State{} = state, first_address) do
    state.address_tokens_list
    {symbol, initial_value} = rpt_increment_initial(state, first_address)
    rpt = %__MODULE__{iteration_symbol: symbol, counter: initial_value}

    cond do
      length(state.address_tokens_list) == 2 -> rpt_limit(state, rpt)
      length(state.address_tokens_list) == 3 -> rpt_increment_and_limit(state, rpt)
    end
  end

  def rpt_increment_initial(%State{} = state, tokens) when is_list(tokens) do
    case Enum.slice(tokens, 0, 3) do
      [{:delimiter, "("}, {:symbol, symbol}, {:delimiter, "="}] ->
        initial_expression = Enum.slice(tokens, 3..-1//1)
        {value, relocation} = Expression.evaluate(state, initial_expression)

        if relocation != 0 do
          raise "Relocatable initial value in RPT is illegal line #{state.line_number}"
        end

        {symbol, value}

      _ ->
        raise "Unrecognized syntax in RPT line #{state.line_number}"
    end
  end

  def rpt_limit(%State{} = state, %__MODULE{} = rpt) do
    [_initial, final_tokens] = state.address_tokens_list

    %{rpt_limit(state, rpt, final_tokens) | increment: 1}
  end

  def rpt_increment_and_limit(%State{} = state, %__MODULE{} = rpt) do
    [_initial, increment_tokens, final_tokens] = state.address_tokens_list

    {increment, relocation} = Expression.evaluate(state, increment_tokens)

    if relocation != 0 do
      raise "Illegal RPT limit - must be absolute not relocatable line #{state.line_number}"
    end

    %{rpt_limit(state, rpt, final_tokens) | increment: increment}
  end

  def rpt_limit(%State{} = state, %__MODULE{} = rpt, final_tokens) when is_list(final_tokens) do
    if List.last(final_tokens) != {:delimiter, ")"} do
      raise "Illegal RPT limit syntax line #{state.line_number}"
    end

    {value, relocation} = Expression.evaluate(state, Enum.slice(final_tokens, 0..-2//1))

    if relocation != 0 do
      raise "Illegal RPT limit - must be absolute not relocatable line #{state.line_number}"
    end

    %{rpt | maximum: value}
  end

  def update_repeat_symbol(%State{} = state) do
    iteration_symbol = state.rpt_state.iteration_symbol

    if iteration_symbol == "" do
      state
    else
      State.set_local_absolute_symbol(
        state,
        state.rpt_state.iteration_symbol,
        state.rpt_state.counter
      )
    end
  end
end
