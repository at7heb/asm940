defmodule TokensTest do
  use ExUnit.Case

  @tokens_table :ets_tokens
  alias A940.Tokens

  test "can create" do
    rv = :ets.info(@tokens_table)
    assert rv == :undefined
    Tokens.create_table()
    rv = :ets.info(@tokens_table)
    assert is_list(rv)
    name = rv[:name]
    assert name == @tokens_table

    :ets.delete(@tokens_table)
    :ets.new(@tokens_table, [:named_table])
    info0 = :ets.info(@tokens_table)
    Tokens.create_table()
    info1 = :ets.info(@tokens_table)
    assert info0[:id] != info1[:id]
  end

  test "can store tokens" do
    Tokens.create_table()
    size0 = :ets.info(@tokens_table)[:memory]
    range = 0..7777
    long_list = 1..100 |> Enum.to_list()

    lists =
      Enum.map(range, fn index ->
        [index, Enum.slice(long_list, 0, Enum.random(10..30))] |> List.flatten()
      end)

    Enum.each(range, fn index -> Tokens.store_tokens(index + 1, Enum.at(lists, index)) end)
    size1 = :ets.info(@tokens_table)[:memory]
    assert size1 > size0

    new_lists = Enum.map(range, fn index -> Tokens.read_tokens(index + 1) end)
    assert lists == new_lists

    assert_raise(RuntimeError, ~r/nothing at that key/, fn -> Tokens.read_tokens(8_388_607) end)
  end

  test "basic range" do
    Tokens.create_table()
    range = 1..7777
    range_0 = 1..7778
    long_list = 1..100 |> Enum.to_list()

    lists =
      Enum.map(range_0, fn index ->
        [index, Enum.slice(long_list, 0, Enum.random(10..30))] |> List.flatten()
      end)

    Enum.each(range, fn index -> Tokens.store_tokens(index, Enum.at(lists, index)) end)

    assert_raise(RuntimeError, ~r/empty/, fn -> Tokens.pop_range() end)

    assert_raise(FunctionClauseError, ~r/no function clause matching/, fn ->
      Tokens.push_range(:a, :b)
    end)

    Tokens.push_range(10, 11)

    first = Tokens.next()
    next = Tokens.next()
    last = Tokens.next()

    assert first == {:ok, 10, Enum.at(lists, 10)}
    assert next == {:ok, 11, Enum.at(lists, 11)}
    assert last == {:error, "no more tokens"}
    :ok = Tokens.rewind()
    another_first = Tokens.next()
    assert first == another_first
    Tokens.push_range(9, 11)
    _ = Tokens.next()
    a_final_first = Tokens.next()
    assert first == a_final_first
    assert is_tuple(first)
    assert 3 == tuple_size(first)
    {a, b, c} = first
    assert a == :ok
    assert b == 10
    assert c == Enum.at(lists, 10)
  end
end
