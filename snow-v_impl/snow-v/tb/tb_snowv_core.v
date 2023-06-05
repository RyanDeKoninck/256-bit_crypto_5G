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

module tb_snowv_core();

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
  reg            tb_aead_mode;
  reg            tb_init;
  reg            tb_next;
  reg [255 : 0]  tb_key;
  reg [127 : 0]  tb_iv;
  wire [127 : 0] tb_keystream_z;
  wire           tb_ready;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  snowv_core dut(
                 .clk(tb_clk),
                 .reset_n(tb_reset_n),

                 .aead_mode(tb_aead_mode),
                 .init(tb_init),
                 .next(tb_next),
                 .key(tb_key),
                 .iv(tb_iv),

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
      $display("aead_mode = 0x%01x, init = 0x%01x, next = 0x%01x",
               dut.aead_mode, dut.init, dut.next);
      $display("key  = 0x%064x ", dut.key);
      $display("iv   = 0x%032x", dut.iv);
      $display("");
      $display("ready  = 0x%01x", dut.ready);
      $display("keystream_z = 0x%032x", dut.keystream_z);
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
      tb_aead_mode = 0;
      tb_init      = 0;
      tb_next      = 0;
      tb_key       = {8{32'h00000000}};
      tb_iv        = {4{32'h00000000}};
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
  // snowv_core_test
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : snowv_core_test
      integer i;
      reg [127 : 0] expected_final;
      
      init_sim();
      dump_dut_state();
      reset_dut();
      dump_dut_state();
      
      // testvectors #1 from https://eprint.iacr.org/2018/1143.pdf
      $display("--- Testvectors #1");
      tc_ctr = tc_ctr + 1;
      tb_key = 256'h0;
      tb_iv = 128'h0;
      expected_final = 128'h7982bfe61d48e2a8f602af8430df4f95;
      
      tb_init = 1;
      #(2 * CLK_PERIOD);
      tb_init = 0;
      wait_ready();

      $display("Init done");
      
      for (i = 0 ; i < 8 ; i = i + 1)
        begin
          tb_next = 1;
          #(2 * CLK_PERIOD);
          tb_next = 0;
          wait_ready();
          $display("result[%1x] = 0x%032x", i, tb_keystream_z);
        end
      
      if (tb_keystream_z == expected_final)
        begin
          $display("*** TC %0d successful.", 1);
          $display("");
        end
      else
        begin
          $display("*** ERROR: TC %0d NOT successful.", 1);
          $display("Expected: 0x%032x", expected_final);
          $display("Got:      0x%032x", tb_keystream_z);
          $display("");
 
          error_ctr = error_ctr + 1;
        end
      
      // testvectors #2 from https://eprint.iacr.org/2018/1143.pdf
      $display("--- Testvectors #2");
      tc_ctr = tc_ctr + 1;
      tb_key = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
      tb_iv = 128'hffffffffffffffffffffffffffffffff;
      expected_final = 128'h09eaa6cb49b83a3b706e6762fcff0486;

      tb_init = 1;
      #(2 * CLK_PERIOD);
      tb_init = 0;
      wait_ready();

      $display("Init done");
      
      for (i = 0 ; i < 8 ; i = i + 1)
        begin
          tb_next = 1;
          #(2 * CLK_PERIOD);
          tb_next = 0;
          wait_ready();
          $display("result[%1x] = 0x%032x", i, tb_keystream_z);
        end
      
      if (tb_keystream_z == expected_final)
        begin
          $display("*** TC %0d successful.", 2);
          $display("");
        end
      else
        begin
          $display("*** ERROR: TC %0d NOT successful.", 2);
          $display("Expected: 0x%032x", expected_final);
          $display("Got:      0x%032x", tb_keystream_z);
          $display("");
 
          error_ctr = error_ctr + 1;
        end
      
      // testvectors #3 from https://eprint.iacr.org/2018/1143.pdf
      $display("--- Testvectors #3");
      tc_ctr = tc_ctr + 1;
      tb_key = 256'hfaeadacabaaa9a8a7a6a5a4a3a2a1a0a5f5e5d5c5b5a59585756555453525150;
      tb_iv = 128'h1032547698badcfeefcdab8967452301;
      expected_final = 128'h91624d59e70fadb073d052de1841b415;
      
      tb_init = 1;
      #(2 * CLK_PERIOD);
      tb_init = 0;
      wait_ready();

      $display("Init done");
    
      for (i = 0 ; i < 8 ; i = i + 1)
        begin
          tb_next = 1;
          #(2 * CLK_PERIOD);
          tb_next = 0;
          wait_ready();
          $display("result[%1x] = 0x%032x", i, tb_keystream_z);
        end
      
      if (tb_keystream_z == expected_final)
        begin
          $display("*** TC %0d successful.", 3);
          $display("");
        end
      else
        begin
          $display("*** ERROR: TC %0d NOT successful.", 3);
          $display("Expected: 0x%032x", expected_final);
          $display("Got:      0x%032x", tb_keystream_z);
          $display("");
 
          error_ctr = error_ctr + 1;
        end

      display_test_result();
      $display("");
      $display("*** SNOW-V core simulation done. ***");
      $finish;
    end // snowv_core_test
endmodule // tb_snowv_core

//======================================================================
// EOF tb_snowv_core.v
//======================================================================
