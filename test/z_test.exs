defmodule ZTest do
  use ExUnit.Case

  test "Basic part 1" do
    Path.wildcard("test/z0*.txt")
    # |> Enum.each(&A940.Conductor.runner(&1))
    |> Enum.each(&A940.Conductor.runner(&1))
  end
end
