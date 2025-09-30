defmodule A940.State do
  defstruct lines: %{},
            tokens_list: []

  def new(lines) do
    {_count, line_map} =
      Enum.reduce(lines, {1, %{}}, fn line, {count, map} ->
        {count + 1, Map.put(map, count, line)}
      end)

    %__MODULE__{lines: line_map}
  end
end
