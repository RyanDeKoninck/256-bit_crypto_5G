//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 03/10/2023 03:02:44 PM
// Design Name: 
// Module Name: aes_tot_wrapper
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

module aes_tot_wrapper(
                   input wire             clk,
                   input wire             resetn,
                   
                   input wire [31 : 0]    arm_to_fpga_cmd,
                   input wire             arm_to_fpga_cmd_valid,
                   output wire            fpga_to_arm_done,
                   input wire             fpga_to_arm_done_read,
                   
                   input wire             arm_to_fpga_data_valid,
                   output wire            arm_to_fpga_data_ready,
                   input wire [1023 : 0]  arm_to_fpga_data,
                   
                   output wire            fpga_to_arm_data_valid,
                   input wire             fpga_to_arm_data_ready,
                   output wire [1023 : 0] fpga_to_arm_data,
                   
                   output wire [3 : 0]    leds
                   );

    //----------------------------------------------------------------
    // Internal constant and parameter definitions.
    //----------------------------------------------------------------
      // States
    localparam CTRL_WAIT_FOR_CMD  = 4'h0;  
    localparam CTRL_READ          = 4'h1;
    localparam CTRL_INIT          = 4'h2;
    localparam CTRL_NEXT          = 4'h3;
    localparam CTRL_FINAL         = 4'h4;
    localparam CTRL_BUSY          = 4'h5;
    localparam CTRL_WRITE         = 4'h6;
    localparam CTRL_ASSERT_DONE   = 4'h7;
    
      // Wrapper commands
    localparam CMD_READ           = 32'h0;
    localparam CMD_COMPUTE_INIT   = 32'h1;
    localparam CMD_COMPUTE_NEXT   = 32'h2;
    localparam CMD_COMPUTE_FINAL  = 32'h3;
    localparam CMD_WRITE          = 32'h4;

    //----------------------------------------------------------------
    // Registers + update variables and write enable.
    //----------------------------------------------------------------
    reg [3 : 0]    aes_tot_wrapper_ctrl_reg;
    reg [3 : 0]    aes_tot_wrapper_ctrl_new;
    reg            aes_tot_wrapper_ctrl_we;
    
    reg            enc_auth_reg;
    wire           enc_auth_new;
    
    reg [255 : 0]  key_reg;
    wire [255 : 0] key_new;
    
    reg            keylen_reg;
    wire           keylen_new;
    
    reg [127 : 0]  counter_reg;
    wire [127 : 0] counter_new;
    
    reg [7 : 0]    final_size_reg;
    wire [7 : 0]   final_size_new;
    
    reg [127 : 0]  block_i_reg;
    wire [127 : 0] block_i_new;
    
    reg            inputs_we;
    
    reg [127 : 0]  result_reg;
    wire [127 : 0] result_new;
    reg            result_we;
    
    reg            fpga_to_arm_data_valid_reg;
    wire           fpga_to_arm_data_valid_new;
    
    reg            arm_to_fpga_data_ready_reg;
    wire           arm_to_fpga_data_ready_new;
    
    reg            fpga_to_arm_done_reg;
    wire           fpga_to_arm_done_new;
    
    //----------------------------------------------------------------
    // Wires.
    //----------------------------------------------------------------
      // Core I/O
    reg            core_init;
    reg            core_next;
    reg            core_finalize;
    wire           core_enc_auth;
    wire [127 : 0] core_counter;
    wire [255 : 0] core_key;
    wire           core_keylen;
    wire [7 : 0]   core_final_size;
    wire [127 : 0] core_block_i;
    
    wire [127 : 0] core_result;
    wire           core_ready;
    
    //----------------------------------------------------------------
    // Instantiations.
    //----------------------------------------------------------------
    aes_tot tot(
                .clk(clk),
                .reset_n(resetn),
                .init(core_init),
                .next(core_next),
                .finalize(core_finalize),
                .enc_auth(core_enc_auth),
                .counter(core_counter),
                .key(core_key),
                .keylen(core_keylen),
                .final_size(core_final_size),
                .block_i(core_block_i),
                
                .block_o(core_result),
                .ready(core_ready)
                );

    //----------------------------------------------------------------
    // Concurrent connectivity for ports etc.
    //----------------------------------------------------------------
      // Core I/O
    assign core_enc_auth   = enc_auth_reg;
    assign core_key        = key_reg;
    assign core_keylen     = keylen_reg;
    assign core_counter    = counter_reg;
    assign core_block_i    = block_i_reg;
    assign core_final_size = final_size_reg;
    assign result_new      = core_result;
    
      // ARM to FPGA data decomposition
    assign enc_auth_new   = arm_to_fpga_data[521];
    assign counter_new    = arm_to_fpga_data[520 : 393];
    assign key_new        = arm_to_fpga_data[392 : 137];
    assign keylen_new     = arm_to_fpga_data[136];
    assign final_size_new = arm_to_fpga_data[135 : 128];
    assign block_i_new    = arm_to_fpga_data[127 : 0];
    
      // Wrapper I/O
    assign fpga_to_arm_data       = {896'h0, result_reg};
    assign fpga_to_arm_data_valid = fpga_to_arm_data_valid_reg;
    assign arm_to_fpga_data_ready = arm_to_fpga_data_ready_reg;
    assign fpga_to_arm_done       = fpga_to_arm_done_reg;
    
      // The four LEDs on the board are used as debug signals.
    assign leds = aes_tot_wrapper_ctrl_reg;

    //----------------------------------------------------------------
    // reg_update
    //
    // Update functionality for all registers in the core.
    // All registers are positive edge triggered with asynchronous
    // active low reset. All registers have write enable.
    //----------------------------------------------------------------
    always @ (posedge clk or negedge resetn)
      begin: reg_update
        if (!resetn)
          begin
            aes_tot_wrapper_ctrl_reg    <= CTRL_WAIT_FOR_CMD;
            enc_auth_reg                <= 1'b0;
            counter_reg                 <= 128'h0;
            key_reg                     <= 256'h0;
            keylen_reg                  <= 1'b0;
            final_size_reg              <= 8'b0;
            block_i_reg                 <= 128'h0;
            result_reg                  <= 128'h0;
            fpga_to_arm_data_valid_reg  <= 1'b0;
            arm_to_fpga_data_ready_reg  <= 1'b0;
            fpga_to_arm_done_reg        <= 1'b0;
          end
        else
          begin
            if (aes_tot_wrapper_ctrl_we)
              aes_tot_wrapper_ctrl_reg <= aes_tot_wrapper_ctrl_new;
            if (inputs_we)
              begin
                enc_auth_reg   <= enc_auth_new;
                counter_reg    <= counter_new;
                key_reg        <= key_new;
                keylen_reg     <= keylen_new;
                final_size_reg <= final_size_new;
                block_i_reg    <= block_i_new;
              end
            if (result_we)
              result_reg   <= result_new;
            
            // Wrapper control signals don't have a write enable
            fpga_to_arm_data_valid_reg <= fpga_to_arm_data_valid_new;
            arm_to_fpga_data_ready_reg <= arm_to_fpga_data_ready_new;
            fpga_to_arm_done_reg <= fpga_to_arm_done_new;
          end
      end // reg_update

    //----------------------------------------------------------------
    // aes_tot_wrapper_ctrl
    //
    // Control FSM for aes_tot_wrapper.
    //----------------------------------------------------------------
    always @*
      begin: aes_tot_wrapper_ctrl
        aes_tot_wrapper_ctrl_new = CTRL_WAIT_FOR_CMD;
        aes_tot_wrapper_ctrl_we  = 1'b0;
        core_init                = 1'b0;
        core_next                = 1'b0;
        core_finalize            = 1'b0;
        inputs_we                = 1'b0;
        result_we                = 1'b0;
        
        case (aes_tot_wrapper_ctrl_reg)
          CTRL_WAIT_FOR_CMD:
            begin
              if (arm_to_fpga_cmd_valid)
                begin
                  aes_tot_wrapper_ctrl_we  = 1'b1;
                  case (arm_to_fpga_cmd)
                    CMD_READ:
                      aes_tot_wrapper_ctrl_new = CTRL_READ;
                    CMD_COMPUTE_INIT:
                      aes_tot_wrapper_ctrl_new = CTRL_INIT;
                    CMD_COMPUTE_NEXT:
                      aes_tot_wrapper_ctrl_new = CTRL_NEXT;
                    CMD_COMPUTE_FINAL:
                      aes_tot_wrapper_ctrl_new = CTRL_FINAL;
                    CMD_WRITE:
                      aes_tot_wrapper_ctrl_new = CTRL_WRITE;
                    default:
                      aes_tot_wrapper_ctrl_we  = 1'b0;
                  endcase
                end
            end
          CTRL_READ:
            if (arm_to_fpga_data_valid)
              begin
                aes_tot_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                aes_tot_wrapper_ctrl_we  = 1'b1;
                inputs_we                = 1'b1;
              end
          CTRL_INIT:
            begin
              core_init                   = 1'b1;
              aes_tot_wrapper_ctrl_new = CTRL_BUSY;
              aes_tot_wrapper_ctrl_we  = 1'b1;
            end
          CTRL_NEXT:
            begin
              core_next                = 1'b1;
              aes_tot_wrapper_ctrl_new = CTRL_BUSY;
              aes_tot_wrapper_ctrl_we  = 1'b1;
            end
          CTRL_FINAL:
            begin
              core_finalize            = 1'b1;
              aes_tot_wrapper_ctrl_new = CTRL_BUSY;
              aes_tot_wrapper_ctrl_we  = 1'b1;
            end
          CTRL_BUSY:
            if (core_ready)
              begin
                aes_tot_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                aes_tot_wrapper_ctrl_we  = 1'b1;
                result_we                = 1'b1;
              end
          CTRL_WRITE:
            if (fpga_to_arm_data_ready)
              begin
                aes_tot_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                aes_tot_wrapper_ctrl_we  = 1'b1;
              end
          CTRL_ASSERT_DONE:
            if (fpga_to_arm_done_read)
              begin
                aes_tot_wrapper_ctrl_new = CTRL_WAIT_FOR_CMD;
                aes_tot_wrapper_ctrl_we  = 1'b1;
              end
          default:
            begin
          
            end
          endcase // case (aes_tot_wrapper_ctrl_reg)
        end // aes_tot_wrapper_ctrl
    
    //----------------------------------------------------------------
    // Wrapper control signals
    //
    // Set the control signals based on the current state of the FSM.
    //----------------------------------------------------------------
    assign fpga_to_arm_data_valid_new = (aes_tot_wrapper_ctrl_reg == CTRL_WRITE);
    assign arm_to_fpga_data_ready_new = (aes_tot_wrapper_ctrl_reg == CTRL_READ);
    assign fpga_to_arm_done_new       = (aes_tot_wrapper_ctrl_reg == CTRL_ASSERT_DONE);

endmodule