defmodule ATest do
  use ExUnit.Case

  alias A940.Conductor

  test "simple with indexed instruction" do
    source = ["A IDENT", " LDA 6,2", " END"]
    a_out = Conductor.runner(source)
    assert a_out.ident == "A"
    addresses = A940.Memory.all_addresses()
    addresses |> dbg
    address = hd(addresses) |> dbg
    content = A940.Memory.get_memory(address) |> dbg
    # IO.puts("mem val #{Integer.to_string(mem_val.value, 8)}")
    assert content.value == 0o27600006
    # sss = a_out.symbols
    # sss |> dbg
  end
end
