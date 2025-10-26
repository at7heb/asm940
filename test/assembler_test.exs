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
      # " ZRO",
      "LAST EQU *",
      " END"
    ]

    a_out = A940.Conductor.runner(source)
    bru_instruction = Map.get(a_out.code, 2)
    assert bru_instruction.value == 0o0100007
    assert bru_instruction.relocation_value == 0
  end

  test "ASC tests" do
    source = [
      "A IDENT",
      " ASC 'ABC'",
      "A1 ASC 'DEF'",
      "$A2 ASC \"GHI\"",
      "A3 ASC 'TWAS BRILLIG AND THE ...'",
      " END"
    ]

    a_out = A940.Conductor.runner(source)
    ghi = Map.get(a_out.code, 2)
    assert ghi.value == 0x272829
    assert ghi.relocation_value == 0
  end

  test "BES & BSS tests" do
    length = 10

    source = [
      "A IDENT",
      "BB BES #{length}",
      "$CC BES #{length + 5}",
      "DD BSS 5",
      " END"
    ]

    a_out = A940.Conductor.runner(source)
    # check BB symbol
    symbol_value = Map.get(a_out.symbols, "BB")
    assert symbol_value.value == length
    assert symbol_value.relocation == 1
    assert not symbol_value.exported?
    # check CC symbol
    symbol_value = Map.get(a_out.symbols, "CC")
    assert symbol_value.value == length + length + 5
    assert symbol_value.relocation == 1
    assert symbol_value.exported?
    # DD symbol - almost the same as CC
    symbol_value = Map.get(a_out.symbols, "DD")
    assert symbol_value.value == length + length + 5
    assert symbol_value.relocation == 1
    assert not symbol_value.exported?
    # check no extra symbols (A in IDENT counts as one)
    assert length(Map.keys(a_out.symbols)) == 3
    # check no extra memory
    assert length(Map.keys(a_out.code)) == length + length + 5 + 5
  end

  test "COPY tests" do
    source = [
      "A IDENT",
      " COPY AB,BA,E",
      " END"
    ]

    a_out = A940.Conductor.runner(source)
    mem = Map.get(a_out.code, 0)
    assert mem.value == 0o04600114
  end

  test "DEC test" do
    source = [
      "A IDENT",
      " DEC",
      " END"
    ]

    err = "DEC operative is not implemented"

    assert_raise RuntimeError, err, fn -> A940.Conductor.runner(source) end
  end

  test "OCT test" do
    source = [
      "A IDENT",
      " OCT",
      " END"
    ]

    err = "OCT operative is not implemented"

    assert_raise RuntimeError, err, fn -> A940.Conductor.runner(source) end
  end

  test "EXT & FIILIB test" do
    source = [
      "Z IDENT",
      " FIILIB",
      "A EXT *",
      " ZRO",
      "B LDA 77",
      "B EXT",
      "C LDX 5",
      # " EXT 7",
      " END"
    ]

    a_out = A940.Conductor.runner(source)
    symbols = a_out.symbols
    [a_address, b_address, c_address] = Enum.map(["A", "B", "C"], &Map.get(symbols, &1))
    assert a_address.value == 0
    assert a_address.exported?
    assert b_address.value == 1
    assert b_address.exported?
    assert c_address.value == 2
    assert not c_address.exported?
    last = Map.get(a_out.code, 3)
    assert last.value == 0o31_062_144
    assert last.relocation_value == 0
  end

  test "FREEZE smoke test" do
    source = [
      "Z IDENT",
      " FIILIB",
      "A EXT *",
      " ZRO",
      "B LDA 77",
      "B EXT",
      "C LDX 5",
      "D EXT 7",
      " FREEZE",
      " END"
    ]

    _a_out = A940.Conductor.runner(source)
    [keys: symbol_keys] = :ets.lookup(:symbols, :keys)
    [keys: macro_keys] = :ets.lookup(:macros, :keys)
    assert is_list(symbol_keys)
    assert length(symbol_keys) == 4
    assert is_list(macro_keys)
    assert length(macro_keys) == 0
    {"C", c_sym} = hd(:ets.lookup(:symbols, "C"))
    assert c_sym.value == 2
    assert c_sym.relocation == 1
    assert not c_sym.exported?
  end

  test "FRGT  test" do
    source = [
      "Z IDENT",
      " FIILIB",
      "A EXT *",
      " ZRO",
      "B LDA 77",
      "B EXT",
      "C LDX 5",
      "D EXT 7",
      " FRGT B",
      " END"
    ]

    a_out = A940.Conductor.runner(source)
    b_address = Map.get(a_out.symbols, "B")
    assert b_address.forgotten?
    c_address = Map.get(a_out.symbols, "C")
    assert not c_address.forgotten?
  end
end
