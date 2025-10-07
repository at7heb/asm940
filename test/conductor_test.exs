defmodule ConductorTest do
  use ExUnit.Case
  doctest A940.Conductor

  import Bitwise

  @source0 """
   LDA A
  B XXA
  $C LSH 1
  LSH
  * IGNORE
  """
  @tag :skip
  test "create tokens" do
    # IO.puts(@source0)
    result = A940.Conductor.runner(@source0)
    assert is_struct(result)
    assert map_size(result.lines) == 6
    tokens = Enum.at(result.tokens_list, 3)
    assert 4 == tokens.line_number
    assert {:symbol, "LSH"} == hd(tokens.tokens)
  end

  @tag :skip
  test "octal val" do
    # test_octal_decode("10")
    # test_octal_decode("777")
    # test_octal_decode("777B3", "777", 3)
    # test_octal_decode("777B7", "777", 7)
    a = "10B 777B 777B3 777B7"
    result = A940.Conductor.runner(a)
    tokens = Enum.at(result.tokens_list, 0)
    assert {:number, 8} == Enum.at(tokens.tokens, 0)
    assert {:number, 511} == Enum.at(tokens.tokens, 2)
    assert {:number, 511 <<< 9} == Enum.at(tokens.tokens, 4)
    assert {:number, 7 <<< 21} == Enum.at(tokens.tokens, 6)
  end

  @tag :skip
  test "simple token" do
    a = "A"
    result = A940.Conductor.runner(a)
    assert is_struct(result)
    assert map_size(result.lines) == 1
    tokens = Enum.at(result.tokens_list, 0)
    assert 1 == tokens.line_number
    assert 1 == length(tokens.tokens)
    assert {:symbol, "A"} == Enum.at(tokens.tokens, 0)
  end

  # defp test_octal_decode(v) do
  #   assert A940.Tokenizer.decode_octal(v) == String.to_integer(v, 8)
  # end

  # defp test_octal_decode(v, vprime, scale) do
  #   assert A940.Tokenizer.decode_octal(v) ==
  #            (String.to_integer(vprime, 8) <<< (3 * scale) &&& 0o77777777)
  # end
end
