defmodule MemoryTest do
  use ExUnit.Case
  alias A940.{Memory, MemoryAddress, MemoryValue}

  test "can store and read" do
    Memory.new_memory_image_table()
    loc_a = Enum.random(0..8000)
    addr_a = MemoryAddress.new_absolute(loc_a)
    loc_r = Enum.random(8001..16000)
    addr_r = MemoryAddress.new_relocatable(loc_r)
    loc_z = Enum.random(16001..16200)
    addr_z_a = MemoryAddress.new_absolute(loc_z)
    addr_z_r = MemoryAddress.new_relocatable(loc_z)

    num_a = Enum.random(0..(2 ** 22 - 1))
    val_a = MemoryValue.new(num_a, 0)
    num_r = Enum.random((2 ** 22)..(2 ** 23 - 1))
    val_r = MemoryValue.new(num_r, 1)
    Memory.set_memory(addr_a, val_a)
    Memory.set_memory(addr_r, val_r)

    %MemoryValue{
      value: test_value,
      relocation_value: test_relocation,
      address_expression: test_tokens
    } = Memory.get_memory(addr_a)

    assert test_value == num_a
    assert test_relocation == 0
    assert test_tokens == []

    %MemoryValue{
      value: test_value,
      relocation_value: test_relocation,
      address_expression: test_tokens
    } = Memory.get_memory(addr_r)

    assert test_value == num_r
    assert test_relocation == 1
    assert test_tokens == []

    Memory.new_memory_image_table()
    val = MemoryValue.new(1_000_000, 0)
    microseconds_0 = System.monotonic_time(:microsecond)

    Enum.each(0..16383, fn a ->
      addr = MemoryAddress.new_relocatable(a)
      Memory.set_memory(addr, val)
    end)

    microseconds_1 = System.monotonic_time(:microsecond)
    time_per = 16384 / (microseconds_1 - microseconds_0)

    IO.puts("Set memory at #{time_per} us per location")

    microseconds_0 = System.monotonic_time(:microsecond)

    Enum.each(0..1_000_000, fn a ->
      addr = MemoryAddress.new_relocatable(Enum.random(0..16383))
      _v = Memory.get_memory(addr)
    end)

    microseconds_1 = System.monotonic_time(:microsecond)
    time_per = 16384 / (microseconds_1 - microseconds_0)

    IO.puts("Read memory at #{time_per} us per location")
  end
end
