//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 03/10/2023 03:02:44 PM
// Design Name: 
// Module Name: tb_aes_tot
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

module tb_aes_tot();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam DEBUG = 0;

  localparam CLK_HALF_PERIOD = 1;
  localparam CLK_PERIOD      = 2 * CLK_HALF_PERIOD;

  localparam AES_128_BIT_KEY = 0;
  localparam AES_256_BIT_KEY = 1;

  localparam AES_DECIPHER = 1'b0;
  localparam AES_ENCIPHER = 1'b1;


  localparam AES_BLOCK_SIZE = 128;


  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]  cycle_ctr;
  reg [31 : 0]  error_ctr;
  reg [31 : 0]  tc_ctr;
  reg           tc_correct;
  reg           debug_ctrl;

  reg            tb_clk;
  reg            tb_reset_n;
  reg            tb_enc_auth;
  reg [255 : 0]  tb_key;
  reg            tb_keylen;
  reg [127 : 0]  tb_counter;
  reg [7 : 0]    tb_final_size;
  reg            tb_init;
  reg            tb_next;
  reg            tb_finalize;
  reg [127 : 0]  tb_block_i;
  wire [127 : 0] tb_block_o;
  wire           tb_ready;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
 aes_tot dut(
           .clk(tb_clk),
           .reset_n(tb_reset_n),
           
           .enc_auth(tb_enc_auth),
           .key(tb_key),
           .keylen(tb_keylen),
           .counter(tb_counter),
           .final_size(tb_final_size),
           .init(tb_init),
           .next(tb_next),
           .finalize(tb_finalize),
           .block_i(tb_block_i),
           .block_o(tb_block_o),
           .ready(tb_ready)
          );

  //----------------------------------------------------------------
  // clk_gen
  //
  // Always running clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //
  // An always running process that creates a cycle counter and
  // conditionally displays information about the DUT.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;

      #(CLK_PERIOD);

      if (debug_ctrl)
        begin
          dump_dut_state();
        end
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state;
    begin
      $display("cycle:  0x%016x", cycle_ctr);
      $display("Inputs and outputs:");
      $display("init = 0x%01x, next = 0x%01x, finalize = 0x%01x",
               dut.init, dut.next, dut.finalize);
      $display("config: keylength = 0x%01x, final_size = 0x%01x",
               dut.keylen, dut.final_size);
      $display("block = 0x%032x, ready = 0x%01x, result =  0x%032x",
               dut.block_i, dut.ready, dut.block_o);
      $display("");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggle reset to put the DUT into a well known state.
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("TB: Resetting dut.");
      tb_reset_n = 0;
      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // display_test_results()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_results;
    begin
      $display("");
      if (error_ctr == 0)
        begin
          $display("%02d test completed. All test cases completed successfully.", tc_ctr);
        end
      else
        begin
          $display("%02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_results


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr     = 0;
      error_ctr     = 0;
      tc_ctr        = 0;
      debug_ctrl    = 0;

      tb_clk        = 1'h0;
      tb_reset_n    = 1'h1;
      tb_enc_auth   = 1'b1;
      tb_key        = 256'h0;
      tb_keylen     = 1'h0;
      tb_counter    = 128'h0;
      tb_final_size = 8'h0;
      tb_init       = 1'h0;
      tb_next       = 1'h0;
      tb_finalize   = 1'h0;
      tb_block_i    = 128'h0;
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // inc_tc_ctr
  //----------------------------------------------------------------
  task inc_tc_ctr;
    tc_ctr = tc_ctr + 1;
  endtask // inc_tc_ctr


  //----------------------------------------------------------------
  // inc_error_ctr
  //----------------------------------------------------------------
  task inc_error_ctr;
    error_ctr = error_ctr + 1;
  endtask // inc_error_ctr


  //----------------------------------------------------------------
  // pause_finish()
  //
  // Pause for a given number of cycles and then finish sim.
  //----------------------------------------------------------------
  task pause_finish(input [31 : 0] num_cycles);
    begin
      $display("Pausing for %04d cycles and then finishing hard.", num_cycles);
      #(num_cycles * CLK_PERIOD);
      $finish;
    end
  endtask // pause_finish


  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for the ready flag to be set in dut.
  //----------------------------------------------------------------
  task wait_ready;
    begin : wready
      while (tb_ready == 0)
        #(CLK_PERIOD);
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // tc1_reset_state
  //
  // Check that registers in the dut are being correctly reset.
  //----------------------------------------------------------------
  task tc1_reset_state;
    begin : tc1
      inc_tc_ctr();
      debug_ctrl = 0;
      $display("TC1: Check that the dut registers are correctly reset.");
      #(2 * CLK_PERIOD);
      reset_dut();
      #(2 * CLK_PERIOD);
    end
  endtask // tc1_reset_state

  //----------------------------------------------------------------
  // tc3_empty_message
  //
  // Check that the correct ICV is generated for an empty message.
  // The keys and test vectors are from the NIST spec, RFC 4493.
  //----------------------------------------------------------------
  task tc3_empty_message;
    begin : tc3
      integer i;

      inc_tc_ctr();
      tc_correct = 1;
      debug_ctrl = 0;

      $display("TC3: Check that correct ICV is generated for an empty message.");

      tb_key    = 256'h2b7e1516_28aed2a6_abf71588_09cf4f3c_00000000_00000000_00000000_00000000;
      tb_keylen = 1'h0;
      tb_init   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();

      $display("TC3: cmac_core initialized. Now for the final, empty message block.");
      tb_final_size = 8'h0;
      tb_finalize = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_ready();

      #(2 * CLK_PERIOD);
      debug_ctrl = 0;

      $display("TC3: cmac_core finished.");
      if (tb_block_o != 128'hbb1d6929e95937287fa37d129b756746)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC3: Error - Expected 0xbb1d6929e95937287fa37d129b756746, got 0x%032x",
                   tb_block_o);
        end

      if (tc_correct)
        $display("TC3: SUCCESS - ICV for empty message correctly generated.");
      else
        $display("TC3: NO SUCCESS - ICV for empty message not correctly generated.");
      $display("");
    end
  endtask // tc3


  //----------------------------------------------------------------
  // tc4_single_block_message
  //
  // Check that the correct ICV is generated for a single block
  // message.  The keys and test vectors are from the NIST spec,
  // RFC 4493.
  //----------------------------------------------------------------
  task tc4_single_block_message;
    begin : tc4
      integer i;

      inc_tc_ctr();
      tc_correct = 1;
      debug_ctrl = 0;

      $display("TC4: Check that correct ICV is generated for a single block message.");

      tb_key    = 256'h2b7e1516_28aed2a6_abf71588_09cf4f3c_00000000_00000000_00000000_00000000;
      tb_keylen = 1'h0;
      tb_init   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();

      $display("TC4: cmac_core initialized. Now for the final, full message block.");

      tb_block_i    = 128'h6bc1bee2_2e409f96_e93d7e11_7393172a;
      tb_final_size = AES_BLOCK_SIZE;
      tb_finalize   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_ready();

      #(2 * CLK_PERIOD);
      debug_ctrl = 0;

      $display("TC4: cmac_core finished.");
      if (tb_block_o != 128'h070a16b4_6b4d4144_f79bdd9d_d04a287c)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC4: Error - Expected 0x070a16b4_6b4d4144_f79bdd9d_d04a287c, got 0x%032x",
                   tb_block_o);
        end

      if (tc_correct)
        $display("TC4: SUCCESS - ICV for single block message correctly generated.");
      else
        $display("TC4: NO SUCCESS - ICV for single block message not correctly generated.");
      $display("");
    end
  endtask // tc4


  //----------------------------------------------------------------
  // tc5_two_and_a_half_block_message
  //
  // Check that the correct ICV is generated for a message that
  // consists of two and a half (40 bytes) blocks.
  // The keys and test vectors are from the NIST spec, RFC 4493.
  //----------------------------------------------------------------
  task tc5_two_and_a_half_block_message;
    begin : tc5
      integer i;

      inc_tc_ctr();
      tc_correct = 1;
      debug_ctrl = 0;

      $display("TC5: Check that correct ICV is generated for a two and a half block message.");
      tb_key    = 256'h2b7e1516_28aed2a6_abf71588_09cf4f3c_00000000_00000000_00000000_00000000;
      tb_keylen = 1'h0;
      tb_init   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      $display("TC5: cmac_core initialized. Now we process two full blocks.");

      tb_block_i = 128'h6bc1bee2_2e409f96_e93d7e11_7393172a;
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();
      $display("TC5: First block done.");

      tb_block_i = 128'hae2d8a57_1e03ac9c_9eb76fac_45af8e51;
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();
      $display("TC5: Second block done.");

      $display("TC5: Now we process the final half block.");
      tb_block_i      = 128'h30c81c46_a35ce411_00000000_00000000;
      tb_final_size = 8'h40;
      tb_finalize = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_ready();
      #(2 * CLK_PERIOD);
      debug_ctrl = 0;
      $display("TC5: cmac_core finished.");

      if (tb_block_o != 128'hdfa66747_de9ae630_30ca3261_1497c827)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC5: Error - Expected 0xdfa66747_de9ae630_30ca3261_1497c827, got 0x%032x",
                   tb_block_o);
        end

      if (tc_correct)
        $display("TC5: SUCCESS - ICV for two and a half block message correctly generated.");
      else
        $display("TC5: NO SUCCESS - ICV for two and a half block message not correctly generated.");
      $display("");
    end
  endtask // tc5


  //----------------------------------------------------------------
  // tc6_four_block_message
  //
  // Check that the correct ICV is generated for a message that
  // consists of four complete (64 bytes) blocks.
  // The keys and test vectors are from the NIST spec, RFC 4493.
  //----------------------------------------------------------------
  task tc6_four_block_message;
    begin : tc6
      integer i;

      inc_tc_ctr();
      tc_correct = 1;
      debug_ctrl = 0;

      $display("TC6: Check that correct ICV is generated for a four block message.");
      tb_key    = 256'h2b7e1516_28aed2a6_abf71588_09cf4f3c_00000000_00000000_00000000_00000000;
      tb_keylen = 1'h0;
      tb_init   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      $display("TC6: cmac_core initialized. Now we process four full blocks.");

      tb_block_i = 128'h6bc1bee2_2e409f96_e93d7e11_7393172a;
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();

      tb_block_i = 128'hae2d8a57_1e03ac9c_9eb76fac_45af8e51;
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();

      tb_block_i = 128'h30c81c46_a35ce411_e5fbc119_1a0a52ef;
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();

      tb_block_i      = 128'hf69f2445_df4f9b17_ad2b417b_e66c3710;
      tb_final_size = AES_BLOCK_SIZE;
      tb_finalize   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_ready();
      #(2 * CLK_PERIOD);
      debug_ctrl = 0;

      if (tb_block_o != 128'h51f0bebf_7e3b9d92_fc497417_79363cfe)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC6: Error - Expected 0x51f0bebf_7e3b9d92_fc497417_79363cfe, got 0x%032x",
                   tb_block_o);
        end

      if (tc_correct)
        $display("TC6: SUCCESS - ICV for four block message correctly generated.");
      else
        $display("TC6: NO SUCCESS - ICV for four block message not correctly generated.");
      $display("");
    end
  endtask // tc6


  //----------------------------------------------------------------
  // tc7_key256_four_block_message
  //
  // Check that the correct ICV is generated for a message that
  // consists of four complete (64 bytes) blocks. In this test
  // the the key is 256 bits.
  // The keys and test vectors are from the NIST spec.
  //----------------------------------------------------------------
  task tc7_key256_four_block_message;
    begin : tc7
      integer i;

      inc_tc_ctr();
      tc_correct = 1;
      debug_ctrl = 0;

      $display("TC7: Check that correct ICV is generated for a four block message usint a 256 bit key.");
      tb_key    = 256'h603deb10_15ca71be_2b73aef0_857d7781_1f352c07_3b6108d7_2d9810a3_0914dff4;
      tb_keylen = 1'h1;
      tb_init   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      $display("TC7: cmac_core initialized. Now we process four full blocks.");

      tb_block_i = 128'h6bc1bee2_2e409f96_e93d7e11_7393172a;
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();

      tb_block_i = 128'hae2d8a57_1e03ac9c_9eb76fac_45af8e51;
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();

      tb_block_i = 128'h30c81c46_a35ce411_e5fbc119_1a0a52ef;
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();

      tb_block_i = 128'hf69f2445_df4f9b17_ad2b417b_e66c3710;
      tb_final_size = AES_BLOCK_SIZE;
      tb_finalize   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_ready();
      #(2 * CLK_PERIOD);
      debug_ctrl = 0;

      if (tb_block_o != 128'he1992190_549f6ed5_696a2c05_6c315410)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC7: Error - Expected 0xe1992190_549f6ed5_696a2c05_6c315410, got 0x%032x",
                   tb_block_o);
        end

      if (tc_correct)
        $display("TC7: SUCCESS - ICV for four block message using 256 bit key correctly generated.");
      else
        $display("TC7: NO SUCCESS - ICV for four block message using 256 bit key not correctly generated.");
      $display("");
    end
  endtask // tc7


  //----------------------------------------------------------------
  // tc8_single_block_all_zero_message
  //
  // Check that we can get the correct ICV when using the test
  // vector key from RFC5297 and a single block all zero message.
  //----------------------------------------------------------------
  task tc8_single_block_all_zero_message;
    begin : tc8_single_block_all_zero_message
      integer i;

      inc_tc_ctr();
      tc_correct = 1;
      debug_ctrl = 0;

      $display("TC8: Check that correct ICV is generated for a single block, all zero message.");

      tb_key    = 256'hfffefdfc_fbfaf9f8_f7f6f5f4_f3f2f1f0_f0f1f2f3_f4f5f6f7_f8f9fafb_fcfdfeff;
      tb_keylen = 1'h0;
      tb_init   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();

      $display("TC4: cmac_core initialized. Now for the final, full message block.");

      tb_block_i      = 128'h0;
      tb_final_size = AES_BLOCK_SIZE;
      tb_finalize   = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_ready();

      #(2 * CLK_PERIOD);
      debug_ctrl = 0;

      $display("TC8: cmac_core finished.");
      if (tb_block_o != 128'h0e04dfaf_c1efbf04_01405828_59bf073a)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC8: Error - Expected 0x0e04dfaf_c1efbf04_01405828_59bf073a, got 0x%032x",
                   tb_block_o);
        end

      if (tc_correct)
        $display("TC8: SUCCESS - ICV for single block message correctly generated.");
      else
        $display("TC8: NO SUCCESS - ICV for single block message not correctly generated.");
      $display("");
    end
  endtask // tc8_single_block_all_zero_message

  //----------------------------------------------------------------
  // ctr_mode_enc256_test()
  //
  // Perform CTR-mode encryption or decryption single block test.
  //----------------------------------------------------------------
  task ctr_mode_enc256_test();
   begin : ctr_mode_enc_test
     reg [127 : 0] expected;
     $display("*** TC CTR-mode encryption test started.");
     tc_ctr = tc_ctr + 1;
     // Init the cipher with the given key and length.
     tb_key = 256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
     tb_keylen = 1'b1;
     tb_counter = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff;
     tb_final_size = 8'd128;
     
     tb_init = 1;
     #(2 * CLK_PERIOD);
     tb_init = 0;
     wait_ready();
     
     tb_block_i = 128'h6bc1bee22e409f96e93d7e117393172a;
     expected = 128'h601ec313775789a5b7a7f504bbf3d228;
     tb_next = 1;
     #(2 * CLK_PERIOD);
     tb_next = 0;
     wait_ready();
     
     if (tb_block_o == expected)
       $display("*** Block 1 successful.");
     else
       $display("*** Block 1 unsuccessful.");
     $display(""); 
     
     tb_block_i = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
     expected = 128'hf443e3ca4d62b59aca84e990cacaf5c5;
     tb_next = 1;
     #(2 * CLK_PERIOD);
     tb_next = 0;
     wait_ready();
     
     if (tb_block_o == expected)
       $display("*** Block 2 successful.");
     else
       $display("*** Block 2 unsuccessful.");
     $display("");
     
     tb_block_i = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
     expected = 128'h2b0930daa23de94ce87017ba2d84988d;
     tb_next = 1;
     #(2 * CLK_PERIOD);
     tb_next = 0;
     wait_ready();
     
     if (tb_block_o == expected)
       $display("*** Block 3 successful.");
     else
       $display("*** Block 3 unsuccessful.");
     $display("");
     
     tb_block_i = 128'hf69f2445df4f9b17ad2b417be66c3710;
     expected = 128'hdfc9c58db67aada613c2dd08457941a6;
     tb_finalize = 1;
     #(2 * CLK_PERIOD);
     tb_finalize = 0;
     wait_ready();
       
     if (tb_block_o == expected)
       begin
         $display("*** Block 4 successful.");
         $display("");
       end
       else
         begin
           $display("*** ERROR: Block 4 NOT successful.");
           $display("Expected: 0x%032x", expected);
           $display("Got:      0x%032x", tb_block_o);
           $display("");
  
           error_ctr = error_ctr + 1;
        end
     end
    endtask // ctr_mode_enc256_test
  
  //----------------------------------------------------------------
  // ctr_mode_enc128_test()
  //
  // Perform CTR-mode encryption or decryption single block test.
  //----------------------------------------------------------------
  task ctr_mode_enc128_test();
   begin : ctr_mode_enc_test
     reg [127 : 0] expected;
     $display("*** TC CTR-mode encryption test started.");
     tc_ctr = tc_ctr + 1;
     // Init the cipher with the given key and length.
     tb_key = 256'h2b7e151628aed2a6abf7158809cf4f3c00000000000000000000000000000000;
     tb_keylen = 1'b0;
     tb_counter = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff;
     tb_final_size = 8'd128;
     
     tb_init = 1;
     #(2 * CLK_PERIOD);
     tb_init = 0;
     wait_ready();
     
     tb_block_i = 128'h6bc1bee22e409f96e93d7e117393172a;
     expected = 128'h874d6191b620e3261bef6864990db6ce;
     tb_next = 1;
     #(2 * CLK_PERIOD);
     tb_next = 0;
     wait_ready();
     
     if (tb_block_o == expected)
       $display("*** Block 1 successful.");
     else
       $display("*** Block 1 unsuccessful.");
     $display(""); 
     
     tb_block_i = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
     expected = 128'h9806f66b7970fdff8617187bb9fffdff;
     tb_next = 1;
     #(2 * CLK_PERIOD);
     tb_next = 0;
     wait_ready();
     
     if (tb_block_o == expected)
       $display("*** Block 2 successful.");
     else
       $display("*** Block 2 unsuccessful.");
     $display("");
     
     tb_block_i = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
     expected = 128'h5ae4df3edbd5d35e5b4f09020db03eab;
     tb_next = 1;
     #(2 * CLK_PERIOD);
     tb_next = 0;
     wait_ready();
     
     if (tb_block_o == expected)
       $display("*** Block 3 successful.");
     else
       $display("*** Block 3 unsuccessful.");
     $display("");
     
     tb_final_size = 8'd64;
     tb_block_i = 128'had2b417be66c3710;
     expected = 128'h792170a0f3009cee;
     tb_finalize = 1;
     #(2 * CLK_PERIOD);
     tb_finalize = 0;
     wait_ready();
       
     if (tb_block_o == expected)
       begin
         $display("*** Block 4 successful.");
         $display("");
       end
       else
         begin
           $display("*** ERROR: Block 4 NOT successful.");
           $display("Expected: 0x%032x", expected);
           $display("Got:      0x%032x", tb_block_o);
           $display("");
  
           error_ctr = error_ctr + 1;
        end
     end
    endtask // ctr_mode_enc128_test
    
  //----------------------------------------------------------------
  // main
  //
  // The main test functionality.
  // CMAC tests come from https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38B.pdf
  //                  and https://csrc.nist.gov/csrc/media/projects/cryptographic-standards-and-guidelines/documents/examples/aes_cmac.pdf
  // CTR-mode tests come from http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
  //----------------------------------------------------------------
  initial
    begin : main
      $display("*** Testbench for AES TOT started ***");
      $display("");     
      $display("*** Tests for CMAC ***");
      $display("");   

      init_sim();
      
      tc1_reset_state();
      tc3_empty_message();
      tc4_single_block_message();
      tc5_two_and_a_half_block_message();
      tc6_four_block_message();
      tc7_key256_four_block_message();
      tc8_single_block_all_zero_message();
      

      $display("*** Tests for CTR-mode ***");
      $display("");
      
      tb_enc_auth = 0;

      ctr_mode_enc256_test();
      ctr_mode_enc128_test();

      display_test_results();

      $display("*** AES TOT simulation done. ***");
      $finish;
    end // main

endmodule // tb_aes_tot