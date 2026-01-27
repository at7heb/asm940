defmodule A940.MakeElixirBinary do
  alias A940.{Memory, Op, State}

  defstruct ops: [],
            symb: %{},
            mem: [],
            meta: %{}

  @extension ".e9b"
  @path "./temp"

  def new(ops, symb, mem, meta), do: %__MODULE__{ops: ops, symb: symb, mem: mem, meta: meta}

  def output_binary(%State{} = state) do
    # create the output file from the lower case ident with extension ".e9b"
    meta = meta_term(state)

    new(Op.all_op_table_content(), state.symbols, memory_term(state), meta)
    |> write_binary(meta.ident <> @extension)
  end

  defp meta_term(%State{} = state) do
    %{} |> Map.put(:ident, state.ident) |> Map.put(:date_time, NaiveDateTime.utc_now())
  end

  defp write_binary(%__MODULE__{} = assembly_information, file_name) do
    binary = :erlang.term_to_binary(assembly_information)

    # Write the binary to a file
    # Use File.write! for simple cases (raises on error) or File.write for {:ok, :error} handling
    File.write!(Path.join(@path, file_name), binary)
    # => :ok (on success)
  end

  defp memory_term(_state) do
    Memory.all_memory_content()
  end
end
