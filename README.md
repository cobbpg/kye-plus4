# Kye for Commodore Plus/4

This is the Commodore Plus/4 port of Colin Garbutt's puzzle game from 1992, Kye, based on the [C64 port](https://github.com/cobbpg/kye-c64) I made earlier. The game is available as a [free download at Plus/4 World](https://plus4world.powweb.com/software/Kye). You can play the original game via archive.org's emulator [here](https://archive.org/details/win3_Kye).

## Overview

After porting [Stunt Car Racer](https://plus4world.powweb.com/software/Stunt_Car_Racer) to the Plus/4, I got quite familiar with the TED chip, and I realised that the C64 version of Kye could be ported over with ease due to the fact that it doesn't rely much on sprites. The only real challenge was to figure out a way to recreate the SID music given the much more limited capabilities of the TED.

The goal of the game is simple: move around with the green circle thing and collect all the diamonds. It's up to you to discover the rules! The game is controlled with the joystick in port 2 exclusively; there's no keyboard input.

## Build Instructions

The game was created using the following tools:

* [KickAssembler](https://theweb.dk/KickAssembler/) (5.25) with [Sublime Text integration](https://packagecontrol.io/packages/Kick%20Assembler%20(C64))
* [CharPad C16 Pro](https://subchristsoftware.itch.io/charpad-c16-pro) (3.69)
* [Exomizer](https://bitbucket.org/magli143/exomizer/wiki/Home) (3.1.1)

As long as you don't want to change any of the art or sounds, you will only need KickAssembler. Just assemble `kye.asm` directly to get an executable (the command below assumes you have `KickAss.jar` in your classpath):

```
java kickass.KickAssembler kye.asm -o kye.prg
```

If you want to compile the music as a separate executable, assemble `kye-music.asm` instead

```
java kickass.KickAssembler kye-music.asm -o kye-music.prg
```

If you change the graphical assets, you have to export them manually to see the changes in the build:

* CharPad: File → Import/Export → Binary → Export All, and choose the `graphics` folder

## Levels

Kye has hundreds of user-contributed levels available over the internet. A good starting point is the fan site [My Kye Page](https://www.kye.me.uk/), which has the original game as well as the [full archive of level packs in the registered version](https://www.kye.me.uk/charitylevels.html). You can easily change the level packs included in the game by editing the `IncludeLevelPack` commands at the bottom of `startup.asm`. You have about 32K RAM available for levels, which should be enough for over 100 of them.

The levels are parsed from the original format and RLE compressed during assembly. This port has a limitation of 255 active objects at the same time (meaning objects that have their own behaviour, so passive elements like inert blocks or diamonds are not subject to this limit), and it will skip levels exceeding the threshold with a warning. Note that this parser ignores the level count at the top of the file, and cannot handle text appended after the levels.

If you're up for a technical challenge, you are welcome to add an in-game level editor (which the original game does have) and a system to load and save levels on disk. :)

## Technical Notes

### Preprocessor Usage

The code relies heavily on KickAssembler scripting features to wrangle assets during assembly:

* Levels are parsed and RLE compressed by the `IncludeLevelPack` macro.
* The music is parsed and turned into its run-time representation (details below).
* Various LUTs are generated thanks to the ability to maintain hash tables and lists during assembly time.
* Light usage of pseudo-ops to simplify some pointer manipulation (I'm not very consistent about this, as I'm still trying to get a feel for what works best).

### Game Rules

A lot of advanced Kye levels rely on the precise ways the game works. I tried to make sure to replicate these details correctly, so the active objects are processed in a particular order, and especially magnets ("stickers") are checked in a very specific way. Many of these details are not documented anywhere, and I deduced them by testing the original version.

The original game has a bug which I didn't replicate due to its limited usefulness in level building: if Kye happens to be on top of a one-way door when a monster wanders too close and Kye dies, then the door is teleported to Kye's respawn position. In my port, the door stays where it was.

One thing I didn't implement is the logic to look for a free tile to respawn on if Kye's starting position is already occupied. The original game scans in a rectangular spiral of ever increasing radius, always going counterclockwise starting from the bottom left corner. My version simply puts Kye back in the starting position, which might break some of the more evil puzzles.

### Input System

In order to ensure that the game is always responsive and handles well, there's a separate input buffer for both axes (i.e. left-right and up-down). When the joystick is pulled in a certain direction, there's a state machine running each frame generating trigger events (see the `ProcessInput` function in `startup.asm`), which need to be acknowledged by the target logic. This is needed to avoid missing input in some cases. The first trigger event in each axis is followed by a longer wait than the rest. The timings can be tweaked in the `Frequency` namespace in `data.asm`.

### Music Engine

Instead of using an existing tracker, I created my own TED-based music player from scratch. The patterns and their ordering are defined in text files that are parsed by the assembler during build time.

The system augments the TED's two channels with a timer-based "filter", which can do two things:

* Amplitude modulation of any combination of the two channels by turning them on and off at regular intervals, which makes it possible to create lower pitches than the TED can achieve natively.
* Sync the channels to the timer, thereby creating slightly more complex sounds than just the plain pulses provided by the TED. For instance, syncing the lead to the bass usually creates a musically useful distortion effect.

In addition, there's a virtual percussion channel that can be controlled separately from all the physical channels. When drums are played, they simply override the second voice momentarily, which works pretty well if they share the physical channel with the bassline, for instance.

## Credits

Original game: Colin Garbutt

Level sets included in the release:
* Default: Colin Garbutt
* Sampler: Dr Floyd?
* Plus 2: Mark & Dave @ Positive Ltd.
* New Kye: Unkown
* Shapes & Monsters: Dennis K. Fitzgerald
* Danish: Jytte Madsen & Erik Jacobsen

Commodore Plus/4 port and music: Patai Gergely