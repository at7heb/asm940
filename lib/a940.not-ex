defmodule A940 do
  @moduledoc """
  SDS-940 Assembler Pass 1 Implementation.
  Handles comment removal, macro expansion, and basic syntax error flagging.
  """

  @valid_opcodes MapSet.new([
                   "LDA",
                   "STA",
                   "LDB",
                   "STB",
                   "LDX",
                   "STX",
                   "EAX",
                   "XMA",
                   "MIW",
                   "WIM",
                   "MIY",
                   "YIM",
                   "ADD",
                   "ADC",
                   "ADM",
                   "MIN",
                   # Added likely logical instructions
                   "SUB",
                   "SUC",
                   "MUL",
                   "DIV",
                   "ETR",
                   "IOR",
                   "XOR",
                   # Added likely branch instructions
                   "BRU",
                   "BRI",
                   "BDX",
                   # Pseudo-ops
                   "MACRO",
                   "LMACRO",
                   "ENDM",
                   "NARG",
                   "NCHR",
                   "ORG",
                   "EQU",
                   "END",
                   "DS",
                   "DC"
                 ])

  def pass1 do
    lines = IO.stream() |> Enum.map(&String.trim_trailing(&1, "\n"))
    process(lines) |> Enum.each(&IO.puts/1)
  end

  def pass1(path) when is_binary(path) do
    lines = File.read!(path) |> String.split("\n") |> Enum.map(&String.trim_trailing(&1, "\n"))
    process(lines) |> Enum.each(&IO.puts/1)
  end

  def pass1(lines) when is_list(lines) do
    process(lines)
  end

  defp process(lines) do
    process_lines(lines, %{}, nil, [], [])
  end

  defp process_lines([], _macros, nil, _output, acc) do
    Enum.reverse(acc)
  end

  defp process_lines([], _macros, _current_macro, _output, acc) do
    Enum.reverse(["!! Unterminated macro definition" | acc])
  end

  defp process_lines([line | tail], macros, current_macro, output, acc) do
    case parse_line(line) do
      {:comment, _} ->
        process_lines(tail, macros, current_macro, output, acc)

      {:error, _} ->
        process_lines(tail, macros, current_macro, output, ["!!" <> line | acc])

      {:ok, parsed = %{opcode: opcode}} ->
        if current_macro do
          if opcode == "ENDM" do
            macro_name = current_macro.name
            new_macros = Map.put(macros, macro_name, current_macro)
            process_lines(tail, new_macros, nil, [], acc)
          else
            updated_body = [
              reconstruct_line(parsed.label, opcode, parsed.operand) | current_macro.body
            ]

            updated_macro = %{current_macro | body: updated_body}
            process_lines(tail, macros, updated_macro, output, acc)
          end
        else
          case opcode do
            op when op in ["MACRO", "LMACRO"] ->
              if parsed.label == "" do
                process_lines(tail, macros, current_macro, output, ["!!" <> line | acc])
              else
                # Simple parsing of operand for dummy prefix (e.g., "D" or "D,G,4")
                [dummies | rest] = String.split(parsed.operand, ",")
                generated = if length(rest) > 0, do: hd(rest), else: ""
                max_gen = if length(rest) > 1, do: List.last(rest), else: ""

                current_macro = %{
                  name: parsed.label,
                  dummies: dummies,
                  generated: generated,
                  max_gen: max_gen,
                  lmacro: op == "LMACRO",
                  body: []
                }

                process_lines(tail, macros, current_macro, output, acc)
              end

            op when is_map_key(macros, op) ->
              macro = macros[op]
              args = parse_args(parsed.operand)
              label_arg = if parsed.label != "", do: parsed.label, else: ""
              args = [label_arg | args]
              # Body was reversed
              expanded = expand_body(macro.body, macro.dummies, args) |> Enum.reverse()
              # Recursively process expanded lines for nested macros
              expanded_processed = process(expanded)
              process_lines(tail, macros, current_macro, output, expanded_processed ++ acc)

            op ->
              if MapSet.member?(@valid_opcodes, op) or String.match?(op, ~r/^[0-7]+$/) do
                clean_line = reconstruct_line(parsed.label, op, parsed.operand)
                process_lines(tail, macros, current_macro, output, [clean_line | acc])
              else
                process_lines(tail, macros, current_macro, output, ["!!" <> line | acc])
              end
          end
        end
    end
  end

  defp parse_line(line) do
    line = String.trim(line)

    if line == "" or String.starts_with?(line, "*") do
      {:comment, line}
    else
      # Regex to parse label, opcode (with optional -*), operand, comment
      case Regex.run(
             ~r/^(\$?[A-Z0-9]*)?\s+([A-Z0-9]+\*?)\s*([^; \s] * )? \s* (.*)$/x,
             line
           ) do
        [_, label, opcode, operand, comment] ->
          {:ok,
           %{
             label: label || "",
             opcode: opcode || "",
             operand: operand || "",
             comment: comment,
             original: line
           }}

        _ ->
          {:error, line}
      end
    end
  end

  defp reconstruct_line(label, opcode, operand) do
    parts = [label, opcode, operand] |> Enum.reject(&(&1 == ""))
    Enum.join(parts, " | ")
  end

  defp parse_args(operand) do
    # Simple comma split, assuming no nested parens/quotes for simplicity
    if operand == "", do: [], else: String.split(operand, ",")
  end

  defp expand_body(body, dummies, args) do
    Enum.map(body, &expand_line(&1, dummies, args))
  end

  defp expand_line(line, dummies, args) do
    # Basic replacement for D(n)
    Regex.replace(~r/ #{dummies} \ ( ( \d+ ) \ ) /x, line, fn _, num ->
      i = String.to_integer(num)
      if i < length(args), do: Enum.at(args, i), else: "?"
    end)
  end
end
