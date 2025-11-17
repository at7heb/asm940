defmodule A940.Macro do
  alias A940.{State, Tokens}

  defstruct macro_name: "",
            starting_line_number: 0,
            ending_line_number: 0,
            dummy_name: "",
            actual_arguments: [],
            generated_name: "",
            generated_count: 0,
            generated_index: 0,
            level: 0

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

    %{state | macros: Map.put(state.macros, mcro.macro_name, mcro)}
  end

  # the endm function must pop the tokens list
  def endm(%State{} = state, :first_call), do: state

  def endm(%State{} = state, :second_call) do
    if state.current_macro == nil,
      do: raise("ENDM without matching macro call line #{state.line_number}")

    # pop the tokens range and the current macro state
    A940.Tokens.pop_range()
    # state.macro_stack |> dbg
    [current | stack] = state.macro_stack
    %{state | current_macro: current, macro_stack: stack}
  end

  # the call must push the tokens lines, parse the arguments, and arrange for the dummy and generated symbol processing
  # as the macro body tokens are fetched for assembly.
  def call(%State{} = state, :first_call), do: state

  def call(%State{} = state, :second_call) do
    [{:symbol, macro_name}] = state.opcode_tokens
    mcro = Map.get(state.macros, macro_name)

    if nil == mcro,
      do: raise("MH-Macro called but cannot get macro state line #{state.line_number}")

    A940.Tokens.push_range(mcro.starting_line_number, mcro.ending_line_number)

    macro_state =
      case mcro.dummy_name do
        "" -> mcro
        _ -> %{mcro | actual_arguments: get_macro_arguments(state)}
      end

    new_stack = [state.current_macro | state.macro_stack]

    %{state | current_macro: macro_state, macro_stack: new_stack}
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
        nil |> dbg
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
    {mcro, dummy_tokens} |> dbg

    case dummy_tokens do
      [[{:symbol, dummy}], [{:symbol, generated}], [gen_count_expression]] ->
        gen_count = A940.Expression.evaluate(state, gen_count_expression)
        %{mcro | dummy_name: dummy, generated_name: generated, generated_count: gen_count}

      [[{:symbol, dummy}]] ->
        %{mcro | dummy_name: dummy, generated_name: "", generated_count: 0}

      [[]] ->
        %{mcro | dummy_name: "", generated_name: "", generated_count: 0}
    end
    |> dbg
  end

  def get_macro_arguments(%State{} = state) do
    arguments = state.address_tokens_list
    arguments |> dbg()
    # new_mcro = %{state.current_macro | actual_arguments: arguments}
    # %{state | current_macro: new_mcro}
  end

  # empty tokens
  def expand_tokens([], _state), do: []

  def expand_tokens(tokens, %State{current_macro: nil} = _state), do: tokens

  def expand_tokens(tokens, %State{current_macro: mcro} = state) do
  end

  def has_address(%__MODULE__{dummy_name: ""} = _mcro), do: false
  def has_address(%__MODULE__{} = _mcro), do: true
  def get_name(%__MODULE__{} = mcro), do: mcro.macro_name
end
