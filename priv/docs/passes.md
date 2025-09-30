## Pass 0 Create tokens

This is almost an Enum.reduce() sort of thing...

Create a list of tokens with {:atom, value} tuples.
There will be a {:line, line_number, "original line"} tuple before any of the line's tokens.
In the case of a continuation line, there will be a {:continuation, line_number, "original line"} tuple before a continuation line.

| Name / :atom  | Pattern                        | Value              | Description                                         |
| ------------- | ------------------------------ | ------------------ | --------------------------------------------------- |
| :number       | /\-?[0-9]+D?/                  | number             | Number, can be signed                               |
| :number       | /[0-7]+B[0-7]?/                | number             | Octal Number                                        |
| :spaces       | /\s+/                          | " "                | Separator; \n\|\r already removed                   |
| :symbol       | /[0-9A-Z]+/                    | "\<the symbol\>"   | Symbol, op, pseudo-op                               |
| :delimiter    | one of + - * / , ' ( ) = . $ _ | "\<the operator\>" | delimiter                                           |
| :special      | one of : ; \< \> ? [ ] "       | "\<the special\>"  | special character                                   |
| :string6      | /\'[^\']{1,4}'/                | "\<the string\>"   | string literal 1-4 characters with 6 bit characters |
| :string8      | /\"[^\"]{1,}\"/                | "\<the string\>"   | string  with 8 bit characters                       |
| :illegal      | any of  ! # % & @ ^            | \<the character\>" | "Replaced with blanks"! ?                           |
| :end_of_line  | n/a                            | nil                | End of line indicator                               |
| :continuation | /^+/                           | line#, line        | beginning of continuation                           |
| :line         | /^[^+]/                        | line#, line        | beginning of line                                   |

### Notes

1. An identifier is any alphanumeric that does not form a number, so it is important to identify the octal number before the symbol.
2. A line beginning with + is a continuation line of the previous line.
3. A semicolon (;) betweeen parentheses or inside 'string6' does not terminate a line.

### Peephole Transformations
1. A peephole transformation must eliminate the {:end_of_line, _} tuple that precedes a {:continuation, \_}
2. (AND), (OR), (NOT), (EOR), and (R) as {:delimiter, "("}, {:symbol, "..."}, {:delimiter, ")"} tuples must be transformed into e.g. the single tuple{:delimiter, "OR"}


## Pass 1 Build Abstract Syntax Tree

This has a list of structs, which comprise

1. label - text; the label or nil
2. global - boolean; must be false if label is nil, otherwise true if $LABEL LDA =5
3. opcode - text; the opcode field
4. indirect - boolean; true if e.g. LDA* POINTER
5. address - liost; the address field, or approximation thereof
6. index - boolean; true if address,2
7. rest - text; rest of line

The ```label```s like ```GC``` or ```$GC``` are separated from opcode by 1 or more spaces.

```Opcode``` is followed by ```*``` (or not) and terminated by following spaces.

```Address``` is evrythihng after the spaces after the ```opcode``` / ```indirect```, includes strings, and is terminated by spaces, the index indication, or the end of line. 
Spaces withing strings do not terminate the address. 
The ```address``` is a list of symbols, numbers, operators, and strings.
Strings can be 6 bit characters, up to 4: ```'abcd' 'a' '   a'```.
Maybe the 6 bit string should be a ```strang```.
Strings can be 8 bit characters, any number: ```"twas brillig..."```.

The ```index``` is boolean, true if ```,2``` immediately follows the address.

A semicolon - ```;``` - anywhere in a line but neither in a string nor in a comment terminates the statement.

## Instruction types

| name or :atom | explanation                                  | note                   |
| ------------- | -------------------------------------------- | ---------------------- |
| a14           | instruction with 14 bit address, such as LDA | called class 1, type 0 |
| a9            | instruction with 9 bit address, such as LSH  | called class 1, type 1 |
| a0            | instruction with 0 bit address, such as CLA  | called class 2         |

Instruction opcodes may be symbolic or numeric 

## Address Fields

The tag (,[0-7]) at the end of the address field indicates the first 3 bits of the instruction.
It is normally ",2" indicating indexing. POPs and SYSPOPs are usually defined with the OPDEF pseudo instruction (or else by default - e.g. BRS)

An address can be preceded by / or \_.
The virgule (/) indicates indexing.
(So " LDA /COUNTR,2" is redundant!)
The underscore (\_), which was a backarrow back in the day, indicates indirection.
(So " STA* \_CPOINTR" is redundant)

## State Machine

Pass 1 is implemented as a state machine.
It processes 1 character at a time.

```mermaid
---
title: Pass 1 States
---
stateDiagram-v2
    [*] --> Global: "DOLLAR $"
    [*] --> Label: "ALPHA or DIGIT or ??"
    [*] --> Spaces1: "SPACE"
    [*] --> EndOfLine: ";"
    [*] --> Comment: "*"
    Label --> Label: "ALPHA or DIGIT or ??"
    Label --> Spaces1: " "
    Label --> EndOfLine
    Spaces1 --> Spaces1
    Spaces1 --> Opcode
    Spaces1 --> EndOfLine
    Opcode --> Opcode
    Opcode --> Indirect
    Opcode --> Spaces2
    Opcode --> EndOfLine
    Spaces2 --> Symbol
    Spaces2 --> String
    Spaces2 --> Strang
    Spaces2 --> Special
    Spaces2 --> Number
    Spaces2 --> EndOfLine
    Symbol --> Symbol
    Symbol --> Special
    Symbol --> Index0
    Symbol --> EndOfLine
    Index0 --> Symbol
    Index0 --> Number
    Index0 --> String
    Index0 --> Strang
    Index0 --> Index1
    EndOfLine --> [*]
    ```