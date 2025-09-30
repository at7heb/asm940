defmodule ConductorTest do
  use ExUnit.Case
  doctest Asm940

  import Bitwise

  @source0 """
   LDA A
  B XXA
  $C LSH 1
  * IGNORE
  END
  """
  test "create tokens" do
    # IO.puts(@source0)
    result = A940.Conductor.runner(@source0)
    assert is_struct(result)
    assert map_size(result.lines) == 6
  end

  test "octal val" do
    test_octal_decode("10")
    test_octal_decode("777")
    test_octal_decode("777B3", "777", 3)
    test_octal_decode("777B7", "777", 7)
  end

  test "simple token" do
    a = "A"
    A940.Conductor.runner(a) |> dbg
  end

  defp test_octal_decode(v) do
    assert A940.Tokenizer.decode_octal(v) == String.to_integer(v, 8)
  end

  defp test_octal_decode(v, vprime, scale) do
    assert A940.Tokenizer.decode_octal(v) ==
             (String.to_integer(vprime, 8) <<< (3 * scale) &&& 0o77777777)
  end
end
