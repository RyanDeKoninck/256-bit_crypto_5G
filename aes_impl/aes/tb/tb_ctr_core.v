//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2023 09:47:16 PM
// Design Name: 
// Module Name: tb_ctr
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

module tb_ctr_core();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG     = 0;
  parameter DUMP_WAIT = 0;
  
  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

  parameter AES_128_BIT_KEY = 0;
  parameter AES_256_BIT_KEY = 1;
  
  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0] cycle_ctr;
  reg [31 : 0] error_ctr;
  reg [31 : 0] tc_ctr;
  
  reg            tb_clk;
  reg            tb_reset_n;
  reg            tb_init;
  reg            tb_next;
  reg            tb_finalize;
  reg [127 : 0]  tb_init_counter;
  reg [255 : 0]  tb_key;
  reg            tb_keylen;
  reg [127 : 0]  tb_block_i;
  reg [7 : 0]    tb_len_i;
  wire [127 : 0] tb_block_o;
  wire           tb_ready;
  
  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  ctr_core dut(
               .clk(tb_clk),
               .reset_n(tb_reset_n),
               
               .init(tb_init),
               .next(tb_next),
               .finalize(tb_finalize),
               .init_counter(tb_init_counter),
               .key(tb_key),
               .keylen(tb_keylen),
               .block_i(tb_block_i),
               .len_i(tb_len_i),
               
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
      if (DEBUG)
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
      $display("State of DUT");
      $display("------------");
      $display("Inputs and outputs:");
      $display("init = 0x%01x", dut.init);
      $display("next = 0x%01x", dut.next);
      $display("counter  = 0x%032x", dut.init_counter);
      $display("keylen = 0x%01x, key  = 0x%032x ", dut.keylen, dut.key);
      $display("block_i  = 0x%032x", dut.block_i);
      $display("");
      $display("ready        = 0x%01x", dut.ready);
      $display("result = 0x%032x", dut.block_o);
      $display("");
      $display("Encipher state::");
      $display("enc_ctrl = 0x%01x, round_ctr = 0x%01x",
               dut.aes.enc_block.enc_ctrl_reg, dut.aes.enc_block.round_ctr_reg);
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
      $display("*** Toggle reset.");
      tb_reset_n = 0;
      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
    end
  endtask // reset_dut

  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr = 0;
      error_ctr = 0;
      tc_ctr    = 0;

      tb_clk          = 0;
      tb_reset_n      = 1;
      tb_init         = 0;
      tb_next         = 0;
      tb_init_counter = {4{32'h00000000}};
      tb_key          = {8{32'h00000000}};
      tb_keylen       = 0;
      tb_block_i      = {4{32'h00000000}};
    end
  endtask // init_sim
  
  //----------------------------------------------------------------
  // display_test_result()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_result;
    begin
      if (error_ctr == 0)
        begin
          $display("*** All %02d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** %02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_result
  
  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for the ready flag in the dut to be set.
  //
  // Note: It is the callers responsibility to call the function
  // when the dut is actively processing and will in fact at some
  // point set the flag.
  //----------------------------------------------------------------
  task wait_ready;
    begin
      while (!tb_ready)
        begin
          #(CLK_PERIOD);
          if (DUMP_WAIT)
            begin
              dump_dut_state();
            end
        end
    end
  endtask // wait_ready
  
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
     tb_init_counter = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff;
     tb_len_i = 8'd128;
     
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
     tb_init_counter = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff;
     tb_len_i = 8'd128;
     
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
     
     tb_len_i = 8'd64;
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
    // ctr_test
    // The main test functionality.
    // Test vectors copied from the following NIST document.
    //
    // NIST SP 800-38A:
    // http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
    //----------------------------------------------------------------
    initial
      begin : aes_core_test
  
        $display("   -= Testbench for ctr-mode started =-");
        $display("     ================================");
        $display("");
  
        init_sim();
        dump_dut_state();
        reset_dut();
        dump_dut_state();
  
        ctr_mode_enc256_test();
        ctr_mode_enc128_test();
  
        display_test_result();
        $display("");
        $display("*** AES core simulation done. ***");
        $finish;
      end // ctr_test
      
endmodule // tb_ctr