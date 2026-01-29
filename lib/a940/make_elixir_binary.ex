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

    new(Op.all_op_table_content(), global_symbols(state.symbols), memory_term(state), meta)
    |> write_binary(meta.ident <> @extension)
  end

  defp meta_term(%State{} = state) do
    %{} |> Map.put(:ident, state.ident) |> Map.put(:date_time, NaiveDateTime.utc_now())
  end

  defp write_binary(%__MODULE__{} = assembly_information, file_name) do
    binary = :erlang.term_to_binary(assembly_information)
    File.write!(Path.join(@path, file_name), binary)
    # => :ok (on success)
  end

  defp memory_term(_state) do
    Memory.all_memory_content()
  end

  defp global_symbols(%{} = symbols) do
    Map.keys(symbols)
    |> Enum.filter(fn name ->
      symbol = Map.get(symbols, name)
      symbol.exported? and not symbol.forgotten?
    end)
  end
end
