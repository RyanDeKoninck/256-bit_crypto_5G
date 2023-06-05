//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/20/2023 15:12:00
// Design Name: 
// Module Name: zuc256_modadd
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

module zuc256_modadd(
                input wire           clk,
                input wire           reset_n,
                input wire           start,
                input wire [30 : 0]  s15,
                input wire [30 : 0]  s13,
                input wire [30 : 0]  s10,
                input wire [30 : 0]  s4,
                input wire [30 : 0]  s0,
                input wire [30 : 0]  W_shifted,
                input wire           came_from_init,
                output wire [30 : 0] out,
                output wire          ready
               );

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------        
  localparam CTRL_IDLE      = 3'h0;
  localparam CTRL_COMP0     = 3'h1;
  localparam CTRL_COMP1     = 3'h2;
  localparam CTRL_COMP2     = 3'h3;
  localparam CTRL_COMP_INIT = 3'h4;

  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg [2 : 0]   modadd_ctrl_reg;
  reg [2 : 0]   modadd_ctrl_new;
  reg           modadd_ctrl_we;
  
  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;
  
  reg [30 : 0]  temp1b_reg;
  reg [30 : 0]  temp1b_new;
  reg [30 : 0]  temp1b_we;
  
  reg [30 : 0]  temp2b_reg;
  reg [30 : 0]  temp2b_new;
  reg [30 : 0]  temp2b_we;
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [30 : 0]  add1_in1, add1_in2;
  reg [31 : 0]  temp1a;
  reg [30 : 0]  temp1b;
  
  reg [30 : 0]  add2_in1, add2_in2;
  reg [31 : 0]  temp2a;

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready = ready_reg;
  assign out   = temp1b_reg;
  
  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin : reg_update
      if (!reset_n)
        begin
          modadd_ctrl_reg <= CTRL_IDLE;
          ready_reg       <= 1'b0;
          temp1b_reg      <= 32'h0;
          temp2b_reg      <= 32'h0;
        end
      else
        begin
          if (modadd_ctrl_we)
            modadd_ctrl_reg <= modadd_ctrl_new;
          if (ready_we)
            ready_reg <= ready_new;
          if (temp1b_we)
            temp1b_reg  <= temp1b_new;
          if (temp2b_we)
            temp2b_reg  <= temp2b_new;
        end
    end // reg_update
    
  //----------------------------------------------------------------
  // Modular addition logic.
  //----------------------------------------------------------------
  always @*
    begin : multiplexers
      reg temp1b_zero;
      temp1b_zero = (temp1b == 0);
      case (modadd_ctrl_reg)
        CTRL_COMP0:
          begin
            add1_in1 <= {s15[15 : 0], s15[30 : 16]};
            add1_in2 <= {s13[13 : 0], s13[30 : 14]};
            add2_in1 <= {s10[9 : 0],  s10[30 : 10]};
            add2_in2 <= {s4[10 : 0],  s4[30 : 11]};
            temp1b_new <= temp1b;
          end
        CTRL_COMP1:
          begin
            add1_in1 <= temp1b_reg;
            add1_in2 <= temp2b_reg;
            add2_in1 <= {s0[22 : 0],  s0[30 : 23]};
            add2_in2 <= s0;
            temp1b_new <= temp1b;
          end
        CTRL_COMP2:
          begin
            add1_in1 <= temp1b_reg;
            add1_in2 <= temp2b_reg;
            add2_in1 <= {s0[22 : 0],  s0[30 : 23]};
            add2_in2 <= s0; 
            temp1b_new <= temp1b_zero ? 31'b1111111111111111111111111111111 : temp1b;
          end
        CTRL_COMP_INIT:
          begin
            add1_in1 <= temp1b_reg;
            add1_in2 <= W_shifted;
            add2_in1 <= {s0[22 : 0],  s0[30 : 23]};
            add2_in2 <= s0;
            temp1b_new <= temp1b_zero ? 31'b1111111111111111111111111111111 : temp1b;
          end
        default: 
          begin
            add1_in1 <= {s15[15 : 0], s15[30 : 16]};
            add1_in2 <= {s13[13 : 0], s13[30 : 14]};
            add2_in1 <= {s10[9 : 0],  s10[30 : 10]};
            add2_in2 <= {s4[10 : 0],  s4[30 : 11]};
            temp1b_new <= temp1b;
          end  
      endcase  
      
      // Adders
      temp1a     <= add1_in1 + add1_in2;
      temp1b     <= temp1a[30 : 0] + temp1a[31];
      
      temp2a     <= add2_in1 + add2_in2;
      temp2b_new <= temp2a[30 : 0] + temp2a[31];
        
      // Output logic
      //temp1b_new <= (temp1b == 0 && (comp2 || comp_init)) ? 31'b1111111111111111111111111111111 : temp1b;
    end
  
  
  //----------------------------------------------------------------
  // modadd_ctrl
  //
  // Control FSM for modadd.
  //----------------------------------------------------------------
  always @*
    begin : zuc256_ctrl
      modadd_ctrl_new    = CTRL_IDLE;
      modadd_ctrl_we     = 1'b0;
      ready_new          = 1'b0;
      ready_we           = 1'b0;
      temp1b_we          = 1'b0;
      temp2b_we          = 1'b0;
      
      case (modadd_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_new          = 1'b0;
            ready_we           = 1'b1;
            if (start)
              begin
                modadd_ctrl_new    = CTRL_COMP0;
                modadd_ctrl_we     = 1'b1;
              end
          end
        CTRL_COMP0:
          begin
            modadd_ctrl_new    = CTRL_COMP1;
            modadd_ctrl_we     = 1'b1;
            temp1b_we          = 1'b1;
            temp2b_we          = 1'b1;
          end
        CTRL_COMP1:
            begin
              modadd_ctrl_new    = CTRL_COMP2;
              modadd_ctrl_we     = 1'b1;
              temp1b_we          = 1'b1;
              temp2b_we          = 1'b1;
            end
        CTRL_COMP2:
              begin
                temp1b_we          = 1'b1;
                temp2b_we          = 1'b1;
                if (came_from_init)
                  begin
                    modadd_ctrl_new    = CTRL_COMP_INIT;
                    modadd_ctrl_we     = 1'b1;
                  end
                else
                  begin
                    modadd_ctrl_new    = CTRL_IDLE;
                    modadd_ctrl_we     = 1'b1;
                    ready_new          = 1'b1;
                    ready_we           = 1'b1;
                  end
              end
        CTRL_COMP_INIT:
          begin
            temp1b_we          = 1'b1;
            temp2b_we          = 1'b1;
            modadd_ctrl_new    = CTRL_IDLE;
            modadd_ctrl_we     = 1'b1;
            ready_new          = 1'b1;
            ready_we           = 1'b1;
          end
        default: 
          begin
        
          end
      endcase // case (modadd_ctrl_reg)
    end // modadd_ctrl

endmodule // zuc256_modadd

//======================================================================
// EOF zuc256_modadd.v
//======================================================================
