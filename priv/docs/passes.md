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