defmodule LinkEdit do
  defstruct(
    memory: %{},
    symbols: %{},
    opdefs: %{},
    memory_lc: nil,
    relocation_lc: nil,
    load_commands: [],
    save_command: []
  )

  alias LE940.{Commands, Resolver, Output}

  @moduledoc """
  handle link edit control language
  There are two commands, both with two variations:
  load stash-address execution-address file
  load file
  save starting-address file
  save file

  this is someone opinionated in that it assumes an overlay structure, like for the 940 BASIC
  or SNOBOL3 systems.

  Both stash-address and execution-address are required, even if they are the same
  The first load command must specify the two addresses. If the next file is to be loaded
  immediately after the current file, the addresses are not necessary and the file will be
  loaded as you would expect.

  The phases are
  * load all the files, relocating the instructions and data as well as the symbol values.
  * resolve symbol values, e.g. "AAA EQU XTRNL1-XTRNL2"
  * resolve expression references, e.g. " DATA XTRNL1-XTRNL2
  * output the save file
  """

  def new, do: %__MODULE__{}

  def le() do
    IO.puts("Enter commands, one per line (limit: 999,999 lines)")

    Enum.reduce_while(1..999_999, [], fn _linenumber, command_list ->
      line = IO.read(:line)

      case line do
        :eof ->
          {:halt, command_list}

        "\n" ->
          if hd(command_list) == "",
            do: {:halt, tl(command_list)},
            else: {:cont, ["" | command_list]}

        {:error, reason} ->
          raise "IO.read problem: #{reason}!"

        _ ->
          {:cont, [String.trim(line) | command_list]}
      end
    end)
    |> Enum.filter(&(&1 != ""))
    |> Enum.reverse()
    |> le()
  end

  def le(commands) do
    state =
      Commands.process(new(), commands)

    _new_state =
      Enum.reduce(state.load_commands, state, fn [fun, parms] = _command, state ->
        fun.(state, parms)
      end)
      |> dbg
      |> Resolver.process()
      |> Output.process()
  end
end
