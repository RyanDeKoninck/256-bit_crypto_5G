//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/10/2023 15:21:16 PM
// Design Name: 
// Module Name: tb_ghash
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

module tb_ghash_alt();

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
  reg            tb_first_init;
  reg            tb_init;
  reg            tb_next_no_ad;
  reg            tb_next;
  reg            tb_finalize_no_in;
  reg            tb_finalize;
  reg [127 : 0]  tb_H;
  reg [127 : 0]  tb_ad;
  reg [63 : 0]   tb_len_ad;
  reg [127 : 0]  tb_in;
  reg [63 : 0]   tb_len_i;
  wire [127 : 0] tb_out;
  wire           tb_ready;
  
  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  ghash_alt dut(
            .clk(tb_clk),
            .reset_n(tb_reset_n),
             
            .first_init(tb_first_init),
            .init(tb_init),
            .next_no_ad(tb_next_no_ad),
            .next(tb_next),
            .finalize_no_in(tb_finalize_no_in),
            .finalize(tb_finalize),
            
            .H(tb_H),
            .ad(tb_ad),
            .len_ad(tb_len_ad),
            .block_i(tb_in),
            .len_i(tb_len_i),
            
            .X(tb_out),
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
      cycle_ctr         = 0;
      error_ctr         = 0;
      tc_ctr            = 0;

      tb_clk            = 0;
      tb_reset_n        = 1;
      tb_first_init     = 0;
      tb_init           = 0;
      tb_next_no_ad     = 0;
      tb_next           = 0;
      tb_finalize       = 0;
      tb_finalize_no_in = 0;
      tb_in             = {4{32'h00000000}};
      tb_len_i          = 32'h0;
      tb_H              = {4{32'h00000000}};
      tb_ad             = {4{32'h00000000}};
      tb_len_ad         = 32'h0;
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
  // ghash_test
  //
  // The main test functionality. Test cases derived from 
  // https://csrc.nist.rip/groups/ST/toolkit/BCM/documents/proposedmodes/gcm/gcm-spec.pdf
  //----------------------------------------------------------------
  initial
    begin : ghash_test
      reg [127 : 0] expected;
      init_sim();
      reset_dut();
      
      $display("*** GHASH_alt Simulation started. ***");
      $display("");
      
       $display("*** Begin Test Case alt."); // tc with both P and AD
         
       tc_ctr = tc_ctr + 1;
       tb_H = 128'h4a9556fa37aeb7af7fe7ddc9e6c778a5; 
       tb_ad = 128'h0; 
       
       tb_in = 128'h5082efa224b4b2017edd;
       tb_next_no_ad = 1'b1;
       #(CLK_PERIOD*2);
       tb_next_no_ad = 1'b0;
       wait_ready();
              
       tb_len_i = 64'h50;
       tb_len_ad = 64'h0;
       expected = 128'h419b9c7507dd61423e18f6ab66e28221;
       
       tb_finalize = 1'b1;
       #(CLK_PERIOD*2);
       tb_finalize = 1'b0;
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
      $display("*** GHASH simulation done. ***");
      $finish;
    end // ghash_test
      
endmodule // tb_ghash