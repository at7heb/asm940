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
    assert Map.get(a_out.code, 0) == 07_600_005
  end
end
