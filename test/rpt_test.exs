defmodule RptTest do
  use ExUnit.Case

  alias A940.Conductor

  test "easy RPT" do
    source = [
      "A IDENT",
      "B EAX 1",
      "FIRST LDX 10",
      " RPT 2",
      " LDA 1",
      " LDB B",
      " ZRO",
      " ZRO B",
      " ENDR",
      "LAST DATA 55",
      " END"
    ]

    _a_out = Conductor.runner(source)

    addresses = A940.Memory.all_addresses()
    # words = Enum.map(addresses, fn address -> A940.Memory.get_memory(address) end)
    # Enum.each(words, fn word -> IO.puts("#{inspect(word)}") end)
    assert length(addresses) == 11
  end

  # test RPT inside IF false / ENDIF
  # test nested RPTs
  # test RPT 0, ..., ENDR
  # test RPT (I=5,10) ENDR
  # test RPT (I=5,10,2) ... ENDR
  # test RPT 2;LABEL DATA 5; ENDR
end
