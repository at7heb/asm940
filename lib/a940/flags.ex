defmodule A940.Flags do
  defstruct dummy: :default,
            default_base: 10,
            relocating: true,
            label: "",
            done: false,
            address_class: :no_address,
            address_length: 0,
            indirect: false

  def default, do: %__MODULE__{}
end
