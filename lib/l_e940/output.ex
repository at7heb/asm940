defmodule LE940.Output do
  alias A940.MemoryAddress

  def process(%LinkEdit{save_command: []} = state) do
    raise "pretty useless to waste so much energy and not save"
    state
  end

  def process(%LinkEdit{} = state) do
    # |> dbg
    [fun, params] = state.save_command
    fun.(state, params)
  end

  def save(%LinkEdit{} = state, _parameters) do
    stats(state) |> dbg
    state
  end

  defp stats(%LinkEdit{} = state) do
    state.memory
    j = Map.keys(state.memory)
    k = Enum.take(j, 5)
    k |> dbg

    IO.puts("------------------- Memory Location Ranges -------------------")

    state.memory
    |> Map.keys()
    |> Enum.map(fn %MemoryAddress{location: location, relocation: 0} = _address -> location end)
    |> ranges()
    |> Enum.each(fn entry -> IO.puts(entry) end)
  end

  @doc """
  Takes a list of integers and returns a list of string ranges
  representing groups of consecutive numbers.

  ## Examples
      iex> ranges([1, 2, 3, 5, 6, 7, 9, 11, 12])
      ["1->3", "5->7", "9", "11->12"]

      iex> ranges([4])
      ["4"]

      iex> ranges([10, 11, 12, 13])
      ["10->13"]

      iex> ranges([])
      []
  """

  @spec ranges([integer]) :: [String.t()]
  def ranges([]), do: []

  def ranges(numbers) do
    numbers
    |> Enum.sort()
    # optional: remove duplicates if needed
    |> Enum.uniq()
    |> Enum.reduce([], fn
      n, [] ->
        [{n, n}]

      n, [{start, prev} | rest] = acc ->
        if n == prev + 1 do
          [{start, n} | rest]
        else
          [{n, n} | acc]
        end
    end)
    |> Enum.reverse()
    |> Enum.map(&format_range/1)
  end

  defp format_range({nil, finish}), do: "nil -> #{inspect(finish)}"

  defp format_range({start, start}),
    do: Integer.to_string(start, 8)

  defp format_range({start, finish}),
    do: "#{Integer.to_string(start, 8)}->#{Integer.to_string(finish, 8)}"
end
