# how_fast_can_you_type

Authors:
Lázaro Pereira Vinaud Neto
Bruno Figueiredo Lima

Institution:
University of Sao Paulo, Institute Of Mathmetical and Computer Sciences

Course:
Practice in Computer Organization

This is a repo for the course project, which envolves two tasks: First - finishing the cpu vhdl design of an authoral risk-v processor(https://github.com/simoesusp/Processador-ICMC) made by our professor and Second - creating an assembly code for a game in this same processor.

In this repo, there is the assembly code, and also the final cpu vhdl which we were tasked to complete.

The whole thing can be compiled in a DE0-CV FPGA or in the online emulator(https://proc.giroto.dev/).

# AI Use

During the semester, 2026/01, Claude Opus and AI models in general caught our attention by its growing capabilities, and as a joke while we were in a class we decided to test if Claude Opus would be able to complete the CPU vhdl with little context, which it did, in its first try. Up until now we were treating ChatGPT and other AI models as a useful thing but nothing that actually worried us. 

After Claude did that we were a bit shocked, and that led us to try another thing: creating an OS for this architecture, again with little context and a simple prompt. It managed to do that again(not an actual OS, but an actual good simulation of one), what would be the most incredible project for this discipline in all time was done in 5 minutes with little context by Claude, and the code built flawlessly, again in its first attempt. 

Furthermore, both me and my friend, and also our professor started to philosophize about life, human work, even capitalism ability to continue. For us, it is clear that AI already has the capabilities to replace human work, not only theoretically, but it is only a matter of investing and organization. For me personally(Lazaro) manual labor is as easily replaceable, only a bit costlier since it also envolves building a robot, but is is possible and already exists, as in this chinese robot clip: https://www.reddit.com/r/interesting/comments/1tk8cgz/chinese_aipowered_robots_can_solve_workplace/ . 

Sparing the reader of further philosophy, although we did that a lot in this semester, we decide to make this work 100% AI free, so our game was 100% made by humans, it is way simpler than an OS and this text is also 100% AI free. But we also decided to document this moment, which is kind of a huge breakthrough and a new era in our opinion(and even the pope's considering his recent encyclical "Magnifica Humanitas" that is related to the "Rerum Novarum" from the industrial revolution).

Considering that, there is a section with a video, prompts, and results from the whole Claude interaction, showing how little effort is needed to create intelectually hard tasks, and their amazing results.

# Our Game

The game is really simple:

A text appears in the screen, the user need to type it and fast, the letters will change their colors considering what you typed, if you got a letter wrong, it becomes red and you need to go back, your time is your score, the faster the better. When you write things correctly, they become green. The code is througly commented.


