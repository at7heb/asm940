defmodule IfTest do
  use ExUnit.Case

  alias A940.Conductor

  # @tag :skip
  test "simplest IF false" do
    source = ["A IDENT", " IF 0", " ZRO", " ENDF", " DATA 1", " END"]
    a_out = Conductor.runner(source)
    code = a_out.code
    assert map_size(code) == 1
    memory = Map.get(code, 0)
    assert memory.value == 1
    assert memory.relocation_value == 0
    assert memory.address_expression == []
  end

  # @tag :skip
  test "simplest IF true" do
    source = ["A IDENT", " IF 1", " ZRO", " ENDF", " DATA 1", " END"]
    a_out = Conductor.runner(source)
    code = a_out.code
    assert map_size(code) == 2
    memory = Map.get(code, 0)
    assert memory.value == 0
    assert memory.relocation_value == 0
    assert memory.address_expression == []
    memory = Map.get(code, 1)
    assert memory.value == 1
    assert memory.relocation_value == 0
    assert memory.address_expression == []
  end

  test "IF/ELSE/ENDF" do
    source = ["A IDENT", " IF 1", " DATA 1", " ELSE", " DATA 77B", " ENDF", " END"]
    a_out = Conductor.runner(source)
    code = a_out.code
    assert map_size(code) == 1
    memory = Map.get(code, 0)
    assert memory.value == 1
    assert memory.relocation_value == 0
    assert memory.address_expression == []
    source = ["A IDENT", " IF 0", " DATA 1", " ELSE", " DATA 77B", " ENDF", " END"]
    a_out = Conductor.runner(source)
    code = a_out.code
    assert map_size(code) == 1
    memory = Map.get(code, 0)
    assert memory.value == 0o77
    assert memory.relocation_value == 0
    assert memory.address_expression == []
  end

  # test nested IFs
  test "IF/ELSE/ENDF with nested IF/ELSE/ENDF" do
    source = [
      "A IDENT",
      " IF 1",
      " DATA 1",
      " IF 0",
      " DATA 5",
      " ELSE",
      " DATA 7",
      " ENDF",
      " ELSE",
      " DATA 77B",
      " ENDF",
      " END"
    ]

    a_out = Conductor.runner(source)
    code = a_out.code
    assert map_size(code) == 2
    memory = Map.get(code, 0)
    assert memory.value == 1
    assert memory.relocation_value == 0
    assert memory.address_expression == []
    memory = Map.get(code, 1)
    assert memory.value == 7
    assert memory.relocation_value == 0
    assert memory.address_expression == []

    IO.puts("---------- Should skip a few lines ----------")

    source = [
      "A IDENT",
      " IF 0",
      " DATA 1",
      " IF 0",
      " DATA 5",
      " LDA 5",
      " STA 7",
      " EAX 55",
      " ELSE",
      " DATA 7",
      " ENDF",
      " ELSE",
      " DATA 77B",
      " ENDF",
      " END"
    ]

    a_out = Conductor.runner(source)
    code = a_out.code
    assert map_size(code) == 1
    memory = Map.get(code, 0)
    assert memory.value == 0o77
    assert memory.relocation_value == 0
    assert memory.address_expression == []

    source = [
      "A IDENT",
      " IF 0",
      " DATA 1",
      " ELSE",
      " IF 0",
      " DATA 5",
      " ELSE",
      " DATA 7",
      " ENDF",
      " DATA 77B",
      " ENDF",
      " END"
    ]

    a_out = Conductor.runner(source)
    code = a_out.code
    assert map_size(code) == 2
    memory = Map.get(code, 0)
    assert memory.value == 7
    assert memory.relocation_value == 0
    assert memory.address_expression == []
    memory = Map.get(code, 1)
    assert memory.value == 0o77
    assert memory.relocation_value == 0
    assert memory.address_expression == []
  end

  # TODO: test double ELSEs
  # TODO: test ELSE / ELSF sequence
  # TODO: test ELSFs all true
  # TODO: test ELSFs all false
  # TODO: test no ENDF
  # TODO: figure out if you can have ENDR inside an IF before and after an ELSE. Probably not.
end
