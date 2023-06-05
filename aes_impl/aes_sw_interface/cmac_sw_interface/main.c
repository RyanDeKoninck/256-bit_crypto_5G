#include "common.h"

#include "hw_accelerator.h"

// These variables are defined in the testvector.c
// that is created by the testvector generator python script
extern uint32_t tc3_key[32],
                tc3_block0[32],
                tc3_expected[4],
                tc5_key[32],
                tc5_block0[32],
                tc5_block1[32],
                tc5_block2[32],
                tc5_expected[4],
//                tc7_key[32],
//                tc7_block0[32],
//                tc7_block1[32],
//                tc7_block2[32],
//                tc7_block3[32],
//                tc7_expected[4];

uint32_t output[32];

int main()
{
	init_platform();
	init_performance_counters(1);

	xil_printf("----------- Begin CMAC test: -----------\n\r");

	init_HW_access();
	xil_printf("HW initialization successful!\n\r\n\r");

	// tc3 test
	xil_printf("Test tc3...\n\r");
START_TIMING
	cmac_HW_init(tc3_key);
  cmac_HW_finalize(tc3_block0, output);
STOP_TIMING
	customprint(output, "    Output", 32);
	if (check_correctness(output, tc3_expected, 4) != 1) xil_printf("    tc3 test for CMAC correct!\n\r\n\r");
	else xil_printf("    tc3 test for CMAC incorrect :(\n\r\n\r");

	// tc5 test
	xil_printf("Test tc5...\n\r");
START_TIMING
  cmac_HW_init(tc5_key);
  cmac_HW_next(tc5_block0);
  cmac_HW_next(tc5_block1);
  cmac_HW_finalize(tc5_block2, output);
STOP_TIMING
	customprint(output, "    Output", 32);
	if (check_correctness(output, tc5_expected, 4) != 1) xil_printf("    tc5 test for CMAC correct!\n\r\n\r");
	else xil_printf("    tc5 test for CMAC incorrect :(\n\r\n\r");

// !!! Cannot run all tests at the same time due to memory constraints on
// !!! the PYNQ board processor.

//	// tc7 test
//	xil_printf("Test tc7...\n\r");
//START_TIMING
//  cmac_HW_init(tc7_key);
//  cmac_HW_next(tc7_block0);
//  cmac_HW_next(tc7_block1);
//  cmac_HW_next(tc7_block2);
//  cmac_HW_finalize(tc7_block3, output);
//STOP_TIMING
//	customprint(output, "    Output", 32);
//	if (check_correctness(output, tc7_expected, 4) != 1) xil_printf("    tc7 test for CMAC correct!\n\r\n\r");
//	else xil_printf("    tc7 test for CMAC incorrect :(\n\r\n\r");

	xil_printf("----------- End CMAC test -----------\n\r");

	cleanup_platform();

	return 0;
}
