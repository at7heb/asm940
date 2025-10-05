defmodule AssemblerTest do
  use ExUnit.Case

  test "simplest" do
    source = ["A IDENT", " END"]
    a_out = A940.Conductor.runner(source)
    assert a_out.ident == "A"
    assert is_list(a_out.code)
    assert length(a_out.code) == 0
    assert is_list(a_out.relocations)
    assert length(a_out.relocations) == 0
  end
end
