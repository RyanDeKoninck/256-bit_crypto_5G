//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Ryan De Koninck
//
// Create Date: 03/28/2023 10:58:00 AM
// Design Name:
// Module Name: tb_snowv_core
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

module tb_zuc256_core();

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
  reg [7 : 0]    tb_tag_len;
  wire [31 : 0]  tb_keystream_z;
  wire           tb_ready;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  zuc256_core dut(
                  .clk(tb_clk),
                  .reset_n(tb_reset_n), 

                  .init(tb_init),
                  .next(tb_next),
                  .key(tb_key),
                  .iv(tb_iv),
                  .tag_len(tb_tag_len),

                  .keystream_z(tb_keystream_z),
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
      $display("");
      $display("ready  = 0x%01x", dut.ready);
      $display("keystream_z = 0x%08x", dut.keystream_z);
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
      tb_tag_len   = 8'h0;
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
  // zuc256_core_test
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : zuc256_core_test
      integer i;
      reg [31 : 0] expected_final;

      init_sim();
      dump_dut_state();
      reset_dut();
      dump_dut_state();

      // testvectors #1 from http://www.is.cas.cn/ztzl2016/zouchongzhi/201801/W020230201389233346416.pdf
      $display("--- Testvectors #1");
      tc_ctr = tc_ctr + 1;
      tb_key = 256'h0;
      tb_iv = 128'h0;
      expected_final = 32'h637788d9;

      tb_init = 1;
      #(2 * CLK_PERIOD);
      tb_init = 0;
      wait_ready();

      $display("Init done");

      for (i = 0 ; i < 20 ; i = i + 1)
        begin
          tb_next = 1;
          #(2 * CLK_PERIOD);
          tb_next = 0;
          wait_ready();
          $display("keystream[%1x] = 0x%08x", i, tb_keystream_z);
        end

      if (tb_keystream_z == expected_final)
        begin
          $display("*** TC %0d successful.", 1);
          $display("");
        end
      else
        begin
          $display("*** ERROR: TC %0d NOT successful.", 1);
          $display("Expected: 0x%08x", expected_final);
          $display("Got:      0x%08x", tb_keystream_z);
          $display("");

          error_ctr = error_ctr + 1;
        end

      // testvectors #2 http://www.is.cas.cn/ztzl2016/zouchongzhi/201801/W020230201389233346416.pdf
      $display("--- Testvectors #2");
      tc_ctr = tc_ctr + 1;
      tb_key = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
      tb_iv = 128'hffffffffffffffffffffffffffffffff;
      expected_final = 32'h89ea0373;

      tb_init = 1;
      #(2 * CLK_PERIOD);
      tb_init = 0;
      wait_ready();

      $display("Init done");

      for (i = 0 ; i < 20 ; i = i + 1)
        begin
          tb_next = 1;
          #(2 * CLK_PERIOD);
          tb_next = 0;
          wait_ready();
          $display("keystream[%1x] = 0x%08x", i, tb_keystream_z);
        end

      if (tb_keystream_z == expected_final)
        begin
          $display("*** TC %0d successful.", 2);
          $display("");
        end
      else
        begin
          $display("*** ERROR: TC %0d NOT successful.", 2);
          $display("Expected: 0x%08x", expected_final);
          $display("Got:      0x%08x", tb_keystream_z);
          $display("");

          error_ctr = error_ctr + 1;
        end
        
      display_test_result();
      $display("");
      $display("*** ZUC-256 core simulation done. ***");
      $finish;
    end // zuc256_core_test
endmodule // tb_zuc256_core

//======================================================================
// EOF tb_zuc256_core.v
//======================================================================
