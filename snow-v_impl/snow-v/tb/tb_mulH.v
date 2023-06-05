//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/08/2023 19:07:16 PM
// Design Name: 
// Module Name: tb_mulH
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

module tb_mulH();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;
  
  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0] cycle_ctr;
  reg [31 : 0] error_ctr;
  reg [31 : 0] tc_ctr;
  
  reg            tb_clk;
  reg            tb_reset_n;
  reg            tb_start;
  reg [127 : 0]  tb_H;
  reg [127 : 0]  tb_in;
  wire [127 : 0] tb_out;
  wire           tb_ready;
  
  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  mulH dut(
           .clk(tb_clk),
           .reset_n(tb_reset_n),
            
           .start(tb_start),
           .H(tb_H),
           .block_i(tb_in),
            
           .block_o(tb_out),
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
    end
  
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

      tb_clk     = 0;
      tb_reset_n = 1;
      tb_start   = 0;
      tb_in      = {4{32'h00000000}};
      tb_H       = {4{32'h00000000}};
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
        end
    end
  endtask // wait_ready
 
  //----------------------------------------------------------------
  // mulH_test
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : mulH_test
      reg [127 : 0] expected;
      init_sim();
      reset_dut();
      
      tc_ctr = tc_ctr + 1;
      tb_in = {120'b0, 8'b10001010};
      tb_H = {8'b00000010, 112'b0, 8'b00000010};
      expected = {8'b00010100, 112'b1, 8'b10010011};
      tb_start = 1'b1;
      #(CLK_PERIOD*2);
      tb_start = 1'b0;
      wait_ready();
      
      if (tb_out == expected)
         begin
           $display("--- Testcase successful.");
           $display("--- Got: 0x%032x", tb_out);
         end
       else
         begin
           $display("--- ERROR: Testcase NOT successful.");
           $display("--- Expected: 0x%032x", expected);
           $display("--- Got:      0x%032x", tb_out);
           error_ctr = error_ctr + 1;
         end

      tc_ctr = tc_ctr + 1;
      tb_in = 128'hec7bcaca160da13411460e8962e3747a;
      tb_H = 128'h74d42c539a5f3211dc3451f72bd29766;
      expected = 128'ha11f0d6da75ea2c33bc4496b58dd31cf;
      tb_start = 1'b1;
      #(CLK_PERIOD*2);
      tb_start = 1'b0;
      wait_ready();
      
      if (tb_out == expected)
         begin
           $display("--- Testcase successful.");
           $display("--- Got: 0x%032x", tb_out);
         end
       else
         begin
           $display("--- ERROR: Testcase NOT successful.");
           $display("--- Expected: 0x%032x", expected);
           $display("--- Got:      0x%032x", tb_out);
           error_ctr = error_ctr + 1;
         end

      display_test_result();
      $display("");
      $display("*** mulH simulation done. ***");
      $finish;
    end // mulH_test
      
endmodule // tb_mulH