defmodule A940.Pass0 do
  @flagsD %{default_base: 10}

  def run(%A940.State{} = state) do
    state
    |> make_tokens()

    # |> make_fields()
  end

  def make_tokens(%A940.State{} = state) do
    tokens =
      Enum.reduce(
        1..map_size(state.lines),
        [],
        fn line_number, token_list ->
          tokens = A940.Tokenizer.tokens(line_number, Map.get(state.lines, line_number), @flagsD)
          [tokens | token_list]
        end
      )
      |> Enum.reverse()

    %{state | tokens_list: tokens}
  end

  # def make_fields(%A940.State{} = state) do
  #   tokens = state.tokens_list
  #   Enum.take(tokens, 5) |> dbg()
  #   state
  # end
end
