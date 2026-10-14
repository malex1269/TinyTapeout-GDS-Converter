<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Rana Dorada Run is an endless-runner game rendered directly to a VGA monitor (640x480 @ 60 Hz, 25.175 MHz pixel clock) through the TinyVGA PMOD. The player is a Panamanian golden frog that runs through the jungle and must jump over logs, bamboo stalks and crabs, while staying on the ground when a toucan flies by at head height. All characters and graphics are original.

The design has no frame buffer. Every pixel is computed on the fly by comparing the beam position (`pix_x`, `pix_y`) from the sync generator with the position of each object. The frog and the obstacles are small 1-bit and 2-bit sprites stored as combinational ROMs and scaled 2x; the bamboo, the parallax hills, the scrolling ground, the night stars and the 7-segment-style score digits are generated procedurally.

The game state is updated once per frame by a single-cycle enable pulse in the `clk` domain (no derived clocks). The frog follows a simple ballistic model: an initial upward velocity and a gravity of 1 px/frame², doubled when the button is released early, so a long press gives a high jump and a short tap a low one. Two obstacle slots scroll left and are respawned off-screen with a type and an extra distance taken from an 8-bit LFSR, always keeping a minimum gap so every situation can be cleared. Collisions are pixel-exact: a flag is set whenever a frog pixel and an obstacle pixel are drawn at the same time during the scan, and it is evaluated at the end of the frame.

The score is a 3-digit BCD counter. Every 100 points the scrolling speed increases (4 to 7 px/frame) and the time of day changes from day to afternoon, sunset and finally night with stars. Toucans only start appearing after 100 points.

## How to test

1. Connect a TinyVGA PMOD to the output pins and a VGA monitor, and set the clock to 25.175 MHz (25 MHz also works on most monitors).
2. Connect a Gamepad PMOD to the input pins (ui[4] latch, ui[5] clock, ui[6] data), or a push button to ui[0] (active high).
3. Reset the design. The frog waits on the ground with the score at 000.
4. Press Up, A or B on the gamepad (or the button on ui[0]) to start. The same button makes the frog jump; hold it for a high jump, tap it for a low one.
5. Jump over logs, bamboo and crabs. Do not jump when a toucan comes: it flies just above the frog's head.
6. When the frog touches an obstacle it turns red and the game stops. Press the button again to restart.

The design can also be tried in the browser with the Tiny Tapeout VGA Playground: open the Gamepad example, replace the project file, enable gamepad mode and use the Up arrow or the A/B keys.

## External hardware

- TinyVGA PMOD (or an equivalent resistor-ladder VGA adapter) and a VGA monitor.
- Gamepad PMOD with a SNES-style controller, or a single push button on ui[0].
