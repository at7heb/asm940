defmodule RptTest do
  use ExUnit.Case

  alias A940.Conductor

  test "easy RPT" do
    source = [
      "A IDENT",
      "FIST LDX 10",
      " RPT 2",
      " LDA 1",
      " LDB B",
      " ZRO",
      " ZRO B",
      " ENDR",
      "LAST DATA 55",
      " END"
    ]

    a_out = Conductor.runner(source)
  end

  # test RPT inside IF false / ENDIF
  # test nested RPTs
  # test RPT 0, ..., ENDR
  # test RPT (I=5,10) ENDR
  # test RPT (I=5,10,2) ... ENDR
  # test RPT 2;LABEL DATA 5; ENDR
end
