defmodule A940.State do
  defstruct lines: %{},
            tokens_list: [],
            used_tokens: [],
            symbols: %{},
            macros: %{},
            ops: %{},
            # keys are the relocatable location, value is a MemoryValue
            # should this be a genserver??
            code: %{},
            flags: %{},
            # this keeps counting up with each instruction or data word(s)
            # default relocation value of 1 (implicit, not stored)
            location_relative: 0,
            # this starts at value of RELORG and counts up until RETREL
            location_absolute: 0

  def new(lines) do
    {_count, line_map} =
      Enum.reduce(lines, {1, %{}}, fn line, {count, map} ->
        {count + 1, Map.put(map, count, line)}
      end)

    %__MODULE__{lines: line_map, ops: A940.Op.opcode_table()}
  end
end
