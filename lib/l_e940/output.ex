defmodule LE940.Output do
  def process(%LinkEdit{save_command: []} = state) do
    raise "pretty useless to waste so much energy and not save"
    state
  end

  def process(%LinkEdit{} = state) do
    # |> dbg
    [fun, params] = state.save_command
    fun.(state, params)
  end

  def save(%LinkEdit{} = state, _parameters) do
    state
  end
end
