//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Ryan De Koninck
//
// Create Date: 04/20/2023 15:12:00
// Design Name:
// Module Name: zuc256_tot
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

module zuc256_tot(
           input wire            clk,
           input wire            reset_n,
           
           input wire            init,
           input wire            next,
           input wire            final,    // Only used for MAC
           input wire            enc_auth, // 0 : encrypt, 1 : authenticate
           input wire [255 : 0]  key,
           input wire [127 : 0]  iv,
           input wire [127 : 0]  block_i,
           input wire [7 : 0]    i_len,
           input wire [7 : 0]    tag_len,  // Either 32, 64, or 128

           output reg [127 : 0]  block_o,
           output reg            ready
          );

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  
  // -- Keystream generator
  reg            core_init;
  reg            core_next;
  wire [255 : 0] core_key;
  wire [127 : 0] core_iv;
  wire [7 : 0]   core_tag_len;
  wire [31 : 0]  core_z;
  wire           core_ready;  
  
  // -- CTR-mode core
  reg            ctr_core_init;
  reg            ctr_core_next;
  wire [31 : 0]  ctr_core_word_i;
  wire [31 : 0]  ctr_core_keystream_z;
  wire           ctr_core_keystream_ready;
  wire           ctr_core_keystream_init;
  wire           ctr_core_keystream_next;
  wire [31 : 0]  ctr_core_word_o;
  wire           ctr_core_ready;
  
  // -- MAC core
  reg            mac_core_init;
  reg            mac_core_next;
  reg            mac_core_final;
  wire [127 : 0] mac_core_block_i;
  wire [7 : 0]   mac_core_i_len;
  wire [7 : 0]   mac_core_tag_len;
  wire [31 : 0]  mac_core_keystream_z;
  wire           mac_core_keystream_ready;
  wire           mac_core_keystream_init;
  wire           mac_core_keystream_next;
  wire [127 : 0] mac_core_tag;
  wire           mac_core_ready;
  
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
  
   zuc256_ctr_ext ctr_core(
                           .clk(clk),
                           .reset_n(reset_n),
                           
                           .init(ctr_core_init),
                           .next(ctr_core_next),
                           .word_i(ctr_core_word_i),
                           
                           .core_z(ctr_core_keystream_z),
                           .core_ready(ctr_core_keystream_ready),
                           
                           .core_init(ctr_core_keystream_init),
                           .core_next(ctr_core_keystream_next),
                           
                           .word_o(ctr_core_word_o),
                           .ready(ctr_core_ready)
                           );
                   
  zuc256_mac_ext mac_core(
                          .clk(clk),
                          .reset_n(reset_n),
                          
                          .init(mac_core_init),
                          .next(mac_core_next),
                          .final(mac_core_final),
                          .block_i(mac_core_block_i),
                          .i_len(mac_core_i_len),
                          .tag_len(mac_core_tag_len),
                          
                          .core_z(mac_core_keystream_z),
                          .core_ready(mac_core_keystream_ready),
                          
                          .core_init(mac_core_keystream_init),
                          .core_next(mac_core_keystream_next),
                          
                          .tag(mac_core_tag),
                          .ready(mac_core_ready)
                          );

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------  
  assign core_key                 = key;
  assign core_iv                  = iv;
  assign core_tag_len             = tag_len;
  
  assign ctr_core_word_i          = block_i[31 : 0];
  assign ctr_core_keystream_z     = core_z;
  assign ctr_core_keystream_ready = core_ready; 
  
  assign mac_core_block_i         = block_i;
  assign mac_core_i_len           = i_len;
  assign mac_core_tag_len         = tag_len;
  assign mac_core_keystream_z     = core_z;
  assign mac_core_keystream_ready = core_ready;
    
  //----------------------------------------------------------------
  // Logic
  //----------------------------------------------------------------
  always @*
    begin : logic
      mac_core_final = final;
      mac_core_init  = 1'b0;
      mac_core_next  = 1'b0;
      ctr_core_init  = 1'b0;
      ctr_core_next  = 1'b0;
      
      if (enc_auth)
        begin
          mac_core_init = init;
          mac_core_next = next;
          core_init     = mac_core_keystream_init;
          core_next     = mac_core_keystream_next;
          block_o       = mac_core_tag;
          ready         = mac_core_ready;
        end
      else
        begin
          ctr_core_init = init;
          ctr_core_next = next;
          core_init     = ctr_core_keystream_init;
          core_next     = ctr_core_keystream_next;
          block_o       = {96'h0, ctr_core_word_o};
          ready         = ctr_core_ready;
        end
    end // logic
    
endmodule // zuc256_tot
