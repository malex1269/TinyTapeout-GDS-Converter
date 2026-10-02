/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_malex1269_TRIPLEa(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [9:0] counter;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );
  
  wire [9:0] moving_x = pix_x + counter;

  reg [1:0] r_reg, g_reg, b_reg;

  always @(*) begin
    case (moving_x[7:5])
      3'b000: {r_reg, g_reg, b_reg} = {2'b11, 2'b00, 2'b00}; // Franja 0: Rojo puro
      3'b001: {r_reg, g_reg, b_reg} = {2'b11, 2'b11, 2'b00}; // Franja 1: Amarillo
      3'b010: {r_reg, g_reg, b_reg} = {2'b00, 2'b01, 2'b00}; // Franja 2: Verde
      3'b011: {r_reg, g_reg, b_reg} = {2'b11, 2'b11, 2'b11}; // Franja 3: Cyan
      3'b100: {r_reg, g_reg, b_reg} = {2'b00, 2'b00, 2'b11}; // Franja 4: Azul
      3'b101: {r_reg, g_reg, b_reg} = {2'b01, 2'b10, 2'b00}; // Franja 5: Magenta
      3'b110: {r_reg, g_reg, b_reg} = {2'b00, 2'b01, 2'b00}; // Franja 6: Naranja
      3'b111: {r_reg, g_reg, b_reg} = {2'b11, 2'b11, 2'b11}; // Franja 7: Blanco
      default: {r_reg, g_reg, b_reg} = 6'b0;
    endcase
  end

  assign R = video_active ? r_reg : 2'b00;
  assign G = video_active ? g_reg : 2'b00;
  assign B = video_active ? b_reg : 2'b00;
  
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end

  // Suppress unused signals warning
  wire _unused_ok_ = &{moving_x, pix_y};

endmodule
