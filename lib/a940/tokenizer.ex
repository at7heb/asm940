defmodule A940.Tokenizer do
  import Bitwise

  @white_space ~r/^\h+/
  # @number ~r/^([-+]?\d+)/
  @number ~r/^\d+/
  @decimal_number ~r/^(\d+)(D)([-+*\/,()=.$_" ]|$)/
  # @decimal_number ~r/^([-+]?\d+)(D)([-+*\/,()=.$_" ]|$)/
  @octal_number ~r/^([0-7]+)B([0-7]?)([-+*\/,()=.$_"! ]|$)/
  # @octal_number ~r/^([-+]?[0-7]+)B([0-7]?)([-+*\/,()=.$_" ]|$)/
  @symbol ~r/^[A-Z0-9:]+/
  @string_6 ~r/^'([^']{0,4})'/
  @string_long ~r/^'([^']{5,})'/
  @delimiter_diagraphs ~r/^(>=)|^(<=)|^(\.&)/
  @delimiter ~r/^[-+*\/,()=.$_"'←\\]/
  @special ~r/^[;<>?[\]!%&@]/
  @illegal ~r/^[#^]+/

  @eol_tuple {:eol, ""}

  def tokens(line_number, line, flags) when is_integer(line_number) and is_binary(line) do
    # IO.puts("-------------Creating tokens for line #{line_number}-------------")

    cond do
      String.starts_with?(line, "*") ->
        [{:comment, String.slice(line, 1..-1//1)}, @eol_tuple]

      true ->
        all_tokens(line, [], flags, line_number)
    end
  end

  def all_tokens(line, token_list, _flags, _line_number) when line == "",
    do: Enum.reverse([@eol_tuple | token_list])

  def all_tokens(line, token_list, flags, line_number) do
    white_space = Regex.run(@white_space, line)
    decimal_number = Regex.run(@decimal_number, line)
    number = Regex.run(@number, line)
    octal_number = Regex.run(@octal_number, line)
    symbol = Regex.run(@symbol, line)
    string_6 = Regex.run(@string_6, line)
    string_long = Regex.run(@string_long, line)
    delimiter_digraphs = Regex.run(@delimiter_diagraphs, line)
    delimiter = Regex.run(@delimiter, line)
    special = Regex.run(@special, line)
    illegal = Regex.run(@illegal, line)

    # if line_number == 78 do
    #   IO.puts("tokens: |#{line}|")
    # end

    {token_type, token_value, match} =
      cond do
        white_space != nil ->
          {:spaces, " ", hd(white_space)}

        octal_number != nil ->
          # octal_number |> dbg
          number_text = hd(octal_number)

          number_text =
            cond do
              # number_text is all a number
              String.ends_with?(number_text, ["B", "0", "1", "2", "3", "4", "5", "6", "7"]) ->
                number_text

              # number_text has punctuation after it; take it away from the matching string
              true ->
                String.slice(number_text, 0..-2//1)
            end

          {:number, decode_octal(octal_number), number_text}

        decimal_number != nil ->
          # decimal_number |> dbg
          {:number, decode_decimal(decimal_number), hd(decimal_number)}

        symbol != nil ->
          cond do
            String.contains?(hd(symbol), ~w/A B C D E F G H I J K L M N O P Q R S T U V W X Y Z/) ->
              {:symbol, hd(symbol), hd(symbol)}

            hd(symbol) == ":" ->
              {:delimiter, ":", ":"}

            true ->
              {:number, decode_number(hd(number), flags), hd(number)}
          end

        number != nil ->
          {line, number} |> dbg
          {:number, decode_number(hd(number), flags), hd(number)}

        # symbol != nil ->
        #   {:symbol, hd(symbol), hd(symbol)}

        # be sure string_6 check is before delimiter because
        # ' is both string_6 delimiter and a delimiter
        # unmatched ' in a comment will match the delimiter
        string_6 != nil ->
          {:string_6, decode_string_6(hd(tl(string_6))), hd(string_6)}

        string_long != nil ->
          {:string_long, hd(tl(string_long)), hd(string_long)}

        delimiter_digraphs != nil ->
          {:delimiter, hd(delimiter_digraphs), hd(delimiter_digraphs)}

        delimiter != nil ->
          {:delimiter, hd(delimiter), hd(delimiter)}

        special != nil ->
          {:special, hd(special), hd(special)}

        illegal != nil ->
          {:illegal, hd(illegal), hd(illegal)}

        true ->
          {:fail, line, 0} |> dbg
      end

    new_token = {token_type, token_value}
    size_of_match = String.length(match)
    new_line = String.slice(line, size_of_match..-1//1)
    all_tokens(new_line, [new_token | token_list], flags, line_number)
  end

  def decode_number(number, flags),
    do: String.to_integer(number, flags.default_base) &&& 0o77777777

  def decode_decimal(dec), do: String.to_integer(Enum.at(dec, 1)) &&& 0o77777777

  def decode_octal(oct) do
    # oct |> dbg
    value = String.to_integer(Enum.at(oct, 1), 8)
    scale_text = Enum.at(oct, 2, "0")
    scale = if scale_text != "", do: String.to_integer(scale_text), else: 0

    value <<< (3 * scale) &&& 0o77777777
  end

  @character_code_minimum String.to_charlist(" ") |> hd()
  @character_code_maximum String.to_charlist("_") |> hd()
  defp decode_string_6(v) do
    rv =
      String.to_charlist(v)
      |> Enum.reduce(0, fn char, val ->
        actual =
          if char >= @character_code_minimum and char <= @character_code_maximum,
            do: char - 32,
            else: 0o77777777

        accumulator = val <<< 6 ||| actual
        {:string6, actual, accumulator}
        accumulator
      end)

    {rv, v}
  end

  def decode_string_8(v) do
    String.to_charlist(v)
    |> Enum.map(fn ch -> ch - 32 &&& 0o177 end)
    |> Enum.chunk_every(3, 3, [0, 0])
    |> Enum.map(fn [h, m, l] -> h <<< 16 ||| m <<< 8 ||| l end)
  end

  def is_concatenation?({:delimiter, ".&"} = _token) do
    # dbg(token)
    true
  end

  def is_concatenation?(_token) do
    # dbg(token)
    false
  end

  def is_not_concatenation?(token), do: not is_concatenation?(token)

  def token_value({:number, _value, text}), do: text
  def token_value({:number, value}), do: "#{value}"
  def token_value({_, text}), do: text
end
