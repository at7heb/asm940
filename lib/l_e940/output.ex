defmodule LE940.Output do
  def process(%LinkEdit{save_command: []} = state) do
    raise "pretty useless to spend all this time, wasting so much energy, and not save"
    state
  end

  def save(%LinkEdit{} = _state, _parameters) do
  end
end
