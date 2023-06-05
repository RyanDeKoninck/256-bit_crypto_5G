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

module tb_ctr_wrapper();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG           = 0;
  parameter DUMP_WAIT       = 0;
    
  parameter CLK_HALF_PERIOD = 5;
  parameter CLK_PERIOD      = 2 * CLK_HALF_PERIOD;
  parameter RESET_TIME      = 25;
  
  parameter AES_128_BIT_KEY = 1'b0;
  parameter AES_256_BIT_KEY = 1'b1;
  
  // Wrapper commands
  parameter CMD_READ        = 32'h0;
  parameter CMD_COMPUTE     = 32'h1;
  parameter CMD_WRITE       = 32'h2;
  
  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]    cycle_ctr;
  reg [31 : 0]    error_ctr;
  reg [31 : 0]    tc_ctr;  
  
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

  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  ctr_wrapper dut(
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
      $display("ctrl_reg = 0x%01x", dut.ctr_wrapper_ctrl_reg);
      $display("");
      $display("counter = 0x%016x", dut.counter_reg);
      $display("key = 0x%032x", dut.key_reg);
      $display("keylen = 0x%01x", dut.keylen_reg);
      $display("block_i = 0x%016x", dut.block_i_reg);
      $display("block_o = 0x%016x", dut.block_o_reg);
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
      cycle_ctr = 0;
      error_ctr = 0;
      tc_ctr    = 0;

      tb_clk     = 0;
      tb_resetn  = 1;
      tb_arm_to_fpga_cmd         = {32'h00000000};
      tb_arm_to_fpga_cmd_valid   = 0;
      tb_fpga_to_arm_done_read   = 0;
      tb_arm_to_fpga_data_valid  = 0;
      tb_arm_to_fpga_data        = {32{32'h00000000}};
      tb_fpga_to_arm_data_ready  = 0;
      
      tb_input_data              = {32{32'h00000000}};
      tb_output_data             = {32{32'h00000000}};
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
  // ctr_wrapper_test()
  //
  // Perform CTR-mode encryption or decryption single block test.
  //----------------------------------------------------------------
  task ctr_wrapper_test(input [7 : 0]   tc_number,
                        input [127 : 0] counter,
                        input [255 : 0] key,
                        input           key_length,
                        input [127 : 0] block_i,
                        input [127 : 0] expected);
    begin
      $display("*** TC %0d CTR-mode test started.", tc_number);
      tc_ctr = tc_ctr + 1;
      tb_input_data = {511'h0 ,counter, key, key_length, block_i};
      
      #(CLK_PERIOD);
      
      $display("Sending READ command");
      send_cmd_to_hw(CMD_READ);
      send_data_to_hw(tb_input_data);
      wait_done();
      
      $display("Sending COMPUTE command");
      send_cmd_to_hw(CMD_COMPUTE);
      wait_done();
      
      $display("Sending WRITE command");
      send_cmd_to_hw(CMD_WRITE);
      read_data_from_hw(tb_output_data);
      wait_done();
 
      if (tb_output_data[127 : 0] == expected)
        begin
          $display("*** TC %0d successful.", tc_number);
          $display("");
        end
        else
          begin
            $display("*** ERROR: TC %0d NOT successful.", tc_number);
            $display("Expected: 0x%032x", expected);
            $display("Got:      0x%032x", tb_output_data[127 : 0]);
            $display("");
   
            error_ctr = error_ctr + 1;
         end
    end
  endtask // ctr_wrapper_test
  
  //----------------------------------------------------------------
  // ctr_test
  // The main test functionality.
  // Test vectors copied from the following NIST document.
  //
  // NIST SP 800-38A:
  // http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
  //----------------------------------------------------------------
  initial
    begin : ctr_test
      reg [255 : 0] nist_aes128_key1;
      reg [255 : 0] nist_aes256_key1;
      
      reg [127 : 0] nist_counter0;
      reg [127 : 0] nist_counter1;
      reg [127 : 0] nist_counter2;
      reg [127 : 0] nist_counter3;

      reg [127 : 0] nist_plaintext0;
      reg [127 : 0] nist_plaintext1;
      reg [127 : 0] nist_plaintext2;
      reg [127 : 0] nist_plaintext3;
      
      reg [127 : 0] nist_ciphertext0;
      
      reg [127 : 0] nist_ctr_128_enc_expected0;
      reg [127 : 0] nist_ctr_128_enc_expected1;
      reg [127 : 0] nist_ctr_128_enc_expected2;
      reg [127 : 0] nist_ctr_128_enc_expected3;

      reg [127 : 0] nist_ctr_256_enc_expected0;
      reg [127 : 0] nist_ctr_256_enc_expected1;
      reg [127 : 0] nist_ctr_256_enc_expected2;
      reg [127 : 0] nist_ctr_256_enc_expected3;
      
      reg [127 : 0] nist_ctr_256_dec_expected0;
      
      nist_aes128_key1 = 256'h2b7e151628aed2a6abf7158809cf4f3c00000000000000000000000000000000;
      nist_aes256_key1 = 256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
      
      nist_counter0 = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff;
      nist_counter1 = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdff00;
      nist_counter2 = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdff01;
      nist_counter3 = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdff02;

      nist_plaintext0 = 128'h6bc1bee22e409f96e93d7e117393172a;
      nist_plaintext1 = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
      nist_plaintext2 = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
      nist_plaintext3 = 128'hf69f2445df4f9b17ad2b417be66c3710;
      
      nist_ciphertext0 = 128'h601ec313775789a5b7a7f504bbf3d228; // Reverse of first case to test decryption

      nist_ctr_256_enc_expected0 = 128'h601ec313775789a5b7a7f504bbf3d228;
      nist_ctr_256_enc_expected1 = 128'hf443e3ca4d62b59aca84e990cacaf5c5;
      nist_ctr_256_enc_expected2 = 128'h2b0930daa23de94ce87017ba2d84988d;
      nist_ctr_256_enc_expected3 = 128'hdfc9c58db67aada613c2dd08457941a6;

      nist_ctr_128_enc_expected0 = 128'h874d6191b620e3261bef6864990db6ce;
      nist_ctr_128_enc_expected1 = 128'h9806f66b7970fdff8617187bb9fffdff;
      nist_ctr_128_enc_expected2 = 128'h5ae4df3edbd5d35e5b4f09020db03eab;
      nist_ctr_128_enc_expected3 = 128'h1e031dda2fbe03d1792170a0f3009cee;
      
      nist_ctr_256_dec_expected0 = 128'h6bc1bee22e409f96e93d7e117393172a;


      $display("   -= Testbench for ctr-mode started =-");
      $display("     ================================");
      $display("");

      init_sim();
      dump_dut_state();
      reset_dut();
      dump_dut_state();

      $display("");
      $display("ECB 128 bit key tests");
      $display("---------------------");
      ctr_wrapper_test(8'h0, nist_counter0, nist_aes128_key1, AES_128_BIT_KEY,
                                 nist_plaintext0, nist_ctr_128_enc_expected0);

      ctr_wrapper_test(8'h1, nist_counter1, nist_aes128_key1, AES_128_BIT_KEY,
                                 nist_plaintext1, nist_ctr_128_enc_expected1);
                                
      ctr_wrapper_test(8'h2, nist_counter2, nist_aes128_key1, AES_128_BIT_KEY,
                                 nist_plaintext2, nist_ctr_128_enc_expected2);
      
      ctr_wrapper_test(8'h3, nist_counter3, nist_aes128_key1, AES_128_BIT_KEY,
                                 nist_plaintext3, nist_ctr_128_enc_expected3);

      $display("");
      $display("ECB 256 bit key tests");
      $display("---------------------");
      ctr_wrapper_test(8'h4, nist_counter0, nist_aes256_key1, AES_256_BIT_KEY,
                                 nist_plaintext0, nist_ctr_256_enc_expected0);

      ctr_wrapper_test(8'h5, nist_counter1, nist_aes256_key1, AES_256_BIT_KEY,
                                 nist_plaintext1, nist_ctr_256_enc_expected1);
                                
      ctr_wrapper_test(8'h6, nist_counter2, nist_aes256_key1, AES_256_BIT_KEY,
                                 nist_plaintext2, nist_ctr_256_enc_expected2);
      
      ctr_wrapper_test(8'h7, nist_counter3, nist_aes256_key1, AES_256_BIT_KEY,
                                 nist_plaintext3, nist_ctr_256_enc_expected3);
      
      // Decryption is the same in ctr-mode                           
      ctr_wrapper_test(8'h8, nist_counter0, nist_aes256_key1, AES_256_BIT_KEY,
                                 nist_ciphertext0, nist_ctr_256_dec_expected0);

      display_test_result();
      $display("");
      $display("*** AES core simulation done. ***");
      $finish;
    end // ctr_test
    
endmodule // tb_ctr_wrapper
