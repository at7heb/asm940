defmodule A940.If do
  alias A940.{State, Expression}

  @moduledoc """
  Handle IF, ELSE, ELSF, ENDF directives
  at most one clause will be assembled - none if in an IF clause that
  isn't being assembled

  ELSF is illegal if else_count > 0.
  ELSE is illegal if else_count > 0.

  IF pushes an A940.If structure on the state's if_stack
  ENDF pops the A940.If (__MODULE__) structure off the stack.

  IF sets the state's do_assembly flag to the value of the expression
  IF sets the *condition_was_true* flag to the value of the expression

  ELSE and ELSF: first check: if condition_was_true is true, set the
  state's do_assembly flag to false.

  ELSF: if *condition_was_true* is false, handle like IF

  ELSE: if condition_was_true, set it to true and set state's
  do_assembly flag to true.
  """
  defstruct some_condition_was_true: false,
            saved_assembling: true,
            elsf_count: 0,
            else_count: 0

  def f_if(%State{} = state, :first_call) do
    cond do
      state.label_tokens != [] ->
        raise "Label not allowed on IF (line #{state.line_number})"

      length(state.address_tokens_list) != 1 ->
        raise "IF statement must have 1 address (line #{state.line_number})"

      true ->
        state
    end
  end

  def f_if(%State{} = state, :second_call) do
    {value, relocation} = Expression.evaluate(state)

    {assembling, new_if} =
      cond do
        not (is_boolean(value) or is_integer(value)) ->
          raise "IF statement address must be defined (line #{state.line_number})"

        relocation != 0 ->
          raise "IF statement address must not be relocatable (line #{state.line_number})"

        not state.assembling ->
          {false, %__MODULE__{some_condition_was_true: false, saved_assembling: state.assembling}}

        value > 0 ->
          {true, %__MODULE__{some_condition_was_true: true, saved_assembling: state.assembling}}

        value < 1 ->
          {false, %__MODULE__{some_condition_was_true: false, saved_assembling: state.assembling}}

        true ->
          raise "IF statement unrecognized address (line #{state.line_number})"
      end

    %{state | assembling: assembling, if_stack: [new_if | state.if_stack]}
  end

  def f_else(%State{} = state, :first_call) do
    [current_if | _rest_of_ifs] = state.if_stack

    cond do
      state.label_tokens != [] ->
        raise "Label not allowed on ELSE (line #{state.line_number})"

      state.if_stack == [] ->
        raise "Extra ELSE statement without matching IF (line #{state.line_number})"

      current_if.else_count > 0 ->
        raise "Multiple ELSE statements (line #{state.line_number})"

      true ->
        state
    end
  end

  def f_else(%State{} = state, :second_call) do
    [current_if | rest_of_ifs] = state.if_stack

    cond do
      not current_if.saved_assembling or current_if.some_condition_was_true ->
        new_if = %{current_if | else_count: 1}
        %{state | assembling: false, if_stack: [new_if | rest_of_ifs]}

      true ->
        new_if = %{current_if | some_condition_was_true: true, else_count: 1}
        %{state | assembling: true, if_stack: [new_if | rest_of_ifs]}
    end
  end

  def elsf(%State{} = state, :first_call) do
    [current_if | _rest_of_ifs] = state.if_stack

    cond do
      state.label_tokens != [] ->
        raise "Label not allowed on ELSF (line #{state.line_number})"

      state.if_stack == [] ->
        raise "Extra ELSF statement without matching IF (line #{state.line_number})"

      current_if.else_count > 0 ->
        raise "ELSF after ELSE statement without matching IF (line #{state.line_number})"

      length(state.address_tokens_list) != 1 ->
        raise "ELSF statement must have 1 address (line #{state.line_number})"

      true ->
        state
    end
  end

  def elsf(%State{} = state, :second_call) do
    {value, relocation} = Expression.evaluate(state) |> dbg
    [current_if | _rest_of_ifs] = state.if_stack

    {assembling, new_if} =
      cond do
        not (is_boolean(value) or is_integer(value)) ->
          raise "ELSF statement address must be defined (line #{state.line_number})"

        relocation != 0 ->
          raise "IF statement address must not be relocatable (line #{state.line_number})"

        value < 1 or current_if.some_condition_was_true or not current_if.saved_assembling ->
          {false, %{current_if | elsf_count: current_if.elsf_count + 1}}

        value > 0 and not current_if.some_condition_was_true ->
          {true,
           %{current_if | some_condition_was_true: true, elsf_count: current_if.elsf_count + 1}}

        true ->
          raise "IF statement unrecognized address (line #{state.line_number})"
      end

    %{state | assembling: assembling, if_stack: [new_if | state.if_stack]}
  end

  def endf(%State{} = state, :first_call) do
    cond do
      state.label_tokens != [] ->
        raise "Label not allowed on ENDF (line #{state.line_number})"

      state.if_stack == [] ->
        raise "Extra END statement without matching IF (line #{state.line_number})"

      true ->
        state
    end
  end

  def endf(%State{} = state, :second_call) do
    [current_if | rest_of_ifs] = state.if_stack
    # {current_if, state.assembling} |> dbg
    %{state | assembling: current_if.saved_assembling, if_stack: rest_of_ifs}
  end
end
