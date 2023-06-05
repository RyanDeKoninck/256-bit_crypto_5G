//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/24/2023 03:02:44 PM
// Design Name: 
// Module Name: zuc256_ctr
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

module zuc256_ctr(
           input wire            clk,
           input wire            reset_n,
           
           input wire            init,
           input wire            next,
           input wire [255 : 0]  key,
           input wire [127 : 0]  iv,
           input wire [31 : 0]   word_i,
           
           output wire [31 : 0]  word_o,
           output wire           ready
          );
  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------        
  localparam CTRL_IDLE = 2'h0;
  localparam CTRL_INIT = 2'h1;
  localparam CTRL_NEXT = 2'h2;
  localparam CTRL_COMP = 2'h3;
  
  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg [2:0]   ctr_ctrl_reg;
  reg [2:0]   ctr_ctrl_new;
  reg         ctr_ctrl_we;
  
  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg            core_init;
  reg            core_next;
  wire [255 : 0] core_key;
  wire [127 : 0] core_iv;
  wire [7 : 0]   core_tag_len;
  wire [31 : 0]  core_z;
  wire           core_ready;
  
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
                   .tag_len(core_tag_len),
                     
                   .keystream_z(core_z),
                   .ready(core_ready)
                  );
 
    //----------------------------------------------------------------
    // Concurrent connectivity for ports etc.
    //----------------------------------------------------------------
    assign core_key     = key;
    assign core_iv      = iv;
    assign core_tag_len = 8'h0; 
    
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
                  ctr_ctrl_new = CTRL_INIT;
                  ctr_ctrl_we  = 1'b1;
                  core_init    = 1'b1;
                end
              else if (next)
                begin
                  ctr_ctrl_new = CTRL_INIT;
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
          CTRL_COMP:
            begin
              ready_new    = 1'b1;
              ready_we     = 1'b1;
              ctr_ctrl_new = CTRL_IDLE;
              ctr_ctrl_we  = 1'b1;
            end
          default: 
            begin
          
            end
          endcase // case (ctr_ctrl_reg)
          
        end // ctr_ctrl
  
endmodule // ctr
