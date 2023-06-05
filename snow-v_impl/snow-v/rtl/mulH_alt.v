//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/07/2023 06:20:34 PM
// Design Name: 
// Module Name: mulH
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

module mulH_alt(
           input wire            clk,
           input wire            reset_n,
           
           input wire            start,
           input wire [127 : 0]  H,
           input wire [127 : 0]  block_i,
           
           output wire [127 : 0] block_o,
           output wire           ready
          );
  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------        
  localparam CTRL_IDLE     = 2'h0;
  localparam CTRL_LOAD     = 2'h1;
  localparam CTRL_COMP     = 2'h2;
  
  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg [1 : 0]    mulH_ctrl_reg;
  reg [1 : 0]    mulH_ctrl_new;
  reg            mulH_ctrl_we;
  
  reg            ready_reg;
  reg            ready_new;
  reg            ready_we;
  
  reg [127 : 0]  Z_reg;
  reg [127 : 0]  Z_new;
  reg            Z_we;
  
  reg [127 : 0]  V_reg;
  reg [127 : 0]  V_new;
  reg            V_we;
  
  reg signed [7 : 0] ctr_reg;
  reg signed [7 : 0] ctr_new;
  reg                ctr_we;
  reg                ctr_dec;
  reg                ctr_rst;
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
 
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign block_o = Z_reg;
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
          mulH_ctrl_reg <= CTRL_IDLE;
          ready_reg     <= 1'b0;
          Z_reg         <= 128'h0;
          V_reg         <= 128'h0;
          ctr_reg       <= 8'd127;
        end
      else
        begin
          if (mulH_ctrl_we)
            mulH_ctrl_reg <= mulH_ctrl_new;
          if (ready_we)
            ready_reg <= ready_new;
          if (Z_we)
              Z_reg <= Z_new;
          if (V_we)
            V_reg <= V_new;
          if (ctr_we)
            ctr_reg <= ctr_new;
        end
    end // reg_update
    
  //----------------------------------------------------------------
  // mulH Logic
  //----------------------------------------------------------------
  always @*
    begin : mulH_logic
      if (mulH_ctrl_reg == CTRL_LOAD)
        begin
          Z_new = 128'h0;
          V_new = block_i;
        end
      else
        begin
          if (H[ctr_reg] == 1'b1)
            Z_new = Z_reg ^ V_reg;
          else
            Z_new = Z_reg;
          if (V_reg[0] == 1'b0)
            V_new = V_reg >> 1;
          else
            V_new = (V_reg >> 1) ^ {8'b11100001, 120'h0};
        end
    end // mulH_logic
    
  //----------------------------------------------------------------
  // ctr
  //----------------------------------------------------------------
  always @*
    begin : ctr
      ctr_new = 8'h0;
      ctr_we  = 1'b0;
      if (ctr_rst)
        begin
          ctr_new = 8'd127;
          ctr_we  = 1'b1;
        end
      else if (ctr_dec)
        begin
          ctr_new = ctr_reg - 1;
          ctr_we  = 1'b1;
        end
    end // ctr  
    
  //----------------------------------------------------------------
  // mulH_ctrl
  //
  // Control FSM for mulH.
  //----------------------------------------------------------------
  always @*
    begin: mulH_ctrl
      ready_new     = 1'b0;
      ready_we      = 1'b0;
      mulH_ctrl_new = CTRL_IDLE;
      mulH_ctrl_we  = 1'b0;
      Z_we          = 1'b0;
      V_we          = 1'b0;
      ctr_rst       = 1'b0;
      ctr_dec       = 1'b0;
        
      case (mulH_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_new = 1'b0;
            ready_we  = 1'b1;
            if (start)
              begin
                mulH_ctrl_new = CTRL_LOAD;
                mulH_ctrl_we  = 1'b1;
              end
          end
        CTRL_LOAD:
          begin
            Z_we = 1'b1;
            V_we = 1'b1;
            mulH_ctrl_new = CTRL_COMP;
            mulH_ctrl_we  = 1'b1;
          end
        CTRL_COMP:
          begin
            Z_we    = 1'b1;
            V_we    = 1'b1;
            ctr_dec = 1'b1;
            if (ctr_reg < 0)
              begin
                mulH_ctrl_new = CTRL_IDLE;
                mulH_ctrl_we  = 1'b1;
                ctr_rst       = 1'b1;
                ready_new     = 1'b1;
                ready_we      = 1'b1;
              end
          end
        default: 
          begin
        
          end
        endcase // case (mulH_ctrl_reg)
        
      end // mulH_ctrl
  
endmodule // mulH
