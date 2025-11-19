defmodule MacroTest do
  use ExUnit.Case

  alias A940.Conductor

  # @tag :skip
  test "easy MACRO" do
    source = [
      "A IDENT",
      "B4B7 DATA 4B7",
      " EAX LAST",
      "SKAP MACRO",
      " SKA B4B7",
      " ENDM",
      "SKAN MACRO",
      " SKA B4B7",
      " BRU *+2",
      " ENDM",
      " SKAP",
      " CNA",
      " SKAN",
      " EAX 5B3",
      "LAST DATA 55",
      " END"
    ]

    _a_out = Conductor.runner(source)

    addresses = A940.Memory.all_addresses()
    words = Enum.map(addresses, fn address -> A940.Memory.get_memory(address) end)
    Enum.each(words, fn word -> IO.puts("#{inspect(word)}") end)
    assert length(addresses) == 8
  end

  # @tag :skip
  test "MACRO with argument" do
    source = [
      "A IDENT",
      "DOUBLE MACRO D",
      " DATA 2*D(1)",
      " ENDM",
      " DOUBLE 40B",
      " EAX 5B3",
      " END"
    ]

    _a_out = Conductor.runner(source)

    addresses = A940.Memory.all_addresses()
    words = Enum.map(addresses, fn address -> A940.Memory.get_memory(address) end)
    Enum.each(words, fn word -> IO.puts("#{inspect(word)}") end)
    assert length(addresses) == 2
  end
end
