//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 03/28/2023 02:52:57 PM
// Design Name: 
// Module Name: aes_enc_round
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

module tb_aes_enc_round();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG     = 0;
  parameter DUMP_WAIT = 0;

  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]   cycle_ctr;
  reg [31 : 0]   error_ctr;
  reg [31 : 0]   tc_ctr;

  reg            tb_clk;
  reg            tb_reset_n;

  reg            tb_start;
  wire           tb_ready;
  reg [127 : 0]  tb_round_key;

  wire [31 : 0]  tb_sboxw_i;
  wire [31 : 0]  tb_sboxw_o;

  reg [127 : 0]  tb_block_i;
  wire [127 : 0] tb_block_o;
  
  reg [127 : 0] round_key;
  reg [127 : 0] block_i;
  reg [127 : 0] block_o;

  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  // We need an sbox for the tests.
  aes_sbox sbox(
                .sboxw(tb_sboxw_i),
                .new_sboxw(tb_sboxw_o)
               );


  // The device under test.
  aes_enc_round dut(
                    .clk(tb_clk),
                    .reset_n(tb_reset_n),

                    .start(tb_start),
                    .round_key(tb_round_key),

                    .sboxw_i(tb_sboxw_i),
                    .sboxw_o(tb_sboxw_o),

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
      $display("Interfaces");
      $display("ready = 0x%01x, start = 0x%01x",
               dut.ready, dut.start);
      $display("block_i = 0x%032x", dut.block_i);
      $display("block_o = 0x%032x", dut.block_o);
      $display("");

      $display("Control states");
      $display("enc_ctrl = 0x%01x, update_type = 0x%01x, sword_ctr = 0x%01x",
               dut.enc_round_ctrl_reg, dut.update_type, dut.sword_ctr_reg);
      $display("");

      $display("Internal data values");
      $display("round_key = 0x%016x", dut.round_key);
      $display("sboxw_i = 0x%08x, sboxw_o = 0x%08x", dut.sboxw_i, dut.sboxw_o);
      $display("block_w0_reg = 0x%08x, block_w1_reg = 0x%08x, block_w2_reg = 0x%08x, block_w3_reg = 0x%08x",
               dut.block_w0_reg, dut.block_w1_reg, dut.block_w2_reg, dut.block_w3_reg);
      $display("");
      $display("old_block          = 0x%08x", dut.round_logic.old_block);
      $display("shiftrows_block    = 0x%08x", dut.round_logic.shiftrows_block);
      $display("mixcolumns_block   = 0x%08x", dut.round_logic.mixcolumns_block);
      $display("addkey_main_block  = 0x%08x", dut.round_logic.addkey_main_block);
      $display("block_w0_new = 0x%08x, block_w1_new = 0x%08x, block_w2_new = 0x%08x, block_w3_new = 0x%08x",
               dut.block_new[127 : 096], dut.block_new[095 : 064],
               dut.block_new[063 : 032], dut.block_new[031 : 000]);
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
      $display("--- Toggle reset.");
      tb_reset_n = 0;
      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
      $display("");
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
      cycle_ctr    = 0;
      error_ctr    = 0;
      tc_ctr       = 0;

      tb_clk       = 0;
      tb_reset_n   = 1;

      tb_start     = 0;

      tb_block_i   = {4{32'h00000000}};
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
          $display("--- All %02d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("--- %02d tests completed - %02d test cases did not complete successfully.",
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
  // test_round_enc()
  //
  // Perform round encryption test.
  //----------------------------------------------------------------
  task test_round_enc(
                      input [127 : 0] round_key,
                      input [127 : 0] block,
                      input [127 : 0] expected);
   begin
     tc_ctr = tc_ctr + 1;

     $display("--- Round encryption started.");

     tb_round_key = round_key;
     tb_block_i   = block;
     tb_start     = 1;
     #(2 * CLK_PERIOD);

     wait_ready();

     if (tb_block_o == expected)
       begin
         $display("--- Testcase successful.");
         $display("--- Got: 0x%032x", tb_block_o);
       end
     else
       begin
         $display("--- ERROR: Testcase NOT successful.");
         $display("--- Expected: 0x%032x", expected);
         $display("--- Got:      0x%032x", tb_block_o);
         error_ctr = error_ctr + 1;
       end
     $display("--- Round encryption test completed.");
   end
  endtask // round_enc_test


  //----------------------------------------------------------------
  // tb_aes_enc_round
  
  // The main test functionality. Tests are taken from FIPS 197,
  // test case AES-128 (Nk=4, Nr=10).
  //----------------------------------------------------------------
  initial
    begin : tb_aes_enc_round
      $display("   -= Testbench for aes encipher round started =-");
      $display("     ============================================");
      $display("");
      
      init_sim();
      reset_dut();
      
      // Test 1
      round_key = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
      block_i   = 128'h00102030405060708090a0b0c0d0e0f0;
      block_o   = 128'h89d810e8855ace682d1843d8cb128fe4;
      test_round_enc(round_key, block_i, block_o);
      
      // Test 2
      round_key = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
      block_i   = 128'h89d810e8855ace682d1843d8cb128fe4;
      block_o   = 128'h4915598f55e5d7a0daca94fa1f0a63f7;
      test_round_enc(round_key, block_i, block_o);
      
      // Test 3
      round_key = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
      block_i   = 128'h4915598f55e5d7a0daca94fa1f0a63f7;
      block_o   = 128'hfa636a2825b339c940668a3157244d17;
      test_round_enc(round_key, block_i, block_o);
      
      // Test 4
      round_key = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
      block_i   = 128'hfa636a2825b339c940668a3157244d17;
      block_o   = 128'h247240236966b3fa6ed2753288425b6c;
      test_round_enc(round_key, block_i, block_o);
      
      // Test 5
      round_key = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
      block_i   = 128'h247240236966b3fa6ed2753288425b6c;
      block_o   = 128'hc81677bc9b7ac93b25027992b0261996;
      test_round_enc(round_key, block_i, block_o);

      display_test_result();
      $display("");
      $display("   -= Testbench for aes encipher round completed =-");
      $display("     ============================================");
      $finish;
    end // tb_aes_encipher_block
endmodule // tb_aes_encipher_block

//======================================================================
// EOF tb_aes_encipher_block.v
//======================================================================
