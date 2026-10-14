![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Rana Dorada Run

An endless-runner game for VGA, designed in Verilog for fabrication on a [Tiny Tapeout](https://tinytapeout.com) chip.

A Panamanian golden frog (*rana dorada*) runs through the jungle. Jump over logs, bamboo and crabs, but stay on the ground when a toucan flies by. Every 100 points the game speeds up and the time of day changes: day, afternoon, sunset and night with stars. All characters and graphics are original.

| | |
|---|---|
| Author | Martín Saldaña |
| Top module | `tt_um_malex1269_rana_dorada` |
| Clock | 25.175 MHz (VGA 640x480 @ 60 Hz) |
| Tiles | 1x1 |
| Datasheet | [docs/info.md](docs/info.md) |
| Project page | https://malex1269.github.io/tt-rana-dorada-run/ |

## What you need to play

- The Tiny Tapeout demo board with the chip.
- A **TinyVGA PMOD** on the output PMOD header and a VGA monitor (640x480 @ 60 Hz).
- A way to jump: a **Gamepad PMOD** with a SNES-compatible controller on the input PMOD header, or a push button on `ui[0]` (DIP switch 1 also works).

## Quick start on the demo board

1. Plug the TinyVGA PMOD into the output header and connect the monitor.
2. In the [Tiny Tapeout Commander](https://commander.tinytapeout.com/), select `tt_um_malex1269_rana_dorada` and set the clock to 25175000 Hz.
3. Use manual inputs (DIP switches / input PMOD), plug in the Gamepad PMOD or the push button, keep the DIP switches off when using the gamepad, and reset the project.
4. Press Up, A or B (or the button on `ui[0]`) to start and to jump.

The full step-by-step setup, including the MicroPython commands, is in the [datasheet](docs/info.md#how-to-test).

## How to play

| Action | Gamepad PMOD | Push button |
|--------|--------------|-------------|
| Start / restart | Up, A or B | `ui[0]` |
| Jump | Up, A or B | `ui[0]` |
| High jump / low jump | hold / tap | hold / tap |

- Jump over logs, bamboo (tall, needs a high jump) and crabs.
- Do **not** jump when a toucan comes; it only hits the frog in the air. Toucans appear after 100 points.
- When the frog touches an obstacle it turns red. Press jump to play again.

## Pinout

| Pin | Function |
|-----|----------|
| `ui[0]` | Jump button (active high) |
| `ui[4]` | Gamepad PMOD latch |
| `ui[5]` | Gamepad PMOD clock |
| `ui[6]` | Gamepad PMOD data |
| `uo[0]`, `uo[4]` | Red (R1, R0) |
| `uo[1]`, `uo[5]` | Green (G1, G0) |
| `uo[2]`, `uo[6]` | Blue (B1, B0) |
| `uo[3]` | VSync |
| `uo[7]` | HSync |

## Try it in the browser

Open the Gamepad example in the [Tiny Tapeout VGA Playground](https://vga-playground.com/?preset=gamepad), replace `project.v` with [`src/project.v`](src/project.v), enable gamepad mode (controller icon next to the `ui_in` buttons), click on the game screen and play with the Up arrow or the `a` / `b` keys. Shift+R resets the design.

## How it works

The design has no frame buffer: every pixel is computed on the fly from the beam position, using small sprite ROMs (frog, log, crab, toucan) and procedural graphics (bamboo, parallax hills, scrolling ground, stars and a 7-segment-style score). The game state is updated once per frame, jumps follow a simple gravity model, obstacles are chosen with an 8-bit LFSR, and collisions are detected pixel by pixel during the scan. See the [datasheet](docs/info.md) for details.

## Repository contents

| Path | Content |
|------|---------|
| `src/project.v` | The game (top module `tt_um_malex1269_rana_dorada`) |
| `src/hvsync_generator.v` | VGA sync generator from the Tiny Tapeout VGA template |
| `src/gamepad_pmod.v` | Gamepad PMOD driver by Pat Deegan (Apache-2.0) |
| `info.yaml` | Tiny Tapeout project metadata and pinout |
| `docs/info.md` | Datasheet: how it works, how to test, external hardware |
| `test/` | cocotb testbench (`tb.v`, `test.py`, `Makefile`) |

## About Tiny Tapeout

Tiny Tapeout is an educational project that makes it easier and cheaper than ever to get digital and analog designs manufactured on a real chip. Learn more at https://tinytapeout.com.

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Join the community](https://tinytapeout.com/discord)
