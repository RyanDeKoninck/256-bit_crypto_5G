#include "common.h"
#include "platform/interface.h"

#include "hw_accelerator.h"

// Note that these tree CMDs are same as
// they are defined in *_wrapper.v
#define CMD_READ            0
#define CMD_COMPUTE_INIT    1
#define CMD_COMPUTE_NEXT    2
#define CMD_COMPUTE_FINAL   3
#define CMD_WRITE           4

void init_HW_access(void)
{
	interface_init();
}

void customprint(uint32_t *large_number, char *str, int size)
{
	int32_t i;

	xil_printf("%s = ",str);
	for (i = size-1; i >= 0; i--) {
		xil_printf("0x%x,", large_number[i]);
	}
	xil_printf("\n\r");
}

int check_correctness(uint32_t *expected, uint32_t *calculated, int size)
{
	for (int i = 0; i < size; i++) {
		if (expected[i] != calculated[i]) return 1;
	}
	return 0;
}

void zuc256_tot_HW_init(uint32_t *input)
{
	//// --- Send the read command and transfer input data to FPGA
	send_cmd_to_hw(CMD_READ);
	send_data_to_hw(input);
	while(!is_done());

	//// --- Perform the compute operation
	send_cmd_to_hw(CMD_COMPUTE_INIT);
	while(!is_done());
}

void zuc256_tot_HW_next(uint32_t *input, uint32_t *output)
{
	//// --- Send the read command and transfer input data to FPGA
	send_cmd_to_hw(CMD_READ);
	send_data_to_hw(input);
	while(!is_done());

	//// --- Perform the compute operation
	send_cmd_to_hw(CMD_COMPUTE_NEXT);
	while(!is_done());

	//// --- Send write command and transfer output data from FPGA
	send_cmd_to_hw(CMD_WRITE);
	read_data_from_hw(output);
	while(!is_done());
}

void zuc256_tot_HW_finalize(uint32_t *output)
{
	//// --- Perform the compute operation
	send_cmd_to_hw(CMD_COMPUTE_FINAL);
	while(!is_done());

	//// --- Send write command and transfer output data from FPGA
	send_cmd_to_hw(CMD_WRITE);
	read_data_from_hw(output);
	while(!is_done());
}
