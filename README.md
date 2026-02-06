# Asm940

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `asm940` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:asm940, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/asm940>.

### Memory Map

``` bash
RES
DDT
;TB1.
24000;TB6.
20000;TB2.
;TB3.
;F<PATCH:
23002425,30B6;R
24000;TB4.
;TB5.
PATCH;F
23003132,30242500;R
%F
DUMP
"BASIC-DUMP"
```

### Relocation

My guesses

|command|effect|state|
| :------------: | :------------ | :---------: |
|;TB1.|load 1BAS into page 0|```----,---```|
|24000;TB6|load 6BAS into pages 5+6|```1---,-66-``` |
|20000;TB2.|load 2BAS into page 4|```1---,266-```|
|;TB3.|load 3BAS right after 2BAS page 4|```1---,266-```|
|23002425,30B6;R|move 6BAS to pages 2&3|```1-66,2---```|
|24000;TB4.|load 4BASW into page 5|```1-66,24--```|
|;TB5.|load 5BAS into pages 5 & 6|```1-66, 245-```|

### LOADING with 940ASM's LinkEdit

``` elixir
  def le0() do
    [
      "load 240 240 temp/1BAS.e9b",
      "load 10000 24000 temp/6BAS.e9b",
      "load 20000 20000 temp/2BAS.e9b",
      "load temp/3BAS.e9b",
      "load 24000 24000 temp/4BAS.e9b",
      "load temp/5BAS.e9b",
      "save aaa"
    ]
    |> le
  end

```
