/*
 * Rana Dorada Run — juego tipo "runner" para Tiny Tapeout
 * Salida VGA 640x480 @ 60 Hz por TinyVGA PMOD. Personaje y gráficos originales.
 * Basado en la plantilla VGA de Uri Shaked (Apache-2.0)
 * SPDX-License-Identifier: Apache-2.0
 *
 * La rana dorada corre por la selva. Hay que saltar troncos, bambúes y
 * cangrejos, y NO saltar cuando viene un tucán volando a media altura.
 * Cada 100 puntos sube la velocidad (4 a 7 px/frame) y cambia la hora del día:
 * día, tarde, atardecer y noche con estrellas. Los tucanes aparecen desde 100.
 *
 * Controles (cualquiera de los dos sirve):
 *   - Gamepad PMOD en ui_in[6:4] (latch=ui_in[4], clk=ui_in[5], data=ui_in[6]):
 *       Arriba, A o B = SALTAR. En el VGA Playground: activar el modo gamepad
 *       y usar la flecha Arriba o las teclas 'a' / 'b' del teclado.
 *   - Pulsador simple en ui_in[0] (activo en alto) = SALTAR.
 *   Saltar también inicia y reinicia la partida.
 *   Mantener presionado = salto alto; toque corto = salto más bajo.
 *
 * Requiere gamepad_pmod.v (Pat Deegan, Apache-2.0) y hvsync_generator.v.
 *
 * Diseño sin memoria de video: todo se dibuja comparando pix_x/pix_y con la
 * posición de los objetos. El estado del juego se actualiza una sola vez por
 * frame con un pulso de habilitación (frame_tick) en el dominio de clk.
 */

