defmodule AssemblerTest do
  use ExUnit.Case

  # @tag :skip
  test "simplest" do
    source = ["A IDENT", " LDX 10", " ZRO", "B LDA 1", " LDB B", " ZRO", " ZRO B", " END"]
    a_out = A940.Conductor.runner(source)
    assert a_out.ident == "A"
    assert is_map(a_out.code)
    # a_out.code |> dbg
    assert map_size(a_out.code) == 6
    # a_out.symbols |> dbg
    # assert is_list(a_out.relocations)
    # assert length(a_out.relocations) == 0
  end

  # @tag :skip
  test "duplicate IDENTs cause error" do
    source = ["A IDENT", "B IDENT", " END"]
    err = "Multiple IDENT directives"
    assert_raise RuntimeError, err, fn -> A940.Conductor.runner(source) end
  end

  # @tag :skip
  test "no IDENT directive" do
    source = [" END"]
    err = "No IDENT directive"
    assert_raise RuntimeError, err, fn -> A940.Conductor.runner(source) end
  end

  # @tag :skip
  test "simple with instruction" do
    source = ["A IDENT", " LDA 5", " END"]
    a_out = A940.Conductor.runner(source)
    assert a_out.ident == "A"
    assert is_map(a_out.code)
    assert map_size(a_out.code) == 1
    mem_val = Map.get(a_out.code, 0)

    assert mem_val.value == 0o7_600_005
  end

  # @tag :skip
  test "simple with indexed instruction" do
    source = ["A IDENT", " LDA 6,2", " END"]
    a_out = A940.Conductor.runner(source)
    assert a_out.ident == "A"
    assert is_map(a_out.code)
    assert map_size(a_out.code) == 1
    mem_val = Map.get(a_out.code, 0)
    # IO.puts("mem val #{Integer.to_string(mem_val.value, 8)}")
    assert mem_val.value == 0o27600006
    # sss = a_out.symbols
    # sss |> dbg
  end

  test "simple with indexed and indirect instruction" do
    source = ["A IDENT", " LDA* 6,2", " END"]
    a_out = A940.Conductor.runner(source)
    assert a_out.ident == "A"
    assert is_map(a_out.code)
    assert map_size(a_out.code) == 1
    mem_val = Map.get(a_out.code, 0)
    # IO.puts("mem val #{Integer.to_string(mem_val.value, 8)} S/B 27640006")
    assert mem_val.value == 0o27640006
    # sss = a_out.symbols
    # sss |> dbg
  end

  # @tag :skip
  test "simple with labels instruction" do
    source = ["A IDENT", "B LDA 6,2", "C STA* 7", " END"]
    a_out = A940.Conductor.runner(source)
    assert a_out.ident == "A"
    assert is_map(a_out.code)
    assert map_size(a_out.code) == 2
    mem_val = Map.get(a_out.code, 0)
    # IO.puts("mem val #{Integer.to_string(mem_val.value, 8)}")
    assert mem_val.value == 0o27_600_006
    # a_out.symbols |> dbg
  end

  # @tag :skip
  test "comment lines" do
    source = ["A IDENT", "*****", "* EQUS", " END"]
    a_out = A940.Conductor.runner(source)
    a_out
    # |> dbg
  end

  # @tag :skip
  test "EQU tests" do
    source = [
      "A IDENT",
      "A0 ZRO",
      "A0ALS EQU A0",
      "A1 LDA 5",
      "C0 EQU *",
      "SEVEN EQU 7",
      " BRU SEVEN",
      "$LAST EQU *",
      "C1 ZRO",
      "$C2 ZRO",
      " END"
    ]

    a_out = A940.Conductor.runner(source)
    a_out |> dbg
  end

  test "ASC tests" do
    source = [
      "A IDENT",
      " ASC 'ABC'",
      "A1 ASC 'DEF'",
      "$A2 ASC \"GHI\"",
      " END"
    ]

    a_out = A940.Conductor.runner(source)
    a_out |> dbg
  end
end
