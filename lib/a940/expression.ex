defmodule A940.Expression do
  import Bitwise

  defstruct tokens: [],
            value_stack: [],
            relocation_stack: [],
            operator_stack: [],
            symbols: %{},
            current_location: 0,
            current_relocation: 0

  @doc """
  From the NARP manual.
  <primary> :: = <symbol>|<constant>|[<expression›]
  ‹basic expression» :: = <primary>|<primary› <binary operator><basic expression>
  ‹expression» :: = ‹basic expression›|<unary operator›‹basic expression>

  One correction: a primary is a symbol, constant, #asterisk#, or bracketed instruction

    |---|---|---|
    |Op|Precedence|Note|
    |---|---|---|
    |^|6|exponentiation; exponent >= 0|
    |*|5|multiplication|
    |/|5|division|
    |+(u)|4|unary nop|
    |-(u)|4|unary negation|
    |+|4|addition|
    |-|4|subtraction|
    |< <= = # >= >|3|relational|
    |@|2|logical not|
    |&|1|logical and|
    |!|0|logical or|
    |%|0|logical exclusive or|
    |[ ]|-1|grouping|

    A * B + C: Push A; Push *; Push B; + <= *; pop 2 operands and 1 operator; push result back

  """
  def new(tokens, symbols, current_location, current_relocation) do
    %__MODULE__{
      tokens: tokens ++ [{:delimiter, "]"}],
      symbols: symbols,
      current_location: current_location,
      current_relocation: current_relocation,
      operator_stack: ["["]
    }
  end

  def evaluate(tokens, symbols, current_location, current_relocation) do
    evstate = new(tokens, symbols, current_location, current_relocation)
    evaluate(evstate)
  end

  def evaluate(%A940.State{} = state) do
    if state.line_number == 265 do
      state.address_tokens_list |> dbg
    end

    {current_location, current_relocation} = A940.State.current_location(state)

    evaluate(
      hd(state.address_tokens_list),
      state.symbols,
      current_location,
      current_relocation
    )
  end

  def evaluate(%__MODULE__{} = evstate) do
    {evstate.tokens, evstate.operator_stack, evstate.value_stack, evstate.symbols}
    # |> dbg

    save_tokens = evstate.tokens

    try do
      new_state = ev_expression(evstate)
      {hd(new_state.value_stack), hd(new_state.relocation_stack)}
    catch
      x -> {x, save_tokens}
    end
  end

  def ev_expression(%__MODULE__{tokens: []} = evstate) do
    {evstate.tokens, evstate.operator_stack, evstate.value_stack}
    # |> dbg

    cond do
      length(evstate.operator_stack) > 0 -> throw(:error)
      length(evstate.value_stack) != 1 -> throw(:error)
      true -> evstate
    end
  end

  def ev_expression(%__MODULE__{tokens: [first | _rest]} = evstate) do
    {evstate.tokens, evstate.operator_stack, evstate.value_stack}
    # |> dbg

    cond do
      first == {:delimiter, "+"} -> push_or_evaluate(rest(evstate), "U+") |> ev_basic_expression()
      first == {:delimiter, "-"} -> push_or_evaluate(rest(evstate), "U-") |> ev_basic_expression()
      first == {:delimiter, "@"} -> push_or_evaluate(rest(evstate), "U@") |> ev_basic_expression()
      true -> ev_basic_expression(evstate)
    end
  end

  def ev_basic_expression(%__MODULE__{tokens: []} = evstate) do
    {evstate.tokens, evstate.operator_stack, evstate.value_stack}
    # |> dbg

    evstate
  end

  def ev_basic_expression(%__MODULE__{} = evstate) do
    {evstate.tokens, evstate.operator_stack, evstate.value_stack}
    # |> dbg
    ev_primary(evstate) |> op_and_primary()
  end

  def op_and_primary(%__MODULE__{} = evstate) do
    {evstate.tokens, evstate.operator_stack, evstate.value_stack}
    # > dbg

    cond do
      length(evstate.tokens) == 0 ->
        evstate

      hd(evstate.tokens) == {:delimiter, "^"} ->
        push_or_evaluate(rest(evstate), "^") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "*"} ->
        push_or_evaluate(rest(evstate), "*") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "/"} ->
        push_or_evaluate(rest(evstate), "/") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "+"} ->
        push_or_evaluate(rest(evstate), "+") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "-"} ->
        push_or_evaluate(rest(evstate), "-") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "U+"} ->
        push_or_evaluate(rest(evstate), "U+") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "U-"} ->
        push_or_evaluate(rest(evstate), "U-") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "U@"} ->
        push_or_evaluate(rest(evstate), "U@") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "<"} ->
        push_or_evaluate(rest(evstate), "<") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "<="} ->
        push_or_evaluate(rest(evstate), "<=") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "="} ->
        push_or_evaluate(rest(evstate), "=") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "#"} ->
        push_or_evaluate(rest(evstate), "#") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, ">="} ->
        push_or_evaluate(rest(evstate), ">=") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, ">"} ->
        push_or_evaluate(rest(evstate), ">") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "&"} ->
        push_or_evaluate(rest(evstate), "&") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "!"} ->
        push_or_evaluate(rest(evstate), "!") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "%"} ->
        push_or_evaluate(rest(evstate), "%") |> ev_basic_expression()

      hd(evstate.tokens) == {:delimiter, "]"} ->
        push_or_evaluate(rest(evstate), "]") |> ev_basic_expression()

      true ->
        evstate.tokens |> dbg
        raise "couldn't find an operator"
    end
  end

  def ev_primary(%__MODULE__{tokens: []} = evstate) do
    {evstate.tokens, evstate.operator_stack, evstate.value_stack}
    # |> dbg
    raise "do we get here?"
    # evstate
  end

  def ev_primary(%__MODULE__{tokens: [first | _rest]} = evstate) do
    {evstate.tokens, evstate.operator_stack, evstate.value_stack}
    #  |> dbg
    {tag, value} = first
    #  |> dbg

    cond do
      tag == :number ->
        push_number(rest(evstate), value)

      tag == :symbol ->
        push_symbol(rest(evstate), value)

      first == {:delimiter, "*"} ->
        push_current(rest(evstate))

      first == {:delimiter, "["} ->
        evstate = push_operator(rest(evstate), "[") |> ev_expression()
        {evstate.tokens, evstate.operator_stack, evstate.value_stack}
        #  |> dbg

        cond do
          # unwind from expressions in [brackets]
          evstate.tokens == [] -> evstate
          hd(evstate.tokens) == {:delimiter, "]"} -> push_or_evaluate(rest(evstate), "]")
          true -> throw({:error})
        end

      tag == :string_6 ->
        {value_1, _} = value
        push_number(rest(evstate), value_1)

      true ->
        raise "error in ev_primary"
    end
  end

  def rest(%__MODULE__{tokens: [_first | rest]} = evstate), do: %{evstate | tokens: rest}

  def push_number(%__MODULE__{} = evstate, value) when is_integer(value) do
    value = value &&& 0o77777777
    #  |> dbg
    push(evstate, value, 0)
  end

  def push_current(%__MODULE__{} = evstate) do
    push(evstate, evstate.current_location, evstate.current_relocation)
  end

  def push_symbol(%__MODULE__{} = evstate, symbol_name) do
    symbol = Map.get(evstate.symbols, symbol_name)
    #  |> dbg
    #     value: 0,
    # relocation: 0,
    # expression_tokens: expression,
    cond do
      symbol.expression_tokens == nil or symbol.expression_tokens == [] ->
        push(evstate, symbol.value, symbol.relocation)

      length(symbol.expression_tokens) > 0 ->
        throw(:undefined_symbol)
    end
  end

  def push(%__MODULE__{} = evstate, value, relocation)
      when is_integer(value) and is_integer(relocation) do
    value_stack = [value | evstate.value_stack]
    relocation_stack = [relocation | evstate.relocation_stack]
    %{evstate | value_stack: value_stack, relocation_stack: relocation_stack}
  end

  def push_operator(%__MODULE__{} = evstate, operator) do
    "pushing operator #{operator}"
    #  |> dbg
    %{evstate | operator_stack: [operator | evstate.operator_stack]}
  end

  def push_or_evaluate(
        %__MODULE__{operator_stack: [first_op | rest_of_ops] = _stacked_ops} = evstate,
        op
      ) do
    {evstate.tokens, evstate.operator_stack, evstate.value_stack, op}
    #  |> dbg
    {op, first_op, rest_of_ops}
    #  |> dbg
    done_with_grouping = op == "]" and first_op == "["
    {"boolean", done_with_grouping}
    #  |> dbg

    cond do
      # when []s match, forget it, delete the open bracket -- [
      done_with_grouping ->
        cond do
          evstate.tokens != [] ->
            # "op&primary"
            #  |> dbg
            op_and_primary(%{evstate | operator_stack: rest_of_ops})

          true ->
            # "return evstate"
            #  |> dbg
            %{evstate | operator_stack: rest_of_ops}
        end

      # new_evstate = %{evstate | operator_stack: new_rest_of_ops} |> dbg

      # cond do
      #   # process the next operator if there is one...

      #   rest_of_ops != [] ->
      #     [new_operator | new_operator_stack] = rest_of_ops
      #     new_evstate = %{evstate | operator_stack: new_operator_stack}
      #     {new_operator, new_operator_stack} |> dbg
      #     push_or_evaluate(new_evstate, new_operator)

      #   # otherwise return
      #   true ->
      #     "push_or_evaluate returning" |> dbg
      #     %{evstate | operator_stack: []}
      # end

      precedence(op) < precedence(first_op) ->
        # keep evaluating until operator on top of the stack is higher precedence
        apply_stack_operator(evstate) |> push_or_evaluate(op)

      true ->
        push_operator(evstate, op)
        # %{evstate | operator_stack: [op | stacked_ops]}
    end
  end

  @doc """
  advance to the next token in the expression
  """

  def precedence(op) when is_binary(op) do
    case op do
      # everything is pushed after this
      "[" ->
        5

      "^" ->
        60

      "*" ->
        50

      "/" ->
        50

      "U+" ->
        40

      "U-" ->
        40

      "+" ->
        40

      "-" ->
        40

      "<" ->
        30

      "<=" ->
        30

      "=" ->
        30

      "#" ->
        30

      ">=" ->
        30

      ">" ->
        30

      "U@" ->
        25

      "&" ->
        20

      "!" ->
        10

      "%" ->
        10

      "]" ->
        0
    end
  end

  def apply_stack_operator(%__MODULE__{operator_stack: [first_op | _rest_of_ops]} = evstate) do
    case first_op do
      "[" ->
        raise "cannot apply [ operator"

      "U+" ->
        pop_1_value_1_operator(evstate)

      "U-" ->
        pop_1_value_1_operator(evstate)

      "U@" ->
        pop_1_value_1_operator(evstate)

      _ ->
        pop_2_values_1_operator(evstate)
    end
  end

  def eval_operator(op, value_1, relocation_1) when is_binary(op) do
    case op do
      # everything is pushed after this
      "U+" ->
        {value_1, relocation_1}

      "U-" ->
        {-value_1, -relocation_1}

      "U@" ->
        cond do
          relocation_1 != 0 -> throw(:relocation_error)
          true -> {Bitwise.bxor(value_1, 0o77777777), 0}
        end

      true ->
        raise "unknown unary operator #{op}"
    end
  end

  def eval_operator(op, value_1, relocation_1, value_2, relocation_2) do
    # rules for relocation are on page 2-8 of the NARP manual
    {value, relocation} =
      case op do
        "[" ->
          raise "cannot evaluate operator ["

        "^" ->
          cond do
            relocation_1 != 0 or relocation_2 != 0 -> raise "exponentials must be absolute"
            value_2 < 0 -> raise "exponent in #{value_1} ^ #{value_2} cannot be negative"
            # 0^0 is 1???
            value_2 == 0 -> {1, 0}
            true -> {value_1 ** value_2, 0}
          end

        "*" ->
          cond do
            relocation_1 != 0 and relocation_2 != 0 ->
              raise "multiplication relocation error"

            relocation_1 != 0 ->
              {value_1 * value_2, relocation_1 * value_2}

            relocation_2 != 0 ->
              {value_1 * value_2, relocation_2 * value_1}

            true ->
              {value_1 * value_2, 0}
          end

        "/" ->
          cond do
            relocation_1 != 0 or relocation_2 != 0 -> raise "division operands must be absolute"
            true -> {div(value_1, value_2), 0}
          end

        "+" ->
          {value_1 + value_2, relocation_1 + relocation_2}

        "-" ->
          {value_1 - value_2, relocation_1 - relocation_2}

        "<" ->
          cond do
            relocation_1 != relocation_2 ->
              raise "relational operands must have same relocation factor"

            true ->
              {if(value_1 < value_2, do: 1, else: 0), 0}
          end

        "<=" ->
          cond do
            relocation_1 != relocation_2 ->
              raise "relational operands must have same relocation factor"

            true ->
              {if(value_1 <= value_2, do: 1, else: 0), 0}
          end

        "=" ->
          cond do
            relocation_1 != relocation_2 ->
              raise "relational operands must have same relocation factor"

            true ->
              {if(value_1 == value_2, do: 1, else: 0), 0}
          end

        "#" ->
          cond do
            relocation_1 != relocation_2 ->
              raise "relational operands must have same relocation factor"

            true ->
              {if(value_1 != value_2, do: 1, else: 0), 0}
          end

        ">=" ->
          cond do
            relocation_1 != relocation_2 ->
              raise "relational operands must have same relocation factor"

            true ->
              {if(value_1 >= value_2, do: 1, else: 0), 0}
          end

        ">" ->
          cond do
            relocation_1 != relocation_2 ->
              raise "relational operands must have same relocation factor"

            true ->
              {if(value_1 > value_2, do: 1, else: 0), 0}
          end

        "&" ->
          cond do
            relocation_1 != 0 or relocation_2 != 0 ->
              raise "logical operation operands must be absolute"

            true ->
              {value_1 &&& value_2, 0}
          end

        "!" ->
          cond do
            relocation_1 != 0 or relocation_2 != 0 ->
              raise "logical operation operands must be absolute"

            true ->
              {value_1 ||| value_2, 0}
          end

        "%" ->
          cond do
            relocation_1 != 0 or relocation_2 != 0 ->
              raise "logical operation operands must be absolute"

            true ->
              {Bitwise.bxor(value_1, value_2), 0}
          end

        _ ->
          raise "cannot evaluate #{value_1} #{op} #{value_2}"
      end

    {value &&& 0o77777777, relocation}
  end

  def pop_2_values_1_operator(%__MODULE__{} = evstate) do
    {evstate, right_value, right_relocation} = pop_value(evstate)
    {evstate, left_value, left_relocation} = pop_value(evstate)
    {evstate, operator} = pop_operator(evstate)

    push_value(
      evstate,
      eval_operator(operator, left_value, left_relocation, right_value, right_relocation)
    )
  end

  def pop_1_value_1_operator(%__MODULE__{} = evstate) do
    {evstate, value, relocation} = pop_value(evstate)
    {evstate, operator} = pop_operator(evstate)
    push_value(evstate, eval_operator(operator, value, relocation))
  end

  def pop_value(%__MODULE__{} = evstate) do
    [value | rest_of_values] = evstate.value_stack
    [relocation | rest_of_relocations] = evstate.relocation_stack
    evstate = %{evstate | value_stack: rest_of_values, relocation_stack: rest_of_relocations}
    # {value, relocation}
    # |> dbg
    {evstate, value, relocation}
  end

  def pop_operator(%__MODULE__{operator_stack: [first | rest]} = evstate) do
    {%{evstate | operator_stack: rest}, first}
  end

  def push_value(%__MODULE__{} = evstate, {value, relocation}),
    do: push_value(evstate, value, relocation)

  def push_value(%__MODULE__{} = evstate, value, relocation) do
    value_stack = [value | evstate.value_stack]
    relocation_stack = [relocation | evstate.relocation_stack]
    # value_stack
    # |> dbg
    %{evstate | value_stack: value_stack, relocation_stack: relocation_stack}
  end
end
