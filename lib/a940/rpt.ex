defmodule A940.Rpt do
  alias A940.{Expression, State}

  defstruct starting_statement_number: 0,
            level: 0,
            counter: 0,
            maximum: 0,
            increment: 0,
            increment_list: [],
            nested_repeats: []

  def rpt(%State{} = state, :first_call) do
    state
  end

  def rpt(%State{} = state, :second_call) do
    # first_address_count = length(state.address_tokens_list |> hd)
    first_address = state.address_tokens_list |> hd

    rpt_state =
      case Enum.slice(first_address, 0..2) do
        [{:delimiter, "("}, {:symbol, _}, {:delimiter, "="}] -> if_increment(state, first_address)
        _ -> %__MODULE__{counter: 1, maximum: Expression.evaluate(state, first_address)}
      end

    if rpt_state.counter > rpt_state.maximum do
      raise "Illegal RPT statement at line #{state.line_number} - MUST repeat at least once"
    end

    rpt_state = %{
      rpt_state
      | starting_statement_number: state.line_number + 1,
        nested_repeats: [state.rpt_state | rpt_state.nested_repeats]
    }

    %{state | rpt_state: rpt_state}
  end

  def endr(%State{} = state, :first_call) do
    state
  end

  def endr(%State{} = state, :second_call) do
    rpt = state.rpt_state
    new_counter = rpt.counter + rpt.increment

    if new_counter <= rpt.maximum do
      new_rpt = %{rpt | counter: new_counter}
      IO.puts("ENDR cont ---- #{inspect(new_rpt)}")

      %{state | rpt_state: new_rpt, line_number: rpt.starting_statement_number}
    else
      next_rpt_state = hd(rpt.nested_repeats)
      IO.puts("ENDR term ---- #{inspect(next_rpt_state)}")
      %{state | rpt_state: next_rpt_state}
    end
  end

  def if_increment(%State{} = state, first_address) do
    state.address_tokens_list |> dbg
    first_address |> dbg
    %__MODULE__{}
    # TODO: fix this
  end
end
