defmodule LE940.Commands do
  @address_range 0..16383

  def process(%LinkEdit{} = state, commands) when is_list(commands) do
    new_commands =
      Enum.map(commands, fn command ->
        parse_and_translate_command(command)
      end)

    %{state | commands: new_commands}
  end

  defp parse_and_translate_command(command) when is_binary(command) do
    words = String.split(command, " ")
    parse_and_translate_command(hd(words), tl(words))
  end

  defp parse_and_translate_command("load", [stash_address, execution_address, path])
       when is_binary(stash_address) and is_binary(execution_address) and
              is_binary(path) do
    stash_addr = String.to_integer(stash_address, 8)
    execution_addr = String.to_integer(execution_address, 8)

    if stash_addr not in @address_range or execution_addr not in @address_range do
      raise "illegal stash #{stash_addr} or execution #{execution_addr} address"
    end

    # Ensure file exists
    if not File.exists?(path) do
      raise "No such file as #{path}"
    end

    _command = [&LE940.Loader.load/2, {stash_addr, execution_addr, path}]
  end

  defp parse_and_translate_command("load", [path])
       when is_binary(path) do
    # Ensure file exists
    if not File.exists?(path) do
      raise "No such file as #{path}"
    end

    _command = [&LE940.Loader.load/2, {path}]
  end

  # defp parse_and_translate("load", [stash_address, execution_address, path])
  #      when is_binary(stash_address) and is_binary(execution_address) and
  #             is_binary(path) do
  #   stash_addr = String.to_integer(stash_address, 8)
  #   execution_addr = String.to_integer(execution_address, 8)

  #   if stash_addr not in @address_range or execution_addr not in @address_range do
  #     raise "illegal stash #{stash_addr} or execution #{execution_addr} address"
  #   end

  #   # Ensure file exists
  #   if not File.exists?(path) do
  #     raise "No such file as #{path}"
  #   end

  #   command = [LE940.Loader.load() / 2, {stash_addr, execution_addr, file}]
  # end

  defp parse_and_translate_command("save", [start_address, path])
       when is_binary(start_address) and is_binary(path) do
    start_addr = String.to_integer(start_address, 8)

    if start_addr not in @address_range do
      raise "illegal start #{start_addr} address"
    end

    # Ensure file exists
    if not File.exists?(path) do
      raise "No such file as #{path}"
    end

    _command = [&LE940.Output.save/2, {start_addr, path}]
  end

  defp parse_and_translate_command("save", [path]) when is_binary(path) do
    # Ensure file exists
    if not File.exists?(path) do
      raise "No such file as #{path}"
    end

    _command = [&LE940.Output.save/2, {path}]
  end
end
