//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/26/2023 03:02:44 PM
// Design Name: 
// Module Name: aes_tot
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

module aes_tot(
           input wire            clk,
           input wire            reset_n,
           
           input wire            init,
           input wire            next,
           input wire            finalize,
           input wire            enc_auth,  // 0: Encrypt, 1: Authenticate
           input wire [127 : 0]  counter,
           input wire [255 : 0]  key,
           input wire            keylen,
           input wire [7 : 0]    final_size, // Only used to process the final block of the message for both CMAC and CTR-mode
           input wire [127 : 0]  block_i,
           
           output reg [127 : 0]  block_o,
           output reg            ready
          );
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  
  // AES Core
  wire           core_encdec;
  reg            core_init;
  reg            core_next;
  wire           core_ready;
  wire [255 : 0] core_key;
  wire           core_keylen;
  reg  [127 : 0] core_block;
  wire [127 : 0] core_result;
  wire           core_valid;
  
  // CTR Core
  wire           ctr_core_init;
  wire           ctr_core_next;
  wire           ctr_core_finalize;
  wire [127 : 0] ctr_core_init_counter;
  wire [127 : 0] ctr_core_block_i;
  wire [7 : 0]   ctr_core_len_i;
  wire [127 : 0] ctr_core_block_o;
  wire           ctr_core_ready;
  
  wire           ctr_core_core_init;
  wire           ctr_core_core_next;
  wire [127 : 0] ctr_core_core_block;
  
  // CMAC Core
  wire [7 : 0]   cmac_core_final_size;
  wire           cmac_core_init;
  wire           cmac_core_next;
  wire           cmac_core_finalize;
  wire [127 : 0] cmac_core_block;
  wire [127 : 0] cmac_core_result;
  wire           cmac_core_ready;
  wire           cmac_core_valid;
  
  wire           cmac_core_core_init;
  wire           cmac_core_core_next;
  wire [127 : 0] cmac_core_core_block;
  
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
              
  ctr_core_ext ctr(
                   .clk(clk),
                   .reset_n(reset_n),
                   
                   .init(ctr_core_init),
                   .next(ctr_core_next),
                   .finalize(ctr_core_finalize),
                   .init_counter(ctr_core_init_counter),
                   .block_i(ctr_core_block_i),
                   .len_i(ctr_core_len_i),
                   
                   .core_init(ctr_core_core_init),
                   .core_next(ctr_core_core_next),
                   .core_block(ctr_core_core_block),
                   .core_ready(core_ready),
                   .core_result(core_result),
                   .core_valid(core_valid),
                   
                   .block_o(ctr_core_block_o),
                   .ready(ctr_core_ready)
                  );
  
  cmac_core_ext cmac(
                     .clk(clk),
                     .reset_n(reset_n),
                     
                     .final_size(cmac_core_final_size),
                     .init(cmac_core_init),
                     .next(cmac_core_next),
                     .finalize(cmac_core_finalize),
                     .block(cmac_core_block),
                     
                     .core_init(cmac_core_core_init),
                     .core_next(cmac_core_core_next),
                     .core_block(cmac_core_core_block),
                     .core_ready(core_ready),
                     .core_result(core_result),
                     .core_valid(core_valid),
                     
                     .result(cmac_core_result),
                     .ready(cmac_core_ready),
                     .valid(cmac_core_valid)
                    );
 
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  
  // AES Core
  assign core_encdec           = 1'b1;    // Only encryption is needed for CTR-mode and CMAC
  assign core_key              = key;
  assign core_keylen           = keylen;  // Keylen: 0 for 128-bit, 1 for 256-bit
  
  // CTR Core
  assign ctr_core_init         = init && (!enc_auth);
  assign ctr_core_next         = next && (!enc_auth);
  assign ctr_core_finalize     = finalize && (!enc_auth);
  assign ctr_core_init_counter = counter;
  assign ctr_core_block_i      = block_i;
  assign ctr_core_len_i        = final_size;
  
  // CMAC Core
  assign cmac_core_final_size  = final_size;
  assign cmac_core_init        = init && enc_auth;
  assign cmac_core_next        = next && enc_auth;
  assign cmac_core_finalize    = finalize && enc_auth;
  assign cmac_core_block       = block_i;
      
  //----------------------------------------------------------------
  // Logic
  //----------------------------------------------------------------
  always @*
    begin : aes_tot_logic
      if (enc_auth)
        begin
          block_o     = cmac_core_result;
          ready       = cmac_core_ready;
          core_init   = cmac_core_core_init;
          core_next   = cmac_core_core_next;
          core_block  = cmac_core_core_block;
        end
      else
        begin
          block_o     = ctr_core_block_o;
          ready       = ctr_core_ready;
          core_init   = ctr_core_core_init;
          core_next   = ctr_core_core_next;
          core_block  = ctr_core_core_block;
        end
    end // aes_tot_logic
    
  
endmodule // aes_tot
