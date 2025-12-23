defmodule A940.Listing do
  alias A940.{Memory, MemoryAddress, MemoryValue, State}

  def make_listing(%State{listing_name: ""} = state), do: state

  def make_listing(%State{listing_name: listing_name} = state) do
    list_next(listing_name, state)
  end

  def list_next(listing_name, %State{} = state) do
    loc = Memory.first()

    {next_address, listing_string} = make_listing_line(loc)
    IO.puts(listing_string)
    list_next(listing_name, state, next_address)
  end

  def list_next(listing_name, %State{} = state, %MemoryAddress{} = address) do
    loc = Memory.next(address)

    if(loc != :"$end_of_table") do
      {next_address, listing_string} = make_listing_line(loc)
      IO.puts(listing_string)
      list_next(listing_name, state, next_address)
    end
  end

  def make_listing_line({address, [{address_again, value, code}]} = _location) do
    line_number = fmt_int(code.line_number, 5, 10, " ")
    address_part = MemoryAddress.format_for_listing(address)

    extra_address_part =
      if address != address_again do
        " MH " <> MemoryAddress.format_for_listing(address_again)
      else
        ""
      end

    memory_value_part = ["  ", MemoryValue.format_for_listing(value)]

    code_part = ["  ", format_for_listing(code)]
    {address, [line_number, " ", address_part, extra_address_part, memory_value_part, code_part]}
  end

  def format_for_listing(%MemoryAddress{
        label: label,
        opcode: opcode,
        address: address,
        comments: comment
      }) do
    [
      fmt_string(concat_token_values(label), 10),
      "  ",
      fmt_string(concat_token_values(opcode), 10),
      "  ",
      if comment != [] do
        fmt_string(concat_list_of_token_list_values(address), 20)
      else
        concat_list_of_token_list_values(address)
      end,
      concat_token_values(comment)
    ]
  end

  def concat_token_values(tokens) when is_list(tokens) do
    Enum.map(tokens, fn {_type, value} -> string_value(value) end)
    |> Enum.join("")
  end

  def string_value(val) when is_binary(val), do: val
  def string_value(val) when is_integer(val), do: Integer.to_string(val)
  def string_value({_, val}) when is_binary(val), do: val

  def concat_list_of_token_list_values(list_of_token_lists) when is_list(list_of_token_lists) do
    Enum.map(list_of_token_lists, fn token_list -> concat_token_values(token_list) end)
    |> Enum.join(",")
  end

  def fmt_int(n, width, base, pad) do
    n
    |> Integer.to_string(base)
    |> String.pad_leading(width, pad)
  end

  def fmt_string(s, width) when is_binary(s) and is_integer(width) do
    String.pad_trailing(s, width, " ")
  end
end
