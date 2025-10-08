defmodule AssemblerTest do
  use ExUnit.Case

  test "simplest" do
    source = ["A IDENT", " END"]
    a_out = A940.Conductor.runner(source)
    assert a_out.ident == "A"
    assert is_map(a_out.code)
    assert map_size(a_out.code) == 0
    # assert is_list(a_out.relocations)
    # assert length(a_out.relocations) == 0
  end

  test "duplicate IDENTs cause error" do
    source = ["A IDENT", "B IDENT", " END"]
    err = "Multiple IDENT directives"
    assert_raise RuntimeError, err, fn -> A940.Conductor.runner(source) end
  end

  test "no IDENT directive" do
    source = [" END"]
    err = "No IDENT directive"
    assert_raise RuntimeError, err, fn -> A940.Conductor.runner(source) end
  end

  test "simple with instruction" do
    source = ["A IDENT", " LDA 5", " END"]
    a_out = A940.Conductor.runner(source)
    assert a_out.ident == "A"
    assert is_map(a_out.code)
    assert map_size(a_out.code) == 1
    mem_val = Map.get(a_out.code, 0)

    assert mem_val.value == 0o7_600_005
  end

  test "simple with indexed instruction" do
    source = ["A IDENT", " LDA 6,2", " END"]
    a_out = A940.Conductor.runner(source)
    assert a_out.ident == "A"
    assert is_map(a_out.code)
    assert map_size(a_out.code) == 1
    mem_val = Map.get(a_out.code, 0)
    IO.puts("mem val #{Integer.to_string(mem_val.value, 8)}")
    assert mem_val.value == 0o27_600_006
  end
end
