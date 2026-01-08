defmodule A940.MemoryAddress do
  alias A940.Listing

  defstruct location: 0,
            relocation: 0,
            label: [],
            opcode: [],
            address: [],
            comments: [],
            line_number: 0,
            dummy: false

  def new_relocatable(location)
      when is_integer(location) and location >= 0 and location <= 16383 do
    %__MODULE__{location: location, relocation: 1}
  end

  def new_absolute(location)
      when is_integer(location) and location >= 0 and location <= 16383 do
    %__MODULE__{location: location, relocation: 0}
  end

  def new(location, true), do: new(location, 1)
  def new(location, false), do: new(location, 0)

  def new(location, relocation)
      when is_integer(location) and location >= 0 and location <= 16383 and is_integer(relocation) do
    %__MODULE__{location: location, relocation: relocation}
  end

  def new({location, relocation}), do: new(location, relocation)

  def new_dummy(location, relocation) do
    a = new(location, relocation)
    %{a | dummy: true}
  end

  def new_dummy({location, relocation}), do: new_dummy(location, relocation)

  def xxset_source(
        %__MODULE__{} = address,
        line_number,
        label_tokens,
        opcode_tokens,
        address_tokens_list,
        comment \\ []
      ) do
    %{
      address
      | label: label_tokens,
        opcode: opcode_tokens,
        address: address_tokens_list,
        line_number: line_number,
        comments: comment
    }
  end

  @address_width 5
  def format_for_listing(%__MODULE__{dummy: true} = _address),
    do: String.duplicate(" ", @address_width + 1)

  def format_for_listing(%__MODULE__{relocation: 0, location: loc}),
    do: Listing.fmt_int(loc, @address_width, 8, "0") <> "A"

  def format_for_listing(%__MODULE__{relocation: 1, location: loc}),
    do: Listing.fmt_int(loc, @address_width, 8, "0") <> " "

  def address(%__MODULE__{} = address) do
    %{address | label: [], opcode: [], address: [], comments: [], line_number: 0}
  end

  def source(%__MODULE__{} = address) do
    %{address | location: 0, relocation: 0}
  end
end
