defmodule A940.Listing do
  alias A940.{Memory, MemoryAddress, MemoryValue, State}
  # text will be an IOlist
  defstruct source_line_number: 0, text_list: [], location: MemoryAddress.new_dummy(0, 0)

  @listing_ets :listing_lines
  @content_space "  "
  def new(line_number, line_text_list, %MemoryAddress{} = location)
      when is_integer(line_number) and is_list(line_text_list),
      do: %__MODULE__{
        source_line_number: line_number,
        text_list: line_text_list,
        location: location
      }

  def create_listing_table() do
    case :ets.whereis(@listing_ets) do
      :undefined -> nil
      _ -> :ets.delete(@listing_ets)
    end

    :ets.new(@listing_ets, [:ordered_set, :protected, :named_table])

    :ets.insert(@listing_ets, {:current_line, 0})
  end

  def add_line_listing(%State{} = state) do
    location = State.current_location(state)
    add_line_listing(state, location)
  end

  def add_line_listing(%State{} = state, %MemoryAddress{} = location) do
    add_line_listing(
      state.line_number,
      state.label_tokens,
      state.opcode_tokens,
      state.address_tokens_list,
      state.comment,
      location
    )

    state
  end

  def add_line_listing(%State{} = state, {_loc, _rel} = location) do
    add_line_listing(state, MemoryAddress.new(location))
  end

  def add_line_listing(%State{} = state, :literal, {value, 0}) do
    new(
      state.line_number,
      [fmt_int(value, 8, 10, "0"), "D   ABSOLUTE  LITERAL"],
      MemoryAddress.new(State.current_location(state))
    )
    |> stash_listing_line()
  end

  def add_line_listing(%State{} = state, :literal, {value, 1}) do
    new(
      state.line_number,
      [fmt_int(value, 8, 10, "0"), "D RELOCATABLE LITERAL"],
      MemoryAddress.new(State.current_location(state))
    )
    |> stash_listing_line()
  end

  def add_line_listing(%State{} = state, :literal, expression) when is_list(expression) do
    new(
      state.line_number,
      ["LITERAL ", concat_token_values(expression)],
      MemoryAddress.new(State.current_location(state))
    )
    |> stash_listing_line()
  end

  def add_line_listing(
        source_line_number,
        # no label
        [],
        # no opcode
        [],
        # no address
        [[]],
        # store as comment tokens
        [{:comment, comment_text}],
        %MemoryAddress{} = location
      ) do
    new(
      source_line_number,
      [@content_space, comment_text],
      location
    )
    |> stash_listing_line()
  end

  def add_line_listing(
        source_line_number,
        label,
        opcode,
        addresses,
        comment_text,
        %MemoryAddress{} = location
      ) do
    new(
      source_line_number,
      [
        " ",
        format_for_listing(label, opcode, addresses, comment_text)
      ],
      location
    )
    |> stash_listing_line()
  end

  def stash_listing_line(%__MODULE__{} = line) do
    listing_line_number = get_listing_line_number()
    :ets.insert(@listing_ets, {listing_line_number, line})
  end

  def make_listing(%State{listing_name: ""} = state), do: state

  def make_listing(%State{listing_name: listing_name} = state) do
    list_next(listing_name, 1)
    state
  end

  def list_next(listing_name, line_number) do
    listing_line = :ets.lookup(@listing_ets, line_number)

    if listing_line == [] do
      nil
    else
      [{^line_number, listing_line}] = listing_line

      location = listing_line.location

      memory_value_part =
        if location.dummy do
          "          "
        else
          # {listing_line.location, Memory.get_memory(listing_line.location)} |> dbg
          MemoryValue.format_for_listing(Memory.get_memory(listing_line.location))
        end

      IO.puts([
        # fmt_int(line_number, 5, 10, " "),
        fmt_int(listing_line.source_line_number, 5, 10, " "),
        " ",
        MemoryAddress.format_for_listing(listing_line.location),
        " ",
        memory_value_part,
        " ",
        listing_line.text_list
      ])

      list_next(listing_name, line_number + 1)
    end
  end

  # def list_next(listing_name, %State{} = state) do
  #   loc = Memory.first()

  #   {next_address, listing_string} = make_listing_line(loc)
  #   IO.puts(listing_string)
  #   list_next(listing_name, state, next_address)
  # end

  # def list_next(listing_name, %State{} = state, %MemoryAddress{} = address) do
  #   loc = Memory.next(address)

  #   if(loc != :"$end_of_table") do
  #     {next_address, listing_string} = make_listing_line(loc)
  #     IO.puts(listing_string)
  #     list_next(listing_name, state, next_address)
  #   end
  # end

  def make_listing_line(%State{} = state) do
    line_number = fmt_int(state.line_number, 5, 10, " ")
    address = State.get_current_location(state)
    address_part = MemoryAddress.format_for_listing(address)

    # extra_address_part =
    #   if address != address_again do
    #     " MH " <> MemoryAddress.format_for_listing(address_again)
    #   else
    #     ""
    #   end

    memory_value_part = ["  ", MemoryValue.format_for_listing(Memory.get_memory(address))]

    code_part = [
      "  ",
      format_for_listing(
        state.label_tokens,
        state.opcode_tokens,
        state.address_tokens_list,
        state.comment
      )
    ]

    {address,
     [" L: ", line_number, " A: ", address_part, " M: ", memory_value_part, " C: ", code_part]}
  end

  def make_listing_line({address, [{_address_again, value, code}]} = _location) do
    line_number = fmt_int(code.line_number, 5, 10, " ")
    address_part = MemoryAddress.format_for_listing(address)

    # extra_address_part =
    #   if address != address_again do
    #     " MH " <> MemoryAddress.format_for_listing(address_again)
    #   else
    #     ""
    #   end

    memory_value_part = ["  ", MemoryValue.format_for_listing(value)]

    code_part = ["  ", format_for_listing(code)]

    {address,
     [" L: ", line_number, " A: ", address_part, " M: ", memory_value_part, " C: ", code_part]}
  end

  def format_for_listing(%MemoryAddress{
        label: label,
        opcode: opcode,
        address: address,
        comments: comment
      }),
      do: format_for_listing(label, opcode, address, comment)

  def format_for_listing(label, opcode, address, comment) do
    if label == [] and opcode == [] and address == [[]] do
      [concat_token_values(comment)]
    else
      [
        " ",
        fmt_string(concat_token_values(label), 9),
        fmt_string(concat_token_values(opcode), 8),
        if comment != [] do
          [fmt_string(concat_list_of_token_list_values(address), 15), " "]
        else
          concat_list_of_token_list_values(address)
        end,
        concat_token_values(comment)
      ]
    end
  end

  def concat_token_values(tokens) when is_list(tokens) do
    List.flatten(tokens)
    |> Enum.map(fn {_type, value} -> string_value(value) end)
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

  def get_listing_line_number() do
    :ets.update_counter(@listing_ets, :current_line, 1)
  end
end
