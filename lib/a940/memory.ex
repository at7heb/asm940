defmodule A940.Memory do
  import Bitwise

  alias A940.{Conductor, MemoryAddress, MemoryValue, State}
  @mem_ets :memory_locations
  @trace_location 0o2

  def new_memory_image_table() do
    case :ets.whereis(@mem_ets) do
      :undefined -> nil
      _ -> :ets.delete(@mem_ets)
    end

    :ets.new(@mem_ets, [:ordered_set, :protected, :named_table])
  end

  def set_memory(%MemoryAddress{} = address, %MemoryValue{} = value) do
    # case is_empty?(MemoryAddress.address(address)) do
    #   true ->
    if address.location == @trace_location do
      IO.puts("address: #{inspect(address)}: \n.        #{inspect(value)}")
      Conductor.log_this()
    end

    :ets.insert(
      @mem_ets,
      {MemoryAddress.address(address), value, MemoryAddress.source(address)}
    )

    #   _ ->
    #     raise "Memory location #{inspect(address)} written twice"
    # end
  end

  # Memory.merge_address(location, address_field, state.flags.address_length)
  def merge_address(%MemoryAddress{} = location, address, address_field_length) do
    mask = 2 ** address_field_length - 1

    merge_memory(location, address, mask)
  end

  def set_address(
        %MemoryAddress{} = location,
        %MemoryAddress{location: address_location, relocation: address_relocation} =
          new_address_field
      ) do
    lookup = :ets.lookup(@mem_ets, location)

    cond do
      lookup == [] ->
        raise(
          "cannot set address of non-existent memory #{inspect(location)}, " <>
            "new address = #{inspect(new_address_field)}"
        )

      true ->
        [{_, %MemoryValue{dummy: false} = content, source}] = lookup
        data_to_keep = content.value &&& 0o77740000
        new_content_value = data_to_keep ||| (address_location &&& 0o37777)

        new_content = %{
          content
          | value: new_content_value,
            relocation_value: address_relocation,
            mask: 0o77777777,
            dummy: false
        }

        if location.location == @trace_location, do: Conductor.log_this()

        :ets.insert(@mem_ets, {location, new_content, source})
    end
  end

  # Memory.merge_tag(location, tag)
  def merge_tag(%MemoryAddress{} = location, tag) do
    word_tag = tag <<< 21
    mask = 0o70000000
    merge_memory(location, word_tag, mask)
  end

  def merge_memory(%MemoryAddress{} = location, {address_value, relocation}, mask)
      when address_value >= 0 and address_value <= 16383 and relocation >= 0 and
             relocation <= 15 and
             mask == 0o37777 do
    lookup = :ets.lookup(@mem_ets, location)

    cond do
      lookup == [] ->
        raise(
          "cannot merge into non-existent memory #{inspect(location)}, " <>
            "#{Integer.to_string(address_value, 8)}, #{Integer.to_string(mask, 8)}"
        )

      true ->
        [{_, %MemoryValue{} = content, source}] = lookup
        content_mask = Bitwise.bxor(0o77777777, mask)
        new_content_value = (content.value &&& content_mask) ||| (address_value &&& mask)
        if location.location == @trace_location, do: Conductor.log_this()

        :ets.insert(
          @mem_ets,
          {location, %{content | value: new_content_value, relocation_value: relocation}, source}
        )
    end
  end

  def merge_memory(%MemoryAddress{} = location, data, mask)
      when is_integer(data) and is_integer(mask) and data <= mask and data >= 0 and mask >= 0 do
    lookup = :ets.lookup(@mem_ets, location)

    cond do
      lookup == [] ->
        raise(
          "cannot merge into non-existent memory #{inspect(location)}, " <>
            "#{Integer.to_string(data, 8)}, #{Integer.to_string(mask, 8)}"
        )

      true ->
        [{_, %MemoryValue{} = content, source}] = lookup
        masked_data = data &&& mask
        new_content_value = content.value ||| masked_data
        if location.location == @trace_location, do: Conductor.log_this()

        :ets.insert(@mem_ets, {location, %{content | value: new_content_value}, source})
    end
  end

  def get_memory(%MemoryAddress{} = address) do
    lookup = :ets.lookup(@mem_ets, address)

    cond do
      lookup == [] ->
        nil

      true ->
        [{_, %MemoryValue{} = value, _}] = lookup
        value
    end
  end

  def get_memory(location, relocation) do
    get_memory(MemoryAddress.new(location, relocation))
  end

  def all_addresses() do
    # Pattern: {key, :_} matches any tuple with 2 elements, returns only key
    :ets.match(@mem_ets, {:"$1", :_, :_})
    |> List.flatten()
    |> Enum.sort(fn a, b -> a.relocation <= b.relocation and a.location <= b.location end)
  end

  def is_empty?(%MemoryAddress{} = address) do
    lookup = :ets.lookup(@mem_ets, address)

    cond do
      lookup == [] -> true
      true -> false
    end
  end

  def first() do
    :ets.first_lookup(@mem_ets)
  end

  def next(%MemoryAddress{} = current) do
    :ets.next_lookup(@mem_ets, MemoryAddress.address(current))
  end

  def dump_memory(%State{} = state, tag) do
    IO.puts(tag)

    :ets.tab2list(@mem_ets)
    # |> Enum.take(3)
    |> Enum.map(fn {address, content, _address1} ->
      {address.relocation, Integer.to_string(address.location, 8),
       Integer.to_string(content.value, 8)}
    end)
    |> Enum.each(&IO.puts("#{inspect(&1)}"))

    state
  end
end
