defmodule A940.Pass0 do
  @flagsD %{default_base: 10}

  def run(%A940.State{} = state) do
    state
    |> make_tokens()

    # |> make_fields()
  end

  def make_tokens(%A940.State{} = state) do
    Enum.each(
      1..map_size(state.lines),
      fn line_number ->
        tokens = A940.Tokenizer.tokens(line_number, Map.get(state.lines, line_number), @flagsD)
        A940.Tokens.store_tokens(line_number, tokens)
      end
    )

    A940.Tokens.push_range(1, map_size(state.lines))
    state
  end

  def make_tokens_for_one_line(line, line_number)
      when is_binary(line) and is_integer(line_number) do
    A940.Tokenizer.tokens(line_number, line, @flagsD)
  end
end
