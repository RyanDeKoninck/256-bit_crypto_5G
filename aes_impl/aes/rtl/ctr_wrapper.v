// NOT UP-TO-DATE

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 03/10/2023 03:02:44 PM
// Design Name: 
// Module Name: ctr_wrapper
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

module ctr_wrapper(
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
    localparam CTRL_START         = 4'h2;
    localparam CTRL_BUSY          = 4'h3;
    localparam CTRL_WRITE         = 4'h4;
    localparam CTRL_ASSERT_DONE   = 4'h5;
    
      // Wrapper commands
    localparam CMD_READ           = 32'h0;
    localparam CMD_COMPUTE        = 32'h1;
    localparam CMD_WRITE          = 32'h2;

    //----------------------------------------------------------------
    // Registers + update variables and write enable.
    //----------------------------------------------------------------
    reg [3 : 0]    ctr_wrapper_ctrl_reg;
    reg [3 : 0]    ctr_wrapper_ctrl_new;
    reg            ctr_wrapper_ctrl_we;
    
    reg [127 : 0]  counter_reg;
    wire [127 : 0] counter_new;
    reg            counter_we;
    
    reg [255 : 0]  key_reg;
    wire [255 : 0] key_new;
    reg            key_we;
    
    reg            keylen_reg;
    wire           keylen_new;
    reg            keylen_we;
    
    reg [127 : 0]  block_i_reg;
    wire [127 : 0] block_i_new;
    reg            block_i_we;
    
    reg [127 : 0]  block_o_reg;
    wire [127 : 0] block_o_new;
    reg            block_o_we;
    
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
    reg            core_start;
    wire [127 : 0] core_counter;
    wire [255 : 0] core_key;
    wire           core_keylen;
    wire [127 : 0] core_block_i;
    wire [127 : 0] core_block_o;
    wire           core_ready;
    
    //----------------------------------------------------------------
    // Instantiations.
    //----------------------------------------------------------------
    ctr_core ctr(
                 .clk(clk),
                 .reset_n(resetn),
                 .start(core_start),
                 .counter(core_counter),
                 .key(core_key),
                 .keylen(core_keylen),
                 .block_i(core_block_i),
                 .block_o(core_block_o),
                 .ready(core_ready)
                 );

    //----------------------------------------------------------------
    // Concurrent connectivity for ports etc.
    //----------------------------------------------------------------
      // Core I/O
    assign core_counter = counter_reg;
    assign core_key     = key_reg;
    assign core_keylen  = keylen_reg;
    assign core_block_i = block_i_reg;
    
      // ARM to FPGA data decomposition
    assign counter_new  = arm_to_fpga_data[512 : 385];
    assign key_new      = arm_to_fpga_data[384 : 129];
    assign keylen_new   = arm_to_fpga_data[128];
    assign block_i_new  = arm_to_fpga_data[127 : 0];
    
      // Wrapper I/O
    assign fpga_to_arm_data       = {896'h0, block_o_reg};
    assign fpga_to_arm_data_valid = fpga_to_arm_data_valid_reg;
    assign arm_to_fpga_data_ready = arm_to_fpga_data_ready_reg;
    assign fpga_to_arm_done       = fpga_to_arm_done_reg;
    assign block_o_new            = core_block_o;
    
      // The four LEDs on the board are used as debug signals.
    //assign leds = ~ctr_wrapper_ctrl_reg;
    assign leds = ctr_wrapper_ctrl_reg;

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
            ctr_wrapper_ctrl_reg       <= CTRL_WAIT_FOR_CMD;
            counter_reg                <= 1'b0;
            key_reg                    <= 256'h0;
            keylen_reg                 <= 1'b0;
            block_i_reg                <= 128'h0;
            block_o_reg                <= 128'h0;
            fpga_to_arm_data_valid_reg <= 1'b0;
            arm_to_fpga_data_ready_reg <= 1'b0;
            fpga_to_arm_done_reg       <= 1'b0;
          end
        else
          begin
            if (ctr_wrapper_ctrl_we)
              ctr_wrapper_ctrl_reg <= ctr_wrapper_ctrl_new;
            if (counter_we)
              counter_reg <= counter_new;
            if (key_we)
              key_reg <= key_new;
            if (keylen_we)
              keylen_reg <= keylen_new;
            if (block_i_we)
              block_i_reg <= block_i_new;
            if (block_o_we)
              block_o_reg <= block_o_new;
            
            // Wrapper control signals don't have a write enable
            fpga_to_arm_data_valid_reg <= fpga_to_arm_data_valid_new;
            arm_to_fpga_data_ready_reg <= arm_to_fpga_data_ready_new;
            fpga_to_arm_done_reg <= fpga_to_arm_done_new;
          end
      end // reg_update

    //----------------------------------------------------------------
    // ctr_wrapper_ctrl
    //
    // Control FSM for ctr_wrapper.
    //----------------------------------------------------------------
    always @*
      begin: ctr_wrapper_ctrl
        ctr_wrapper_ctrl_new = CTRL_WAIT_FOR_CMD;
        ctr_wrapper_ctrl_we  = 1'b0;
        core_start           = 1'b0;
        counter_we           = 1'b0;
        key_we               = 1'b0;
        keylen_we            = 1'b0;
        block_i_we           = 1'b0;
        block_o_we           = 1'b0;
        
        case (ctr_wrapper_ctrl_reg)
          CTRL_WAIT_FOR_CMD:
            begin
              if (arm_to_fpga_cmd_valid)
                begin
                  ctr_wrapper_ctrl_we  = 1'b1;
                  case (arm_to_fpga_cmd)
                    CMD_READ:
                      ctr_wrapper_ctrl_new = CTRL_READ;
                    CMD_COMPUTE:
                      ctr_wrapper_ctrl_new = CTRL_START;
                    CMD_WRITE:
                      ctr_wrapper_ctrl_new = CTRL_WRITE;
                    default:
                      ctr_wrapper_ctrl_we  = 1'b0;
                  endcase
                end
            end
          CTRL_READ:
            if (arm_to_fpga_data_valid)
              begin
                ctr_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                ctr_wrapper_ctrl_we  = 1'b1;
                counter_we           = 1'b1;
                key_we               = 1'b1;
                keylen_we            = 1'b1;
                block_i_we           = 1'b1;
              end
          CTRL_START:
            begin
              core_start = 1'b1;
              ctr_wrapper_ctrl_new = CTRL_BUSY;
              ctr_wrapper_ctrl_we  = 1'b1;
            end
          CTRL_BUSY:
            if (core_ready)
              begin
                ctr_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                ctr_wrapper_ctrl_we  = 1'b1;
                block_o_we           = 1'b1;
              end
          CTRL_WRITE:
            if (fpga_to_arm_data_ready)
              begin
                ctr_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                ctr_wrapper_ctrl_we  = 1'b1;
              end
          CTRL_ASSERT_DONE:
            if (fpga_to_arm_done_read)
              begin
                ctr_wrapper_ctrl_new = CTRL_WAIT_FOR_CMD;
                ctr_wrapper_ctrl_we  = 1'b1;
              end
          default:
            begin
          
            end
          endcase // case (ctr_wrapper_ctrl_reg)
        end // ctr_wrapper_ctrl
    
    //----------------------------------------------------------------
    // Wrapper control signals
    //
    // Set the control signals based on the current state of the FSM.
    //----------------------------------------------------------------
    assign fpga_to_arm_data_valid_new = (ctr_wrapper_ctrl_reg == CTRL_WRITE);
    assign arm_to_fpga_data_ready_new = (ctr_wrapper_ctrl_reg == CTRL_READ);
    assign fpga_to_arm_done_new       = (ctr_wrapper_ctrl_reg == CTRL_ASSERT_DONE);

endmodule