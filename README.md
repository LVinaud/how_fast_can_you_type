# how_fast_can_you_type

### Authors:

- Bernardo Rodrigues Tameirão Santos
- Bruno Figueiredo Lima
- Lázaro Pereira Vinaud Neto

### Institution:

University of Sao Paulo, Institute Of Mathmetical and Computer Sciences

### Course:

Practice in Computer Organization

This is a repo for the course project, which envolves two tasks: First - finishing the cpu vhdl design of an authoral risk-v processor(https://github.com/simoesusp/Processador-ICMC) made by our professor and Second - creating an assembly code for a game in this same processor.

In this repo, there is the assembly code, and also the final cpu vhdl which we were tasked to complete.

The whole thing can be compiled in a DE0-CV FPGA or in the online emulator(https://proc.giroto.dev/).

# AI Use

During the semester, 2026/01, Claude Opus and AI models in general caught our attention by its growing capabilities, and as a joke while we were in a class we decided to test if Claude Opus would be able to complete the CPU vhdl with little context, which it did, in its first try. Up until now we were treating ChatGPT and other AI models as a useful thing but nothing that actually worried us.

After Claude did that we were a bit shocked, and that led us to try another thing: creating an OS for this architecture, again with little context and a simple prompt. It managed to do that again(not an actual OS, but an actual good simulation of one), what would be the most incredible project for this discipline in all time was done in 5 minutes with little context by Claude, and the code built flawlessly, again in its first attempt.

Furthermore, both me and my friend, and also our professor started to philosophize about life, human work, even capitalism ability to continue. For us, it is clear that AI already has the capabilities to replace human work, not only theoretically, but it is only a matter of investing and organization. For me personally(Lazaro) manual labor is as easily replaceable, only a bit costlier since it also envolves building a robot, but is is possible and already exists, as in this chinese robot clip: https://www.reddit.com/r/interesting/comments/1tk8cgz/chinese_aipowered_robots_can_solve_workplace/ .

Sparing the reader of further philosophy, although we did that a lot in this semester, we decided to make this work 100% AI free, so our game was 100% made by humans, it is way simpler than an OS and this text is also 100% AI free. But we also decided to document this moment, which is kind of a huge breakthrough and a new era in our opinion(and even the pope's considering his recent encyclical "Magnifica Humanitas" that is related to the "Rerum Novarum" from the industrial revolution).

Considering that, there is a section with a video, prompts, and results from the whole Claude interaction, showing how little effort is needed to create intelectually hard tasks, and their amazing results.

# Our Game

The game is really simple:

A text appears in the screen, the user need to type it and fast, the letters will change their colors considering what you typed, if you got a letter wrong, it becomes red and you need to go back, your time is your score, the faster the better. When you write things correctly, they become green. The code is througly commented.

Screenshot of the game running:

<img width="1895" height="892" alt="image" src="https://github.com/user-attachments/assets/d39d3880-7620-41f4-9370-110df3f90709" />

# Architecture ADD-Ons

As part of the course, we are also tasked to implement a new instruction, make the assembler recognize it, and use the new instruction in our game. Since we use random numbers a lot to choose the new sequence of words, we decided to implement and use that and also an instructions to see how much time has passed since the computer started. The game code, cpu.vhd and assembler are all in the version_with_added_instructions folder.

## Architecture Modification: `RAND` and `RDTIME` Instructions

The processor has been extended with two new instructions, both using the one-register format (the same as `INCHAR`):

| Mnemonic | Opcode `IR(15..10)` | Operation |
|-----------|---------------------|-----------|
| `RAND RX` | `110110` | `RX <- random number` |
| `RDTIME RX` | `110111` | `RX <- time in milliseconds since startup` |

### `RAND`

The processor includes an internal counter (`Aleatorio`) that increments by 1 on every clock cycle. Since the program reads this counter at unpredictable moments (for example, when the player presses a key), the retrieved value serves as a random number. In the game, the `MOD` instruction is used to select one of the available phrases.

### `RDTIME`

The processor keeps track of elapsed time using a clock-cycle counter (`PreMili`). Every 12,000 clock cycles (equivalent to 1 ms with a 12 MHz clock), it increments a millisecond counter (`Milis`). The `RDTIME` instruction simply copies the value of this millisecond counter into the destination register. Dividing the resulting value by 1000 gets the elapsed time in seconds.


