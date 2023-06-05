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

module zuc256_mac(
           input wire            clk,
           input wire            reset_n,
           
           input wire            init,
           input wire            next,
           input wire            final,
           input wire [255 : 0]  key,
           input wire [127 : 0]  iv,
           input wire [127 : 0]  block_i,
           input wire [7 : 0]    i_len,
           input wire [7 : 0]    tag_len, // Either 32, 64, or 128

           output wire [127 : 0] tag,
           output wire           ready
          );

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam CTRL_IDLE      = 3'h0;
  localparam CTRL_INIT_CORE = 3'h1;
  localparam CTRL_NEXT_CORE = 3'h2;
  localparam CTRL_LOAD      = 3'h3;
  localparam CTRL_INIT_TAG  = 3'h4;
  localparam CTRL_COMP      = 3'h5;
  localparam CTRL_FINAL     = 3'h6;
  
  localparam S = 4;
  localparam S_min1 = S - 1;

  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg [2 : 0]   zuc256_mac_ctrl_reg;
  reg [2 : 0]   zuc256_mac_ctrl_new;
  reg           zuc256_mac_ctrl_we;

  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;

  reg [127 : 0] tag_reg;
  reg [127 : 0] tag_new;
  reg           tag_we;
  
  reg [31 : 0]  keystream_reg [7 : 0];
  reg [31 : 0]  keystream_new [7 : 0];
  reg           keystream_we;
  
  // Counter
  reg [8 : 0]   counter_reg;
  reg [8 : 0]   counter_new;
  reg           counter_we;
  reg           counter_inc;
  reg           counter_rst;
  
  // Extra control signals
  reg            came_from_init_reg;
  reg            came_from_init_new;
  reg            came_from_init_we;
  
  reg            came_from_next_reg;
  reg            came_from_next_new;
  reg            came_from_next_we;

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg            core_init;
  reg            core_next;
  wire [255 : 0] core_key;
  wire [127 : 0] core_iv;
  wire [31 : 0]  core_z;
  wire           core_ready;
  
  wire [255 : 0] long_keystream;
  
  // Extra control signals
  reg            initialize;
  reg            finalize;
  reg [8 : 0]    exit_len;      
  
  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  zuc256_core core(
                   .clk(clk),
                   .reset_n(reset_n),
                   
                   .init(core_init),
                   .next(core_next),
                   .key(core_key),
                   .iv(core_iv),
                   .tag_len(tag_len),
                   
                   .keystream_z(core_z),
                   .ready(core_ready)
                   );

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign tag   = tag_reg;
  assign ready = ready_reg;
  
  assign core_key = key;
  assign core_iv  = iv; 
  
  assign long_keystream = {keystream_reg [0], keystream_reg [1],
                           keystream_reg [2], keystream_reg [3],
                           keystream_reg [4], keystream_reg [5],
                           keystream_reg [6], keystream_reg [7]};
  
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
          zuc256_mac_ctrl_reg <= CTRL_IDLE;
          ready_reg           <= 1'b0;
          tag_reg             <= 128'h0;
          for (i = 0; i < 8; i = i + 1)
            keystream_reg [i] <= 32'h0;
          counter_reg         <= 9'd0;
          came_from_init_reg  <= 1'b0;
          came_from_next_reg  <= 1'b0;
        end
      else
        begin
          if (zuc256_mac_ctrl_we)
            zuc256_mac_ctrl_reg <= zuc256_mac_ctrl_new;
          if (ready_we)
            ready_reg <= ready_new;
          if (tag_we)
            tag_reg  <= tag_new;
          if (keystream_we)
            for (i = 0; i < 8; i = i + 1)
              keystream_reg [i] <= keystream_new [i];
          if (counter_we)
            counter_reg <= counter_new;
          if (came_from_init_we)
            came_from_init_reg <= came_from_init_new;
          if (came_from_next_we)
            came_from_next_reg <= came_from_next_new;
        end
    end // reg_update
    
  //----------------------------------------------------------------
  // shift_reg
  //----------------------------------------------------------------
  always@*
    begin : shift_reg
      integer i;
      for (i = 0; i < 7; i = i + 1)
        keystream_new [i] = keystream_reg [i + 1];
      keystream_new [7] = core_z;
    end

  //----------------------------------------------------------------
  // mac_logic
  //----------------------------------------------------------------
  always @*
    begin : mac_logic
      integer i;
      reg [7 : 0]   inv_counter;
      reg [127 : 0] temp [0 : S_min1];
      reg [255 : 0] shifted [0 : S_min1];
      reg [255 : 0] final_shifted;
      reg [127 : 0] temp_final;
      
      inv_counter   = 127 - counter_reg;
      shifted [0]   = long_keystream << counter_reg;
      final_shifted = long_keystream >> (128 - i_len);
      
      if (block_i[inv_counter] == 1'b1)
        temp [0] = tag_reg ^ shifted [0] [255 : 128];
      else
        temp [0] = tag_reg;
      
      for (i = 1; i < S; i = i + 1)
        begin
          shifted [i] = shifted [i - 1] << 1;
          if (block_i[inv_counter - i] == 1'b1)
            temp [i] = temp [i - 1] ^ shifted [i] [255 : 128];
          else
            temp [i] = temp [i - 1];
        end
      
      temp_final = tag_reg ^ final_shifted[127 : 0];
      if (initialize)
        begin
          if (tag_len == 8'd32)
            tag_new = {long_keystream[159 : 128], 96'h0};
          else if (tag_len == 8'd64)
            tag_new = {long_keystream[191 : 128], 64'h0};
          else
            tag_new = long_keystream[255 : 128];
        end
      else if (finalize)
        begin
          if (tag_len == 8'd32)
            tag_new = {96'h0, temp_final[127 : 96]};
          else if (tag_len == 8'd64)
            tag_new = {64'h0, temp_final[127 : 64]};
          else
            tag_new = temp_final;
        end
      else
        tag_new = temp [S_min1];

    end // mac_logic

  //----------------------------------------------------------------
  // counter
  //
  // Counter with reset and increase logic.
  //----------------------------------------------------------------
  always @*
    begin : counter
      counter_new = 9'h0;
      counter_we  = 1'b0;

      if (counter_rst)
        begin
          counter_new = 9'h0;
          counter_we  = 1'b1;
        end
      else if (counter_inc)
        begin
          if (came_from_init_reg || came_from_next_reg)
            counter_new = counter_reg + 32;
          else
            counter_new = counter_reg + S;
          counter_we  = 1'b1;
        end
    end // counter

  //----------------------------------------------------------------
  // mac_ctrl
  //
  // Control FSM for mac.
  //----------------------------------------------------------------
  always @*
    begin : zuc256_mac_ctrl
      zuc256_mac_ctrl_new = CTRL_IDLE;
      zuc256_mac_ctrl_we  = 1'b0;
      ready_new           = 1'b0;
      ready_we            = 1'b0;
      tag_we              = 1'b0;
      keystream_we        = 1'b0;
      core_init           = 1'b0;
      core_next           = 1'b0;
      counter_inc         = 1'b0;
      counter_rst         = 1'b0;
      initialize          = 1'b0;
      finalize            = 1'b0;
      came_from_init_new  = 1'b0;
      came_from_init_we   = 1'b0;
      came_from_next_new  = 1'b0;
      came_from_next_we   = 1'b0;

      case (zuc256_mac_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_new          = 1'b0;
            ready_we           = 1'b1;
            if (init)
              begin
                zuc256_mac_ctrl_new = CTRL_INIT_CORE;
                zuc256_mac_ctrl_we  = 1'b1;
                core_init           = 1'b1;
                came_from_init_new  = 1'b1;
                came_from_init_we   = 1'b1;
              end
            else if (next)
              begin
                zuc256_mac_ctrl_new = CTRL_NEXT_CORE;
                zuc256_mac_ctrl_we  = 1'b1;
                core_next           = 1'b1;
                came_from_next_new  = 1'b1;
                came_from_next_we   = 1'b1;
              end
            else if (final)
              begin
                zuc256_mac_ctrl_new = CTRL_FINAL;
                zuc256_mac_ctrl_we  = 1'b1;
              end
          end
        CTRL_INIT_CORE:
          begin
            if (core_ready)
              begin
                zuc256_mac_ctrl_new = CTRL_NEXT_CORE;
                zuc256_mac_ctrl_we  = 1'b1;
                core_next           = 1'b1; 
                counter_inc         = 1'b1;
              end
          end
        CTRL_NEXT_CORE:
          begin
            if (core_ready)
              begin
                zuc256_mac_ctrl_new = CTRL_LOAD;
                zuc256_mac_ctrl_we  = 1'b1;
                if (counter_reg < exit_len)
                  core_next = 1'b1;
              end
          end
        CTRL_LOAD:
          begin
            counter_inc  = 1'b1;
            keystream_we = 1'b1;
            if (counter_reg < exit_len)
              begin
                zuc256_mac_ctrl_new = CTRL_NEXT_CORE;
                zuc256_mac_ctrl_we  = 1'b1;  
              end   
            else
              begin
                counter_rst = 1'b1;
                if (came_from_init_reg)
                  begin
                    zuc256_mac_ctrl_new = CTRL_INIT_TAG;
                    zuc256_mac_ctrl_we  = 1'b1; 
                  end
                else 
                  begin
                    came_from_next_new  = 1'b0;
                    came_from_next_we   = 1'b1;
                    zuc256_mac_ctrl_new = CTRL_COMP;
                    zuc256_mac_ctrl_we  = 1'b1;
                    came_from_next_new  = 1'b0;
                    came_from_next_we   = 1'b1;
                  end
              end   
          end
        CTRL_INIT_TAG:
          begin
            initialize          = 1'b1;
            tag_we              = 1'b1;
            zuc256_mac_ctrl_new = CTRL_IDLE;
            zuc256_mac_ctrl_we  = 1'b1;
            came_from_init_new  = 1'b0;
            came_from_init_we   = 1'b1;
            ready_new           = 1'b1;
            ready_we            = 1'b1;
          end
        CTRL_COMP:
          begin
            tag_we      = 1'b1;
            counter_inc = 1'b1;
            if (counter_reg >= (exit_len - S)) 
              begin
                zuc256_mac_ctrl_new = CTRL_IDLE;
                zuc256_mac_ctrl_we  = 1'b1;
                ready_new           = 1'b1;
                ready_we            = 1'b1;
                counter_rst         = 1'b1;
              end
          end
        CTRL_FINAL:
          begin
            finalize            = 1'b1;
            tag_we              = 1'b1;
            zuc256_mac_ctrl_new = CTRL_IDLE;
            zuc256_mac_ctrl_we  = 1'b1;
            ready_new           = 1'b1;
            ready_we            = 1'b1;
          end
        default:
          begin

          end
      endcase // case (zuc256_ctrl_reg)
    end // zuc256_ctrl
  
  always@*
    begin
      if (came_from_init_reg)
        begin
          if (tag_len == 8'd32)
            exit_len = 9'd160;
          else if (tag_len == 8'd64)
            exit_len = 9'd192;
          else
            exit_len = 9'd256;
        end
      else if (came_from_next_reg)
        exit_len = 9'd96;
      else
        exit_len = 9'd128;
    end
    
endmodule // zuc256_mac
