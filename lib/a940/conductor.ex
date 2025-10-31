defmodule A940.Conductor do
  def runner do
    lines = IO.stream() |> Enum.map(&String.trim_trailing(&1, "\n"))
    process(lines) |> Enum.each(&IO.puts/1)
  end

  def runner(path_or_lines) when is_binary(path_or_lines), do: runcount(path_or_lines, 99_999_999)

  def runner(lines) when is_list(lines) do
    process(lines)
  end

  def runcount(path_or_lines, line_count) when is_binary(path_or_lines) do
    {status, inhalt} = File.read(path_or_lines)

    cond do
      status == :ok -> inhalt
      true -> path_or_lines
    end
    |> String.upcase()
    |> String.split("\n")
    |> Enum.take(line_count)
    |> Enum.map(&String.trim_trailing(&1, "\r"))
    |> Enum.map(&String.trim_trailing(&1, " "))
    |> process()
  end

  def runs(s), do: runcount(s, 70)

  defp process(lines) when is_list(lines) do
    A940.Op.new_opcode_table()
    process(A940.State.new(lines))
  end

  defp process(%A940.State{} = state) do
    processed_state =
      state
      |> A940.Pass0.run()
      |> A940.Pass1.run()
      |> A940.Pass2.run()

    # {processed_state.code, processed_state.symbols} |> dbg
    processed_state
  end
end
