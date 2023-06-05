//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 03/10/2023 03:02:44 PM
// Design Name: 
// Module Name: ctr_core
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

module ctr_core(
           input wire            clk,
           input wire            reset_n,
           
           input wire            init,
           input wire            next,
           input wire            finalize,
           input wire [127 : 0]  init_counter,
           input wire [255 : 0]  key,
           input wire            keylen,
           input wire [127 : 0]  block_i,
           input wire [7 : 0]    len_i,
           
           output reg [127 : 0]  block_o,
           output wire           ready
          );
  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------        
  localparam CTRL_IDLE       = 3'h0;
  localparam CTRL_LOAD       = 3'h1;
  localparam CTRL_INIT       = 3'h2;
  localparam CTRL_NEXT       = 3'h3;
  localparam CTRL_FINAL      = 3'h4;
  localparam CTRL_COMP       = 3'h5;
  
  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg [2:0]     ctr_ctrl_reg;
  reg [2:0]     ctr_ctrl_new;
  reg           ctr_ctrl_we;
  
  reg [127 : 0] counter_reg;
  reg [127 : 0] counter_new;
  reg           counter_we;
  
  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;
  
  reg           finalize_reg;
  reg           finalize_new;
  reg           finalize_we;
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  wire           core_encdec;
  reg            core_init;
  reg            core_next;
  wire           core_ready;
  wire [255 : 0] core_key;
  wire           core_keylen;
  wire [127 : 0] core_block;
  wire [127 : 0] core_result;
  wire           core_valid;
  
  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  aes_core aes(
               .clk(clk),
               .reset_n(reset_n),
  
               .encdec(core_encdec),
               .init(core_init),
               .next(core_next),
               .ready(core_ready),
                 
               .key(core_key),
               .keylen(core_keylen),
                 
               .block(core_block),
               .result(core_result),
               .result_valid(core_valid)
              );
 
    //----------------------------------------------------------------
    // Concurrent connectivity for ports etc.
    //----------------------------------------------------------------
    assign core_encdec = 1'b1;    // Only encryption is needed for CTR-mode
    assign core_key    = key;
    assign core_keylen = keylen;  // Keylen: 0 for 128-bit, 1 for 256-bit
    assign core_block  = counter_reg;
    
    assign ready = ready_reg;
  
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
            ctr_ctrl_reg  <= CTRL_IDLE;
            ready_reg     <= 1'b0;
            counter_reg   <= 128'h0;
            finalize_reg  <= 1'b0;
          end
        else
          begin
            if (ctr_ctrl_we)
              ctr_ctrl_reg <= ctr_ctrl_new;
            if (ready_we)
              ready_reg <= ready_new;
            if (counter_we)
              counter_reg <= counter_new;
            if (finalize_we)
              finalize_reg <= finalize_new;
          end
      end // reg_update
      
    //----------------------------------------------------------------
    // XOR between input block and AES-core output block
    //----------------------------------------------------------------
    always @*
      begin
        if (finalize_reg)
          block_o = block_i ^ (core_result << (128 - len_i)) >> (128 - len_i);
        else
          block_o = block_i ^ core_result;
      end
    
    //----------------------------------------------------------------
    // counter_reg logic
    //----------------------------------------------------------------
    always @*
      begin
        if ((ctr_ctrl_reg == CTRL_IDLE) && init)
          counter_new = init_counter;
        else
          counter_new = {counter_reg[127 : 64], counter_reg[63 : 0] + 64'h1};
      end
    
    //----------------------------------------------------------------
    // ctr_ctrl
    //
    // Control FSM for ctr.
    //----------------------------------------------------------------
    always @*
      begin: ctr_ctrl
        ready_new    = 1'b0;
        ready_we     = 1'b0;
        ctr_ctrl_new = CTRL_IDLE;
        ctr_ctrl_we  = 1'b0;
        counter_we   = 1'b0;
        
        core_init    = 1'b0;
        core_next    = 1'b0;
        
        finalize_new = 1'b0;
        finalize_we  = 1'b0;
        
        case (ctr_ctrl_reg)
          CTRL_IDLE:
            begin
              ready_new = 1'b0;
              ready_we  = 1'b1;
              if (init)
                begin
                  finalize_new = 1'b0;
                  finalize_we  = 1'b1;
                  ctr_ctrl_new = CTRL_INIT;
                  ctr_ctrl_we  = 1'b1;
                  core_init    = 1'b1;
                  counter_we   = 1'b1;
                end
              else if (next)
                begin
                  ctr_ctrl_new = CTRL_NEXT;
                  ctr_ctrl_we  = 1'b1;
                  core_next    = 1'b1;
                end
              else if (finalize)
                begin
                  ctr_ctrl_new = CTRL_FINAL;
                  ctr_ctrl_we  = 1'b1;
                  core_next    = 1'b1;
                end
            end
          CTRL_INIT:
            begin
              if (core_ready)
                begin
                  ctr_ctrl_new = CTRL_IDLE;
                  ctr_ctrl_we  = 1'b1;
                  ready_new    = 1'b1;
                  ready_we     = 1'b1;
                end
            end
          CTRL_NEXT:
            begin
              if (core_ready)
                begin
                  ctr_ctrl_new = CTRL_COMP;
                  ctr_ctrl_we  = 1'b1;
                end
            end
          CTRL_FINAL:
            begin
              if (core_ready)
                begin
                  ctr_ctrl_new = CTRL_COMP;
                  ctr_ctrl_we  = 1'b1;
                  finalize_new = 1'b1;
                  finalize_we  = 1'b1;
                end
            end
          CTRL_COMP:
            begin
              ctr_ctrl_new = CTRL_IDLE;
              ctr_ctrl_we  = 1'b1;
              ready_new    = 1'b1;
              ready_we     = 1'b1;
              counter_we   = 1'b1;
            end
          default: 
            begin
          
            end
          endcase // case (ctr_ctrl_reg)
          
        end // ctr_ctrl
  
endmodule // ctr
