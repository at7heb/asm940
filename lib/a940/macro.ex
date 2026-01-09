defmodule A940.Macro do
  alias A940.{Listing, MemoryAddress, State, Tokens, Tokenizer}

  defstruct macro_name: "",
            starting_line_number: 0,
            ending_line_number: 0,
            dummy_name: "",
            actual_arguments: [],
            generated_name: "",
            generated_count: 0,
            generated_index: 0,
            level: 0

  @debug_line nil

  def macro(%State{} = state, :first_call), do: state

  def macro(%State{} = state, :second_call) do
    dummy_tokens = state.address_tokens_list

    mcro =
      case state.label_tokens do
        [{:symbol, macro_name}] ->
          %__MODULE__{macro_name: macro_name, starting_line_number: state.line_number + 1}

        _ ->
          raise "Macro must have symbol in label field line #{state.line_number}"
      end
      |> find_matching_endm()
      |> process_dummy_tokens(state, dummy_tokens)

    A940.Op.update_opcode_table(mcro)
    Listing.add_line_listing(state, MemoryAddress.new_dummy(0, 0))

    %{state | macros: Map.put(state.macros, mcro.macro_name, mcro)}
  end

  # the endm function must pop the tokens list
  def endm(%State{} = state, :first_call), do: state

  def endm(%State{} = state, :second_call) do
    if state.current_macro == nil,
      do: raise("ENDM without matching macro call line #{state.line_number}")

    macro_name = state.current_macro.macro_name
    new_macro = update_for_generated_symbols(state, macro_name)
    new_macro_map = Map.put(state.macros, macro_name, new_macro)
    # pop the tokens range and the current macro state
    A940.Tokens.pop_range()
    # state.macro_stack |> dbg
    Listing.add_line_listing(state, MemoryAddress.new_dummy(0, 0))
    [current | stack] = state.macro_stack
    %{state | current_macro: current, macro_stack: stack, macros: new_macro_map}
  end

  def update_for_generated_symbols(%State{} = state, macro_name) do
    mcro = Map.get(state.macros, macro_name)
    new_index = mcro.generated_index + mcro.generated_count
    %{mcro | generated_index: new_index}
  end

  def narg(%State{} = state, :first_call), do: state

  def narg(%State{} = state, :second_call) do
    val = length(state.current_macro.actual_arguments)
    # state, symbol_name, value, ?, relocation, exported
    Listing.add_line_listing(state, MemoryAddress.new_dummy(0, 0))

    State.redefine_symbol_value(
      state,
      A940.Pass1.label_name(state.label_tokens),
      val,
      0,
      false
    )
  end

  def nchar(%State{} = state, :first_call), do: state

  def nchar(%State{} = state, :second_call) do
    # {:nchr, state.label_tokens, state.address_tokens_list} |> dbg

    if length(state.address_tokens_list) != 1 do
      raise "NCHAR needs exactly one address field element line #{state.line_number}"
    end

    if length(state.label_tokens) != 1 do
      raise "NCHAR needs a non-global label line #{state.line_number}"
    end

    val = String.length(process_concatenation(hd(state.address_tokens_list), state))
    # {:nchr, val} |> dbg
    Listing.add_line_listing(state, MemoryAddress.new_dummy(0, 0))

    State.redefine_symbol_value(
      state,
      A940.Pass1.label_name(state.label_tokens),
      val,
      0,
      false
    )
  end

  # the call must push the tokens lines, parse the arguments, and arrange for the dummy and generated symbol processing
  # as the macro body tokens are fetched for assembly.
  def call(%State{} = state, :first_call), do: state

  def call(%State{} = state, :second_call) do
    [{:symbol, macro_name}] = state.opcode_tokens
    # {macro_name, Map.keys(state.macros)} |> dbg
    mcro = Map.get(state.macros, macro_name)

    if nil == mcro,
      do: raise("MH-Macro called but cannot get macro state line #{state.line_number}")

    A940.Tokens.push_range(mcro.starting_line_number, mcro.ending_line_number)

    macro_state =
      case mcro.dummy_name do
        "" -> mcro
        _ -> %{mcro | actual_arguments: remove_grouping_parens(state.address_tokens_list)}
      end

    if state.line_number == @debug_line do
      {state.address_tokens_list, remove_grouping_parens(state.address_tokens_list)}
    end

    new_stack = [state.current_macro | state.macro_stack]
    Listing.add_line_listing(state, MemoryAddress.new_dummy(0, 0))

    %{state | current_macro: macro_state, macro_stack: new_stack}
  end

  def remove_grouping_parens([[tokens_list]]) when is_list(tokens_list) do
    remove_grouping_parens([tokens_list])
  end

  def remove_grouping_parens(tokens_list) when is_list(tokens_list) do
    Enum.map(tokens_list, &remove_grouping_parens_one_field(&1))
  end

  def remove_grouping_parens_one_field([field_list]) when is_list(field_list) do
    remove_grouping_parens_one_field(field_list)
  end

  def remove_grouping_parens_one_field(field_list) when is_list(field_list) do
    # field_list |> dbg
    first_token = Enum.at(field_list, 0)
    last_token = Enum.at(field_list, -1)

    if first_token == {:delimiter, "("} and last_token == {:delimiter, ")"} do
      Enum.slice(field_list, 1..-2//1)
    else
      field_list
    end

    # |> dbg
  end

  def expand_dummy(%State{current_macro: nil} = _state, tokens_list) when is_list(tokens_list),
    do: tokens_list

  def expand_dummy(%State{} = state, tokens_list) when is_list(tokens_list) do
    mcro = state.current_macro

    case mcro.dummy_name do
      nil ->
        tokens_list

      "" ->
        tokens_list

      # there is a dummy name, so in the dummy name must be expanded throught the statement
      _ ->
        nil
    end
  end

  def find_matching_endm(%__MODULE__{} = mcro) do
    tokens = Tokens.next()

    if tuple_size(tokens) == 2 do
      raise "Unterminated MACRO directive"
    end

    {:ok, current, tokens} = tokens

    case Enum.slice(tokens, 0..1) do
      [{:spaces, " "}, {:symbol, "ENDM"}] ->
        if mcro.level == 0 do
          %{mcro | ending_line_number: current}
        else
          find_matching_endm(%{mcro | level: mcro.level - 1})
        end

      [{:symbol, _}, {:spaces, " "}, {:symbol, "MACRO"}] ->
        find_matching_endm(%{mcro | level: mcro.level + 1})

      _ ->
        find_matching_endm(mcro)
    end
  end

  def process_dummy_tokens(%__MODULE__{} = mcro, %State{} = state, dummy_tokens) do
    # {mcro, dummy_tokens} |> dbg

    case dummy_tokens do
      [[{:symbol, dummy}], [{:symbol, generated}], [gen_count_expression]] ->
        {gen_count, gen_relocation} = A940.Expression.evaluate(state, [gen_count_expression])

        if gen_relocation != 0 or gen_count < 1,
          do: raise("Macro generated symbol count >=1 and absolute line #{state.line_number}")

        %{mcro | dummy_name: dummy, generated_name: generated, generated_count: gen_count}

      [[{:symbol, dummy}]] ->
        %{mcro | dummy_name: dummy, generated_name: "", generated_count: 0}

      [[]] ->
        %{mcro | dummy_name: "", generated_name: "", generated_count: 0}
    end

    # |> dbg
  end

  def expand_macro_tokens([], _state), do: []

  def expand_macro_tokens(tokens, %State{current_macro: nil} = _state), do: tokens

  def expand_macro_tokens(tokens, %State{current_macro: mcro} = state) do
    # look for dummy symbol followed by "("; then look for generated symbol followed by "("
    if mcro.dummy_name == "" do
      tokens
    else
      find_process_macro_symbols(tokens, [], state)
      |> find_process_concatenation(state)

      # |> List.flatten() |> Enum.reverse()
    end

    # state isn't changed; just the tokens
  end

  def find_process_macro_symbols([], new_tokens_list, %State{} = _state),
    do: new_tokens_list |> Enum.reverse() |> List.flatten()

  def find_process_macro_symbols(tokens, new_tokens_list, %State{} = state)
      when is_list(tokens) do
    mcro = state.current_macro
    dummy_symbol_name = mcro.dummy_name
    generated_symbol_name = mcro.generated_name

    case Enum.slice(tokens, 0..1) do
      [{:symbol, ^dummy_symbol_name}, {:delimiter, "("}] ->
        {index_tokens, remaining_tokens} =
          A940.Address.get_balanced_tokens(Enum.slice(tokens, 2..-1//1))

        index_tokens = find_process_macro_symbols(index_tokens, [], state)
        {index, 0} = A940.Expression.evaluate(state, index_tokens)
        new_tokens = Enum.slice(mcro.actual_arguments, (index - 1)..(index - 1))
        find_process_macro_symbols(remaining_tokens, [new_tokens | new_tokens_list], state)

      [{:symbol, ^generated_symbol_name}, {:delimiter, "("}] ->
        # almost the same, but return {:symbol, ...}
        {index_tokens, remaining_tokens} =
          A940.Address.get_balanced_tokens(Enum.slice(tokens, 2..-1//1))

        index_tokens = find_process_macro_symbols(index_tokens, [], state)
        {index, 0} = A940.Expression.evaluate(state, index_tokens)
        index = index + mcro.generated_index
        new_token = {:symbol, generated_symbol_name <> Integer.to_string(index)}
        find_process_macro_symbols(remaining_tokens, [new_token | new_tokens_list], state)

      _ ->
        find_process_macro_symbols(tl(tokens), [hd(tokens) | new_tokens_list], state)
    end
  end

  def find_process_concatenation(tokens, %State{} = state) when is_list(tokens) do
    if find_concatenation(tokens) do
      process_concatenation(tokens, state)
      |> A940.Pass0.make_tokens_for_one_line(state.line_number)
    else
      tokens
    end
  end

  def find_concatenation(tokens) when is_list(tokens) do
    Enum.any?(tokens, &Tokenizer.is_concatenation?(&1))
  end

  def process_concatenation(tokens, %State{} = state) when is_list(tokens) do
    if state.line_number == @debug_line do
      tokens |> dbg
    end

    tokens
    |> List.flatten()
    |> Enum.filter(&Tokenizer.is_not_concatenation?(&1))
    |> Enum.map(fn token -> Tokenizer.token_value(token) end)
    |> Enum.join()

    # |> dbg
  end

  def has_address(%__MODULE__{dummy_name: ""} = _mcro), do: false
  def has_address(%__MODULE__{} = _mcro), do: true
  def get_name(%__MODULE__{} = mcro), do: mcro.macro_name
end
