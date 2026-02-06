defmodule LE940.Loader do
  import Bitwise

  @all_ones 0o77_777_777

  def process(%LinkEdit{} = state) do
    raise "is this called?"
    state
  end

  def load(%LinkEdit{} = state, {path} = _parameters) do
    assembly_info = File.read!(path) |> :erlang.binary_to_term()
    handle_new_assembly_info(state, assembly_info)
  end

  def load(%LinkEdit{} = state, {stash_addr, execution_addr, path} = _parameters) do
    assembly_info = File.read!(path) |> :erlang.binary_to_term()
    # sample("Memory Sample", assembly_info.mem)
    # sample("Symbol Sample", assembly_info.symb)

    # sample(
    #   "Expression Sample",
    #   Map.filter(assembly_info.symb, fn {_key, val} -> val.expression_tokens != [] end)
    # )
    {"loader", stash_addr, execution_addr, path} |> dbg

    %{state | stash_offset: stash_addr, run_offset: execution_addr}
    |> handle_new_assembly_info(assembly_info)
  end

  defp handle_new_assembly_info(%LinkEdit{} = state, assembly_info) do
    relocate_symbols(state, assembly_info.symb)
    |> relocate_memory(assembly_info.mem)
    |> adjust_state_offsets(assembly_info.meta)
  end

  defp adjust_state_offsets(%LinkEdit{} = state, %{text_size: text_size} = meta) do
    {state.stash_offset, meta} |> dbg
    %{state | stash_offset: text_size + state.stash_offset}
  end

  # defp sample(label, map) when is_binary(label) and is_map(map) do
  #   sample = Map.to_list(map) |> Enum.shuffle() |> Enum.take(10)
  #   IO.puts(label)
  #   dbg(sample)
  #   # map |> dbg
  # end

  # defp sample(label, alist) when is_binary(label) and is_list(alist) do
  #   sample = Enum.shuffle(alist) |> Enum.take(10)
  #   IO.puts(label)
  #   dbg(sample)
  # end

  defp relocate_memory(%LinkEdit{} = state, mem) when is_list(mem) do
    state_memory =
      Enum.reduce(mem, state.memory, fn memory_entry, new_memory_map ->
        {adjusted_address, adjusted_word} =
          relocate_one_word(state.run_offset, state.stash_offset, memory_entry)

        stash_if_unique(
          new_memory_map,
          adjusted_address,
          adjusted_word
        )
      end)

    show_memory_expressions(state_memory)
    %{state | memory: state_memory}
  end

  defp relocate_one_word(run_offset, stash_offset, memory_entry) do
    {adjust_address_of_memory(stash_offset, memory_entry),
     adjust_memory_content_address(run_offset, memory_entry)}
  end

  defp adjust_address_of_memory(
         _stash_offset,
         {%A940.MemoryAddress{relocation: 0} = addr, _, _}
       ),
       do: addr

  defp adjust_address_of_memory(
         stash_offset,
         {%A940.MemoryAddress{relocation: 1} = addr, _, _} = _memory_entry
       ) do
    %{addr | location: addr.location + stash_offset, relocation: 0}
  end

  defp adjust_memory_content_address(
         run_offset,
         {_, %A940.MemoryValue{address_expression: []} = mem, _} = _memory_entry
       ) do
    new_address = mem.value &&& mem.mask + mem.relocation_value * run_offset &&& mem.mask
    new_mem_value = (mem.value &&& bxor(mem.mask, @all_ones)) ||| new_address
    %{mem | value: new_mem_value}
  end

  defp adjust_memory_content_address(
         _run_offset,
         {_, %A940.MemoryValue{} = mem, _} = _memory_entry
       ) do
    # {"runtime expression", mem.address_expression} |> dbg
    mem
  end

  # defp relocate_one_word(
  #        run_offset,
  #        stash_offset,
  #        {%A940.MemoryAddress{} = address0, %A940.MemoryValue{} = word_value,
  #         %A940.MemoryAddress{} = address1}
  #      ) do
  #   if address1.value != 0 or address1.relocation != 0 or address1.expression_tokens != [],
  #     do: raise("Memory word at #{inspect(address0)} has funny address1 #{inspect(address1)}")

  #   new_adress = adjust_address_for_loading(stash_offset, address0)
  #   new_word_value = adjust_address_for_running(run_offset, word_value)
  # end

  # defp relocate_one_word(
  #        run_offset,
  #        stash_offset,
  #        {%A940.MemoryAddress{relocation: 1, expression_tokens: []} = address0,
  #         %A940.MemoryValue{} = word_value, %A940.MemoryAddress{} = address1}
  #      ) do
  # end

  defp relocate_symbols(%LinkEdit{} = state, %{} = symb) do
    state_symbols =
      Map.to_list(symb)
      |> Enum.reduce(%{}, fn {name, value}, new_symbol_map ->
        Map.put(new_symbol_map, name, relocate_symbol(state.run_offset, value))
      end)

    %{state | symbols: state_symbols}
  end

  # to relocate, must not be defined by an expression.
  defp relocate_symbol(
         execution_lc,
         %A940.Address{expression_tokens: [], relocation: relocation} = addr
       ) do
    %{addr | value: addr.value + relocation * execution_lc &&& addr.mask, relocation: 0}
  end

  # otherwise return the symbol, and a later phase will resolve the values.
  # the expression probably involves a symbol from another assembly.
  defp relocate_symbol(_execution_lc, %A940.Address{} = addr), do: addr

  defp stash_if_unique(map, key, value) do
    if not Map.has_key?(map, key),
      do: Map.put(map, key, value),
      else:
        raise(
          "multiple definition of key #{inspect(key)}-old: #{inspect(Map.get(map, key))}, new: #{inspect(value)}}"
        )
  end

  def show_memory_expressions(state_memory) do
    state_memory
    |> Map.to_list()
    |> Enum.map(fn {addr, val} -> {addr.location, val} end)
    |> Enum.sort(fn {addr0, _val0}, {addr1, _val1} -> addr0 <= addr1 end)
    |> Enum.filter(fn {_addr, val} -> val.address_expression != [] end)
    |> Enum.each(fn {addr, val} ->
      IO.puts(
        "#{Integer.to_string(addr, 8)} -> #{Integer.to_string(val.value, 8)}" <>
          "&#{Integer.to_string(val.mask, 8)}, #{inspect(val.address_expression)}"
      )
    end)
  end
end
