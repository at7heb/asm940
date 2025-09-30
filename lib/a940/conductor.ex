defmodule A940.Conductor do
  def runner do
    lines = IO.stream() |> Enum.map(&String.trim_trailing(&1, "\n"))
    process(lines) |> Enum.each(&IO.puts/1)
  end

  def runner(path_or_lines) when is_binary(path_or_lines) do
    {status, inhalt} = File.read(path_or_lines)

    cond do
      status == :ok -> inhalt
      true -> path_or_lines
    end
    |> String.upcase()
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing(&1, " "))
    |> process()
  end

  def runner(lines) when is_list(lines) do
    process(lines)
  end

  defp process(lines) when is_list(lines) do
    process(A940.State.new(lines))
  end

  defp process(%A940.State{} = state) do
    new_tokens_list =
      Enum.reduce(
        1..map_size(state.lines),
        [],
        fn line_number, token_list ->
          tokens = A940.Tokenizer.tokens(line_number, Map.get(state.lines, line_number))
          [tokens | token_list]
        end
      )
      |> Enum.reverse()

    %{state | tokens_list: new_tokens_list}
  end
end
