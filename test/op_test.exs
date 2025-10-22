defmodule OpTest do
  use ExUnit.Case

  test "Directive b()" do
    assert A940.Directive.b(0) == 0o40000000
    assert A940.Directive.b(23) == 1
    assert A940.Directive.b(22) == 2
    assert A940.Directive.b(21) == 4
    assert A940.Directive.b(20) == 8
    assert A940.Directive.b(19) == 16
    assert A940.Directive.b(18) == 32
    assert A940.Directive.b(17) == 64
    assert A940.Directive.b(16) == 128
    assert A940.Directive.b(15) == 256
    assert A940.Directive.b(14) == 512
    assert A940.Directive.b(1) == 0o20000000
  end

  test "Directive.copy_token" do
    assert 1 == A940.Directive.copy_token({:symbol, "A"}, 0)
    assert 3 == A940.Directive.copy_token({:symbol, "B"}, 1)
    assert 2 ** 22 + 3 == A940.Directive.copy_token({:symbol, "X"}, 3)
    assert 4 == A940.Directive.copy_token({:symbol, "AB"}, 0)
    assert 8 == A940.Directive.copy_token({:symbol, "BA"}, 0)
    assert 16 == A940.Directive.copy_token({:symbol, "BX"}, 0)
    assert 32 == A940.Directive.copy_token({:symbol, "XB"}, 0)
    assert 64 == A940.Directive.copy_token({:symbol, "E"}, 0)
    assert 128 == A940.Directive.copy_token({:symbol, "XA"}, 0)
    assert 256 == A940.Directive.copy_token({:symbol, "AX"}, 0)
    assert 512 == A940.Directive.copy_token({:symbol, "N"}, 0)
  end
end
