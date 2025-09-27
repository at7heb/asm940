defmodule A940Test do
  use ExUnit.Case
  doctest Asm940

  test "greets the world" do
    v =
      A940.pass1(["A  LDA   B", "A  LDA*  B", "A LDA B,2", "* comment", "A LDA *B", "A LDA *B,2"])

    IO.puts("")
    Enum.each(v, &IO.puts(&1))
    assert true
  end
end
