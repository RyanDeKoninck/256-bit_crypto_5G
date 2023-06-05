//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 03/10/2023 03:02:44 PM
// Design Name: 
// Module Name: ctr
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

module tb_cmac_wrapper();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG            = 0;
  parameter DUMP_WAIT        = 0;
    
  parameter CLK_HALF_PERIOD  = 5;
  parameter CLK_PERIOD       = 2 * CLK_HALF_PERIOD;
  parameter RESET_TIME       = 25;
  
  parameter AES_128_BIT_KEY  = 1'b0;
  parameter AES_256_BIT_KEY  = 1'b1;
  
  parameter AES_BLOCK_SIZE   = 128;
  
  // Wrapper commands
  parameter CMD_READ_KEY     = 32'h0;
  parameter CMD_READ_BLOCK   = 32'h1;
  parameter CMD_COMPUTE_INIT = 32'h2;
  parameter CMD_COMPUTE_NEXT = 32'h3;
  parameter CMD_WRITE        = 32'h4;
  
  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]    cycle_ctr;
  reg [31 : 0]    error_ctr;
  reg [31 : 0]    tc_ctr;  
  reg             tc_correct;
  
  reg             tb_clk;
  reg             tb_resetn;
  reg  [31 : 0]   tb_arm_to_fpga_cmd;
  reg             tb_arm_to_fpga_cmd_valid;
  wire            tb_fpga_to_arm_done;
  reg             tb_fpga_to_arm_done_read;

  reg             tb_arm_to_fpga_data_valid;
  wire            tb_arm_to_fpga_data_ready;
  reg  [1023 : 0] tb_arm_to_fpga_data;

  wire            tb_fpga_to_arm_data_valid;
  reg             tb_fpga_to_arm_data_ready;
  wire [1023 : 0] tb_fpga_to_arm_data;

  wire [3 : 0]    tb_leds;

  reg  [1023 : 0] tb_input_data;
  reg  [1023 : 0] tb_output_data;
  
  reg  [255 : 0]  tb_key;
  reg             tb_keylen;
  reg             tb_finalize;
  reg  [7 : 0]    tb_final_size;
  reg  [127 : 0]  tb_block_i;

  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  cmac_wrapper dut(
                   .clk                    (tb_clk                    ),
                   .resetn                 (tb_resetn                 ),
             
                   .arm_to_fpga_cmd        (tb_arm_to_fpga_cmd        ),
                   .arm_to_fpga_cmd_valid  (tb_arm_to_fpga_cmd_valid  ),
                   .fpga_to_arm_done       (tb_fpga_to_arm_done       ),
                   .fpga_to_arm_done_read  (tb_fpga_to_arm_done_read  ),
            
                   .arm_to_fpga_data_valid (tb_arm_to_fpga_data_valid ),
                   .arm_to_fpga_data_ready (tb_arm_to_fpga_data_ready ),
                   .arm_to_fpga_data       (tb_arm_to_fpga_data       ),
            
                   .fpga_to_arm_data_valid (tb_fpga_to_arm_data_valid ),
                   .fpga_to_arm_data_ready (tb_fpga_to_arm_data_ready ),
                   .fpga_to_arm_data       (tb_fpga_to_arm_data       ),
            
                   .leds                   (tb_leds                   )
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
      $display("cycle: 0x%016x", cycle_ctr);
      $display("State of DUT");
      $display("------------");
      $display("ctrl_reg = 0x%01x", dut.cmac_wrapper_ctrl_reg);
      $display("");
      $display("key = 0x%064x", dut.key_reg);
      $display("keylen = 0x%01x", dut.keylen_reg);
      $display("finalize = 0x%01x", dut.finalize_reg);
      $display("final_size = 0x%02x", dut.final_size_reg);
      $display("block_i = 0x%032x", dut.block_i_reg);
      $display("result = 0x%032x", dut.result_reg);
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
      tb_resetn = 0;
      #(RESET_TIME);
      tb_resetn = 1;
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
      cycle_ctr                 = 0;
      error_ctr                 = 0;
      tc_ctr                    = 0;

      tb_clk                    = 0;
      tb_resetn                 = 1;
      tb_arm_to_fpga_cmd        = {32'h00000000};
      tb_arm_to_fpga_cmd_valid  = 0;
      tb_fpga_to_arm_done_read  = 0;
      tb_arm_to_fpga_data_valid = 0;
      tb_arm_to_fpga_data       = {32{32'h00000000}};
      tb_fpga_to_arm_data_ready = 0;
      
      tb_input_data             = {32{32'h00000000}};
      tb_output_data            = {32{32'h00000000}};
      
      tb_key                    = {4{32'h00000000}};
      tb_keylen                 = 1'b0;
      tb_finalize               = 1'b0;
      tb_final_size             = 8'h00;
      tb_block_i                = {4{32'h00000000}};
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
  // send_cmd_to_hw()
  //
  // Send the given command to the FPGA.
  //----------------------------------------------------------------
  task send_cmd_to_hw(input [31 : 0] command);
    begin
        // Assert the command and valid
        tb_arm_to_fpga_cmd <= command;
        tb_arm_to_fpga_cmd_valid <= 1'b1;
        #(CLK_PERIOD);
        // Desassert the valid signal after one cycle
        tb_arm_to_fpga_cmd_valid <= 1'b0;
        #(CLK_PERIOD);
    end
  endtask
  
  //----------------------------------------------------------------
  // send_data_to_hw()
  //
  // Send the given data to the FPGA.
  //----------------------------------------------------------------
  task send_data_to_hw(input [1023 : 0] data);
    begin
        // Assert data and valid
        tb_arm_to_fpga_data <= data;
        tb_arm_to_fpga_data_valid <= 1'b1;
        #(CLK_PERIOD);
        // Wait till accelerator is ready to read it
        wait(tb_arm_to_fpga_data_ready == 1'b1);
        // It is read, do not continue asserting valid
        tb_arm_to_fpga_data_valid <= 1'b0;
        #(CLK_PERIOD);
    end
  endtask

  //----------------------------------------------------------------
  // read_data_from_hw()
  //
  // Read data from the FPGA.
  //----------------------------------------------------------------
  task read_data_from_hw(output [1023:0] odata);
    begin
        // Assert ready signal
        tb_fpga_to_arm_data_ready <= 1'b1;
        #(CLK_PERIOD);
        // Wait for valid signal
        wait(tb_fpga_to_arm_data_valid == 1'b1);
        // If valid read the output data
        odata <= tb_fpga_to_arm_data;
        // Do not continue asserting ready
        tb_fpga_to_arm_data_ready <= 1'b0;
        #(CLK_PERIOD);
    end
    endtask

  //----------------------------------------------------------------
  // wait_done()
  //
  // Wait until accelerator is done.
  //----------------------------------------------------------------
  task wait_done;
    begin
      // Wait for accelerator's done
      wait(tb_fpga_to_arm_done == 1'b1);
      // Signal that it is read
      tb_fpga_to_arm_done_read <= 1'b1;
      #(CLK_PERIOD);
      // Desassert the signal after one cycle
      tb_fpga_to_arm_done_read <= 1'b0;
      #(CLK_PERIOD);
    end
  endtask

  //----------------------------------------------------------------
  // load_key_and_init()
  //
  // Load key, initialize, and wait until done.
  //----------------------------------------------------------------
  task load_key_and_init(input [1023 : 0] in);
    begin
      $display("Sending READ_KEY command");
      send_cmd_to_hw(CMD_READ_KEY);
      send_data_to_hw(in);
      wait_done();
      
      $display("Sending COMPUTE_INIT command");
      send_cmd_to_hw(CMD_COMPUTE_INIT);
      wait_done();
    end
  endtask

  //----------------------------------------------------------------
  // load_block_and_compute()
  //
  // Load block, compute, and wait until done.
  //----------------------------------------------------------------
  task load_block_and_compute(input  [1023 : 0] in,
                              output [1023 : 0] out);
    begin
      $display("Sending READ_BLOCK command");
      send_cmd_to_hw(CMD_READ_BLOCK);
      send_data_to_hw(in);
      wait_done();
        
      $display("Sending COMPUTE_NEXT command");
      send_cmd_to_hw(CMD_COMPUTE_NEXT);
      wait_done();
        
      $display("Sending WRITE command");
      send_cmd_to_hw(CMD_WRITE);
      read_data_from_hw(out);
      wait_done();
    end
  endtask
  
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

      $display("TC3: Check that correct ICV is generated for an empty message.");

      tb_key    = 256'h2b7e1516_28aed2a6_abf71588_09cf4f3c_00000000_00000000_00000000_00000000;
      tb_keylen = 1'h0;
      tb_input_data = {767'h0, tb_keylen, tb_key};
      #(CLK_PERIOD);
      load_key_and_init(tb_input_data);

      $display("TC3: cmac_core initialized. Now for the final, empty message block.");
      tb_final_size = 8'h00;
      tb_finalize = 1'h1;
      tb_block_i = 128'h0;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);
      
      $display("TC3: cmac_core finished.");
      if (tb_output_data[127:0] != 128'hbb1d6929e95937287fa37d129b756746)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC3: Error - Expected 0xbb1d6929e95937287fa37d129b756746, got 0x%032x",
                   tb_output_data[127:0]);
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

      $display("TC4: Check that correct ICV is generated for a single block message.");

      tb_key    = 256'h2b7e1516_28aed2a6_abf71588_09cf4f3c_00000000_00000000_00000000_00000000;
      tb_keylen = 1'h0;
      tb_input_data = {767'h0, tb_keylen, tb_key};
      #(CLK_PERIOD);
      load_key_and_init(tb_input_data);

      $display("TC4: cmac_core initialized. Now for the final, full message block.");

      tb_block_i    = 128'h6bc1bee2_2e409f96_e93d7e11_7393172a;
      tb_final_size = AES_BLOCK_SIZE;
      tb_finalize   = 1'h1;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);

      $display("TC4: cmac_core finished.");
      if (tb_output_data[127:0] != 128'h070a16b4_6b4d4144_f79bdd9d_d04a287c)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC4: Error - Expected 0x070a16b4_6b4d4144_f79bdd9d_d04a287c, got 0x%032x",
                   tb_output_data[127:0]);
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

      $display("TC5: Check that correct ICV is generated for a two and a half block message.");
      tb_key    = 256'h2b7e1516_28aed2a6_abf71588_09cf4f3c_00000000_00000000_00000000_00000000;
      tb_keylen = 1'h0;
      tb_input_data = {767'h0, tb_keylen, tb_key};
      #(CLK_PERIOD);
      load_key_and_init(tb_input_data);
      
      $display("TC5: cmac_core initialized. Now we process two full blocks.");
      
      tb_block_i = 128'h6bc1bee2_2e409f96_e93d7e11_7393172a;
      tb_finalize = 1'b0;
      tb_final_size = 8'h00;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);
      $display("TC5: First block done.");

      tb_block_i = 128'hae2d8a57_1e03ac9c_9eb76fac_45af8e51;
      tb_finalize = 1'b0;
      tb_final_size = 8'h00;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);
      $display("TC5: Second block done.");

      $display("TC5: Now we process the final half block.");
      tb_block_i    = 128'h30c81c46_a35ce411_00000000_00000000;
      tb_final_size = 8'h40;
      tb_finalize = 1'h1;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);
      $display("TC5: cmac_core finished.");

      if (tb_output_data[127:0] != 128'hdfa66747_de9ae630_30ca3261_1497c827)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC5: Error - Expected 0xdfa66747_de9ae630_30ca3261_1497c827, got 0x%032x",
                   tb_output_data[127:0]);
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

      $display("TC6: Check that correct ICV is generated for a four block message.");
      tb_key    = 256'h2b7e1516_28aed2a6_abf71588_09cf4f3c_00000000_00000000_00000000_00000000;
      tb_keylen = 1'h0;
      tb_input_data = {767'h0, tb_keylen, tb_key};
      #(CLK_PERIOD);
      load_key_and_init(tb_input_data);
      
      $display("TC6: cmac_core initialized. Now we process four full blocks.");

      tb_block_i = 128'h6bc1bee2_2e409f96_e93d7e11_7393172a;
      tb_finalize = 1'b0;
      tb_final_size = 8'h00;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);

      tb_block_i = 128'hae2d8a57_1e03ac9c_9eb76fac_45af8e51;
      tb_finalize = 1'b0;
      tb_final_size = 8'h00;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);

      tb_block_i = 128'h30c81c46_a35ce411_e5fbc119_1a0a52ef;
      tb_finalize = 1'b0;
      tb_final_size = 8'h00;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);

      tb_block_i = 128'hf69f2445_df4f9b17_ad2b417b_e66c3710;
      tb_final_size = AES_BLOCK_SIZE;
      tb_finalize = 1'h1;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);

      if (tb_output_data[127:0] != 128'h51f0bebf_7e3b9d92_fc497417_79363cfe)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC6: Error - Expected 0x51f0bebf_7e3b9d92_fc497417_79363cfe, got 0x%032x",
                   tb_output_data[127:0]);
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

      $display("TC7: Check that correct ICV is generated for a four block message usint a 256 bit key.");
      tb_key    = 256'h603deb10_15ca71be_2b73aef0_857d7781_1f352c07_3b6108d7_2d9810a3_0914dff4;
      tb_keylen = 1'h1;
      tb_input_data = {767'h0, tb_keylen, tb_key};
      #(CLK_PERIOD);
      load_key_and_init(tb_input_data);
      
      $display("TC7: cmac_core initialized. Now we process four full blocks.");

      tb_block_i = 128'h6bc1bee2_2e409f96_e93d7e11_7393172a;
      tb_finalize = 1'b0;
      tb_final_size = 8'h00;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);
      
      tb_block_i = 128'hae2d8a57_1e03ac9c_9eb76fac_45af8e51;
      tb_finalize = 1'b0;
      tb_final_size = 8'h00;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);

      tb_block_i = 128'h30c81c46_a35ce411_e5fbc119_1a0a52ef;
      tb_finalize = 1'b0;
      tb_final_size = 8'h00;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);

      tb_block_i = 128'hf69f2445_df4f9b17_ad2b417b_e66c3710;
      tb_final_size = AES_BLOCK_SIZE;
      tb_finalize   = 1'h1;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);

      if (tb_output_data[127:0] != 128'he1992190_549f6ed5_696a2c05_6c315410)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC7: Error - Expected 0xe1992190_549f6ed5_696a2c05_6c315410, got 0x%032x",
                   tb_output_data[127:0]);
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

      $display("TC8: Check that correct ICV is generated for a single block, all zero message.");
      tb_key    = 256'hfffefdfc_fbfaf9f8_f7f6f5f4_f3f2f1f0_f0f1f2f3_f4f5f6f7_f8f9fafb_fcfdfeff;
      tb_keylen = 1'h0;
      tb_input_data = {767'h0, tb_keylen, tb_key};
      #(CLK_PERIOD);
      load_key_and_init(tb_input_data);

      $display("TC8: cmac_core initialized. Now for the final, full message block.");

      tb_block_i    = 128'h0;
      tb_final_size = AES_BLOCK_SIZE;
      tb_finalize   = 1'h1;
      tb_input_data = {887'h0, tb_finalize, tb_final_size, tb_block_i};
      #(CLK_PERIOD);
      load_block_and_compute(tb_input_data, tb_output_data);

      $display("TC8: cmac_core finished.");
      if (tb_output_data[127:0] != 128'h0e04dfaf_c1efbf04_01405828_59bf073a)
        begin
          tc_correct = 0;
          inc_error_ctr();
          $display("TC8: Error - Expected 0x0e04dfaf_c1efbf04_01405828_59bf073a, got 0x%032x",
                   tb_output_data[127:0]);
        end

      if (tc_correct)
        $display("TC8: SUCCESS - ICV for single block message correctly generated.");
      else
        $display("TC8: NO SUCCESS - ICV for single block message not correctly generated.");
      $display("");
    end
  endtask // tc8_single_block_all_zero_message
  
  
  
  //----------------------------------------------------------------
  // cmac_test
  // The main test functionality.
  // Test vectors copied from the following NIST document.
  //
  // NIST SP 800-38A:
  // http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
  //----------------------------------------------------------------
  initial
    begin : aes_core_test
      $display("*** Testbench for CMAC_WRAPPER started ***");
      $display("");

      init_sim();
      reset_dut();

      tc3_empty_message();
      tc4_single_block_message();
      tc5_two_and_a_half_block_message();
      tc6_four_block_message();
      tc7_key256_four_block_message();
      tc8_single_block_all_zero_message();

      display_test_result();

      $display("*** CMAC_WRAPPER simulation done. ***");
      $finish;
    end // ctr_wrapper_test
    
endmodule // tb_ctr_wrapper
