defmodule TokenizerTest do
  use ExUnit.Case
  doctest A940.Tokenizer

  alias A940.Tokenizer

  import(Bitwise)

  test "create tokens" do
    t = Tokenizer.tokens(1, "A")
    assert 1 == length(t.tokens)
    assert {:symbol, "A"} == hd(t.tokens)

    t = Tokenizer.tokens(77, "A LDA A")
    assert 5 == length(t.tokens)
    assert {:symbol, "LDA"} == Enum.at(t.tokens, 2)
    assert 77 == t.line_number

    t = Tokenizer.tokens(178, "A LDA* =123,2") |> dbg
    assert 9 == length(t.tokens)
    assert {:number, 123} == Enum.at(t.tokens, 6)
    assert 178 = t.line_number
  end
end
