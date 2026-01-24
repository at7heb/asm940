defmodule A940.Resolve do
  alias A940.{Expression, Memory, MemoryAddress, MemoryValue, State}

  def resolve_symbols(%State{} = state) do
    scan_symbols(state)
    |> resolve_literals()
  end

  def resolve_literals(%State{} = state) do
    # need to do these steps:
    #  1. find the literals and where each is used
    #  2. evaluate the literals, keeping where used
    #  3. get the unique list of literal values
    #  4. add the literal values to memory and save where they are
    #     as a map of value --> address
    #  5. go back to update the %MemoryValue where the literal is used
    memory = all_memory()

    has_literals =
      Enum.filter(memory, fn {_first_address,
                              [
                                {%MemoryAddress{} = _address, %MemoryValue{} = value,
                                 %MemoryAddress{} = _extra_address}
                              ]} = _mem ->
        value.address_expression != [] and hd(value.address_expression) == {:delimiter, "="}
      end)

    IO.puts("#{length(memory)} memory entries")
    IO.puts("#{length(has_literals)} of memory have literal addresses")

    evaluated_addresses_and_literals =
      Enum.map(has_literals, &evaluate_a_literal(state, &1))

    uniq_literal_values =
      Enum.map(evaluated_addresses_and_literals, &elem(&1, 1))
      |> Enum.sort()
      |> Enum.uniq()

    # {"unique literal values", uniq_literal_values} |> dbg

    {new_state, value_address_map} =
      Enum.reduce(uniq_literal_values, {state, %{}}, fn literal_value,
                                                        {temporary_state, va_map} ->
        # literal_value |> dbg

        {new_state, %MemoryAddress{} = address} =
          A940.Directive.literal_data(temporary_state, literal_value)

        {new_state, Map.put(va_map, literal_value, address)}
      end)

    # Enum.each()
    # value_address_map |> dbg

    # evaluated_addresses_and_literals tells where in the assembled code each literal value
    # .  is used.
    # value_address_map tells where the literal of the given value is stored in memory.
    update_literal_references(state, evaluated_addresses_and_literals, value_address_map)
    new_state
  end

  def update_literal_references(
        %State{} = _state,
        evaluated_addresses_and_literals,
        value_address_map
      )
      when is_list(evaluated_addresses_and_literals) and is_map(value_address_map) do
    Enum.each(
      evaluated_addresses_and_literals,
      fn {%MemoryAddress{} = address_of_use, {_value, _relocation} = literal_value} ->
        address_of_literal = Map.get(value_address_map, literal_value)
        Memory.set_address(address_of_use, address_of_literal)
      end
    )
  end

  def evaluate_a_literal(
        state,
        {first_address,
         [
           {%MemoryAddress{} = _address, %MemoryValue{} = value,
            %MemoryAddress{} = _extra_address}
         ]}
      ) do
    [{:delimiter, "="} | literal_expression] = value.address_expression
    # literal_expression |> dbg
    literal_value = Expression.evaluate(state, literal_expression)
    rv = {first_address, literal_value}
    # {"evaluate a literal:", rv} |> dbg
    rv
  end

  def extract_literal_value(
        {_first_address,
         [
           {%MemoryAddress{} = _address, %MemoryValue{} = value,
            %MemoryAddress{} = _extra_address}
         ]}
      ) do
    value
  end

  def all_memory() do
    first = Memory.first()
    all_memory([first]) |> Enum.reverse()
  end

  def all_memory(partial) when is_list(partial) do
    first = hd(partial)
    {first_address, [_]} = first
    next = Memory.next(first_address)

    case next do
      :"$end_of_table" ->
        partial

      _ ->
        if length(partial) > 10_000, do: raise("looping #{inspect(next)}")
        all_memory([next | partial])
    end
  end

  def scan_symbols(%State{} = state) do
    symbol_names = Map.keys(state.symbols)

    unknown_name_and_values =
      Enum.map(symbol_names, fn name ->
        {name, Map.get(state.symbols, name)}
      end)
      |> Enum.filter(fn {_name, value} -> value.expression_tokens != [] end)

    {new_state, new_count} =
      Enum.reduce(
        unknown_name_and_values,
        {state, 0},
        fn {name, value}, {state, count} ->
          {flag, new_state} = try_to_resolve_symbol(state, name, value)

          cond do
            flag == :defined ->
              # {"defined #{name}", value} |> dbg
              {new_state, count + 1}

            flag == :undefined ->
              {state, count}

            true ->
              raise "unknown return from try_to_resolve_symbol()"
          end
        end
      )

    if new_count == 0 do
      # "done with resolving symbols" |> dbg
      new_state
    else
      scan_symbols(new_state)
    end
  end

  def try_to_resolve_symbol(%State{} = state, name, %A940.Address{} = address)
      when is_binary(name) do
    value = Expression.evaluate(state, address.expression_tokens)

    cond do
      is_tuple(value) and tuple_size(value) == 2 and is_integer(elem(value, 0)) and
          is_integer(elem(value, 1)) ->
        {number, relocation} = value

        {flag, new_state} =
          {:defined,
           State.redefine_symbol_value(state, name, number, relocation, false, 0o77777777)}

        # Map.get(state.symbols, name) |> dbg
        # Map.get(new_state.symbols, name) |> dbg
        {flag, new_state}

      true ->
        {:undefined, state}
    end
  end

  def update_symbol_references(%State{} = state) do
    update_symbol_references(state, Memory.first())
  end

  def update_symbol_references(%State{} = state, address_and_content) do
    {address0, [{address1, word, _address2}]} = address_and_content
    if address0 != address1, do: raise("address mismatch in update_symbol_references")
    # address_and_content |> dbg
    new_state = update_one_symbol_reference(state, word, address0)

    next = Memory.next(address0)

    if next == :"$end_of_table" do
      new_state
    else
      update_symbol_references(new_state, next)
    end
  end

  def update_one_symbol_reference(
        %State{} = state,
        %MemoryValue{address_expression: []} = _value,
        %MemoryAddress{} = _address
      ) do
    state
  end

  def update_one_symbol_reference(
        %State{} = state,
        %MemoryValue{address_expression: expr} = _value,
        %MemoryAddress{} = address
      ) do
    # {value, address} |> dbg
    expr_value = Expression.evaluate(state, expr)
    # {address, expr, expr_value} |> dbg

    cond do
      is_tuple(expr_value) and is_integer(elem(expr_value, 0)) and is_integer(elem(expr_value, 1)) ->
        if elem(expr_value, 0) == 24041 do
          IO.puts(
            "merging address #{inspect(expr)} to address #{Integer.to_string(address.location, 8)}B"
          )
        end

        Memory.merge_masked(address, expr_value)

      true ->
        nil
    end

    # memory updates don't change state; return it unchanged.
    state
  end
end
