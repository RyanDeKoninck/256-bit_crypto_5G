//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 04/16/2023 00:20:44 AM
// Design Name: 
// Module Name: tb_snowv_gcm_wrapper
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

module tb_snowv_gcm_wrapper();

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
  parameter CMD_COMPUTE_NEXT_AD = 32'h2;
  parameter CMD_COMPUTE_NEXT    = 32'h3;
  parameter CMD_COMPUTE_FINAL   = 32'h4;
  parameter CMD_WRITE           = 32'h5;
  
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
  
  reg             tb_encdec_only;
  reg             tb_auth_only;
  reg             tb_encdec;
  reg             tb_adj_len;
  reg  [255 : 0]  tb_key;
  reg  [127 : 0]  tb_iv;
  reg  [127 : 0]  tb_ad;
  reg  [63 : 0]   tb_len_ad;
  reg  [127 : 0]  tb_block_i;
  reg  [63 : 0]   tb_len_i;
  
  assign tb_input_data = {252'h0, tb_encdec_only, tb_auth_only, tb_encdec, tb_adj_len,
                          tb_key, tb_iv, tb_ad, tb_len_ad, tb_block_i, tb_len_i};

  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  snowv_gcm_wrapper dut(
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
      $display("ctrl_reg = 0x%01x", dut.snowv_gcm_wrapper_ctrl_reg);
      $display("");
      $display("key = 0x%064x", dut.key_reg);
      $display("block_i = 0x%032x", dut.block_i_reg);
      $display("block_o = 0x%032x", dut.block_o_reg);
      $display("tag = 0x%032x", dut.tag_reg);
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
      
      tb_encdec_only            = 1'b0;
      tb_auth_only              = 1'b0;
      tb_encdec                 = 1'b0;
      tb_adj_len                = 1'b0;
      tb_key                    = {8{32'h00000000}};
      tb_iv                     = {4{32'h00000000}};
      tb_ad                     = {4{32'h00000000}};
      tb_len_ad                 = {2{32'h00000000}};
      tb_block_i                = {4{32'h00000000}};
      tb_len_i                  = {2{32'h00000000}};
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
  // load_and_next_ad()
  //
  // Load inputs, process next AD block, and wait until done.
  //----------------------------------------------------------------
  task load_and_next_ad(input [1023 : 0] in);
    begin
      $display("Sending READ command");
      send_cmd_to_hw(CMD_READ);
      send_data_to_hw(in);
      wait_done();
      
      $display("Sending COMPUTE_NEXT_AD command");
      send_cmd_to_hw(CMD_COMPUTE_NEXT_AD);
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
  // test4
  //
  // Test vectors #4 for SNOWV-GCM from https://eprint.iacr.org/2018/1143.pdf
  //----------------------------------------------------------------
  task test4;
    begin : test4
      integer i;
      reg [127 : 0] expected_H, expected_Mtag, expected_tag;

      $display("*** Testvectors #4 BEGIN");
      inc_tc_ctr();

      tb_key     = 256'hfaeadacabaaa9a8a7a6a5a4a3a2a1a0a5f5e5d5c5b5a59585756555453525150;
      tb_iv      = 128'h1032547698badcfeefcdab8967452301;
      tb_ad      = 128'h66656463626139383736353433323130;
      tb_len_ad  = 64'h80;
      tb_len_i   = 64'h0;
      
      expected_H = 128'h4a9556fa37aeb7af7fe7ddc9e6c778a5;
      expected_Mtag = 128'h4c4285965b315061aefe494c57ac7cfc;
      
      #(CLK_PERIOD);
      load_and_init(tb_input_data);
      
      if (dut.core.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.core.H_reg);
      else
        $display("H correct!");
      
      if (dut.core.Mtag_reg != expected_Mtag)
        $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.core.Mtag_reg);
      else
        $display("Mtag correct!");
      
      expected_tag = 128'h1abbdc5ab608df7a082c027ad7c80e25;
      
      #(CLK_PERIOD);
      finalize(tb_output_data);
      
      if (tb_output_data[127 : 0] != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_output_data[127 : 0]);
          inc_error_ctr();
        end
      else
        $display("Tag correct!");
      
      $display("*** Testvectors #4 END");
      $display("");
      
    end
  endtask // test4

  //----------------------------------------------------------------
  // test5
  //
  // Test vectors #5 for SNOWV-GCM from https://eprint.iacr.org/2018/1143.pdf
  //----------------------------------------------------------------
  task test5;
    begin : test5
      integer i;
      reg [127 : 0] expected_H, expected_Mtag, expected_block_o, expected_tag;

      $display("*** Testvectors #5 BEGIN");
      inc_tc_ctr();

      tb_key     = 256'hfaeadacabaaa9a8a7a6a5a4a3a2a1a0a5f5e5d5c5b5a59585756555453525150;
      tb_iv      = 128'h1032547698badcfeefcdab8967452301;
      tb_ad      = 128'h0;
      tb_len_ad  = 64'h0;
      tb_len_i   = 64'h50;
      tb_encdec  = 1'b1;

      expected_H = 128'h4a9556fa37aeb7af7fe7ddc9e6c778a5;
      expected_Mtag = 128'h4c4285965b315061aefe494c57ac7cfc;
      
      #(CLK_PERIOD);
      load_and_init(tb_input_data);
      
      if (dut.core.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.core.H_reg);
      else
        $display("H correct!");
      
      if (dut.core.Mtag_reg != expected_Mtag)
        begin
          $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.core.Mtag_reg);
        end
      else
        $display("Mtag correct!");
      
      tb_block_i       = 128'h39383736353433323130;
      expected_block_o = 128'h5082efa224b4b2017edd;
      tb_adj_len       = 1'b1;
      
      #(CLK_PERIOD);
      load_and_next(tb_input_data, tb_output_data);
      
      if (tb_output_data[255 : 128] != expected_block_o)
        begin
          $display("Ciphertext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_output_data[255 : 128]);
        end
      else
        $display("Ciphertext correct!");
        
      expected_tag = 128'h0dd919e35cec312390e6bfe7314efedd;
      
      #(CLK_PERIOD);
      finalize(tb_output_data);
         
      if (tb_output_data[127 : 0] != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_output_data[127 : 0]);
          inc_error_ctr();
        end
      else
        $display("Tag correct!"); 
      
      $display("*** Testvectors #5 END");
      $display("");
    end
  endtask // test5

  //----------------------------------------------------------------
  // test6
  //
  // Test vectors #6 for SNOWV-GCM from https://eprint.iacr.org/2018/1143.pdf
  //----------------------------------------------------------------
  task test6;
    begin : test6
      integer i;
      reg [127 : 0] expected_H, expected_Mtag, expected_block_o, expected_tag;

      $display("*** Testvectors #6 BEGIN");
      inc_tc_ctr();
      
      tb_encdec_only = 1'b0;
      tb_auth_only   = 1'b0;
      tb_encdec      = 1'b1;
      tb_adj_len     = 1'b0;
      tb_key         = 256'hfaeadacabaaa9a8a7a6a5a4a3a2a1a0a5f5e5d5c5b5a59585756555453525150;
      tb_iv          = 128'h1032547698badcfeefcdab8967452301;
      tb_ad          = 128'h2165756c6176207473657420444141;
      tb_len_ad      = 64'd120;
      tb_block_i     = 128'h0;
      tb_len_i       = 64'd264;
      
      expected_H = 128'h4a9556fa37aeb7af7fe7ddc9e6c778a5;
      expected_Mtag = 128'h4c4285965b315061aefe494c57ac7cfc;
      
      #(CLK_PERIOD);
      
      load_and_init(tb_input_data);
      
      if (dut.core.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.core.H_reg);
      else
        $display("H correct!");
      
      if (dut.core.Mtag_reg != expected_Mtag)
        begin
          $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.core.Mtag_reg);
        end
      else
        $display("Mtag correct!");
      
      // First block
      tb_block_i       = 128'h66656463626139383736353433323130;
      expected_block_o = 128'hc1327ae807275082efa224b4b2017edd;
      
      #(CLK_PERIOD);
      load_and_next(tb_input_data, tb_output_data);
      
      if (tb_output_data[255 : 128] != expected_block_o)
        begin
          $display("Ciphertext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_output_data[255 : 128]);
        end
      
      // 2nd block
      tb_block_i       = 128'h65646f6d20444145412d56776f6e5320;
      expected_block_o = 128'h1be95956a1b53e24127ffd1818d0b052;
        
      #(CLK_PERIOD);
      load_and_next(tb_input_data, tb_output_data);
        
      if (tb_output_data[255 : 128] != expected_block_o)
        begin
          $display("Ciphertext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_output_data[255 : 128]);
        end
        
      // 3rd block
      tb_block_i       = 128'h21;
      expected_block_o = 128'h4c;
      tb_adj_len       = 1'b1;
        
      #(CLK_PERIOD);
      load_and_next(tb_input_data, tb_output_data);
        
      if (tb_output_data[255 : 128] != expected_block_o)
        begin
          $display("Ciphertext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_output_data[255 : 128]);
        end
      else
        $display("Ciphertext correct!");
        
      expected_tag = 128'h9b02eed99a3e7c74de513ab7a5a67e90;
      
      #(CLK_PERIOD);
      finalize(tb_output_data);
         
      if (tb_output_data[127 : 0] != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_output_data[127 : 0]);
          inc_error_ctr();
        end
      else
        $display("Tag correct!");
      
      $display("*** Testvectors #6 END");
      $display("");
    end
  endtask // test6
  
  
  
  //----------------------------------------------------------------
  // snowv_gcm_test
  // The main test functionality.
  // Test vectors copied from https://eprint.iacr.org/2018/1143.pdf
  //----------------------------------------------------------------
  initial
    begin : snowv_gcm_test
      $display("*** Testbench for snowv_gcm_WRAPPER started ***");
      $display("");

      init_sim();
      reset_dut();
      
      test4();
      test5();
      test6();

      display_test_result();

      $display("*** snowv_gcm_WRAPPER simulation done. ***");
      $finish;
    end // snowv_gcm_wrapper_test
    
endmodule // tb_snowv_gcm_wrapper
