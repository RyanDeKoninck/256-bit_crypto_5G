//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/07/2023 06:20:34 PM
// Design Name: 
// Module Name: snowv_gcm
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

module snowv_gcm(
           input wire            clk,
           input wire            reset_n,
           
           input wire            init,        // initialize SNOW-V, calculate H and Mtag, and process first AD block (if present)
           input wire            next_ad,     // process subsequent AD blocks
           input wire            next,        // process plaintext/ciphertext blocks
           input wire            finalize,    // calculate tag
           input wire            encdec_only, // set high when not calculating a tag (speedup)
           input wire            auth_only,   // set high when only calculating a tag (speedup)
           input wire            encdec,      // set high when enciphering, low when deciphering (and always low when not using encryption!)
           input wire            adj_len,     // set high when last block_i is not 128 bits long
           input wire [255 : 0]  key,
           input wire [127 : 0]  iv,
           input wire [127 : 0]  ad,
           input wire [63 : 0]   len_ad,
           input wire [127 : 0]  block_i,
           input wire [63 : 0]   len_i,
           
           output wire [127 : 0] block_o,
           output wire [127 : 0] tag,
           output wire           ready,
           output wire           tag_ready
          );
  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------        
  localparam CTRL_IDLE        = 4'h0;
  localparam CTRL_INIT        = 4'h1;
  localparam CTRL_DERIVE_H    = 4'h2;
  localparam CTRL_MTAG_NO_AD  = 4'h3;
  localparam CTRL_MTAG_W_AD   = 4'h4;
  localparam CTRL_MTAG_W_AD_2 = 4'h5;
  localparam CTRL_NEXT_AD     = 4'h6;
  localparam CTRL_NEXT_ENCDEC = 4'h7;
  localparam CTRL_NEXT_AUTH   = 4'h8;
  localparam CTRL_NEXT        = 4'h9;
  localparam CTRL_XOR_ENCDEC  = 4'ha;
  localparam CTRL_XOR         = 4'hb;
  localparam CTRL_AUTH        = 4'hc;
  localparam CTRL_FINAL       = 4'hd;
  localparam CTRL_FINAL_XOR   = 4'he;
  
  //----------------------------------------------------------------
  // Registers + update variables and write enable.
  //----------------------------------------------------------------
  reg [3 : 0]    snowv_gcm_ctrl_reg;
  reg [3 : 0]    snowv_gcm_ctrl_new;
  reg            snowv_gcm_ctrl_we;
  
  reg            ready_reg;
  reg            ready_new;
  reg            ready_we;
  
  reg            tag_ready_reg;
  reg            tag_ready_new;
  reg            tag_ready_we;
  
  reg [127 : 0]  H_reg;
  wire [127 : 0] H_new;
  reg            H_we;
  
  reg [127 : 0]  Mtag_reg;
  wire [127 : 0] Mtag_new;
  reg            Mtag_we;
  
  reg [127 : 0]  block_o_reg;
  reg [127 : 0]  block_o_new;
  reg            block_o_we;

  // Extra control signals
  reg            first_block_reg;
  reg            first_block_new;
  reg            first_block_we;
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  
  // For SNOW-V core
  wire           core_aead_mode;
  reg            core_init;
  reg            core_next;
  wire [255 : 0] core_key;
  wire [127 : 0] core_iv;
  wire [127 : 0] core_keystream_z;
  wire           core_ready;
  
  // For GHASH core
  reg            ghash_first_init;     // Use for first block of AD
  reg            ghash_init;           // Use for subsequent blocks of AD
  reg            ghash_next_no_ad;     // Use for the first block of ciphertext if no AD
  reg            ghash_next;           // Use for the first block of ciphertext if there is AD or for subsequent blocks
  reg            ghash_finalize_no_in; // Use to finalize if no AD and no ciphertext
  reg            ghash_finalize;       // Use to finalize (final XOR and mulH)
  wire [127 : 0] ghash_H;
  wire [127 : 0] ghash_ad;
  wire [63 : 0]  ghash_len_ad;
  wire [127 : 0] ghash_in;
  wire [63 : 0]  ghash_len_i;
  wire [127 : 0] ghash_out;
  wire           ghash_ready;
  
  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  snowv_core snowv(
                   .clk(clk),
                   .reset_n(reset_n),
      
                   .aead_mode(core_aead_mode),
                   .init(core_init),
                   .next(core_next),     
                   .key(core_key),
                   .iv(core_iv),
                     
                   .keystream_z(core_keystream_z),
                   .ready(core_ready)
                  );
  
  ghash_alt ghash_alt(
              .clk(clk),
              .reset_n(reset_n),
               
              .first_init(ghash_first_init),
              .init(ghash_init),
              .next_no_ad(ghash_next_no_ad),
              .next(ghash_next),
              .finalize_no_in(ghash_finalize_no_in),
              .finalize(ghash_finalize),
                
              .H(ghash_H),
              .ad(ghash_ad),
              .len_ad(ghash_len_ad),
              .block_i(ghash_in),
              .len_i(ghash_len_i),
              
              .X(ghash_out),
              .ready(ghash_ready)
              );
 
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign core_aead_mode = 1'b1;
  assign core_key       = key;
  assign core_iv        = iv;
  
  assign ghash_H        = H_reg;
  assign ghash_ad       = ad;
  assign ghash_len_ad   = len_ad;
  // encdec == 1 -> Encryption, thus GHASH needs ciphertext_reg as input
  // encdec == 0 -> Decryption, thus GHASH needs block_i as input
  assign ghash_in       = encdec ? block_o_reg : block_i;
  assign ghash_len_i    = len_i;
  
  assign H_new          = core_keystream_z;
  assign Mtag_new       = core_keystream_z; 
  // encdec == 1 -> Encryption
  // encdec == 0 -> Decryption
  assign block_o        = block_o_reg;
  assign ready          = ready_reg;
  assign tag_ready      = tag_ready_reg;
  
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
          snowv_gcm_ctrl_reg  <= CTRL_IDLE;
          ready_reg           <= 1'b0;
          tag_ready_reg       <= 1'b0;
          H_reg               <= 128'h0;
          Mtag_reg            <= 128'h0;
          block_o_reg         <= 128'h0;
          first_block_reg     <= 1'b0;
        end
      else
        begin
          if (snowv_gcm_ctrl_we)
            snowv_gcm_ctrl_reg <= snowv_gcm_ctrl_new;
          if (ready_we)
            ready_reg <= ready_new;
          if (tag_ready_we)
            tag_ready_reg <= tag_ready_new;
          if (H_we)
            H_reg <= H_new;
          if (Mtag_we)
            Mtag_reg <= Mtag_new;
          if (block_o_we)
            block_o_reg <= block_o_new;
          if (first_block_we)
            first_block_reg <= first_block_new;
        end
    end // reg_update
    
  //----------------------------------------------------------------
  // Encryption/Decryption Logic
  //----------------------------------------------------------------
  always@*
    begin
      if (adj_len == 1)
        block_o_new = block_i ^ (core_keystream_z << (128 - len_i[6 : 0])) >> (128 - len_i[6 : 0]);
      else
        block_o_new = block_i ^ core_keystream_z;
    end
  
  //----------------------------------------------------------------
  // Tag logic
  //----------------------------------------------------------------
  assign tag = ghash_out ^ Mtag_reg;

  //----------------------------------------------------------------
  // snowv_gcm_ctrl
  //
  // Control FSM for snowv_gcm.
  //----------------------------------------------------------------
  always @*
    begin: snowv_gcm_ctrl
      ready_new            = 1'b0;
      ready_we             = 1'b0;
      tag_ready_new        = 1'b0;
      tag_ready_we         = 1'b0;
      snowv_gcm_ctrl_new   = CTRL_IDLE;
      snowv_gcm_ctrl_we    = 1'b0;
      H_we                 = 1'b0;
      Mtag_we              = 1'b0;
      block_o_we           = 1'b0;
      
      core_init            = 1'b0;
      core_next            = 1'b0;
      ghash_first_init     = 1'b0;
      ghash_init           = 1'b0;
      ghash_next_no_ad     = 1'b0;
      ghash_next           = 1'b0;
      ghash_finalize_no_in = 1'b0;
      ghash_finalize       = 1'b0;
      
      first_block_new      = 1'b0;
      first_block_we       = 1'b0;
        
      case (snowv_gcm_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_new     = 1'b0;
            ready_we      = 1'b1;
            tag_ready_new = 1'b0;
            tag_ready_we  = 1'b1;
            if (init)
              begin
                snowv_gcm_ctrl_new = CTRL_INIT;
                snowv_gcm_ctrl_we  = 1'b1;
                core_init          = 1'b1;
                first_block_new    = 1'b1;
                first_block_we     = 1'b1;
              end
            if (next_ad)
              begin
                snowv_gcm_ctrl_new = CTRL_NEXT_AD;
                snowv_gcm_ctrl_we  = 1'b1;
                ghash_init         = 1'b1;
              end
            if (next)
              begin
                if (encdec_only)
                  begin
                    snowv_gcm_ctrl_new = CTRL_NEXT_ENCDEC;
                    snowv_gcm_ctrl_we  = 1'b1;
                    core_next          = 1'b1;
                  end
                else if (auth_only)
                  begin
                    snowv_gcm_ctrl_new = CTRL_NEXT_AUTH;
                    snowv_gcm_ctrl_we  = 1'b1;
                    if (first_block_reg && (len_ad == 64'h0))
                      ghash_next_no_ad = 1'b1;
                    else
                      ghash_next = 1'b1;
                  end
                else
                  begin
                    snowv_gcm_ctrl_new = CTRL_NEXT;
                    snowv_gcm_ctrl_we  = 1'b1;
                    core_next          = 1'b1;
                  end
              end
            if (finalize)
              begin
                snowv_gcm_ctrl_new = CTRL_FINAL;
                snowv_gcm_ctrl_we  = 1'b1;
                if ((len_ad == 64'h0) && (len_i == 64'h0))
                  ghash_finalize_no_in = 1'b1;
                else
                  ghash_finalize = 1'b1;
              end
          end
        CTRL_INIT:
          begin
            if (core_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_DERIVE_H;
                snowv_gcm_ctrl_we  = 1'b1;
                core_next          = 1'b1;
              end
          end
        CTRL_DERIVE_H:
          begin
            if (core_ready)
              begin
                core_next          = 1'b1;
                H_we               = 1'b1;
                if (len_ad == 64'h0)
                  begin
                    snowv_gcm_ctrl_new = CTRL_MTAG_NO_AD;
                    snowv_gcm_ctrl_we  = 1'b1;
                  end
                else
                  begin
                    snowv_gcm_ctrl_new = CTRL_MTAG_W_AD;
                    snowv_gcm_ctrl_we  = 1'b1;
                  end
              end
          end
        CTRL_MTAG_NO_AD:
          begin
            if (core_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_IDLE;
                snowv_gcm_ctrl_we  = 1'b1;
                Mtag_we            = 1'b1;
                ready_new          = 1'b1;
                ready_we           = 1'b1;
              end
          end
        CTRL_MTAG_W_AD:
          begin
            if (core_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_MTAG_W_AD_2;
                snowv_gcm_ctrl_we  = 1'b1;
                Mtag_we            = 1'b1;
                ghash_first_init   = 1'b1;
              end
          end
        CTRL_MTAG_W_AD_2:
          begin
            if (ghash_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_IDLE;
                snowv_gcm_ctrl_we  = 1'b1;
                ready_new          = 1'b1;
                ready_we           = 1'b1;
              end
          end
        CTRL_NEXT_AD:
          begin
            if (ghash_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_IDLE;
                snowv_gcm_ctrl_we  = 1'b1;
              end
          end
        CTRL_NEXT_ENCDEC:
          begin
            if (core_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_XOR;
                snowv_gcm_ctrl_we  = 1'b1;
              end
          end
        CTRL_NEXT_AUTH:
          begin
            first_block_new = 1'b0;
            first_block_we  = 1'b1;
            if (ghash_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_IDLE;
                snowv_gcm_ctrl_we  = 1'b1;
                ready_new          = 1'b1;
                ready_we           = 1'b1;
              end
          end
        CTRL_NEXT:
          begin
            if (core_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_XOR;
                snowv_gcm_ctrl_we  = 1'b1;
              end
          end
        CTRL_XOR_ENCDEC:
          begin
            snowv_gcm_ctrl_new = CTRL_IDLE;
            snowv_gcm_ctrl_we  = 1'b1;
            ready_new          = 1'b1;
            ready_we           = 1'b1;
            block_o_we         = 1'b1;
          end  
        CTRL_XOR:
          begin
            snowv_gcm_ctrl_new = CTRL_AUTH;
            snowv_gcm_ctrl_we  = 1'b1;
            block_o_we         = 1'b1;
            if (first_block_reg && (len_ad == 64'h0))
              ghash_next_no_ad = 1'b1;
            else
              ghash_next = 1'b1;
          end
        CTRL_AUTH:
          begin
            first_block_new = 1'b0;
            first_block_we  = 1'b1;
            if (ghash_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_IDLE;
                snowv_gcm_ctrl_we  = 1'b1;
                ready_new          = 1'b1;
                ready_we           = 1'b1;
              end
          end
        CTRL_FINAL:
          begin
            if (ghash_ready)
              begin
                snowv_gcm_ctrl_new = CTRL_FINAL_XOR;
                snowv_gcm_ctrl_we  = 1'b1;
              end
          end 
        CTRL_FINAL_XOR:
          begin
            snowv_gcm_ctrl_new = CTRL_IDLE;
            snowv_gcm_ctrl_we  = 1'b1;
            tag_ready_new      = 1'b1;
            tag_ready_we       = 1'b1;
          end  
        default: 
          begin
        
          end
        endcase // case (snowv_gcm_ctrl_reg)
        
      end // snowvgcm_ctrl
  
endmodule // snowv_gcm
