defmodule A940.MemoryAddress do
  defstruct location: 0, relocation: 0

  def new_relocatable(location)
      when is_integer(location) and location >= 0 and location <= 16383 do
    %__MODULE__{location: location, relocation: 1}
  end

  def new_absolute(location)
      when is_integer(location) and location >= 0 and location <= 16383 do
    %__MODULE__{location: location, relocation: 0}
  end

  def new(location, relocation)
      when is_integer(location) and location >= 0 and location <= 16383 do
    %__MODULE__{location: location, relocation: relocation}
  end

  def new({location, relocation}), do: new(location, relocation)
end
