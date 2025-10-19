defmodule A940.Flags do
  defstruct dummy: :default,
            default_base: 10,
            relocating: true,
            done: false

  def default, do: %__MODULE__{}
end
