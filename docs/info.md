<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Rana Dorada Run is an endless-runner game rendered directly to a VGA monitor (640x480 @ 60 Hz, 25.175 MHz pixel clock) through the TinyVGA PMOD. The player is a Panamanian golden frog (*rana dorada*) that runs through the jungle and must jump over logs, bamboo stalks and crabs, while staying on the ground when a toucan flies by at head height. All characters and graphics are original.

The design has no frame buffer. Every pixel is computed on the fly by comparing the beam position (`pix_x`, `pix_y`) from the sync generator with the position of each object. The frog and the obstacles are small 2-colour sprites stored as combinational ROMs and scaled 2x; the bamboo, the parallax hills, the scrolling ground, the night stars and the 7-segment-style score digits are generated procedurally.

The game state is updated once per frame by a single-cycle enable pulse in the `clk` domain (no derived clocks). The frog follows a simple ballistic model: an initial upward velocity and a gravity of 1 px/frame², doubled when the button is released early, so a long press gives a high jump and a short tap a low one. Two obstacle slots scroll to the left and are respawned off-screen with a type and an extra distance taken from an 8-bit LFSR, always keeping a minimum gap so that every situation can be cleared. Collisions are pixel-exact: a flag is set whenever a frog pixel and an obstacle pixel are drawn at the same time during the scan, and it is evaluated at the end of the frame.

The score is a 3-digit BCD counter shown in the top-right corner. Every 100 points the scrolling speed increases (from 4 to 7 px/frame) and the time of day changes from day to afternoon, sunset and finally night with stars. Toucans only start appearing after 100 points.

The controls are read from a Gamepad PMOD through the official `gamepad_pmod` driver (serial latch/clock/data on `ui[4:6]`), or from a single push button on `ui[0]`; both are synchronized to the system clock.

## How to test

### What you need

- A Tiny Tapeout demo board with the chip.
- A TinyVGA PMOD connected to the **output** PMOD header (`uo[7:0]`) and a VGA monitor that accepts 640x480 @ 60 Hz.
- One way to control the game:
  - a Gamepad PMOD with a SNES-compatible controller on the **input** PMOD header (`ui[7:0]`), or
  - a push button between 3.3 V and `ui[0]` (with a pull-down resistor), or simply DIP switch 1 on the demo board (works, but is less comfortable).

### Setting up the demo board

1. Connect the TinyVGA PMOD to the output header and the monitor to the TinyVGA PMOD.
2. Open the Tiny Tapeout Commander at https://commander.tinytapeout.com/ (Chrome, Edge, Opera or Brave) and connect to the board. If the board is not detected, unplug the input PMOD and turn all DIP switches off, then try again.
3. Select the project `tt_um_malex1269_rana_dorada` and click **SELECT**.
4. Set the clock to 25175000 Hz and click **SET**. If the board can only reach a nearby value (for example 25 MHz), the image will still work on most monitors.
5. Make sure the inputs are driven manually (by the DIP switches / input PMOD) and not by the RP2040, then plug in the Gamepad PMOD or the push button. When using the Gamepad PMOD, keep all DIP switches off.
6. Reset the project from the **INTERACT** tab. The game appears on the monitor with the frog standing still and the score at 000.

The same setup from the MicroPython REPL:

```python
from ttboard.mode import RPMode
tt.shuttle.tt_um_malex1269_rana_dorada.enable()
tt.mode = RPMode.ASIC_MANUAL_INPUTS
tt.clock_project_PWM(25_175_000)
```

### How to play

| Action | Gamepad PMOD | Push button / DIP 1 |
|--------|--------------|---------------------|
| Start / restart | Up, A or B | press `ui[0]` |
| Jump | Up, A or B | press `ui[0]` |
| High jump | hold the button | hold `ui[0]` high |
| Low jump | tap the button | short pulse on `ui[0]` |

1. Press jump to start. The score starts counting.
2. Jump over logs, bamboo stalks and crabs. Bamboo is tall and needs a long (high) jump.
3. Do **not** jump when a toucan comes: it flies just above the frog's head and only hits it if the frog is in the air.
4. Every 100 points the game gets faster and the sky changes colour.
5. When the frog touches an obstacle it turns red and the game stops. Press jump again to restart from 000.

### Trying it without the chip

The design runs in the Tiny Tapeout VGA Playground (https://vga-playground.com/?preset=gamepad): replace the contents of `project.v` with `src/project.v` from this repository (keeping `gamepad_pmod.v` and `hvsync_generator.v`), enable gamepad mode with the controller icon next to the `ui_in` buttons, click on the game screen and use the Up arrow or the `a` / `b` keys. Shift+R resets the design. The Playground runs slower than real time, so the game looks slower than on the chip.

## External hardware

- TinyVGA PMOD and a VGA monitor (640x480 @ 60 Hz).
- Gamepad PMOD with a SNES-compatible controller, or a single push button on `ui[0]`.
