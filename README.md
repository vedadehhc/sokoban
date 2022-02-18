# Sokoban

The classic game [Sokoban](https://en.wikipedia.org/wiki/Sokoban) implemented using the RISC-V ISA.

## Prerequisites
Must have QEMU installed (see [this guide](https://pdos.csail.mit.edu/6.S081/2021/tools.html) from MIT's 6.S081).

## Running
Run `make` in the root directory to assemble and link the RISC-V code. 

Run `make run` in the root directory to actually run the game in QEMU. 

Once the game is running, terminate QEMU with `CTRL+A X`.

## Level Select
Once the game loads, you will be prompted to select a level. There are currently 155 levels which can be selected by entering a number from 1 - 155 and hitting `Return` (level data taken from MIT's 6.009 and can be found [here](https://py.mit.edu/spring22/labs/lab02)). Entering 0 will terminate the program (note that this does not terminate QEMU). 

Entering any other number (or string) has undefined behavior. That is, this will mostly result in the program ask for another input, but sometimes it loads a level even with seemingly invalid input. That is because the base 10 converter doesn't check if inputted characters are digits, it just uses ASCII codes to compute the 'value' of each character. For example, if you request level `a`, the game will load level `'a' - '0' = 97 - 48 = 49`.

## Game Display

Game displays look something like this:

```
+--+
|.F|
|..+-+
|*s..|
|..o.|
|..+-+
+--+ 
```

Here is a key of symbols included in game displays:
- `+-#`: an immovable wall
- `.`: an empty space through which both the player and boxes can move
- `F`: a flag with no other objects atop it
- `s`: the player
- `$`: the player with a flag underneath it
- `o`: a box, all of which should be pushed onto flags to complete the level
- `*`: a box with a flag underneath it

## Game Controls

Once a level has been loaded, you can use the following controls:
- `wasd`: move the character in four directions
- `r`: restart the current level
- `q`: quit to level select

Any other input will be ignored.
