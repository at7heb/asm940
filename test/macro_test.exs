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
      "AA NCHR D(1)",
      " DATA AA",
      " FRGT AA",
      " ENDM",
      " DOUBLE 40B",
      " EAX 5B3",
      " END"
    ]

    _a_out = Conductor.runner(source)

    addresses = A940.Memory.all_addresses()
    words = Enum.map(addresses, fn address -> A940.Memory.get_memory(address) end)
    Enum.each(words, fn word -> IO.puts("#{inspect(word)}") end)
    assert length(addresses) == 3
  end

  test "MACRO with concatenation" do
    source = [
      "A IDENT",
      "B EQU 77B5",
      "DOUBLE MACRO D",
      ":.&D(1) EQU 2*D(2)",
      " ENDM",
      " DOUBLE A,40B",
      " DOUBLE B,30B",
      " DATA :A",
      " DATA :B",
      " END"
    ]

    _a_out = Conductor.runner(source)

    addresses = A940.Memory.all_addresses()
    words = Enum.map(addresses, fn address -> A940.Memory.get_memory(address) end)
    Enum.each(words, fn word -> IO.puts("#{inspect(word)}") end)
    assert length(addresses) == 2
  end

  test "MACRO with NARG" do
    source = [
      "A IDENT",
      "B EQU 77B5",
      "COUNT MACRO D,G,1",
      "G(1) NARG",
      " DATA G(1)",
      " ENDM",
      " COUNT A",
      " COUNT B,C,D",
      " END"
    ]

    _a_out = Conductor.runner(source)

    addresses = A940.Memory.all_addresses()
    words = Enum.map(addresses, fn address -> A940.Memory.get_memory(address) end)
    Enum.each(words, fn word -> IO.puts("#{inspect(word)}") end)
    assert length(addresses) == 2
  end
end
