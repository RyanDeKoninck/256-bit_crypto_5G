//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/24/2023 03:02:44 PM
// Design Name: 
// Module Name: zuc256_ctr_ext
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

module zuc256_ctr_ext(
           input wire            clk,
           input wire            reset_n,
           
           input wire            init,
           input wire            next,
           input wire [31 : 0]   word_i,
           
           input wire [31 : 0]   core_z,
           input wire            core_ready,
           
           output reg            core_init,
           output reg            core_next,
           
           output wire [31 : 0]  word_o,
           output wire           ready
          );
  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------        
  localparam CTRL_IDLE = 1'b0;
  localparam CTRL_COMP = 1'b1;
  
  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg         ctr_ctrl_reg;
  reg         ctr_ctrl_new;
  reg         ctr_ctrl_we;
  
  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;
 
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
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
        end
      else
        begin
          if (ctr_ctrl_we)
            ctr_ctrl_reg <= ctr_ctrl_new;
          if (ready_we)
            ready_reg <= ready_new;
        end
    end // reg_update
    
  //----------------------------------------------------------------
  // XOR between input block and AES-core output block
  //----------------------------------------------------------------
  assign word_o = word_i ^ core_z;
  
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
      
      core_init    = 1'b0;
      core_next    = 1'b0;
      
      case (ctr_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_new = 1'b0;
            ready_we  = 1'b1;
            if (init)
              begin
                ctr_ctrl_new = CTRL_COMP;
                ctr_ctrl_we  = 1'b1;
                core_init    = 1'b1;
              end
            else if (next)
              begin
                ctr_ctrl_new = CTRL_COMP;
                ctr_ctrl_we  = 1'b1;
                core_next    = 1'b1;
              end
          end
        CTRL_COMP:
          begin
            if (core_ready)
              begin
                ctr_ctrl_new = CTRL_IDLE;
                ctr_ctrl_we  = 1'b1;
                ready_new    = 1'b1;
                ready_we     = 1'b1;
              end
          end
        default: 
          begin
        
          end
        endcase // case (ctr_ctrl_reg)
        
      end // ctr_ctrl
  
endmodule // ctr
