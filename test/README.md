# Testbench for Rana Dorada Run

This folder contains the [cocotb](https://docs.cocotb.org/en/stable/) testbench for `tt_um_malex1269_rana_dorada`. For more information about testing Tiny Tapeout projects, see the [website](https://tinytapeout.com/hdl/testing/).

## Files

- [tb.v](tb.v): instantiates the top module `tt_um_malex1269_rana_dorada` and exposes its pins to cocotb.
- [test.py](test.py): VGA test from the Tiny Tapeout VGA template. It resets the design, checks the HSync/VSync timing and captures frames as PNG images into `output/`. As in the Tiny Tapeout workshop guide, both tests currently start with `cocotb.pass_test()`, so they only check that the design compiles and simulates; remove that line to run the full frame capture.
- [Makefile](Makefile): `PROJECT_SOURCES = project.v hvsync_generator.v gamepad_pmod.v`.

## How to run

To run the RTL simulation:

```sh
make -B
```

To run gatelevel simulation, first harden your project and copy `../runs/wokwi/results/final/verilog/gl/{your_module_name}.v` to `gate_level_netlist.v`.

Then run:

```sh
make -B GATES=yes
```

If you wish to save the waveform in VCD format instead of FST format, edit tb.v to use `$dumpfile("tb.vcd");` and then run:

```sh
make -B FST=
```

This will generate `tb.vcd` instead of `tb.fst`.

## How to view the waveform file

Using GTKWave

```sh
gtkwave tb.fst tb.gtkw
```

Using Surfer

```sh
surfer tb.fst
```
