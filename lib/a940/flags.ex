defmodule A940.Flags do
  defstruct dummy: :default,
            default_base: 10,
            relocating: true,
            indirect: false,
            done: false

  def default, do: %__MODULE__{}
  def default_with_base(base), do: %__MODULE__{default_base: base}
end
