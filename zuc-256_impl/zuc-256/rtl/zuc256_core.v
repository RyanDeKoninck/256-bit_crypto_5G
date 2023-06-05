//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/20/2023 15:12:00
// Design Name: 
// Module Name: zuc256_core
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

module zuc256_core(
           input wire            clk,
           input wire            reset_n,
           
           input wire            init,
           input wire            next,
           input wire [255 : 0]  key,
           input wire [127 : 0]  iv,
           input wire [7 : 0]    tag_len,
           
           output wire [31 : 0] keystream_z,
           output wire          ready
          );
  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------        
  localparam CTRL_IDLE  = 3'h0;
  localparam CTRL_LOAD  = 3'h1;
  localparam CTRL_INIT  = 3'h2;
  localparam CTRL_NEXT  = 3'h3;
  
  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg [2 : 0]   zuc256_ctrl_reg;
  reg [2 : 0]   zuc256_ctrl_new;
  reg           zuc256_ctrl_we;
  
  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;
  
  // LFSRs
  reg [30 : 0]  lfsr_reg[0 : 15];
  reg [30 : 0]  lfsr_new[0 : 15];
  reg           lfsr_we;
  
  // FSM
  reg [31 : 0]  R1_reg;
  reg [31 : 0]  R1_new;
  reg           R1_we;
  
  reg [31 : 0]  R2_reg;
  reg [31 : 0]  R2_new;
  reg           R2_we;
  
  reg [15 : 0]  W1H_reg;
  reg [15 : 0]  W1H_new;
  reg           W1H_we;
  
  reg [31 : 0]   W_reg;
  reg [31 : 0]   W_new;
  reg            W_we;
  
  reg [31 : 0]   z_reg;
  reg [31 : 0]   z_new;
  reg            z_we;
    
  // Counter to count the number of cycles
  reg [7 : 0]   counter_reg;
  reg [7 : 0]   counter_new;
  reg           counter_we;
  reg           counter_inc;
  reg           counter_rst;
  
  // Extra control signals
  reg            came_from_init_reg;
  reg            came_from_init_new;
  reg            came_from_init_we;
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  
  reg [31 : 0]   X0;
  reg [31 : 0]   X1;
  reg [31 : 0]   X2;
  reg [31 : 0]   X3;
  
  wire [31 : 0]  W_shifted;
  
  // Connections with instantiations.
  reg [31 : 0]   zuc256_sboxw_i;
  wire [31 : 0]  zuc256_sboxw_o;
  
  reg            zuc256_modadd_start;
  wire [30 : 0]  zuc256_modadd_s15;
  wire [30 : 0]  zuc256_modadd_s13;
  wire [30 : 0]  zuc256_modadd_s10;
  wire [30 : 0]  zuc256_modadd_s4;
  wire [30 : 0]  zuc256_modadd_s0;
  wire [30 : 0]  zuc256_modadd_W_shifted;
  wire           zuc256_modadd_came_from_init;
  wire [30 : 0]  zuc256_modadd_out;
  wire           zuc256_modadd_ready;
  
  // Extra control signals
  wire           phase;
    
  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  zuc256_sbox sbox(
                   .sboxw(zuc256_sboxw_i),
                   .new_sboxw(zuc256_sboxw_o)
                   );
                
  zuc256_modadd full_modadd(
                            .clk(clk),
                            .reset_n(reset_n),
                            .start(zuc256_modadd_start),
                            .s15(zuc256_modadd_s15),
                            .s13(zuc256_modadd_s13),
                            .s10(zuc256_modadd_s10),
                            .s4(zuc256_modadd_s4),
                            .s0(zuc256_modadd_s0),
                            .W_shifted(zuc256_modadd_W_shifted),
                            .came_from_init(zuc256_modadd_came_from_init),
                            .out(zuc256_modadd_out),
                            .ready(zuc256_modadd_ready)
                            );
                              
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready                        = ready_reg; 
  assign keystream_z                  = z_reg;
  
  assign zuc256_modadd_s15            = lfsr_reg [15]; 
  assign zuc256_modadd_s13            = lfsr_reg [13]; 
  assign zuc256_modadd_s10            = lfsr_reg [10]; 
  assign zuc256_modadd_s4             = lfsr_reg [4]; 
  assign zuc256_modadd_s0             = lfsr_reg [0];
  assign zuc256_modadd_W_shifted      = W_shifted[30 : 0];
  assign zuc256_modadd_came_from_init = came_from_init_reg;
    
  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin : reg_update
      integer i;
      if (!reset_n)
        begin
          zuc256_ctrl_reg <= CTRL_IDLE;
          ready_reg       <= 1'b0;
          for (i = 0 ; i < 16 ; i = i + 1)
            begin
              lfsr_reg [i] <= 31'h0;
            end
          R1_reg             <= 32'h0;
          R2_reg             <= 32'h0;
          W1H_reg             <= 32'h0;
          counter_reg        <= 8'h0;
          came_from_init_reg <= 1'b0;
          W_reg              <= 32'h0;
          z_reg              <= 32'h0;
        end
      else
        begin
          if (zuc256_ctrl_we)
            zuc256_ctrl_reg <= zuc256_ctrl_new;
          if (ready_we)
            ready_reg <= ready_new;
          if (lfsr_we)
            for (i = 0 ; i < 16 ; i = i + 1)
              begin
                lfsr_reg [i] <= lfsr_new [i];
              end
          if (R1_we)
            R1_reg  <= R1_new;
          if (R2_we)
            R2_reg  <= R2_new;
          if (W1H_we)
              W1H_reg  <= W1H_new;
          if (W_we)
            W_reg <= W_new;
          if (z_we)
            z_reg <= z_new;
          if (counter_we)
            counter_reg <= counter_new;
          if (came_from_init_we)
            came_from_init_reg <= came_from_init_new;
        end
    end // reg_update
    
  //----------------------------------------------------------------
  // lfsr_logic
  //
  // Update logic for the LFSRs.
  //----------------------------------------------------------------
  always @*
    begin : lfsr_logic
      integer i;
      
      reg [6 : 0] d [0 : 15];
      if (tag_len == 8'd0)
        begin
          d [0]  = 7'b1100100;
          d [1]  = 7'b1000011;
          d [2]  = 7'b1111011;
          d [3]  = 7'b0101010;
          d [4]  = 7'b0010001;
          d [5]  = 7'b0000101;
          d [6]  = 7'b1010001;
          d [7]  = 7'b1000010;
          d [8]  = 7'b0011010;
          d [9]  = 7'b0110001;
          d [10] = 7'b0011000;
          d [11] = 7'b1100110;
          d [12] = 7'b0010100;
          d [13] = 7'b0101110;
          d [14] = 7'b0000001;
          d [15] = 7'b1011100;
        end
      else if (tag_len == 8'd32)
        begin
          d [0]  = 7'b1100100;
          d [1]  = 7'b1000011;
          d [2]  = 7'b1111010;
          d [3]  = 7'b0101010;
          d [4]  = 7'b0010001;
          d [5]  = 7'b0000101;
          d [6]  = 7'b1010001;
          d [7]  = 7'b1000010;
          d [8]  = 7'b0011010;
          d [9]  = 7'b0110001;
          d [10] = 7'b0011000;
          d [11] = 7'b1100110;
          d [12] = 7'b0010100;
          d [13] = 7'b0101110;
          d [14] = 7'b0000001;
          d [15] = 7'b1011100;
        end
      else if (tag_len == 8'd64)
        begin
          d [0]  = 7'b1100101;
          d [1]  = 7'b1000011;
          d [2]  = 7'b1111011;
          d [3]  = 7'b0101010;
          d [4]  = 7'b0010001;
          d [5]  = 7'b0000101;
          d [6]  = 7'b1010001;
          d [7]  = 7'b1000010;
          d [8]  = 7'b0011010;
          d [9]  = 7'b0110001;
          d [10] = 7'b0011000;
          d [11] = 7'b1100110;
          d [12] = 7'b0010100;
          d [13] = 7'b0101110;
          d [14] = 7'b0000001;
          d [15] = 7'b1011100;
        end
      else
        begin
          d [0]  = 7'b1100101;
          d [1]  = 7'b1000011;
          d [2]  = 7'b1111010;
          d [3]  = 7'b0101010;
          d [4]  = 7'b0010001;
          d [5]  = 7'b0000101;
          d [6]  = 7'b1010001;
          d [7]  = 7'b1000010;
          d [8]  = 7'b0011010;
          d [9]  = 7'b0110001;
          d [10] = 7'b0011000;
          d [11] = 7'b1100110;
          d [12] = 7'b0010100;
          d [13] = 7'b0101110;
          d [14] = 7'b0000001;
          d [15] = 7'b1011100;
        end
      
      if (zuc256_ctrl_reg == CTRL_LOAD)
        begin
          lfsr_new [0]  = {key[7 : 0], d [0], key[135 : 128], key[199 : 192]};
          lfsr_new [1]  = {key[15 : 8], d [1], key[143 : 136], key[207 : 200]};
          lfsr_new [2]  = {key[23 : 16], d [2], key[151 : 144], key[215 : 208]};
          lfsr_new [3]  = {key[31 : 24], d [3], key[159 : 152], key[223 : 216]};
          lfsr_new [4]  = {key[39 : 32], d [4], key[167 : 160], key[231 : 224]};
          lfsr_new [5]  = {key[47 : 40], d [5], key[175 : 168], key[239 : 232]};
          lfsr_new [6]  = {key[55 : 48], d [6], key[183 : 176], key[247 : 240]};
          lfsr_new [7]  = {key[63 : 56], d [7], iv[7 : 0], iv[71 : 64]};
          lfsr_new [8]  = {key[71 : 64], d [8], iv[15 : 8], iv[79 : 72]};
          lfsr_new [9]  = {key[79 : 72], d [9], iv[23 : 16], iv[87 : 80]};
          lfsr_new [10] = {key[87 : 80], d [10], iv[31 : 24], iv[95 : 88]};
          lfsr_new [11] = {key[95 : 88], d [11], iv[39 : 32], iv[103 : 96]};
          lfsr_new [12] = {key[103 : 96], d [12], iv[47 : 40], iv[111 : 104]};
          lfsr_new [13] = {key[111 : 104], d [13], iv[55 : 48], iv[119 : 112]};
          lfsr_new [14] = {key[119 : 112], d [14], iv[63 : 56], iv[127 : 120]};
          lfsr_new [15] = {key[127 : 120], d [15], key[191 : 184], key[255 : 248]};
        end
      else
        begin
          for (i = 0 ; i < 15 ; i = i + 1)
            begin
              lfsr_new [i] = lfsr_reg [i+1];
            end
          lfsr_new [15] = zuc256_modadd_out;
       end
    end // lfsr_logic
    
  assign W_shifted = W_reg >> 1;
    
  //----------------------------------------------------------------
  // bit_reorganization_logic
  //
  // Update X0, X1, X2 and X3.
  //----------------------------------------------------------------
  always@*
    begin : bit_reorganization
      X0 = {lfsr_reg [15][30 : 15], lfsr_reg [14][15 : 0]};
      X1 = {lfsr_reg [11][15 : 0],  lfsr_reg [9][30 : 15]};
      X2 = {lfsr_reg [7][15 : 0],   lfsr_reg [5][30 : 15]};
      X3 = {lfsr_reg [2][15 : 0],   lfsr_reg [0][30 : 15]};
    end // bit_reorganization
    
  //----------------------------------------------------------------
  // fsm_logic
  //
  // Update and output logic for the FSM.
  //----------------------------------------------------------------
  function [31 : 0] L1(input [31 : 0] x);
    begin
      L1 = x ^ {x[29 : 0], x[31 : 30]} ^ {x[21 : 0], x[31 : 22]} ^ {x[13 : 0], x[31 : 14]} ^ {x[7 : 0], x[31 : 8]};
    end
  endfunction
  
  function [31 : 0] L2(input [31 : 0] x);
    begin
      L2 = x ^ {x[23 : 0], x[31 : 24]} ^ {x[17 : 0], x[31 : 18]} ^ {x[9 : 0], x[31 : 10]} ^ {x[1 : 0], x[31 : 2]};
    end
  endfunction
  
  always @*
    begin : fsm_logic
      reg [31 : 0] W1;
      reg [31 : 0] W2;
      
      // -- FSM update logic
      W1 = R1_reg + X1;
      W2 = R2_reg ^ X2;
      
      W1H_new = W1[31 : 16];
      
      if (phase == 0)
        zuc256_sboxw_i = L1({W1[15 : 0], W2[31 : 16]});
      else
        zuc256_sboxw_i = L2({W2[15 : 0], W1H_reg});
      
      if (zuc256_ctrl_reg == CTRL_LOAD)
        begin
          R1_new  = 64'h0;
          R2_new  = 64'h0;
        end
     else
       begin
          R1_new = zuc256_sboxw_o;
          R2_new = zuc256_sboxw_o;
      end
          
      // -- FSM output logic
      W_new = (X0 ^ R1_reg) + R2_reg;
      z_new = W_reg ^ X3;
      
    end // fsm_logic
  
  //----------------------------------------------------------------
  // counter
  //
  // Counter with reset and increase logic.
  //----------------------------------------------------------------
  always @*
    begin : counter
      counter_new = 8'h0;
      counter_we  = 1'b0;

      if (counter_rst)
        begin
          counter_new = 8'h0;
          counter_we  = 1'b1;
        end
      else if (counter_inc)
        begin
          counter_new = counter_reg + 1'b1;
          counter_we  = 1'b1;
        end
    end // counter
    
  //----------------------------------------------------------------
  // zuc256_ctrl
  //
  // Control FSM for zuc256.
  //----------------------------------------------------------------
  always @*
    begin : zuc256_ctrl
      zuc256_ctrl_new     = CTRL_IDLE;
      zuc256_ctrl_we      = 1'b0;
      ready_new           = 1'b0;
      ready_we            = 1'b0;
      lfsr_we             = 1'b0;
      R1_we               = 1'b0;
      R2_we               = 1'b0;
      W_we                = 1'b0;
      W1H_we              = 1'b0;
      z_we                = 1'b0;
      counter_inc         = 1'b0;
      counter_rst         = 1'b0;
      came_from_init_new  = 1'b0;
      came_from_init_we   = 1'b0;
      zuc256_modadd_start = 1'b0;
      
      case (zuc256_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_new          = 1'b0;
            ready_we           = 1'b1;
            if (init)
              begin
                zuc256_ctrl_new     = CTRL_LOAD;
                zuc256_ctrl_we      = 1'b1;
                came_from_init_new  = 1'b1;
                came_from_init_we   = 1'b1;
              end
            else if (next)
              begin
                zuc256_ctrl_new     = CTRL_NEXT;
                zuc256_ctrl_we      = 1'b1;
                zuc256_modadd_start = 1'b1;
              end
          end
        CTRL_LOAD:
          begin
            lfsr_we             = 1'b1;
            R1_we               = 1'b1;
            R2_we               = 1'b1;
            zuc256_ctrl_new     = CTRL_INIT;
            zuc256_ctrl_we      = 1'b1;
            zuc256_modadd_start = 1'b1;
          end
        CTRL_INIT:
          begin
            if (phase == 0)
              begin
                counter_inc = 1'b1;
                R1_we               = 1'b1;
                W_we                = 1'b1;
                W1H_we              = 1'b1;
              end
            else
              if (zuc256_modadd_ready)
                begin
                  counter_inc         = 1'b1;
                  R2_we               = 1'b1;
                  lfsr_we             = 1'b1;
                  zuc256_modadd_start = 1'b1;
                  if (counter_reg >= 8'd95)
                    begin
                      z_we               = 1'b1;
                      zuc256_ctrl_new    = CTRL_NEXT;
                      zuc256_ctrl_we     = 1'b1;
                      counter_rst        = 1'b1;
                      came_from_init_new = 1'b0;
                      came_from_init_we  = 1'b1;
                    end
                end
          end
        CTRL_NEXT:
          begin
            if (phase == 0)
              begin
                counter_inc         = 1'b1;
                R1_we               = 1'b1;
                W_we                = 1'b1;
                W1H_we              = 1'b1;
              end
            else
              if (zuc256_modadd_ready)
                begin
                  counter_rst     = 1'b1;
                  R2_we           = 1'b1;
                  z_we            = 1'b1;
                  lfsr_we         = 1'b1;
                  zuc256_ctrl_new = CTRL_IDLE;
                  zuc256_ctrl_we  = 1'b1;
                  ready_new       = 1'b1;
                  ready_we        = 1'b1;
                  counter_rst     = 1'b1;
                end
          end
        default: 
          begin
        
          end
      endcase // case (zuc256_ctrl_reg)
    end // zuc256_ctrl
    
  // Other control signals
  assign phase = (counter_reg[0] == 1'b1);
  
endmodule // zuc256_core
