defmodule A940.Tokens do
  @tokens_table :ets_tokens
  @moduledoc """
  Store tokens in keys like {:line_tokens, line_number}
  Permit push_range(min, max) -> :ok; This sets a range
  Permit pop_range() -> :ok; This goes to the previous range state
  Permit next() -> {:ok, line_number, tokens_list} or {:error, "no more tokens"}
  Permit current() -> {:ok, line_number, tokens_list} or {:error, "no more tokens"}
  Permit rewind() -> :ok; So the next next() will return tokens at beginning of range

  If no range is active, pop_range, next, and rewind will raise a RuntimeError.

  The range state is {current, first, last} and push_range(min, max) pushes the
  current range state and sets the current range state to {min, min, max}

  next() increments the current term in the :current_range tuple
  current() is just like next, but doesn't change the :current_range tuple
  """

  def create_table() do
    case :ets.info(@tokens_table) do
      :undefined -> nil
      _ -> :ets.delete(@tokens_table)
    end

    :ets.new(@tokens_table, [:named_table])
    :ets.insert(@tokens_table, {:current_range, nil})
    :ets.insert(@tokens_table, {:range_stack, nil})
  end

  def store_tokens(line_number, token_list)
      when is_integer(line_number) and line_number > 0 and is_list(token_list) do
    term = {{:line_tokens, line_number}, token_list}

    if not :ets.insert(@tokens_table, term) do
      raise ":ets.insert(#{@tokens_table}, #{inspect(term)})"
    end
  end

  def read_tokens(line_number) when is_integer(line_number) and line_number > 0 do
    key = {:line_tokens, line_number}
    result = :ets.lookup(@tokens_table, key)

    case result do
      [] -> raise "read_tokens(#{line_number}): nothing at that key"
      [{^key, tokens}] -> tokens
      _ -> raise "read_tokens(#{line_number}): unexpected result: #{inspect(result)}"
    end
  end

  def pop_range() do
    range_stack_result = :ets.lookup(@tokens_table, :range_stack)

    case range_stack_result do
      [{:range_stack, nil}] ->
        raise "Range stack is empty"

      [{:range_stack, ranges_list}] ->
        [current | rest] = ranges_list
        :ets.insert(@tokens_table, {:current_range, current})
        :ets.insert(@tokens_table, {:range_stack, rest})

      _ ->
        raise("Unexpected result in pop_range()")
    end

    :ok
  end

  def push_range(min, max) when is_integer(min) and is_integer(max) do
    current = :ets.lookup(@tokens_table, :current_range)
    stack = :ets.lookup(@tokens_table, :range_stack)
    new_current = {min, min, max}
    new_stack = [current | stack]
    true = :ets.insert(@tokens_table, {:current_range, new_current})
    true = :ets.insert(@tokens_table, {:range_stack, new_stack})
    :ok
  end

  def next() do
    [{:current_range, {current, min, max}}] = :ets.lookup(@tokens_table, :current_range)

    cond do
      current < min ->
        raise "Inconsistent token range {#{current}, #{min}, #{max}}"

      current > max ->
        {:error, "no more tokens"}

      true ->
        tokens = read_tokens(current)
        next = current + 1
        true = :ets.insert(@tokens_table, {:current_range, {next, min, max}})
        {:ok, current, tokens}
    end
  end

  def current() do
    [{:current_range, {current, min, max}}] = :ets.lookup(@tokens_table, :current_range)

    cond do
      current < min ->
        raise "Inconsistent token range {#{current}, #{min}, #{max}}"

      current > max ->
        {:error, "no more tokens"}

      true ->
        tokens = read_tokens(current)
        {:ok, current, tokens}
    end
  end

  def rewind() do
    [{:current_range, {_current, min, max}}] = :ets.lookup(@tokens_table, :current_range)
    true = :ets.insert(@tokens_table, {:current_range, {min, min, max}})
    :ok
  end
end
