//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Ryan De Koninck
//
// Create Date: 04/24/2023 10:58:00 AM
// Design Name:
// Module Name: tb_zuc256_ctr
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

module tb_zuc256_ctr();

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
  reg            tb_init;
  reg            tb_next;
  reg [255 : 0]  tb_key;
  reg [127 : 0]  tb_iv;
  reg [31 : 0]   tb_word_i;
  wire [31 : 0]  tb_word_o;
  wire           tb_ready;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  zuc256_ctr dut(
                 .clk(tb_clk),
                 .reset_n(tb_reset_n),

                 .init(tb_init),
                 .next(tb_next),
                 .key(tb_key),
                 .iv(tb_iv),
                 .word_i(tb_word_i),

                 .word_o(tb_word_o),
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
      $display("init = 0x%01x, next = 0x%01x",
                dut.init, dut.next);
      $display("key  = 0x%064x ", dut.key);
      $display("iv   = 0x%032x", dut.iv);
      $display("word_i   = 0x%08x", dut.word_i);
      $display("");
      $display("ready  = 0x%01x", dut.ready);
      $display("word_o   = 0x%08x", dut.word_o);
      $display("------------");
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
      cycle_ctr    = 0;
      error_ctr    = 0;
      tc_ctr       = 0;

      tb_clk       = 0;
      tb_reset_n   = 1;
      tb_init      = 0;
      tb_next      = 0;
      tb_key       = {8{32'h00000000}};
      tb_iv        = {4{32'h00000000}};
      tb_word_i    = {4{32'h00000000}};
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
  // zuc256_mac_test
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : zuc256_mac_test
      integer i;
      reg [31 : 0] expected;

      init_sim();
      dump_dut_state();
      reset_dut();
      dump_dut_state();
      
      // Test 1 based on http://www.is.cas.cn/ztzl2016/zouchongzhi/201801/W020230201389233346416.pdf
      $display("--- Test #1");
      tc_ctr = tc_ctr + 1;
      tb_key = 256'h0;
      tb_iv = 128'h0;

      tb_init = 1;
      #(2 * CLK_PERIOD);
      tb_init = 0;
      wait_ready();
      $display("Init done");
      
      // First Block
      tb_word_i = 32'h01020304;
      expected = 32'h336ea36;

      tb_next = 1;
      #(2 * CLK_PERIOD);
      tb_next = 0;
      wait_ready();
      if (tb_word_o == expected)
        $display("*** Ciphertext %0d correct.", 1);
      else
        $display("*** Ciphertext %0d incorrect.", 1);

      // Second Block
      tb_word_i = 32'h05060708;
      expected = 32'hf5c4259a;

      tb_next = 1;
      #(2 * CLK_PERIOD);
      tb_next = 0;
      wait_ready();
      if (tb_word_o == expected)
        $display("*** Ciphertext %0d correct.", 2);
      else
        $display("*** Ciphertext %0d incorrect.", 2);
      
      // Third Block
      tb_word_i = 32'h090a0b0c;
      expected = 32'h318f3d6e;

      tb_next = 1;
      #(2 * CLK_PERIOD);
      tb_next = 0;
      wait_ready();
      if (tb_word_o == expected)
        $display("*** Ciphertext %0d correct.", 3);
      else
        $display("*** Ciphertext %0d incorrect.", 3);
      
      // Fourth Block
      tb_word_i = 32'h0d0e0f00;
      expected = 32'ha76c42ef;

      tb_next = 1;
      #(2 * CLK_PERIOD);
      tb_next = 0;
      wait_ready();
      if (tb_word_o == expected)
        $display("*** Ciphertext %0d correct.", 4);
      else
        begin
          $display("*** Ciphertext %0d incorrect.", 4);
          error_ctr = error_ctr + 1;
        end
      
      // Test 2 based on http://www.is.cas.cn/ztzl2016/zouchongzhi/201801/W020230201389233346416.pdf
      $display("--- Test #2");
      tc_ctr = tc_ctr + 1;
      tb_key = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
      tb_iv = 128'hffffffffffffffffffffffffffffffff;

      tb_init = 1;
      #(2 * CLK_PERIOD);
      tb_init = 0;
      wait_ready();
      $display("Init done");
      
      // First Block
      tb_word_i = 32'h01020304;
      expected = 32'h3887e1ab;

      tb_next = 1;
      #(2 * CLK_PERIOD);
      tb_next = 0;
      wait_ready();
      if (tb_word_o == expected)
        $display("*** Ciphertext %0d correct.", 1);
      else
        $display("*** Ciphertext %0d incorrect.", 1);

      // Second Block
      tb_word_i = 32'h05060708;
      expected = 32'h3035d321;

      tb_next = 1;
      #(2 * CLK_PERIOD);
      tb_next = 0;
      wait_ready();
      if (tb_word_o == expected)
        $display("*** Ciphertext %0d correct.", 2);
      else
        $display("*** Ciphertext %0d incorrect.", 2);
      
      // Third Block
      tb_word_i = 32'h090a0b0c;
      expected = 32'h3a8f8bfc;

      tb_next = 1;
      #(2 * CLK_PERIOD);
      tb_next = 0;
      wait_ready();
      if (tb_word_o == expected)
        $display("*** Ciphertext %0d correct.", 3);
      else
        $display("*** Ciphertext %0d incorrect.", 3);
      
      // Fourth Block
      tb_word_i = 32'h0d0e0f00;
      expected = 32'hedd603e9;

      tb_next = 1;
      #(2 * CLK_PERIOD);
      tb_next = 0;
      wait_ready();
      if (tb_word_o == expected)
        $display("*** Ciphertext %0d correct.", 4);
      else
        begin
          $display("*** Ciphertext %0d incorrect.", 4);
          error_ctr = error_ctr + 1;
        end     

      display_test_result();
      $display("");
      $display("*** ZUC-256 CTR simulation done. ***");
      $finish;
    end // zuc256_mac_test
endmodule // tb_zuc256_mac

//======================================================================
// EOF tb_zuc256_mac.v
//======================================================================
