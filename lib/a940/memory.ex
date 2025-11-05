defmodule A940.Memory do
  import Bitwise
  alias A940.{MemoryAddress, MemoryValue}
  @mem_ets :memory_locations

  def new_memory_image_table() do
    case :ets.whereis(@mem_ets) do
      :undefined -> nil
      _ -> :ets.delete(@mem_ets)
    end

    :ets.new(@mem_ets, [:set, :protected, :named_table])
  end

  def set_memory(%MemoryAddress{} = address, %MemoryValue{} = value) do
    case is_empty?(address) do
      true -> :ets.insert(@mem_ets, {address, value})
      _ -> raise "Memory location #{inspect(address)} written twice"
    end
  end

  # Memory.merge_address(location, address_field, state.flags.address_length)
  def merge_address(%MemoryAddress{} = location, address, address_field_length) do
    mask = 2 ** address_field_length - 1

    merge_memory(location, address, mask)
  end

  # Memory.merge_tag(location, tag)
  def merge_tag(%MemoryAddress{} = location, tag) do
    word_tag = tag <<< 21
    mask = 0o70000000
    merge_memory(location, word_tag, mask)
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
        [{_, %MemoryValue{} = content}] = lookup
        masked_data = data &&& mask
        new_content_value = content.value ||| masked_data
        :ets.insert(@mem_ets, {location, %{content | value: new_content_value}})
    end
  end

  def get_memory(%MemoryAddress{} = address) do
    lookup = :ets.lookup(@mem_ets, address)

    cond do
      lookup == [] ->
        nil

      true ->
        [{_, %MemoryValue{} = value}] = lookup
        value
    end
  end

  def all_addresses() do
    # Pattern: {key, :_} matches any tuple with 2 elements, returns only key
    :ets.match(@mem_ets, {:"$1", :_})
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
end
