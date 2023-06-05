//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 03/28/2023 02:52:57 PM
// Design Name: 
// Module Name: aes_enc_round
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`default_nettype none

module aes_enc_round(
                     input wire            clk,
                     input wire            reset_n,

                     input wire            start,
                     input wire [127 : 0]  round_key,

                     output wire [31 : 0]  sboxw_i,
                     input wire  [31 : 0]  sboxw_o,

                     input wire [127 : 0]  block_i,
                     output wire [127 : 0] block_o,
                     output wire           ready
                     );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam CTRL_IDLE  = 2'h0;
  localparam CTRL_SBOX  = 2'h1;
  localparam CTRL_MAIN  = 2'h2;
  
  localparam NO_UPDATE    = 2'h0;
  localparam SBOX_UPDATE  = 2'h1;
  localparam MAIN_UPDATE  = 2'h2;

  //----------------------------------------------------------------
  // Round functions with sub functions.
  //----------------------------------------------------------------
  function [7 : 0] gm2(input [7 : 0] op);
    begin
      gm2 = {op[6 : 0], 1'b0} ^ (8'h1b & {8{op[7]}});
    end
  endfunction // gm2

  function [7 : 0] gm3(input [7 : 0] op);
    begin
      gm3 = gm2(op) ^ op;
    end
  endfunction // gm3

  function [31 : 0] mixw(input [31 : 0] w);
    reg [7 : 0] b0, b1, b2, b3;
    reg [7 : 0] mb0, mb1, mb2, mb3;
    begin
      b0 = w[31 : 24];
      b1 = w[23 : 16];
      b2 = w[15 : 08];
      b3 = w[07 : 00];

      mb0 = gm2(b0) ^ gm3(b1) ^ b2      ^ b3;
      mb1 = b0      ^ gm2(b1) ^ gm3(b2) ^ b3;
      mb2 = b0      ^ b1      ^ gm2(b2) ^ gm3(b3);
      mb3 = gm3(b0) ^ b1      ^ b2      ^ gm2(b3);

      mixw = {mb0, mb1, mb2, mb3};
    end
  endfunction // mixw

  function [127 : 0] mixcolumns(input [127 : 0] data);
    reg [31 : 0] w0, w1, w2, w3;
    reg [31 : 0] ws0, ws1, ws2, ws3;
    begin
      w0 = data[127 : 096];
      w1 = data[095 : 064];
      w2 = data[063 : 032];
      w3 = data[031 : 000];

      ws0 = mixw(w0);
      ws1 = mixw(w1);
      ws2 = mixw(w2);
      ws3 = mixw(w3);

      mixcolumns = {ws0, ws1, ws2, ws3};
    end
  endfunction // mixcolumns

  function [127 : 0] shiftrows(input [127 : 0] data);
    reg [31 : 0] w0, w1, w2, w3;
    reg [31 : 0] ws0, ws1, ws2, ws3;
    begin
      w0 = data[127 : 096];
      w1 = data[095 : 064];
      w2 = data[063 : 032];
      w3 = data[031 : 000];

      ws0 = {w0[31 : 24], w1[23 : 16], w2[15 : 08], w3[07 : 00]};
      ws1 = {w1[31 : 24], w2[23 : 16], w3[15 : 08], w0[07 : 00]};
      ws2 = {w2[31 : 24], w3[23 : 16], w0[15 : 08], w1[07 : 00]};
      ws3 = {w3[31 : 24], w0[23 : 16], w1[15 : 08], w2[07 : 00]};

      shiftrows = {ws0, ws1, ws2, ws3};
    end
  endfunction // shiftrows

  function [127 : 0] addroundkey(input [127 : 0] data, input [127 : 0] rkey);
    begin
      addroundkey = data ^ rkey;
    end
  endfunction // addroundkey


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [1 : 0]   sword_ctr_reg;
  reg [1 : 0]   sword_ctr_new;
  reg           sword_ctr_we;
  reg           sword_ctr_inc;
  reg           sword_ctr_rst;

  reg [127 : 0] block_new;
  reg [31 : 0]  block_w0_reg;
  reg [31 : 0]  block_w1_reg;
  reg [31 : 0]  block_w2_reg;
  reg [31 : 0]  block_w3_reg;
  reg           block_w0_we;
  reg           block_w1_we;
  reg           block_w2_we;
  reg           block_w3_we;

  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;

  reg [1 : 0]   enc_round_ctrl_reg;
  reg [1 : 0]   enc_round_ctrl_new;
  reg           enc_round_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0] muxed_sboxw;
  reg [2 : 0]  update_type;

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign sboxw_i = muxed_sboxw;
  assign block_o = {block_w0_reg, block_w1_reg, block_w2_reg, block_w3_reg};
  assign ready   = ready_reg;


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin: reg_update
      if (!reset_n)
        begin
          block_w0_reg  <= 32'h0;
          block_w1_reg  <= 32'h0;
          block_w2_reg  <= 32'h0;
          block_w3_reg  <= 32'h0;
          sword_ctr_reg <= 2'h0;
          ready_reg     <= 1'b1;
          enc_round_ctrl_reg  <= CTRL_IDLE;
        end
      else
        begin
          if (block_w0_we)
            block_w0_reg <= block_new[127 : 096];

          if (block_w1_we)
            block_w1_reg <= block_new[095 : 064];

          if (block_w2_we)
            block_w2_reg <= block_new[063 : 032];

          if (block_w3_we)
            block_w3_reg <= block_new[031 : 000];

          if (sword_ctr_we)
            sword_ctr_reg <= sword_ctr_new;

          if (ready_we)
            ready_reg <= ready_new;

          if (enc_round_ctrl_we)
            enc_round_ctrl_reg <= enc_round_ctrl_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // round_logic
  //
  // The logic needed to implement init, main and final rounds.
  //----------------------------------------------------------------
  always @*
    begin : round_logic
      reg [127 : 0] old_block, shiftrows_block, mixcolumns_block;
      reg [127 : 0] addkey_init_block, addkey_main_block, addkey_final_block;

      block_new   = 128'h0;
      muxed_sboxw = 32'h0;
      block_w0_we = 1'b0;
      block_w1_we = 1'b0;
      block_w2_we = 1'b0;
      block_w3_we = 1'b0;

      old_block          = {block_w0_reg, block_w1_reg, block_w2_reg, block_w3_reg};
      shiftrows_block    = shiftrows(old_block);
      mixcolumns_block   = mixcolumns(shiftrows_block);
      addkey_main_block  = addroundkey(mixcolumns_block, round_key);

      case (update_type)
        SBOX_UPDATE:
          begin
            block_new = {sboxw_o, sboxw_o, sboxw_o, sboxw_o};
            case (sword_ctr_reg)
              2'h0:
                begin
                  muxed_sboxw = block_i[127 : 096];
                  block_w0_we = 1'b1;
                end

              2'h1:
                begin
                  muxed_sboxw = block_i[095 : 064];
                  block_w1_we = 1'b1;
                end

              2'h2:
                begin
                  muxed_sboxw = block_i[063 : 032];
                  block_w2_we = 1'b1;
                end

              2'h3:
                begin
                  muxed_sboxw = block_i[031 : 000];
                  block_w3_we = 1'b1;
                end
            endcase // case (sbox_mux_ctrl_reg)
          end

        MAIN_UPDATE:
          begin
            block_new    = addkey_main_block;
            block_w0_we  = 1'b1;
            block_w1_we  = 1'b1;
            block_w2_we  = 1'b1;
            block_w3_we  = 1'b1;
          end

        default:
          begin
          end
      endcase // case (update_type)
    end // round_logic


  //----------------------------------------------------------------
  // sword_ctr
  //
  // The subbytes word counter with reset and increase logic.
  //----------------------------------------------------------------
  always @*
    begin : sword_ctr
      sword_ctr_new = 2'h0;
      sword_ctr_we  = 1'b0;

      if (sword_ctr_rst)
        begin
          sword_ctr_new = 2'h0;
          sword_ctr_we  = 1'b1;
        end
      else if (sword_ctr_inc)
        begin
          sword_ctr_new = sword_ctr_reg + 1'b1;
          sword_ctr_we  = 1'b1;
        end
    end // sword_ctr


  //----------------------------------------------------------------
  // enc_round_ctrl
  //
  // The FSM that controls the encipher operations.
  //----------------------------------------------------------------
  always @*
    begin: enc_round_ctrl
      // Default assignments.
      sword_ctr_inc = 1'b0;
      sword_ctr_rst = 1'b0;
      ready_new     = 1'b0;
      ready_we      = 1'b0;
      update_type   = NO_UPDATE;
      enc_round_ctrl_new  = CTRL_IDLE;
      enc_round_ctrl_we   = 1'b0;

      case(enc_round_ctrl_reg)
        CTRL_IDLE:
          begin
            if (start)
              begin
                ready_new     = 1'b0;
                ready_we      = 1'b1;
                enc_round_ctrl_new  = CTRL_SBOX;
                enc_round_ctrl_we   = 1'b1;
              end
          end

        CTRL_SBOX:
          begin
            sword_ctr_inc = 1'b1;
            update_type   = SBOX_UPDATE;
            if (sword_ctr_reg == 2'h3)
              begin
                enc_round_ctrl_new  = CTRL_MAIN;
                enc_round_ctrl_we   = 1'b1;
              end
          end

        CTRL_MAIN:
          begin
            sword_ctr_rst     = 1'b1;
            update_type       = MAIN_UPDATE;
            enc_round_ctrl_we = 1'b1;
            ready_new         = 1'b1;
            ready_we          = 1'b1;
          end

        default:
          begin
            // Empty. Just here to make the synthesis tool happy.
          end
      endcase // case (enc_round_ctrl_reg)
    end // enc_round_ctrl

endmodule // aes_enc_round
