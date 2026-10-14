![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Rana Dorada Run

An endless-runner game for VGA, designed in Verilog for fabrication on a [Tiny Tapeout](https://tinytapeout.com) chip.

A Panamanian golden frog (*rana dorada*) runs through the jungle. Jump over logs, bamboo and crabs, but stay on the ground when a toucan flies by. Every 100 points the game speeds up and the time of day changes: day, afternoon, sunset and night with stars. All characters and graphics are original.

- Author: Martín Saldaña
- Top module: `tt_um_malex1269_rana_dorada`
- Clock: 25.175 MHz (VGA 640x480 @ 60 Hz)
- [Full project documentation](docs/info.md)

## How it works

The design has no frame buffer: every pixel is computed on the fly from the beam position, using small sprite ROMs (frog, log, crab, toucan) and procedural graphics (bamboo, parallax hills, scrolling ground, stars and a 7-segment-style score). The game state is updated once per frame, jumps follow a simple gravity model (hold for a high jump, tap for a low one), obstacles are chosen with an 8-bit LFSR, and collisions are detected pixel by pixel during the scan.

## Controls and hardware

| Pin | Function |
|-----|----------|
| `ui[0]` | Jump button (active high) |
| `ui[4]` | Gamepad PMOD latch |
| `ui[5]` | Gamepad PMOD clock |
| `ui[6]` | Gamepad PMOD data |
| `uo[7:0]` | TinyVGA PMOD (R, G, B, HSync, VSync) |

On the Gamepad PMOD, Up, A or B start the game and make the frog jump. A single push button on `ui[0]` works too.

External hardware: TinyVGA PMOD and a VGA monitor, plus a Gamepad PMOD or a push button.

## Source files

- `src/project.v`: the game (top module).
- `src/hvsync_generator.v`: VGA sync generator from the Tiny Tapeout VGA template.
- `src/gamepad_pmod.v`: Gamepad PMOD driver by Pat Deegan (Apache-2.0).

## Try it in the browser

Open the Gamepad example in the [Tiny Tapeout VGA Playground](https://vga-playground.com/?preset=gamepad), replace `project.v` with the one in `src/`, enable gamepad mode and play with the Up arrow or the A/B keys.

## About Tiny Tapeout

Tiny Tapeout is an educational project that makes it easier and cheaper than ever to get digital and analog designs manufactured on a real chip. Learn more at https://tinytapeout.com.

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Join the community](https://tinytapeout.com/discord)
