defmodule A940.Tokenizer do
  defstruct line_number: 1,
            tokens: []

  import Bitwise

  @white_space ~r/^\h+/
  @decimal_number ~r/^\d+/
  @octal_number ~r/^[0-7]+(B[0-7])?/
  @symbol ~r/^[A-Z0-9]+/
  @string_6 ~r/^'[^']{1,4}'/
  @string_8 ~r/^"[^"]+"/
  @delimiter ~r/^[-+*\/,()=.$_]/
  @special ~r/^[:;<>?[\]!%&@]/
  @illegal ~r/^[#^]+/

  def tokens(line_number, line) when is_integer(line_number) and is_binary(line) do
    cond do
      String.length(line) == 0 ->
        %__MODULE__{line_number: line_number, tokens: [{:eol, ""}]}

      String.starts_with?(line, "*") ->
        %__MODULE__{
          line_number: line_number,
          tokens: [{:comment, String.slice(line, 1..-1//1)}]
        }

      true ->
        %__MODULE__{line_number: line_number, tokens: all_tokens(line, [])}
    end
  end

  def all_tokens(line, token_list) when line == "", do: Enum.reverse(token_list)

  def all_tokens(line, token_list) do
    # white_space = ~r/^\h+/
    # decimal_number = ~r/^\d+/
    # octal_number = ~r/^[0-7]+(B[0-7])?/
    # symbol = ~r/^[A-Z0-9]+/
    # string_6 = ~r/^'[^']{1,4}'/
    # string_8 = ~r/^"[^"]+"/
    # delimiter = ~r/^[-+*\/,()=.$_]/
    # special = ~r/^[:;<>?[\]]/
    # illegal = ~r/^[!#%&@^]+/
    white_space = Regex.run(@white_space, line)
    decimal_number = Regex.run(@decimal_number, line)
    octal_number = Regex.run(@octal_number, line)
    symbol = Regex.run(@symbol, line)
    string_6 = Regex.run(@string_6, line)
    string_8 = Regex.run(@string_8, line)
    delimiter = Regex.run(@delimiter, line)
    special = Regex.run(@special, line)
    illegal = Regex.run(@illegal, line)

    {token_type, token_value, match} =
      cond do
        white_space != nil ->
          {:spaces, hd(white_space), hd(white_space)}

        decimal_number != nil ->
          {:number, String.to_integer(hd(decimal_number)), hd(decimal_number)}

        octal_number != nil ->
          {:number, decode_octal(hd(octal_number)), hd(octal_number)}

        symbol != nil ->
          {:symbol, hd(symbol), hd(symbol)}

        string_6 != nil ->
          {:string_6, decode_string_6(hd(string_6)), hd(string_6)}

        string_8 != nil ->
          {:string_8, decode_string_8(hd(string_8)), hd(string_8)}

        delimiter != nil ->
          {:delimiter, hd(delimiter), hd(delimiter)}

        special != nil ->
          {:special, hd(special), hd(special)}

        illegal != nil ->
          {:illegal, hd(illegal), hd(illegal)}

        true ->
          {:fail, 0, 0}
      end

    new_token = {token_type, token_value}
    size_of_match = String.length(match)
    new_line = String.slice(line, size_of_match..-1//1)
    all_tokens(new_line, [new_token | token_list])
  end

  def decode_octal(oct) do
    value =
      cond do
        String.contains?(oct, "B") -> decode_scaled_octal(oct)
        true -> String.to_integer(oct, 8)
      end

    value &&& 0o77777777
  end

  defp decode_scaled_octal(oct) do
    oct_length = String.length(oct)
    base = String.slice(oct, 0..(oct_length - 3)) |> String.to_integer(8)
    shift = String.slice(oct, (oct_length - 1)..-1//1) |> String.to_integer()
    base <<< (3 * shift)
  end

  defp decode_string_6(_v), do: 0
  defp decode_string_8(v), do: v
end