`default_nettype none

module tt_um_malex1269_rana_dorada(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // ------------------------------------------------------------------
  // VGA
  // ------------------------------------------------------------------
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

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // ------------------------------------------------------------------
  // Constantes
  // ------------------------------------------------------------------
  localparam [9:0] GROUND_Y = 10'd400;  // primera línea del suelo
  localparam [9:0] FROG_TOP = 10'd368;  // GROUND_Y - 32 (rana de 32x32)
  localparam [9:0] OBS_TOP  = 10'd376;  // GROUND_Y - 24 (obstáculo de 32x24)
  localparam [9:0] BIRD_TOP = 10'd350;  // altura de vuelo del tucán
  localparam [4:0] JUMP_V   = 5'd12;    // velocidad inicial del salto
  localparam [9:0] MIN_GAP  = 10'd224;  // separación mínima entre obstáculos
  localparam [9:0] SPAWN_X  = 10'd640;  // reaparición justo fuera de pantalla

  localparam [1:0] S_IDLE = 2'd0;
  localparam [1:0] S_RUN  = 2'd1;
  localparam [1:0] S_OVER = 2'd2;

  localparam [1:0] T_LOG    = 2'd0;  // tronco (bajo)
  localparam [1:0] T_BAMBOO = 2'd1;  // bambú (alto)
  localparam [1:0] T_CRAB   = 2'd2;  // cangrejo (bajo, animado)
  localparam [1:0] T_BIRD   = 2'd3;  // tucán volando: NO saltar

  // Un pulso de un ciclo por frame, al terminar la zona visible
  wire frame_tick = (pix_x == 10'd0) && (pix_y == 10'd480);

  // ------------------------------------------------------------------
  // Entradas: Gamepad PMOD (módulo oficial) + pulsador en ui_in[0]
  // ------------------------------------------------------------------
  wire gp_b, gp_y, gp_select, gp_start, gp_up, gp_down, gp_left, gp_right;
  wire gp_a, gp_x, gp_l, gp_r, gp_present;

  gamepad_pmod_single gamepad (
    .rst_n(rst_n),
    .clk(clk),
    .pmod_data(ui_in[6]),
    .pmod_clk(ui_in[5]),
    .pmod_latch(ui_in[4]),
    .b(gp_b), .y(gp_y), .select(gp_select), .start(gp_start),
    .up(gp_up), .down(gp_down), .left(gp_left), .right(gp_right),
    .a(gp_a), .x(gp_x), .l(gp_l), .r(gp_r),
    .is_present(gp_present)
  );

  // Sincronizador (2 FF) para el pulsador externo
  reg btn_meta, btn_ext;
  always @(posedge clk) begin
    btn_meta <= ui_in[0];
    btn_ext  <= btn_meta;
  end

  wire btn = btn_ext | gp_up | gp_a | gp_b;

  // ------------------------------------------------------------------
  // LFSR de 8 bits libre (corre cada ciclo): fuente pseudoaleatoria
  // ------------------------------------------------------------------
  reg [7:0] lfsr;
  always @(posedge clk) begin
    if (~rst_n) lfsr <= 8'h5A;
    else        lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
  end

  // ------------------------------------------------------------------
  // Estado del juego
  // ------------------------------------------------------------------
  reg [1:0]        state;
  reg              btn_prev;        // botón en el frame anterior (detección de flanco)
  reg [6:0]        frog_h;          // altura de la rana sobre el suelo (px)
  reg signed [4:0] frog_v;          // velocidad vertical (px/frame, + hacia arriba)
  reg [9:0]        obs0_x, obs1_x;  // borde izquierdo de cada obstáculo
  reg [1:0]        obs0_t, obs1_t;  // tipo de cada obstáculo
  reg [7:0]        scroll;          // desplazamiento del fondo
  reg [2:0]        presc;           // divide frames para el puntaje y la animación
  reg [3:0]        sc2, sc1, sc0;   // puntaje BCD (centenas, decenas, unidades)
  reg              hit;             // colisión detectada durante el barrido del frame

  wire btn_rise = btn & ~btn_prev;

  // Nivel 0..3 según las centenas: fija la velocidad y la hora del día
  wire [1:0] level = (sc2 >= 4'd3) ? 2'd3 : sc2[1:0];
  wire [2:0] speed = 3'd4 + {1'b0, level};

  // Física del salto (aritmética con signo de 8 bits)
  wire signed [7:0] h_next = $signed({1'b0, frog_h}) + {{3{frog_v[4]}}, frog_v};
  wire grounded = (frog_h == 7'd0) && (frog_v == 5'sd0);

  // Reaparición: al menos MIN_GAP detrás del otro obstáculo, más un extra aleatorio
  wire [9:0] spawn_rand = SPAWN_X + {3'b000, lfsr[6:0]};
  wire [9:0] after1     = obs1_x + MIN_GAP;
  wire [9:0] after0     = obs0_x + MIN_GAP;
  wire [9:0] spawn0     = (after1 > spawn_rand) ? after1 : spawn_rand;
  wire [9:0] spawn1     = (after0 > spawn_rand) ? after0 : spawn_rand;

  // Tipo aleatorio; los tucanes solo aparecen desde los 100 puntos
  function [1:0] pick_type;
    input [1:0] r;
    input       birds_ok;
    begin
      pick_type = (r == T_BIRD && !birds_ok) ? T_LOG : r;
    end
  endfunction
  wire birds_ok = (sc2 != 4'd0);

  always @(posedge clk) begin
    if (~rst_n) begin
      state    <= S_IDLE;
      btn_prev <= 1'b0;
      frog_h   <= 7'd0;
      frog_v   <= 5'sd0;
      obs0_x   <= SPAWN_X;
      obs1_x   <= 10'd960;
      obs0_t   <= T_LOG;
      obs1_t   <= T_BAMBOO;
      scroll   <= 8'd0;
      presc    <= 3'd0;
      {sc2, sc1, sc0} <= 12'h000;
    end else if (frame_tick) begin
      btn_prev <= btn;

      case (state)
        // ---------------- Esperando inicio / reinicio ----------------
        S_IDLE, S_OVER: begin
          if (btn_rise) begin
            state  <= S_RUN;
            frog_h <= 7'd0;
            frog_v <= 5'sd0;
            obs0_x <= SPAWN_X;
            obs1_x <= 10'd960;
            obs0_t <= {1'b0, lfsr[0]};          // al inicio: tronco o bambú
            obs1_t <= pick_type({lfsr[2], lfsr[3]}, 1'b0);
            presc  <= 3'd0;
            {sc2, sc1, sc0} <= 12'h000;
          end
        end

        // ---------------- Jugando ----------------
        S_RUN: begin
          if (hit) begin
            state <= S_OVER;
          end else begin
            // --- Rana: salto con gravedad de 1 px/frame^2 ---
            if (grounded) begin
              if (btn) frog_v <= $signed(JUMP_V);
            end else if (h_next <= 8'sd0) begin
              frog_h <= 7'd0;               // aterrizaje
              frog_v <= 5'sd0;
            end else begin
              frog_h <= h_next[6:0];
              // soltar el botón mientras sube duplica la gravedad (salto más bajo)
              if (~btn && (frog_v > 5'sd0))
                frog_v <= frog_v - 5'sd2;
              else
                frog_v <= frog_v - 5'sd1;
            end

            // --- Obstáculos: avanzan a la izquierda y reaparecen a la derecha ---
            if (obs0_x <= {7'd0, speed}) begin
              obs0_x <= spawn0;
              obs0_t <= pick_type(lfsr[7:6], birds_ok);
            end else begin
              obs0_x <= obs0_x - {7'd0, speed};
            end

            if (obs1_x <= {7'd0, speed}) begin
              obs1_x <= spawn1;
              obs1_t <= pick_type(lfsr[3:2], birds_ok);
            end else begin
              obs1_x <= obs1_x - {7'd0, speed};
            end

            scroll <= scroll + {5'd0, speed};

            // --- Puntaje BCD: +1 cada 8 frames (~7.5 puntos/s) ---
            presc <= presc + 3'd1;
            if (presc == 3'd7) begin
              if (sc0 != 4'd9) sc0 <= sc0 + 4'd1;
              else begin
                sc0 <= 4'd0;
                if (sc1 != 4'd9) sc1 <= sc1 + 4'd1;
                else begin
                  sc1 <= 4'd0;
                  sc2 <= (sc2 == 4'd9) ? 4'd0 : sc2 + 4'd1;
                end
              end
            end
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  // ------------------------------------------------------------------
  // Rana: sprite 16x16 escalado x2 (32x32) en x = 64..95, dos colores
  // ------------------------------------------------------------------
  wire [9:0] frog_top = FROG_TOP - {3'd0, frog_h};
  wire [9:0] frog_dy  = pix_y - frog_top;
  wire in_frog  = (pix_x[9:5] == 5'd2) && (frog_dy[9:5] == 5'd0);
  wire [3:0] frog_row = frog_dy[4:1];
  wire [3:0] frog_col = pix_x[4:1];
  wire frog_air = ~grounded;

  reg [15:0] frog_m, frog_a;
  // ---- Rana: silueta (frog_m) y acento (frog_a) ----
  always @(*) begin
    case ({frog_air, frog_row})
      {1'b0, 4'd5}, {1'b1, 4'd5}: begin frog_m = 16'b0000000000111000; frog_a = 16'b0000000000000000; end
      {1'b0, 4'd6}, {1'b1, 4'd6}: begin frog_m = 16'b0000000001111100; frog_a = 16'b0000000000010000; end
      {1'b0, 4'd7}, {1'b1, 4'd7}: begin frog_m = 16'b0000011111111110; frog_a = 16'b0000000000000000; end
      {1'b0, 4'd8}, {1'b1, 4'd8}: begin frog_m = 16'b0001111111111111; frog_a = 16'b0000000000000000; end
      {1'b0, 4'd9}, {1'b1, 4'd9}: begin frog_m = 16'b0011111111111111; frog_a = 16'b0000000110000000; end
      {1'b0, 4'd10}, {1'b1, 4'd10}: begin frog_m = 16'b0111111111111110; frog_a = 16'b0000000000011110; end
      {1'b0, 4'd11}, {1'b1, 4'd11}: begin frog_m = 16'b0111111111111110; frog_a = 16'b0000110000000000; end
      {1'b0, 4'd12}, {1'b1, 4'd12}: begin frog_m = 16'b0011111111111100; frog_a = 16'b0000000000000000; end
      {1'b0, 4'd13}: begin frog_m = 16'b0111110000011000; frog_a = 16'b0000000000000000; end
      {1'b0, 4'd14}: begin frog_m = 16'b1111110000011000; frog_a = 16'b0000000000000000; end
      {1'b0, 4'd15}: begin frog_m = 16'b1111000000111100; frog_a = 16'b0000000000000000; end
      {1'b1, 4'd13}: begin frog_m = 16'b0001111111110000; frog_a = 16'b0000000000000000; end
      {1'b1, 4'd14}: begin frog_m = 16'b1100000000001000; frog_a = 16'b0000000000000000; end
      {1'b1, 4'd15}: begin frog_m = 16'b0110000000000100; frog_a = 16'b0000000000000000; end
      default: begin frog_m = 16'd0; frog_a = 16'd0; end
    endcase
  end


  wire frog_m_px = in_frog && frog_m[4'd15 - frog_col];
  wire frog_a_px = in_frog && frog_a[4'd15 - frog_col];

  // ------------------------------------------------------------------
  // Obstáculos: 32 px de ancho. Como siempre están separados más de 32 px,
  // en cada columna de pantalla hay como máximo uno, y comparten la ROM.
  // ------------------------------------------------------------------
  wire [9:0] dx0 = pix_x - obs0_x;
  wire [9:0] dx1 = pix_x - obs1_x;
  wire in0 = (dx0[9:5] == 5'd0);
  wire in1 = (dx1[9:5] == 5'd0);
  wire [1:0] obs_type = in0 ? obs0_t : obs1_t;
  wire [4:0] odx      = in0 ? dx0[4:0] : dx1[4:0];
  wire       in_obs_x = in0 | in1;

  // Sprites 16x12 escalados x2 (32x24): tronco, cangrejo y tucán
  wire [9:0] obs_top = (obs_type == T_BIRD) ? BIRD_TOP : OBS_TOP;
  wire [9:0] ody     = pix_y - obs_top;
  wire [3:0] obs_row = ody[4:1];
  wire [3:0] obs_col = odx[4:1];
  wire       obs_anim = presc[2];
  wire in_obs_spr = in_obs_x && (obs_type != T_BAMBOO) &&
                    (ody[9:5] == 5'd0) && (obs_row < 4'd12);

  reg [15:0] obs_m, obs_a;
  // ---- Obstáculos con sprite: {tipo, animación, fila} ----
  always @(*) begin
    case ({obs_type, obs_anim, obs_row})
      {2'd0, 1'b0, 4'd4}: begin obs_m = 16'b0011111111111100; obs_a = 16'b0000000000000000; end
      {2'd0, 1'b0, 4'd5}: begin obs_m = 16'b0111111111111111; obs_a = 16'b0111000001000000; end
      {2'd0, 1'b0, 4'd6}: begin obs_m = 16'b1111111111111111; obs_a = 16'b1010100000000010; end
      {2'd0, 1'b0, 4'd7}: begin obs_m = 16'b1111111111111111; obs_a = 16'b1101100001000000; end
      {2'd0, 1'b0, 4'd8}: begin obs_m = 16'b1111111111111111; obs_a = 16'b1010100000001000; end
      {2'd0, 1'b0, 4'd9}: begin obs_m = 16'b0111111111111111; obs_a = 16'b0111000000000000; end
      {2'd0, 1'b0, 4'd10}: begin obs_m = 16'b0011111111111100; obs_a = 16'b0000000000000000; end
      {2'd0, 1'b1, 4'd4}: begin obs_m = 16'b0011111111111100; obs_a = 16'b0000000000000000; end
      {2'd0, 1'b1, 4'd5}: begin obs_m = 16'b0111111111111111; obs_a = 16'b0111000001000000; end
      {2'd0, 1'b1, 4'd6}: begin obs_m = 16'b1111111111111111; obs_a = 16'b1010100000000010; end
      {2'd0, 1'b1, 4'd7}: begin obs_m = 16'b1111111111111111; obs_a = 16'b1101100001000000; end
      {2'd0, 1'b1, 4'd8}: begin obs_m = 16'b1111111111111111; obs_a = 16'b1010100000001000; end
      {2'd0, 1'b1, 4'd9}: begin obs_m = 16'b0111111111111111; obs_a = 16'b0111000000000000; end
      {2'd0, 1'b1, 4'd10}: begin obs_m = 16'b0011111111111100; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd0}: begin obs_m = 16'b0110000000000110; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd1}: begin obs_m = 16'b1110000000000111; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd2}: begin obs_m = 16'b1010000000000101; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd3}: begin obs_m = 16'b0110000000000110; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd4}: begin obs_m = 16'b0010010000100100; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd5}: begin obs_m = 16'b0010010000100100; obs_a = 16'b0000010000100000; end
      {2'd2, 1'b0, 4'd6}: begin obs_m = 16'b0001111111111000; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd7}: begin obs_m = 16'b0011111111111100; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd8}: begin obs_m = 16'b0111111111111110; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd9}: begin obs_m = 16'b0011111111111100; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd10}: begin obs_m = 16'b0010101001010100; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b0, 4'd11}: begin obs_m = 16'b0101010000101010; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd0}: begin obs_m = 16'b0110000000000110; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd1}: begin obs_m = 16'b1110000000000111; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd2}: begin obs_m = 16'b1010000000000101; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd3}: begin obs_m = 16'b0110000000000110; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd4}: begin obs_m = 16'b0010010000100100; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd5}: begin obs_m = 16'b0010010000100100; obs_a = 16'b0000010000100000; end
      {2'd2, 1'b1, 4'd6}: begin obs_m = 16'b0001111111111000; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd7}: begin obs_m = 16'b0011111111111100; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd8}: begin obs_m = 16'b0111111111111110; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd9}: begin obs_m = 16'b0011111111111100; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd10}: begin obs_m = 16'b0010101001010100; obs_a = 16'b0000000000000000; end
      {2'd2, 1'b1, 4'd11}: begin obs_m = 16'b0010101001010100; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b0, 4'd0}: begin obs_m = 16'b0000000000111000; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b0, 4'd1}: begin obs_m = 16'b0000000000111100; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b0, 4'd2}: begin obs_m = 16'b0000000001111100; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b0, 4'd3}: begin obs_m = 16'b0000000011111000; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b0, 4'd4}: begin obs_m = 16'b0000000111110000; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b0, 4'd5}: begin obs_m = 16'b0011011111111100; obs_a = 16'b0011000000000000; end
      {2'd3, 1'b0, 4'd6}: begin obs_m = 16'b1111111111111110; obs_a = 16'b1111100000000000; end
      {2'd3, 1'b0, 4'd7}: begin obs_m = 16'b0011111111110000; obs_a = 16'b0011100000000000; end
      {2'd3, 1'b0, 4'd8}: begin obs_m = 16'b0000001111000000; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b1, 4'd5}: begin obs_m = 16'b0011011111111100; obs_a = 16'b0011000000000000; end
      {2'd3, 1'b1, 4'd6}: begin obs_m = 16'b1111111111111110; obs_a = 16'b1111100000000000; end
      {2'd3, 1'b1, 4'd7}: begin obs_m = 16'b0011111111111110; obs_a = 16'b0011100000000000; end
      {2'd3, 1'b1, 4'd8}: begin obs_m = 16'b0000000111110000; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b1, 4'd9}: begin obs_m = 16'b0000000011111000; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b1, 4'd10}: begin obs_m = 16'b0000000001111000; obs_a = 16'b0000000000000000; end
      {2'd3, 1'b1, 4'd11}: begin obs_m = 16'b0000000000110000; obs_a = 16'b0000000000000000; end
      default: begin obs_m = 16'd0; obs_a = 16'd0; end
    endcase
  end

  wire obs_m_px = in_obs_spr && obs_m[4'd15 - obs_col];
  wire obs_a_px = in_obs_spr && obs_a[4'd15 - obs_col];

  // Bambú (procedural): tallo de 8 px, 48 px de alto, nudos cada 16 px y una hoja
  wire [9:0] hy = (GROUND_Y - 10'd1) - pix_y;   // altura del píxel sobre el suelo
  wire hy_ok = (hy[9:6] == 4'd0) && (hy[5:0] < 6'd48);
  wire bamboo_px = in_obs_x && (obs_type == T_BAMBOO) && hy_ok && (
      (odx >= 5'd12 && odx <= 5'd19) ||                                     // tallo
      (odx >= 5'd11 && odx <= 5'd20 && hy[3:1] == 3'd7) ||                  // nudos
      (odx >= 5'd20 && odx <= 5'd27 && hy[5:0] >= 6'd34 && hy[5:0] <= 6'd36) ||
      (odx >= 5'd24 && odx <= 5'd29 && hy[5:0] >= 6'd37 && hy[5:0] <= 6'd38));  // hoja

  wire obs_px = obs_m_px | bamboo_px;

  // ------------------------------------------------------------------
  // Colisión por píxel: si en algún píxel visible coinciden rana y
  // obstáculo durante el barrido, el frame cuenta como choque.
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (~rst_n || frame_tick) hit <= 1'b0;
    else if (video_active && frog_m_px && obs_px) hit <= 1'b1;
  end

  // ------------------------------------------------------------------
  // Fondo: colinas con paralaje, pasto, tierra con piedras y estrellas
  // ------------------------------------------------------------------
  wire [6:0] hx   = pix_x[6:0] + scroll[7:1];          // colinas a media velocidad
  wire [5:0] tri_w = hx[6] ? ~hx[5:0] : hx[5:0];       // onda triangular 0..63
  wire hill  = (pix_y < GROUND_Y) && (pix_y >= 10'd360 - {5'd0, tri_w[5:1]});
  wire grass = (pix_y >= GROUND_Y) && (pix_y < GROUND_Y + 10'd4);
  wire soil  = (pix_y >= GROUND_Y + 10'd4);
  wire [7:0] tex = pix_x[7:0] + scroll;
  wire pebble = ((pix_y[9:1] == 9'd205) && (tex[5:2] == 4'd0)) ||    // y = 410..411
                ((pix_y[9:1] == 9'd210) && (tex[6:3] == 4'd5));      // y = 420..421
  wire night = (level == 2'd3);
  // Estrellas: una por fila de bloques de 8x8, columna dada por una permutación
  // de bits de la fila (no cuesta lógica, solo cableado)
  wire [5:0] yb = pix_y[8:3];
  wire [5:0] star_col = {yb[2], yb[0], yb[4], yb[1], yb[5], yb[3]} ^ 6'b101101;
  wire star  = night && (pix_y < 10'd320) && (pix_x[2:1] == 2'd0) && (pix_y[2:1] == 2'd0) &&
               (pix_x[8:3] == star_col);

  // ------------------------------------------------------------------
  // Puntaje: 3 dígitos de 7 segmentos dibujados en x = 560..607, y = 32..63
  // ------------------------------------------------------------------
  function [6:0] seg7;  // {a,b,c,d,e,f,g}
    input [3:0] d;
    begin
      case (d)
        4'd0: seg7 = 7'b1111110;
        4'd1: seg7 = 7'b0110000;
        4'd2: seg7 = 7'b1101101;
        4'd3: seg7 = 7'b1111001;
        4'd4: seg7 = 7'b0110011;
        4'd5: seg7 = 7'b1011011;
        4'd6: seg7 = 7'b1011111;
        4'd7: seg7 = 7'b1110000;
        4'd8: seg7 = 7'b1111111;
        4'd9: seg7 = 7'b1111011;
        default: seg7 = 7'b0000000;
      endcase
    end
  endfunction

  wire in_score = (pix_y[9:5] == 5'd1) && (pix_x[9:4] >= 6'd35) && (pix_x[9:4] <= 6'd37);
  wire [3:0] digit = (pix_x[9:4] == 6'd35) ? sc2 :
                     (pix_x[9:4] == 6'd36) ? sc1 : sc0;
  wire [6:0] segs = seg7(digit);
  wire [3:0] lx = pix_x[3:0];
  wire [4:0] ly = pix_y[4:0];
  wire col_l = (lx < 4'd4);
  wire col_r = (lx >= 4'd8) && (lx < 4'd12);
  wire row_t = (ly < 5'd14);
  wire row_b = (ly >= 5'd10) && (ly < 5'd24);
  wire in_w  = (lx < 4'd12);
  wire score_px = in_score && (
      (segs[6] && in_w && ly < 5'd4)                  ||  // a
      (segs[5] && col_r && row_t)                     ||  // b
      (segs[4] && col_r && row_b)                     ||  // c
      (segs[3] && in_w && ly >= 5'd20 && ly < 5'd24)  ||  // d
      (segs[2] && col_l && row_b)                     ||  // e
      (segs[1] && col_l && row_t)                     ||  // f
      (segs[0] && in_w && ly >= 5'd10 && ly < 5'd14));    // g

  // ------------------------------------------------------------------
  // Mezcla de capas y colores (RRGGBB, 2 bits por canal)
  // ------------------------------------------------------------------
  reg [5:0] sky;
  always @(*) begin
    case (level)
      2'd0:    sky = 6'b01_10_11;   // día
      2'd1:    sky = 6'b10_10_11;   // tarde
      2'd2:    sky = 6'b11_10_01;   // atardecer
      default: sky = 6'b00_00_10;   // noche
    endcase
  end

  reg [5:0] obs_color;
  always @(*) begin
    case (obs_type)
      T_LOG:    obs_color = obs_a_px ? 6'b01_00_00 : 6'b10_01_00;  // tronco
      T_BAMBOO: obs_color = 6'b10_11_00;                           // bambú
      T_CRAB:   obs_color = obs_a_px ? 6'b00_00_00 : 6'b11_00_00;  // cangrejo
      default:  obs_color = obs_a_px ? 6'b11_10_00 : 6'b00_00_00;  // tucán (pico naranja)
    endcase
  end

  reg [5:0] rgb;
  always @(*) begin
    if (score_px)
      rgb = night ? 6'b11_11_11 : 6'b00_00_00;
    else if (frog_m_px)
      rgb = frog_a_px ? 6'b00_00_00 :
            (state == S_OVER) ? 6'b11_00_00 : 6'b11_10_00;     // rana dorada (roja al perder)
    else if (obs_px)
      rgb = obs_color;
    else if (grass)
      rgb = 6'b00_10_00;
    else if (soil)
      rgb = pebble ? 6'b01_00_00 : 6'b10_01_00;
    else if (hill)
      rgb = night ? 6'b00_01_01 : 6'b00_10_01;
    else if (star)
      rgb = 6'b11_11_11;
    else
      rgb = sky;
  end

  assign R = video_active ? rgb[5:4] : 2'b00;
  assign G = video_active ? rgb[3:2] : 2'b00;
  assign B = video_active ? rgb[1:0] : 2'b00;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in[7], ui_in[3:1], uio_in, frog_dy[0], ody[0], odx[0],
                      tex[7], tex[1:0], hy[0],
                      gp_y, gp_select, gp_start, gp_down, gp_left, gp_right,
                      gp_x, gp_l, gp_r, gp_present};

endmodule
