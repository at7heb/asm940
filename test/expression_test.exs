defmodule ExpressionTest do
  use ExUnit.Case

  alias A940.Expression

  # @tag :skip
  test "simplest" do
    tokens = [{:number, 1}]
    symbols = %{}
    current_location = 0o1000
    current_relocation = 1
    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    # rv |> dbg
    assert rv == {1, 0}
  end

  # @tag :skip
  test "simple expression" do
    num1 = {:number, 1}
    num3 = {:number, 3}
    # hereloc = {:delimiter, "*"}
    tokens = [num3, {:delimiter, "+"}, num3]
    symbols = %{}
    current_location = 0o1000
    current_relocation = 1
    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    # rv |> dbg
    assert rv == {6, 0}
    tokens = [num1, {:delimiter, "+"}, num3, {:delimiter, "*"}, num3]
    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    assert rv == {10, 0}
  end

  # @tag :skip
  test "here location expressions" do
    # num1 = {:number, 1}
    num3 = {:number, 3}
    hereloc = {:delimiter, "*"}
    symbols = %{}
    current_location = 0o1000
    current_relocation = 1
    tokens = [hereloc, {:delimiter, "+"}, num3]
    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    assert rv == {0o1003, 1}
    # IO.puts("Now trying relocation change!")
    tokens = [hereloc, {:delimiter, "*"}, num3]
    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    assert rv == {0o3000, 3}
  end

  # @tag :skip
  test "nested expressions" do
    # num1 = {:number, 1}
    num3 = {:number, 3}
    hereloc = {:delimiter, "*"}
    symbols = %{}
    current_location = 0o1000
    current_relocation = 1

    tokens = [
      num3,
      {:delimiter, "*"},
      {:delimiter, "["},
      hereloc,
      {:delimiter, "+"},
      num3,
      {:delimiter, "]"}
    ]

    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    assert rv == {0o3011, 3}
  end

  test "long expression" do
    # num1 = {:number, 1}
    num3 = {:number, 3}
    # hereloc = {:delimiter, "*"}
    tokens = [
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "+"},
      num3
    ]

    symbols = %{}
    current_location = 0o1000
    current_relocation = 1
    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    # rv |> dbg
    assert rv == {18, 0}

    tokens = [
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "+"},
      {:delimiter, "["},
      num3,
      {:delimiter, "*"},
      num3,
      {:delimiter, "]"},
      {:delimiter, "+"},
      num3
    ]

    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    # rv |> dbg
    assert rv == {30, 0}

    tokens = [
      num3,
      {:delimiter, "*"},
      num3,
      {:delimiter, "*"},
      num3,
      {:delimiter, "*"},
      num3,
      {:delimiter, "*"},
      num3,
      {:delimiter, "*"},
      {:delimiter, "["},
      num3,
      {:delimiter, "+"},
      num3,
      {:delimiter, "]"},
      {:delimiter, "*"},
      num3
    ]

    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    # rv |> dbg
    assert rv == {4374, 0}
  end

  test "symbol expression" do
    # num1 = {:number, 1}
    num3 = {:number, 3}
    # hereloc = {:delimiter, "*"}
    #   def new(value, relocation, exported \\ false, b14? \\ false)

    symbola =
      A940.Address.new(0o523, 0)

    tokens = [
      num3,
      {:delimiter, "+"},
      {:symbol, "A"}
    ]

    symbols = %{} |> Map.put("A", symbola)
    current_location = 0o1000
    current_relocation = 1
    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    # rv |> dbg
    assert rv == {0o526, 0}

    symbolb = A940.Address.new(0o100, 1)

    symbols = Map.put(symbols, "B", symbolb)

    tokens = [
      num3,
      {:delimiter, "+"},
      {:symbol, "A"},
      {:delimiter, "+"},
      {:symbol, "B"}
    ]

    rv = Expression.evaluate(tokens, symbols, current_location, current_relocation)
    # rv |> dbg
    assert rv == {0o626, 1}

    symbolc =
      A940.Address.new_expression([{:symbol, "B"}, {:delimiter, "-"}, {:number, 1}], false)

    symbols = Map.put(symbols, "C", symbolc)

    tokens = tokens ++ [{:delimiter, "+"}, {:symbol, "C"}]

    rv =
      Expression.evaluate(tokens, symbols, current_location, current_relocation)

    # |> dbg
    assert elem(rv, 0) == :undefined_symbol
    assert is_list(elem(rv, 1))
  end
end
