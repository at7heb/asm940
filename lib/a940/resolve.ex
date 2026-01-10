defmodule A940.Resolve do
  alias A940.Expression
  alias A940.{Memory, MemoryAddress, MemoryValue, State}

  def resolve_symbols(%State{} = state) do
    scan_symbols(state)
    resolve_literals(state)
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
      |> dbg

    {"unique literal values", uniq_literal_values} |> dbg

    {new_state, value_address_map} =
      Enum.reduce(uniq_literal_values, {state, %{}}, fn literal_value,
                                                        {temporary_state, va_map} ->
        literal_value |> dbg

        {new_state, %MemoryAddress{} = address} =
          A940.Directive.literal_data(temporary_state, literal_value)

        {new_state, Map.put(va_map, literal_value, address)}
      end)

    # Enum.each()
    value_address_map |> dbg
    new_state
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
    literal_expression |> dbg
    literal_value = Expression.evaluate(state, literal_expression) |> dbg
    rv = {first_address, literal_value}
    {"evaluate a literal:", rv} |> dbg
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

    values =
      Enum.map(symbol_names, fn name ->
        Map.get(state.symbols, name)
      end)

    unknowns = Enum.filter(values, fn value -> value.expression_tokens != [] end)

    if unknowns != [] do
      raise "some undefined symbols"
    end

    state
  end
end
