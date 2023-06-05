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

module tb_snowv_gcm();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam DEBUG = 0;

  localparam CLK_HALF_PERIOD = 1;
  localparam CLK_PERIOD      = 2 * CLK_HALF_PERIOD;

  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]  cycle_ctr;
  reg [31 : 0]  error_ctr;
  reg [31 : 0]  tc_ctr;
  reg           tc_correct;
  reg           debug_ctrl;

  reg            tb_clk;
  reg            tb_reset_n;
  reg            tb_init;
  reg            tb_next_ad;
  reg            tb_next;
  reg            tb_finalize;
  reg            tb_encdec_only;
  reg            tb_auth_only;
  reg            tb_encdec;
  reg            tb_adj_len;
  reg [255 : 0]  tb_key;
  reg [127 : 0]  tb_iv;
  reg [127 : 0]  tb_ad;
  reg [63 : 0]   tb_len_ad;
  reg [127 : 0]  tb_block_i;
  reg [63 : 0]   tb_len_i;
  wire [127 : 0] tb_block_o;
  wire [127 : 0] tb_tag;
  wire           tb_ready;
  wire           tb_tag_ready;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  snowv_gcm dut(
               .clk(tb_clk),
               .reset_n(tb_reset_n),

               .init(tb_init),
               .next_ad(tb_next_ad),
               .next(tb_next),
               .finalize(tb_finalize),
               .encdec_only(tb_encdec_only),
               .auth_only(tb_auth_only),
               .encdec(tb_encdec), 
               .adj_len(tb_adj_len),
               .key(tb_key),
               .iv(tb_iv),
               .ad(tb_ad),
               .len_ad(tb_len_ad),
               .block_i(tb_block_i),
               .len_i(tb_len_i),
               
               .block_o(tb_block_o),
               .tag(tb_tag),
               .ready(tb_ready),
               .tag_ready(tb_tag_ready)
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

      if (debug_ctrl)
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
      $display("cycle:  0x%016x", cycle_ctr);
      $display("Inputs and outputs:");
      $display("init = 0x%01x, next_ad = 0x%01x",
               dut.init, dut.next_ad);
      $display("next = 0x%01x, finalize = 0x%01x",
               dut.next, dut.finalize);
      $display("encdec_only = 0x%01x, auth_only = 0x%01x, encdec = 0x%01x",
               dut.encdec_only, dut.auth_only, dut.encdec);
      $display("block_i = 0x%032x, ready = 0x%01x, result =  0x%032x",
               dut.block_i, dut.ready, dut.block_o);
      $display("tag = 0x%032x, valid = 0x%01x",
                dut.tag, dut.tag_ready);
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
      $display("");
      tb_reset_n = 0;
      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // display_test_results()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_results;
    begin
      if (error_ctr == 0)
        begin
          $display("%02d test completed. All test cases completed successfully.", tc_ctr);
        end
      else
        begin
          $display("%02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_results


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr      = 0;
      error_ctr      = 0;
      tc_ctr         = 0;
      debug_ctrl     = 0;

      tb_clk         = 1'h0;
      tb_reset_n     = 1'h1;
      tb_init        = 1'h0;
      tb_next_ad     = 1'h0;
      tb_next        = 1'h0;
      tb_finalize    = 1'h0;
      tb_encdec_only = 1'h0;
      tb_auth_only   = 1'b0;
      tb_encdec      = 1'b0;
      tb_adj_len     = 1'b0;
      tb_key         = 256'h0;
      tb_iv          = 128'h0;
      tb_ad          = 128'h0;
      tb_len_ad      = 64'b0;
      tb_block_i     = 128'h0;
      tb_len_i       = 64'h0;
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
  // wait_ready()
  //
  // Wait for the ready flag to be set in dut.
  //----------------------------------------------------------------
  task wait_ready;
    begin : wready
      while (tb_ready == 0)
        #(CLK_PERIOD);
    end
  endtask // wait_ready
  
  //----------------------------------------------------------------
  // wait_tag_ready()
  //
  // Wait for the ready flag to be set in dut.
  //----------------------------------------------------------------
  task wait_tag_ready;
    begin : wtagready
      while (tb_tag_ready == 0)
        #(CLK_PERIOD);
    end
  endtask // wait_tag_ready


  //----------------------------------------------------------------
  // test1
  //
  // Test vectors #1 for SNOWV-GCM from https://eprint.iacr.org/2018/1143.pdf
  //----------------------------------------------------------------
  task test1;
    begin : test1
      integer i;
      reg [127 : 0] expected_H, expected_Mtag, expected_tag;

      $display("*** Testvectors #1 BEGIN");
      inc_tc_ctr();

      tb_key     = 256'h0;
      tb_iv      = 128'h0;
      tb_len_ad  = 64'h0;
      tb_len_i   = 64'h0;
      
      expected_H = 128'hd56549cd78082370f6d4990730d9c0e9;
      expected_Mtag = 128'h9f6c954640efa0b96cd4a4da4c629a02;
      
      tb_init    = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      
      if (dut.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.H_reg);
      else
        $display("H correct!");
      
      if (dut.Mtag_reg != expected_Mtag)
        $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.Mtag_reg);
      else
        $display("Mtag correct!");
      
      expected_tag = 128'h9f6c954640efa0b96cd4a4da4c629a02;
      
      tb_finalize = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_tag_ready();
      
      if (tb_tag != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_tag);
          inc_error_ctr();
        end
      else
        $display("Tag correct!");
      
      $display("*** Testvectors #1 END");
      $display("");
      
    end
  endtask // test1

  //----------------------------------------------------------------
  // test2
  //
  // Test vectors #2 for SNOWV-GCM from https://eprint.iacr.org/2018/1143.pdf
  //----------------------------------------------------------------
  task test2;
    begin : test2
      integer i;
      reg [127 : 0] expected_H, expected_Mtag, expected_tag;

      $display("*** Testvectors #2 BEGIN");
      inc_tc_ctr();

      tb_key     = 256'hfaeadacabaaa9a8a7a6a5a4a3a2a1a0a5f5e5d5c5b5a59585756555453525150;
      tb_iv      = 128'h1032547698badcfeefcdab8967452301;
      tb_len_ad  = 64'h0;
      tb_len_i   = 64'h0;
      
      expected_H = 128'h4a9556fa37aeb7af7fe7ddc9e6c778a5;
      expected_Mtag = 128'h4c4285965b315061aefe494c57ac7cfc;
      
      tb_init    = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      
      if (dut.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.H_reg);
      else
        $display("H correct!");
      
      if (dut.Mtag_reg != expected_Mtag)
        begin
          $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.Mtag_reg);
          inc_error_ctr();
        end
      else
        $display("Mtag correct!");
        
      expected_tag = 128'h4c4285965b315061aefe494c57ac7cfc;
      
      tb_finalize = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_tag_ready();
       
      if (tb_tag != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_tag);
          inc_error_ctr();
        end
      else
        $display("Tag correct!");
      
      $display("*** Testvectors #2 END");
      $display("");
    end
      endtask // test2

  //----------------------------------------------------------------
  // test3
  //
  // Test vectors #3 for SNOWV-GCM from https://eprint.iacr.org/2018/1143.pdf
  //----------------------------------------------------------------
  task test3;
    begin : test3
      integer i;
      reg [127 : 0] expected_H, expected_Mtag, expected_tag;

      $display("*** Testvectors #3 BEGIN");
      inc_tc_ctr();

      tb_key     = 256'h0;
      tb_iv      = 128'h0;
      tb_len_ad  = 64'h80;
      tb_len_i   = 64'h0;
      tb_ad      = 128'h66656463626139383736353433323130;
      
      expected_H = 128'hd56549cd78082370f6d4990730d9c0e9;
      expected_Mtag = 128'h9f6c954640efa0b96cd4a4da4c629a02;
      
      tb_init    = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      
      if (dut.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.H_reg);
      else
        $display("H correct!");
      
      if (dut.Mtag_reg != expected_Mtag)
        $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.Mtag_reg);
      else
        $display("Mtag correct!");
      
      expected_tag = 128'h8403e103426129e11aef35d6fba55a5a;
      
      tb_finalize = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_tag_ready();
      
      if (tb_tag != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_tag);
          inc_error_ctr();
        end
      else
        $display("Tag correct!");
      
      $display("*** Testvectors #3 END");
      $display("");
      
    end
  endtask // test3
  
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
      
      tb_init    = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      
      if (dut.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.H_reg);
      else
        $display("H correct!");
      
      if (dut.Mtag_reg != expected_Mtag)
        $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.Mtag_reg);
      else
        $display("Mtag correct!");
      
      expected_tag = 128'h1abbdc5ab608df7a082c027ad7c80e25;
      
      tb_finalize = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_tag_ready();
      
      if (tb_tag != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_tag);
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
      
      expected_H = 128'h4a9556fa37aeb7af7fe7ddc9e6c778a5;
      expected_Mtag = 128'h4c4285965b315061aefe494c57ac7cfc;
      
      tb_init    = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      
      if (dut.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.H_reg);
      else
        $display("H correct!");
      
      if (dut.Mtag_reg != expected_Mtag)
        begin
          $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.Mtag_reg);
        end
      else
        $display("Mtag correct!");
      
      tb_block_i       = 128'h39383736353433323130;
      tb_encdec        = 1'b1;
      expected_block_o = 128'h5082efa224b4b2017edd;
      tb_adj_len       = 1'b1;
      
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();
      tb_adj_len = 1'b0;
      
      if (tb_block_o != expected_block_o)
        begin
          $display("Ciphertext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_block_o);
          inc_error_ctr();
        end
      else
        $display("Ciphertext correct!");
        
      expected_tag = 128'h0dd919e35cec312390e6bfe7314efedd;
      
      tb_finalize = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_tag_ready();
         
      if (tb_tag != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_tag);
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

      tb_key     = 256'hfaeadacabaaa9a8a7a6a5a4a3a2a1a0a5f5e5d5c5b5a59585756555453525150;
      tb_iv      = 128'h1032547698badcfeefcdab8967452301;
      tb_ad      = 128'h2165756c6176207473657420444141;
      tb_len_ad  = 64'd120;
      tb_len_i   = 64'd264;
      
      expected_H = 128'h4a9556fa37aeb7af7fe7ddc9e6c778a5;
      expected_Mtag = 128'h4c4285965b315061aefe494c57ac7cfc;
      
      tb_init    = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      
      if (dut.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.H_reg);
      else
        $display("H correct!");
      
      if (dut.Mtag_reg != expected_Mtag)
        begin
          $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.Mtag_reg);
        end
      else
        $display("Mtag correct!");
      
      // First block
      tb_encdec        = 1'b1;
      tb_block_i       = 128'h66656463626139383736353433323130;
      expected_block_o = 128'hc1327ae807275082efa224b4b2017edd;
      
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();
      
      if (tb_block_o != expected_block_o)
        begin
          $display("Ciphertext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_block_o);
        end
      
      // 2nd block
      tb_block_i       = 128'h65646f6d20444145412d56776f6e5320;
      expected_block_o = 128'h1be95956a1b53e24127ffd1818d0b052;
        
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();
        
      if (tb_block_o != expected_block_o)
        begin
          $display("Ciphertext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_block_o);
        end
        
      // 3rd block
      tb_block_i       = 128'h21;
      expected_block_o = 128'h4c;
      tb_adj_len       = 1'b1;
        
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();
        
      if (tb_block_o != expected_block_o)
        begin
          $display("Ciphertext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_block_o);
        end
      else
        $display("Ciphertext correct!");
        
      expected_tag = 128'h9b02eed99a3e7c74de513ab7a5a67e90;
      
      tb_finalize = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_tag_ready();
         
      if (tb_tag != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_tag);
          inc_error_ctr();
        end
      else
        $display("Tag correct!"); 
      
      $display("*** Testvectors #6 END");
      $display("");
    end
  endtask // test6
  
  //----------------------------------------------------------------
  // test6_dec
  //
  // Test vectors #6 for SNOWV-GCM from https://eprint.iacr.org/2018/1143.pdf
  // -> now used in inverse direction to check decryption
  //----------------------------------------------------------------
  task test6_dec;
    begin : test6
      integer i;
      reg [127 : 0] expected_H, expected_Mtag, expected_block_o, expected_tag;

      $display("*** Testvectors #6 (decryption) BEGIN");
      inc_tc_ctr();

      tb_key     = 256'hfaeadacabaaa9a8a7a6a5a4a3a2a1a0a5f5e5d5c5b5a59585756555453525150;
      tb_iv      = 128'h1032547698badcfeefcdab8967452301;
      tb_ad      = 128'h2165756c6176207473657420444141;
      tb_len_ad  = 64'd120;
      tb_len_i   = 64'd264;
      
      expected_H = 128'h4a9556fa37aeb7af7fe7ddc9e6c778a5;
      expected_Mtag = 128'h4c4285965b315061aefe494c57ac7cfc;
      
      tb_init    = 1'h1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'h0;
      wait_ready();
      
      if (dut.H_reg != expected_H)
        $display("H incorrect - Expected 0x%032x, got 0x%032x", expected_H, dut.H_reg);
      else
        $display("H correct!");
      
      if (dut.Mtag_reg != expected_Mtag)
        begin
          $display("Mtag incorrect - Expected 0x%032x, got 0x%032x", expected_Mtag, dut.Mtag_reg);
        end
      else
        $display("Mtag correct!");
      
      // First block
      tb_encdec        = 1'b0;
      tb_adj_len       = 1'b0;
      tb_block_i       = 128'hc1327ae807275082efa224b4b2017edd;
      expected_block_o = 128'h66656463626139383736353433323130;
      
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();
      
      if (tb_block_o != expected_block_o)
        begin
          $display("Plaintext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_block_o);
        end
      
      // 2nd block
      tb_adj_len       = 1'b0;
      tb_block_i       = 128'h1be95956a1b53e24127ffd1818d0b052;
      expected_block_o = 128'h65646f6d20444145412d56776f6e5320;
        
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();
        
      if (tb_block_o != expected_block_o)
        begin
          $display("Plaintext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_block_o);
        end
        
      // 3rd block
      tb_adj_len       = 1'b1;
      tb_block_i       = 128'h4c;
      expected_block_o = 128'h21;
      tb_adj_len       = 1'b1;
        
      tb_next  = 1'h1;
      #(2 * CLK_PERIOD);
      tb_next  = 1'h0;
      wait_ready();
        
      if (tb_block_o != expected_block_o)
        begin
          $display("Plaintext incorrect - Expected 0x%032x, got 0x%032x", expected_block_o, tb_block_o);
        end
      else
        $display("Plaintext correct!");
        
      expected_tag = 128'h9b02eed99a3e7c74de513ab7a5a67e90;
      
      tb_finalize = 1'h1;
      #(2 * CLK_PERIOD);
      tb_finalize = 1'h0;
      wait_tag_ready();
         
      if (tb_tag != expected_tag)
        begin
          $display("Tag incorrect - Expected 0x%032x, got 0x%032x", expected_tag, tb_tag);
          inc_error_ctr();
        end
      else
        $display("Tag correct!"); 

      $display("*** Testvectors #6 (decryption) END");
      $display("");
    end
  endtask // test6_dec

  //----------------------------------------------------------------
  // main
  //
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : main
      $display("*** Testbench for SNOWV-GCM started ***");
      $display("");

      init_sim();
      reset_dut();

      test1();
      test2();
      test3();
      test4();
      test5();
      test6();
      test6_dec();

      display_test_results();
      $display("*** SNOWV-GCM simulation done. ***");
      $finish;
    end // main

endmodule // tb_snowv_gcm

//======================================================================
// EOF tb_snowv_gcm.v
//======================================================================
