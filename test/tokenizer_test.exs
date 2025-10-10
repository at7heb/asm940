defmodule TokenizerTest do
  use ExUnit.Case
  doctest A940.Tokenizer

  alias A940.Tokenizer

  import Bitwise

  @flagsB %{default_base: 8}
  @flagsD %{default_base: 10}

  @tag :skip
  test "create tokens" do
    t = Tokenizer.tokens(1, "A", @flagsD)
    assert 1 == length(t.tokens)
    assert {:symbol, "A"} == hd(t.tokens)

    t = Tokenizer.tokens(77, "A LDA A", @flagsD)
    assert 5 == length(t.tokens)
    assert {:symbol, "LDA"} == Enum.at(t.tokens, 2)
    assert 77 == t.line_number

    _t = Tokenizer.tokens(178, "A LDA* =129,2", @flagsD)
    t = Tokenizer.tokens(178, "A LDA* =123,2", @flagsD)
    assert 9 == length(t.tokens)
    assert {:number, 123} == Enum.at(t.tokens, 6)
    assert 178 = t.line_number

    t = Tokenizer.tokens(178, "A LDA* =123,2", @flagsB)
    assert 9 == length(t.tokens)
    assert {:number, 83} == Enum.at(t.tokens, 6)
    assert 178 = t.line_number

    t = Tokenizer.tokens(178, "A LDA* =11B7,1B7", @flagsB)
    assert 9 == length(t.tokens)
    assert {:number, 1 <<< 21} == Enum.at(t.tokens, 6)
    assert {:number, 1 <<< 21} == Enum.at(t.tokens, 8)
    assert 178 = t.line_number
  end

  @tag :skip
  test "6 bit strings" do
    t_struct = Tokenizer.tokens(178, "'' 'A' 'BC' 'DEF' 'GHIJ' '089@'", @flagsB)
    tokens = t_struct.tokens
    assert {:string_6, {0, ""}} == Enum.at(tokens, 0)
    assert {:string_6, {0o4243, "BC"}} == Enum.at(tokens, 4)
    assert {:string_6, {0o444546, "DEF"}} == Enum.at(tokens, 6)
    assert {:string_6, {0o47505152, "GHIJ"}} == Enum.at(tokens, 8)
  end
end
