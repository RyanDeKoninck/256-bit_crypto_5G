//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 03/28/2023 10:58:00 AM
// Design Name: 
// Module Name: snowv_core
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

module snowv_core(
           input wire            clk,
           input wire            reset_n,
           
           input wire            aead_mode,
           input wire            init,
           input wire            next,
           input wire [255 : 0]  key,
           input wire [127 : 0]  iv,
           
           output wire [127 : 0] keystream_z,
           output wire           ready
          );
  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------        
  localparam CTRL_IDLE  = 3'h0;
  localparam CTRL_LOAD  = 3'h1;
  localparam CTRL_ROUND = 3'h2;
  localparam CTRL_INIT  = 3'h3;
  localparam CTRL_NEXT  = 3'h4;
  
  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg [2 : 0]   snowv_ctrl_reg;
  reg [2 : 0]   snowv_ctrl_new;
  reg           snowv_ctrl_we;
  
  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;
  
  // LFSRs
  reg [63 : 0]  lfsr_a_reg[0 : 3];
  reg [63 : 0]  lfsr_a_new[0 : 3];
  
  reg [63 : 0]  lfsr_b_reg[0 : 3];
  reg [63 : 0]  lfsr_b_new[0 : 3];
  
  reg           lfsr_we;
  
  // FSM
  reg [63 : 0]  R1a_reg;
  reg [63 : 0]  R1a_new;
  reg [63 : 0]  R1b_reg;
  reg [63 : 0]  R1b_new;
  
  reg [63 : 0]  R2a_reg;
  reg [63 : 0]  R2a_new;
  reg [63 : 0]  R2b_reg;
  reg [63 : 0]  R2b_new;
  
  reg [63 : 0]  R3a_reg;
  reg [63 : 0]  R3a_new;
  reg [63 : 0]  R3b_reg;
  reg [63 : 0]  R3b_new;
  
  reg [63 : 0]  temp_reg;
  reg [63 : 0]  temp_new;
  
  reg [127 : 0] z_reg;
  reg [127 : 0] z_new;
  reg [63 : 0]  keystream_64;
  
  reg           fsm_we;
  
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
  
  // Connections with instantiations.
  reg            aes_round_start;
  wire [127 : 0] aes_round_key;
  wire [31 : 0]  aes_round_sboxw_i;
  wire [31 : 0]  aes_round_sboxw_o;
  reg  [127 : 0] aes_round_block_i;
  wire [127 : 0] aes_round_block_o;
  wire           aes_round_ready;
  
  // Extra control signals.
  wire           phase;
  reg  [1 : 0]   R1_load_key;
    
  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  aes_enc_round aes_enc_round(
                              .clk(clk),
                              .reset_n(reset_n),

                              .start(aes_round_start),
                              .round_key(aes_round_key),

                              .sboxw_i(aes_round_sboxw_i),
                              .sboxw_o(aes_round_sboxw_o),

                              .block_i(aes_round_block_i),
                              .block_o(aes_round_block_o),
                              .ready(aes_round_ready)
                              );
    
  aes_sbox sbox(
                .sboxw(aes_round_sboxw_i),
                .new_sboxw(aes_round_sboxw_o)
                );
                              
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready         = ready_reg; 
  assign aes_round_key = 128'h0; // Key is always set to zero
  assign keystream_z   = z_reg;
    
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
          snowv_ctrl_reg <= CTRL_IDLE;
          ready_reg      <= 1'b0;
          for (i = 0 ; i < 4 ; i = i + 1)
            begin
              lfsr_a_reg [i] <= 64'h0;
              lfsr_b_reg [i] <= 64'h0;
            end
          R1a_reg      <= 64'h0;
          R1b_reg      <= 64'h0;
          R2a_reg      <= 64'h0;
          R2b_reg      <= 64'h0;
          R3a_reg      <= 64'h0;
          R3b_reg      <= 64'h0;
          temp_reg     <= 64'h0;
          z_reg        <= 128'h0;
          counter_reg  <= 8'h0;
          came_from_init_reg <= 1'b0;
        end
      else
        begin
          if (snowv_ctrl_we)
            snowv_ctrl_reg <= snowv_ctrl_new;
          if (ready_we)
            ready_reg <= ready_new;
          if (lfsr_we)
            for (i = 0 ; i < 4 ; i = i + 1)
              begin
                lfsr_a_reg [i] <= lfsr_a_new [i];
                lfsr_b_reg [i] <= lfsr_b_new [i];
              end
          if (fsm_we)
            begin
              R1a_reg  <= R1a_new;
              R1b_reg  <= R1b_new;
              R2a_reg  <= R2a_new;
              R2b_reg  <= R2b_new;
              R3a_reg  <= R3a_new;
              R3b_reg  <= R3b_new;
              temp_reg <= temp_new;
              z_reg    <= z_new;
            end
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
  function [15 : 0] mul_x(input [15 : 0] a, input [15 : 0] b);
    begin
      if (a[15] == 1'b1)
        mul_x = (a << 1) ^ b;
      else
        mul_x = (a << 1);
      end
  endfunction // mul_x
 
  function [15 : 0] mul_x_inv(input [15 : 0] a, input [15 : 0] b);
    begin
      if (a[0] == 1'b1)
        mul_x_inv = (a >> 1) ^ b;
      else
        mul_x_inv = (a >> 1);
      end
  endfunction // mul_x
  
  function [15 : 0] feedback_a(input [15 : 0] a0, input [15 : 0] a1, input [15 : 0] a8, input [15 : 0] b0);
    begin
      feedback_a = mul_x(a0, 16'h990f) ^ a1 ^ mul_x_inv(a8, 16'hcc87) ^ b0;
    end
  endfunction // feedback_a
  
  function [15 : 0] feedback_b(input [15 : 0] b0, input [15 : 0] b3, input [15 : 0] b8, input [15 : 0] a0);
    begin
      feedback_b = mul_x(b0, 16'hc963) ^ b3 ^ mul_x_inv(b8, 16'he4b1) ^ a0;
    end
  endfunction // feedback_b
  
  always @*
    begin : lfsr_logic
      integer i;
      reg [15 : 0] temp_a [0 : 3];
      reg [15 : 0] temp_b [0 : 3];
      reg [63 : 0] lfsr_a3_new_temp;
      
      if (snowv_ctrl_reg == CTRL_LOAD)
        begin
          lfsr_a_new [0] = iv[63 : 0];
          lfsr_a_new [1] = iv[127 : 64];
          lfsr_a_new [2] = key[63 : 0];
          lfsr_a_new [3] = key[127 : 64];
          // If SNOW-V is used in AEAD-mode, then initialize lfsr_b differently
          if (aead_mode == 1'b0)
            begin
              lfsr_b_new [0] = 64'h0;
              lfsr_b_new [1] = 64'h0;
            end
          else
            begin
              lfsr_b_new [0] = {16'h2064, 16'h6B45, 16'h7865, 16'h6C41};
              lfsr_b_new [1] = {16'h6D6F, 16'h6854, 16'h676E, 16'h694A};
            end
          lfsr_b_new [2] = key[191 : 128];
          lfsr_b_new [3] = key[255 : 192];
        end
      else
        begin
          temp_a [0] = feedback_a(lfsr_a_reg [0] [15 : 0] , lfsr_a_reg [0] [31 : 16], lfsr_a_reg [2] [15 : 0] , lfsr_b_reg [0] [15 : 0]);
          temp_a [1] = feedback_a(lfsr_a_reg [0] [31 : 16], lfsr_a_reg [0] [47 : 32], lfsr_a_reg [2] [31 : 16], lfsr_b_reg [0] [31 : 16]);
          temp_a [2] = feedback_a(lfsr_a_reg [0] [47 : 32], lfsr_a_reg [0] [63 : 48], lfsr_a_reg [2] [47 : 32], lfsr_b_reg [0] [47 : 32]);
          temp_a [3] = feedback_a(lfsr_a_reg [0] [63 : 48], lfsr_a_reg [1] [15 : 0] , lfsr_a_reg [2] [63 : 48], lfsr_b_reg [0] [63 : 48]);
          temp_b [0] = feedback_b(lfsr_b_reg [0] [15 : 0] , lfsr_b_reg [0] [63 : 48], lfsr_b_reg [2] [15 : 0] , lfsr_a_reg [0] [15 : 0]);
          temp_b [1] = feedback_b(lfsr_b_reg [0] [31 : 16], lfsr_b_reg [1] [15 : 0] , lfsr_b_reg [2] [31 : 16], lfsr_a_reg [0] [31 : 16]);
          temp_b [2] = feedback_b(lfsr_b_reg [0] [47 : 32], lfsr_b_reg [1] [31 : 16], lfsr_b_reg [2] [47 : 32], lfsr_a_reg [0] [47 : 32]);
          temp_b [3] = feedback_b(lfsr_b_reg [0] [63 : 48], lfsr_b_reg [1] [47 : 32], lfsr_b_reg [2] [63 : 48], lfsr_a_reg [0] [63 : 48]);
          for (i = 0 ; i < 3 ; i = i + 1)
            begin
              lfsr_a_new [i] = lfsr_a_reg [i+1];
              lfsr_b_new [i] = lfsr_b_reg [i+1];
            end
          lfsr_a3_new_temp = {temp_a [3], temp_a [2], temp_a [1], temp_a [0]};
          lfsr_b_new [3]  = {temp_b [3], temp_b [2], temp_b [1], temp_b [0]};
          
          lfsr_a_new [3] = lfsr_a3_new_temp;
          // Extra step during initialization
          if (came_from_init_reg == 1'b1)
              lfsr_a_new [3]  = lfsr_a3_new_temp ^ keystream_64;
        end
    end // lfsr_logic
    
  //----------------------------------------------------------------
  // fsm_logic
  //
  // Update and output logic for the FSM.
  //----------------------------------------------------------------
  function [63 : 0] add_mod(input [63 : 0] a, input [63 : 0] b);
    begin
      add_mod[31 : 0]  = a[31 : 0]  + b[31 : 0];
      add_mod[63 : 32] = a[63 : 32] + b[63 : 32];
    end
  endfunction
  
  function [127 : 0] sigma(input [127 : 0] state);
    begin
      sigma[7 : 0]     = state[7 : 0];
      sigma[15 : 8]    = state[39 : 32];
      sigma[23 : 16]   = state[71 : 64];
      sigma[31 : 24]   = state[103 : 96];
      sigma[39 : 32]   = state[15 : 8];
      sigma[47 : 40]   = state[47 : 40];
      sigma[55 : 48]   = state[79 : 72];
      sigma[63 : 56]   = state[111 : 104];
      sigma[71 : 64]   = state[23 : 16];
      sigma[79 : 72]   = state[55 : 48];
      sigma[87 : 80]   = state[87 : 80];
      sigma[95 : 88]   = state[119 : 112];
      sigma[103 : 96]  = state[31 : 24];
      sigma[111 : 104] = state[63 : 56];
      sigma[119 : 112] = state[95 : 88];
      sigma[127 : 120] = state[127 : 120];
    end
  endfunction
  
  function [127 : 0] reverse_byte_order(input [127 : 0] state);
    begin
      reverse_byte_order[7 : 0] = state[127 : 120];
      reverse_byte_order[15 : 8] = state[119 : 112];
      reverse_byte_order[23 : 16] = state[111 : 104];
      reverse_byte_order[31 : 24] = state[103 : 96];
      reverse_byte_order[39 : 32] = state[95 : 88];
      reverse_byte_order[47 : 40] = state[87 : 80];
      reverse_byte_order[55 : 48] = state[79 : 72];
      reverse_byte_order[63 : 56] = state[71 : 64];
      reverse_byte_order[71 : 64] = state[63 : 56];
      reverse_byte_order[79 : 72] = state[55 : 48];
      reverse_byte_order[87 : 80] = state[47 : 40];
      reverse_byte_order[95 : 88] = state[39 : 32];
      reverse_byte_order[103 : 96] = state[31 : 24];
      reverse_byte_order[111 : 104] = state[23 : 16];
      reverse_byte_order[119 : 112] = state[15 : 8];
      reverse_byte_order[127 : 120] = state[7 : 0];
    end
  endfunction
    
  always @*
    begin : fsm_logic
      reg [63 : 0]  T1, T2;
      reg [63 : 0]  R1a_temp, R1b_temp;
      reg [127 : 0] state;
      
      T1 = lfsr_b_reg [2];
      T2 = lfsr_a_reg [0];
      
      aes_round_block_i = reverse_byte_order({R1b_reg, R1a_reg});
      temp_new          = R1b_reg;
      
      // -- FSM update logic
      if (snowv_ctrl_reg == CTRL_LOAD)
        begin
          R1a_new  = 64'h0;
          R1b_new  = 64'h0;
          R2a_new  = 64'h0;
          R2b_new  = 64'h0;
          R3a_new  = 64'h0;
          R3b_new  = 64'h0;
        end
      else
        begin
          // Work in two phases to use only 1 AES round core
          {R3b_new, R3a_new} = reverse_byte_order(aes_round_block_o);
          if (phase == 1'b0)
            begin
              R2a_new  = add_mod(R3a_reg ^ T2, R2a_reg);
              R2b_new  = R3b_reg;
              {R1b_temp, R1a_temp} = {R2b_reg, R2a_reg};
            end
          else
            begin
              R2a_new              = R3a_reg;
              R2b_new              = R3b_reg;
              {R1b_temp, R1a_temp} = sigma({add_mod(R2b_reg ^ T2, R1b_reg), R2a_reg});
            end
          {R1b_new, R1a_new} = {R1b_temp, R1a_temp};
          
          // Update R1 in the last two steps of the SNOW-V initialization
          if (R1_load_key[0] == 1'b1)
            begin
              R1a_new = R1a_temp ^ key[63 : 0];
              R1b_new = R1b_temp ^ key[127 : 64];
            end
          else if (R1_load_key[1] == 1'b1)
            begin
              R1a_new = R1a_temp ^ key[191 : 128];
              R1b_new = R1b_temp ^ key[255 : 192];
            end
      end
          
      // -- FSM output logic
      if (phase == 1'b0)
        begin
          keystream_64 = add_mod(R1a_reg, T1) ^ R2a_reg;
          z_new = {64'h0, keystream_64};
        end
      else
        begin
          keystream_64 = add_mod(temp_reg, T1) ^ R1b_reg;
          z_new = {keystream_64, z_reg[63 : 0]};
        end
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
  // snowv_ctrl
  //
  // Control FSM for snowv.
  //----------------------------------------------------------------
  always @*
    begin : snowv_ctrl
      snowv_ctrl_new     = CTRL_IDLE;
      snowv_ctrl_we      = 1'b0;
      ready_new          = 1'b0;
      ready_we           = 1'b0;
      lfsr_we            = 1'b0;
      fsm_we             = 1'b0;
      counter_inc        = 1'b0;
      counter_rst        = 1'b0;
      aes_round_start    = 1'b0;
      R1_load_key        = 2'b00;
      came_from_init_new = 1'b0;
      came_from_init_we  = 1'b0;
      
      case (snowv_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_new          = 1'b0;
            ready_we           = 1'b1;
            came_from_init_new = 1'b0;
            came_from_init_we  = 1'b1;
            if (init)
              begin
                snowv_ctrl_new     = CTRL_LOAD;
                snowv_ctrl_we      = 1'b1;
                came_from_init_new = 1'b1;
                came_from_init_we  = 1'b1;
              end
            else if (next)
              begin
                snowv_ctrl_new = CTRL_ROUND;
                snowv_ctrl_we  = 1'b1;
                aes_round_start = 1'b1;
              end
          end
        CTRL_LOAD:
          begin
            lfsr_we         = 1'b1;
            fsm_we          = 1'b1;
            snowv_ctrl_new  = CTRL_ROUND;
            snowv_ctrl_we   = 1'b1;
            aes_round_start = 1'b1;
          end
        CTRL_ROUND:
          begin
            aes_round_start = 1'b0;
            if (aes_round_ready == 1'b1)
              begin
                if (came_from_init_reg == 1'b1)
                  begin
                    snowv_ctrl_new = CTRL_INIT;
                    snowv_ctrl_we  = 1'b1;
                  end
                else
                  begin
                    snowv_ctrl_new = CTRL_NEXT;
                    snowv_ctrl_we  = 1'b1;
                  end
              end
          end
        CTRL_INIT:
          begin
            counter_inc = 1'b1;
            lfsr_we     = 1'b1;
            fsm_we      = 1'b1;
            if (counter_reg == 16'd29)
              R1_load_key = 2'b01;
            snowv_ctrl_new  = CTRL_ROUND;
            snowv_ctrl_we   = 1'b1;
            aes_round_start = 1'b1;
            if (counter_reg >= 16'd31)
              begin
                snowv_ctrl_new  = CTRL_IDLE;
                snowv_ctrl_we   = 1'b1;
                counter_rst     = 1'b1;
                R1_load_key     = 2'b10;
                aes_round_start = 1'b0;
                ready_new       = 1'b1;
                ready_we        = 1'b1;
              end
          end
        CTRL_NEXT:
          begin
            snowv_ctrl_new  = CTRL_ROUND;
            snowv_ctrl_we   = 1'b1;
            counter_inc     = 1'b1;
            aes_round_start = 1'b1;
            lfsr_we         = 1'b1;
            fsm_we          = 1'b1;
            if (phase == 1'b1)
              begin
                snowv_ctrl_new  = CTRL_IDLE;
                snowv_ctrl_we   = 1'b1;
                ready_new       = 1'b1;
                ready_we        = 1'b1;
                counter_rst     = 1'b1;
                aes_round_start = 1'b0;
              end
          end
        default: 
          begin
        
          end
      endcase // case (snowv_ctrl_reg)
    end // snowv_ctrl
      
  // Other control signals
  assign phase = (counter_reg[0] == 1'b1);
  
endmodule // snowv_core
