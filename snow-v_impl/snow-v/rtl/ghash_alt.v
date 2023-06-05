//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/10/2023 12:18:00 PM
// Design Name: 
// Module Name: ghash
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

module ghash_alt(
           input wire            clk,
           input wire            reset_n,
           
           input wire            first_init,
           input wire            init,
           input wire            next_no_ad,
           input wire            next,
           input wire            finalize_no_in,
           input wire            finalize, 
           input wire [127 : 0]  H,
           input wire [127 : 0]  ad,
           input wire [63 : 0]   len_ad,    
           input wire [127 : 0]  block_i,
           input wire [63 : 0]   len_i,
           
           output wire [127 : 0] X,
           output wire           ready
          );
  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------        
  localparam CTRL_IDLE   = 3'h0;
  localparam CTRL_FINIT  = 3'h1;
  localparam CTRL_INIT   = 3'h2;
  localparam CTRL_FNEXT  = 3'h3;
  localparam CTRL_NEXT   = 3'h4;
  localparam CTRL_FFINAL = 3'h5;
  localparam CTRL_FINAL  = 3'h6;
  
  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg [2 : 0]   ghash_ctrl_reg;
  reg [2 : 0]   ghash_ctrl_new;
  reg           ghash_ctrl_we;
  
  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;
  
  reg [127 : 0] X_reg;
  reg [127 : 0] X_new;
  reg           X_we;
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  
  // Connections with instantiations.
  reg            mulH_start;
  wire [127 : 0] mulH_H;
  reg [127 : 0]  mulH_in;
  wire [127 : 0] mulH_out;
  wire           mulH_ready;
  
  // Other control signals
  wire           loading;
  wire           initializing;
  wire           continuing;
    
  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  mulH_fast mulH_fast(
            .clk(clk),
            .reset_n(reset_n),
    
            .start(mulH_start),
            .H(mulH_H),    
            .block_i(mulH_in),
            
            .block_o(mulH_out),
            .ready(mulH_ready)
            );
    
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  function [127 : 0] reverse_byte_order(input [127 : 0] in);
    begin
      reverse_byte_order[7 : 0] = in[127 : 120];
      reverse_byte_order[15 : 8] = in[119 : 112];
      reverse_byte_order[23 : 16] = in[111 : 104];
      reverse_byte_order[31 : 24] = in[103 : 96];
      reverse_byte_order[39 : 32] = in[95 : 88];
      reverse_byte_order[47 : 40] = in[87 : 80];
      reverse_byte_order[55 : 48] = in[79 : 72];
      reverse_byte_order[63 : 56] = in[71 : 64];
      reverse_byte_order[71 : 64] = in[63 : 56];
      reverse_byte_order[79 : 72] = in[55 : 48];
      reverse_byte_order[87 : 80] = in[47 : 40];
      reverse_byte_order[95 : 88] = in[39 : 32];
      reverse_byte_order[103 : 96] = in[31 : 24];
      reverse_byte_order[111 : 104] = in[23 : 16];
      reverse_byte_order[119 : 112] = in[15 : 8];
      reverse_byte_order[127 : 120] = in[7 : 0];
    end
  endfunction
  
  assign mulH_H = reverse_byte_order(H);
  assign X      = X_reg;
  assign ready  = ready_reg; 
    
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
          ghash_ctrl_reg   <= CTRL_IDLE;
          ready_reg        <= 1'b0;
          X_reg            <= 128'b0;
        end
      else
        begin
          if (ghash_ctrl_we)
            ghash_ctrl_reg <= ghash_ctrl_new;
          if (ready_we)
            ready_reg <= ready_new;
          if (X_we)
              X_reg <= X_new;
        end
    end // reg_update
    
  //----------------------------------------------------------------
  // GHASH Logic
  //----------------------------------------------------------------
  always @*
    begin : ghash_logic      
      if (loading)
        begin
          mulH_in = ad; // Doesn't matter
          X_new = 128'h0;
        end
      else if (initializing)
        begin
          mulH_in = reverse_byte_order(X_reg ^ ad);
          X_new   = reverse_byte_order(mulH_out);
        end
      else if (continuing)
        begin
          mulH_in = reverse_byte_order(X_reg ^ block_i);
          X_new   = reverse_byte_order(mulH_out);
        end
      else
        begin
          mulH_in = reverse_byte_order(X_reg) ^ {len_ad, len_i};
          X_new   = reverse_byte_order(mulH_out);
        end
    end
        
  //----------------------------------------------------------------
  // ghash_ctrl
  //
  // Control FSM for GHASH.
  //----------------------------------------------------------------
  always @*
    begin : ghash_ctrl
      ghash_ctrl_new   = CTRL_IDLE;
      ghash_ctrl_we    = 1'b0;
      ready_new        = 1'b0;
      ready_we         = 1'b0;
      X_we             = 1'b0;
      mulH_start       = 1'b0;
      
      case (ghash_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_new        = 1'b0;
            ready_we         = 1'b1;
            if (first_init)
              begin
                ghash_ctrl_new = CTRL_FINIT;
                ghash_ctrl_we  = 1'b1;
              end
            else if (init)
              begin
                ghash_ctrl_new   = CTRL_INIT;
                ghash_ctrl_we    = 1'b1;
                mulH_start       = 1'b1;
              end
            else if (next_no_ad)
              begin
                ghash_ctrl_new = CTRL_FNEXT;
                ghash_ctrl_we  = 1'b1;
              end
            else if (next)
              begin
                ghash_ctrl_new = CTRL_NEXT;
                ghash_ctrl_we  = 1'b1;
                mulH_start     = 1'b1;
              end
            else if (finalize_no_in)
              begin
                ghash_ctrl_new = CTRL_FFINAL;
                ghash_ctrl_we  = 1'b1;
              end
            else if (finalize)
              begin
                ghash_ctrl_new = CTRL_FINAL;
                ghash_ctrl_we  = 1'b1;
                mulH_start     = 1'b1;
              end
          end
        CTRL_FINIT:
            begin
              ghash_ctrl_new   = CTRL_INIT;
              ghash_ctrl_we    = 1'b1;
              X_we             = 1'b1;
              mulH_start       = 1'b1;
            end
        CTRL_INIT:
          begin
            if (mulH_ready)
              begin
                ghash_ctrl_new = CTRL_IDLE;
                ghash_ctrl_we  = 1'b1;
                ready_new      = 1'b1;
                ready_we       = 1'b1;
                X_we           = 1'b1;
              end
          end
        CTRL_FNEXT:
          begin
            ghash_ctrl_new = CTRL_NEXT;
            ghash_ctrl_we  = 1'b1;
            X_we           = 1'b1;
            mulH_start     = 1'b1;
          end
        CTRL_NEXT:
          begin
            if (mulH_ready)
              begin
                ghash_ctrl_new = CTRL_IDLE;
                ghash_ctrl_we  = 1'b1;
                ready_new      = 1'b1;
                ready_we       = 1'b1;
                X_we           = 1'b1;
              end
          end
        CTRL_FFINAL:
          begin
            ghash_ctrl_new = CTRL_FINAL;
            ghash_ctrl_we  = 1'b1;
            X_we           = 1'b1;
            mulH_start     = 1'b1;
          end
        CTRL_FINAL:
          begin
            if (mulH_ready)
              begin
                ghash_ctrl_new = CTRL_IDLE;
                ghash_ctrl_we  = 1'b1;
                ready_new      = 1'b1;
                ready_we       = 1'b1;
                X_we           = 1'b1;
              end
          end
        default: 
          begin
        
          end
      endcase // case (ghash_ctrl_reg)
    end // ghash_ctrl
    
    assign loading = (ghash_ctrl_reg == CTRL_FINIT || ghash_ctrl_reg == CTRL_FNEXT || ghash_ctrl_reg == CTRL_FFINAL);
    assign initializing = (ghash_ctrl_reg == CTRL_INIT);
    assign continuing = (ghash_ctrl_reg == CTRL_NEXT);
  
endmodule // ghash_core
