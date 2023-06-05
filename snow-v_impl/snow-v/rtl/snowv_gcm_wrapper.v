//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ryan De Koninck
// 
// Create Date: 03/10/2023 03:02:44 PM
// Design Name: 
// Module Name: cmac_wrapper
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

module snowv_gcm_wrapper(
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
    localparam CTRL_WAIT_FOR_CMD   = 4'h0;  
    localparam CTRL_READ           = 4'h1;
    localparam CTRL_INIT           = 4'h2;
    localparam CTRL_NEXT_AD        = 4'h3;
    localparam CTRL_NEXT           = 4'h4;
    localparam CTRL_FINAL          = 4'h5;
    localparam CTRL_BUSY           = 4'h6;
    localparam CTRL_BUSY_TAG       = 4'h7;
    localparam CTRL_WRITE          = 4'h8;
    localparam CTRL_ASSERT_DONE    = 4'h9;
    
      // Wrapper commands
    localparam CMD_READ            = 32'h0;
    localparam CMD_COMPUTE_INIT    = 32'h1;
    localparam CMD_COMPUTE_NEXT_AD = 32'h2;
    localparam CMD_COMPUTE_NEXT    = 32'h3;
    localparam CMD_COMPUTE_FINAL   = 32'h4;
    localparam CMD_WRITE           = 32'h5;

    //----------------------------------------------------------------
    // Registers + update variables and write enable.
    //----------------------------------------------------------------
    reg [3 : 0]    snowv_gcm_wrapper_ctrl_reg;
    reg [3 : 0]    snowv_gcm_wrapper_ctrl_new;
    reg            snowv_gcm_wrapper_ctrl_we;
    
    reg            encdec_only_reg;
    wire           encdec_only_new;
    
    reg            auth_only_reg;
    wire           auth_only_new;
    
    reg            encdec_reg;
    wire           encdec_new;
    
    reg            adj_len_reg;
    wire           adj_len_new;
    
    reg [255 : 0]  key_reg;
    wire [255 : 0] key_new;
    
    reg [127 : 0]  iv_reg;
    wire [127 : 0] iv_new;
    
    reg [127 : 0]  ad_reg;
    wire [127 : 0] ad_new;
    
    reg [63 : 0]   len_ad_reg;
    wire [63 : 0]  len_ad_new;
    
    reg [127 : 0]  block_i_reg;
    wire [127 : 0] block_i_new;
    
    reg [63 : 0]   len_i_reg;
    wire [63 : 0]  len_i_new;
    
    reg            inputs_we;
    
    reg [127 : 0]  block_o_reg;
    wire [127 : 0] block_o_new;
    reg            block_o_we;
    
    reg [127 : 0]  tag_reg;
    wire [127 : 0] tag_new;
    reg            tag_we;
    
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
    reg            core_next_ad;
    reg            core_next;
    reg            core_finalize;
    wire           core_encdec_only;
    wire           core_auth_only;
    wire           core_encdec;
    wire           core_adj_len;
    wire [255 : 0] core_key;
    wire [127 : 0] core_iv;
    wire [127 : 0] core_ad;
    wire [63 : 0]  core_len_ad;
    wire [127 : 0] core_block_i;
    wire [63 : 0]  core_len_i;
    
    wire [127 : 0] core_block_o;
    wire [127 : 0] core_tag;
    wire           core_ready;
    wire           core_tag_ready;
    
    //----------------------------------------------------------------
    // Instantiations.
    //----------------------------------------------------------------
    snowv_gcm core(
                   .clk(clk),
                   .reset_n(resetn),
                   
                   .init(core_init),
                   .next_ad(core_next_ad),
                   .next(core_next),
                   .finalize(core_finalize),
                   .encdec_only(core_encdec_only),
                   .auth_only(core_auth_only),
                   .encdec(core_encdec),
                   .adj_len(core_adj_len),
                   .key(core_key),
                   .iv(core_iv),
                   .ad(core_ad),
                   .len_ad(core_len_ad),
                   .block_i(core_block_i),
                   .len_i(core_len_i),
                   
                   .block_o(core_block_o),
                   .tag(core_tag),
                   .ready(core_ready),
                   .tag_ready(core_tag_ready)
                   );

    //----------------------------------------------------------------
    // Concurrent connectivity for ports etc.
    //----------------------------------------------------------------
      // Core I/O
    assign core_encdec_only = encdec_only_reg;
    assign core_auth_only   = auth_only_reg;
    assign core_encdec      = encdec_reg;
    assign core_adj_len     = adj_len_reg;
    assign core_key         = key_reg;
    assign core_iv          = iv_reg;
    assign core_ad          = ad_reg;
    assign core_len_ad      = len_ad_reg;
    assign core_block_i     = block_i_reg;
    assign core_len_i       = len_i_reg;
    
    assign block_o_new      = core_block_o;
    assign tag_new          = core_tag;
    
      // ARM to FPGA data decomposition
    assign encdec_only_new = arm_to_fpga_data[771];
    assign auth_only_new   = arm_to_fpga_data[770];
    assign encdec_new      = arm_to_fpga_data[769];
    assign adj_len_new     = arm_to_fpga_data[768];
    assign key_new         = arm_to_fpga_data[767 : 512];
    assign iv_new          = arm_to_fpga_data[511 : 384];
    assign ad_new          = arm_to_fpga_data[383 : 256];
    assign len_ad_new      = arm_to_fpga_data[255 : 192];
    assign block_i_new     = arm_to_fpga_data[191 : 64];
    assign len_i_new       = arm_to_fpga_data[63 : 0];
    
      // Wrapper I/O
    assign fpga_to_arm_data       = {768'h0, block_o_reg, tag_reg};
    assign fpga_to_arm_data_valid = fpga_to_arm_data_valid_reg;
    assign arm_to_fpga_data_ready = arm_to_fpga_data_ready_reg;
    assign fpga_to_arm_done       = fpga_to_arm_done_reg;
    
      // The four LEDs on the board are used as debug signals.
    assign leds = snowv_gcm_wrapper_ctrl_reg;

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
            snowv_gcm_wrapper_ctrl_reg <= CTRL_WAIT_FOR_CMD;
            encdec_only_reg            <= 1'b0;
            auth_only_reg              <= 1'b0;
            encdec_reg                 <= 1'b0;
            adj_len_reg                <= 1'b0;
            key_reg                    <= 256'h0;
            iv_reg                     <= 128'h0;
            ad_reg                     <= 128'h0;
            len_ad_reg                 <= 64'h0;
            block_i_reg                <= 128'h0;
            len_i_reg                  <= 64'h0;
            block_o_reg                <= 128'h0;
            tag_reg                    <= 128'h0;
          end
        else
          begin
            if (snowv_gcm_wrapper_ctrl_we)
              snowv_gcm_wrapper_ctrl_reg <= snowv_gcm_wrapper_ctrl_new;
            if (inputs_we)
              begin
                encdec_only_reg            <= encdec_only_new;
                auth_only_reg              <= auth_only_new;
                encdec_reg                 <= encdec_new;
                adj_len_reg                <= adj_len_new;
                key_reg                    <= key_new;
                iv_reg                     <= iv_new;
                ad_reg                     <= ad_new;
                len_ad_reg                 <= len_ad_new;
                block_i_reg                <= block_i_new;
                len_i_reg                  <= len_i_new;
              end
            if (block_o_we)
              block_o_reg <= block_o_new;
            if (tag_we)
              tag_reg <= tag_new;
            
            // Wrapper control signals don't have a write enable
            fpga_to_arm_data_valid_reg <= fpga_to_arm_data_valid_new;
            arm_to_fpga_data_ready_reg <= arm_to_fpga_data_ready_new;
            fpga_to_arm_done_reg <= fpga_to_arm_done_new;
          end
      end // reg_update

    //----------------------------------------------------------------
    // snowv_gcm_wrapper_ctrl
    //
    // Control FSM for cmac_wrapper.
    //----------------------------------------------------------------
    always @*
      begin: snowv_gcm_wrapper_ctrl
        snowv_gcm_wrapper_ctrl_new = CTRL_WAIT_FOR_CMD;
        snowv_gcm_wrapper_ctrl_we  = 1'b0;
        core_init                  = 1'b0;
        core_next_ad               = 1'b0;
        core_next                  = 1'b0;
        core_finalize              = 1'b0;
        inputs_we                  = 1'b0;
        block_o_we                 = 1'b0;
        tag_we                     = 1'b0;
        
        case (snowv_gcm_wrapper_ctrl_reg)
          CTRL_WAIT_FOR_CMD:
            begin
              if (arm_to_fpga_cmd_valid)
                begin
                  snowv_gcm_wrapper_ctrl_we  = 1'b1;
                  case (arm_to_fpga_cmd)
                    CMD_READ:
                      snowv_gcm_wrapper_ctrl_new = CTRL_READ;
                    CMD_COMPUTE_INIT:
                      snowv_gcm_wrapper_ctrl_new = CTRL_INIT;
                    CMD_COMPUTE_NEXT_AD:
                      snowv_gcm_wrapper_ctrl_new = CTRL_NEXT_AD;
                    CMD_COMPUTE_NEXT:
                      snowv_gcm_wrapper_ctrl_new = CTRL_NEXT;
                    CMD_COMPUTE_FINAL:
                      snowv_gcm_wrapper_ctrl_new = CTRL_FINAL;
                    CMD_WRITE:
                      snowv_gcm_wrapper_ctrl_new = CTRL_WRITE;
                    default:
                      snowv_gcm_wrapper_ctrl_we  = 1'b0;
                  endcase
                end
            end
          CTRL_READ:
            if (arm_to_fpga_data_valid)
              begin
                snowv_gcm_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                snowv_gcm_wrapper_ctrl_we  = 1'b1;
                inputs_we                  = 1'b1;
              end
          CTRL_INIT:
            begin
              core_init                  = 1'b1;
              snowv_gcm_wrapper_ctrl_new = CTRL_BUSY;
              snowv_gcm_wrapper_ctrl_we  = 1'b1;
            end
          CTRL_NEXT_AD:
            begin
              core_next_ad               = 1'b1;
              snowv_gcm_wrapper_ctrl_new = CTRL_BUSY;
              snowv_gcm_wrapper_ctrl_we  = 1'b1;
            end
          CTRL_NEXT:
            begin
              core_next                  = 1'b1;
              snowv_gcm_wrapper_ctrl_new = CTRL_BUSY;
              snowv_gcm_wrapper_ctrl_we  = 1'b1;
            end
          CTRL_FINAL:
            begin
              core_finalize              = 1'b1;
              snowv_gcm_wrapper_ctrl_new = CTRL_BUSY_TAG;
              snowv_gcm_wrapper_ctrl_we  = 1'b1;
            end
          CTRL_BUSY:
            if (core_ready)
              begin
                snowv_gcm_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                snowv_gcm_wrapper_ctrl_we  = 1'b1;
                block_o_we = 1'b1;
              end
          CTRL_BUSY_TAG:
            if (core_tag_ready)
              begin
                snowv_gcm_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                snowv_gcm_wrapper_ctrl_we  = 1'b1;
                tag_we = 1'b1;
              end
          CTRL_WRITE:
            if (fpga_to_arm_data_ready)
              begin
                snowv_gcm_wrapper_ctrl_new = CTRL_ASSERT_DONE;
                snowv_gcm_wrapper_ctrl_we  = 1'b1;
              end
          CTRL_ASSERT_DONE:
            if (fpga_to_arm_done_read)
              begin
                snowv_gcm_wrapper_ctrl_new = CTRL_WAIT_FOR_CMD;
                snowv_gcm_wrapper_ctrl_we  = 1'b1;
              end
          default:
            begin
          
            end
          endcase // case (snowv_gcm_wrapper_ctrl_reg)
        end // snowv_gcm_wrapper_ctrl
    
    //----------------------------------------------------------------
    // Wrapper control signals
    //
    // Set the control signals based on the current state of the FSM.
    //----------------------------------------------------------------
    assign fpga_to_arm_data_valid_new = (snowv_gcm_wrapper_ctrl_reg == CTRL_WRITE);
    assign arm_to_fpga_data_ready_new = (snowv_gcm_wrapper_ctrl_reg == CTRL_READ);
    assign fpga_to_arm_done_new       = (snowv_gcm_wrapper_ctrl_reg == CTRL_ASSERT_DONE);

endmodule