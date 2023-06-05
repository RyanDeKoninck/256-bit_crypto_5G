//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/16/2023 00:20:44 AM
// Design Name: 
// Module Name: tb_zuc256_tot_wrapper
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

module tb_zuc256_tot_wrapper();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG            = 0;
  parameter DUMP_WAIT        = 0;
    
  parameter CLK_HALF_PERIOD  = 5;
  parameter CLK_PERIOD       = 2 * CLK_HALF_PERIOD;
  parameter RESET_TIME       = 25;
  
  // Wrapper commands
  parameter CMD_READ            = 32'h0;
  parameter CMD_COMPUTE_INIT    = 32'h1;
  parameter CMD_COMPUTE_NEXT    = 32'h2;
  parameter CMD_COMPUTE_FINAL   = 32'h3;
  parameter CMD_WRITE           = 32'h4;
  
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

  wire [1023 : 0] tb_input_data;
  reg  [1023 : 0] tb_output_data;
  
  reg             tb_enc_auth;
  reg  [255 : 0]  tb_key;
  reg  [127 : 0]  tb_iv;
  reg  [127 : 0]  tb_block_i;
  reg  [7 : 0]    tb_i_len;
  reg  [7 : 0]    tb_tag_len;
  
  assign tb_input_data = {495'h0, tb_enc_auth, tb_key, tb_iv, 
                          tb_block_i, tb_i_len, tb_tag_len};

  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  zuc256_tot_wrapper dut(
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
      $display("ctrl_reg = 0x%01x", dut.zuc256_tot_wrapper_ctrl_reg);
      $display("");
      $display("key = 0x%064x", dut.key_reg);
      $display("block_i = 0x%032x", dut.block_i_reg);
      $display("block_o = 0x%032x", dut.result_reg);
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
      
      tb_output_data            = {32{32'h00000000}};
      
      tb_enc_auth               = 1'b0;
      tb_key                    = {8{32'h00000000}};
      tb_iv                     = {4{32'h00000000}};
      tb_block_i                = {4{32'h00000000}};
      tb_i_len                  = 8'h0;
      tb_tag_len                = 8'h0;
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
  // load_and_init()
  //
  // Load inputs, initialize, and wait until done.
  //----------------------------------------------------------------
  task load_and_init(input [1023 : 0] in);
    begin
      $display("Sending READ command");
      send_cmd_to_hw(CMD_READ);
      send_data_to_hw(in);
      wait_done();
      
      $display("Sending COMPUTE_INIT command");
      send_cmd_to_hw(CMD_COMPUTE_INIT);
      wait_done();
    end
  endtask
  
  //----------------------------------------------------------------
  // load_and_next()
  //
  // Load inputs, process next block, and wait until done.
  //----------------------------------------------------------------
  task load_and_next(input  [1023 : 0] in,
                     output [1023 : 0] out);
    begin
      $display("Sending READ command");
      send_cmd_to_hw(CMD_READ);
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
  // finalize()
  //
  // Load inputs, process next block, and wait until done.
  //----------------------------------------------------------------
  task finalize(output [1023 : 0] out);
    begin
      $display("Sending COMPUTE_FINAL command");
      send_cmd_to_hw(CMD_COMPUTE_FINAL);
      wait_done();
        
      $display("Sending WRITE command");
      send_cmd_to_hw(CMD_WRITE);
      read_data_from_hw(out);
      wait_done();
    end
  endtask
  
  
  //----------------------------------------------------------------
  // zuc256_tot_wrapper_test
  //
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : zuc256_tot_wrapper_test
      reg [127 : 0] expected_final;
      integer i;
      
      $display("*** Testbench for zuc256_tot_WRAPPER started ***");
      $display("");

      init_sim();
      reset_dut();
      
      // CTR Test 2 based on http://www.is.cas.cn/ztzl2016/zouchongzhi/201801/W020230201389233346416.pdf
      $display("--- CTR Test #2");
      tc_ctr = tc_ctr + 1;
      tb_enc_auth = 1'b0;
      tb_key = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
      tb_iv = 128'hffffffffffffffffffffffffffffffff;
      tb_block_i = 128'h0;
      tb_i_len = 8'h0;
      tb_tag_len = 8'h0;

      #(CLK_PERIOD);
      load_and_init(tb_input_data);
      $display("Init done");
      
      // First Block
      tb_block_i = {96'h0, 32'h01020304};
      expected_final = {96'h0, 32'h3887e1ab};

      #(CLK_PERIOD);
      load_and_next(tb_input_data, tb_output_data);
      
      if (tb_output_data[127 : 0] == expected_final)
        $display("*** Ciphertext %0d correct.", 1);
      else
        $display("*** Ciphertext %0d incorrect.", 1);

      // Second Block
      tb_block_i = {96'h0, 32'h05060708};
      expected_final = {96'h0, 32'h3035d321};

      #(CLK_PERIOD);
      load_and_next(tb_input_data, tb_output_data);
      
      if (tb_output_data[127 : 0] == expected_final)
        $display("*** Ciphertext %0d correct.", 2);
      else
        $display("*** Ciphertext %0d incorrect.", 2);
      
      // Third Block
      tb_block_i = {96'h0, 32'h090a0b0c};
      expected_final = {96'h0, 32'h3a8f8bfc};

      #(CLK_PERIOD);
      load_and_next(tb_input_data, tb_output_data);
      
      if (tb_output_data[127 : 0] == expected_final)
        $display("*** Ciphertext %0d correct.", 3);
      else
        $display("*** Ciphertext %0d incorrect.", 3);
      
      // Fourth Block
      tb_block_i = {96'h0, 32'h0d0e0f00};
      expected_final = {96'h0, 32'hedd603e9};

      #(CLK_PERIOD);
      load_and_next(tb_input_data, tb_output_data);
      
      if (tb_output_data[127 : 0] == expected_final)
        $display("*** Ciphertext %0d correct.", 4);
      else
        begin
          $display("*** Ciphertext %0d incorrect.", 4);
          error_ctr = error_ctr + 1;
        end
      
      $display("--- Testvectors #4: 128 bits");
      tc_ctr = tc_ctr + 1;
      tb_enc_auth = 1'b1;
      tb_key = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
      tb_iv = 128'hffffffffffffffffffffffffffffffff;
      tb_block_i = 128'h11111111111111111111111111111111;
      tb_i_len = 8'd32;
      tb_tag_len = 8'd128;
      expected_final = 128'hdd3a4017_357803a5_1c3fb9a5_7a96feda;

      #(CLK_PERIOD);
      load_and_init(tb_input_data);

      $display("Init done");

      for (i = 0 ; i < 31 ; i = i + 1)
        begin
          #(CLK_PERIOD);
          load_and_next(tb_input_data, tb_output_data);
          $display("intermediate_tag[%1d] = 0x%32x", i, tb_output_data[127 : 0]);
        end
      
      tb_block_i = 128'h11111111000000000000000000000000;
      
      #(CLK_PERIOD);
      load_and_next(tb_input_data, tb_output_data);
      $display("intermediate_tag[31] = 0x%32x", tb_output_data[127 : 0]);
        
      #(CLK_PERIOD);
      finalize(tb_output_data);

      if (tb_output_data[127 : 0] == expected_final)
        begin
          $display("*** TC %0d successful.", 4);
          $display("");
        end
      else
        begin
          $display("*** ERROR: TC %0d NOT successful.", 4);
          $display("Expected: 0x%08x", expected_final);
          $display("Got:      0x%08x", tb_output_data[127 : 0]);
          $display("");

          error_ctr = error_ctr + 1;
        end

      display_test_result();
      $display("*** zuc256_tot_WRAPPER simulation done. ***");
      $finish;
    end // zuc256_tot_wrapper_test
    
endmodule // tb_zuc256_tot_wrapper
