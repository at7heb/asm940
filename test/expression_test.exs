defmodule ExpressionTest do
  use ExUnit.Case

  alias A940.Expression

  test "simplest" do
    tokens = [{:number, 1}]
    symbols = %{}
    current_location = 0o1000
    current_relocation = 1
    exp = Expression.new(tokens, symbols, current_location, current_relocation)
    rv = Expression.evaluate(exp)
    rv |> dbg
    assert rv == {1, 0}
  end

  test "simple expression" do
    num1 = {:number, 1}
    num3 = {:number, 3}
    tokens = [num3, {:delimiter, "+"}, num3]
    symbols = %{}
    current_location = 0o1000
    current_relocation = 1
    exp = Expression.new(tokens, symbols, current_location, current_relocation)
    rv = Expression.evaluate(exp)
    rv |> dbg
    assert rv == {4, 0}
  end
end
