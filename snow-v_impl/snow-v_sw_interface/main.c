#include "common.h"

#include "hw_accelerator.h"

// These variables are defined in the testvector.c
// that is created by the testvector generator python script
extern uint32_t tc4_init[32],
                tc4_expected_tag[4],
                tc6_init[32],
                tc6_block0[32],
                tc6_expected_block0[4],
                tc6_block1[32],
                tc6_expected_block1[4],
                tc6_block2[32],
                tc6_expected_block2[4],
                tc6_expected_tag[4];

uint32_t output[32];

int main()
{
	init_platform();
	init_performance_counters(1);

	xil_printf("----------- Begin SNOWV-GCM test: -----------\n\r");

	init_HW_access();
	xil_printf("HW initialization successful!\n\r\n\r");

	// tc4 test
	xil_printf("Test tc4...\n\r");
START_TIMING
	snowv_gcm_HW_init(tc4_init);
  snowv_gcm_HW_finalize(output);
STOP_TIMING
	customprint(output, "    Output", 32);
	if (check_correctness(output, tc4_expected_tag, 4) != 1) xil_printf("    tc4 test for SNOWV-GCM correct!\n\r\n\r");
	else xil_printf("    tc4 test for SNOWV-GCM incorrect :(\n\r\n\r");

	// tc6 test
	xil_printf("Test tc6...\n\r");
  snowv_gcm_HW_init(tc6_init);
  snowv_gcm_HW_next(tc6_block0, output);
  customprint(output, "    Output", 32);
	if (check_correctness(output + 4, tc6_expected_block0, 4) != 1) xil_printf("    tc6 test: first block for SNOWV-GCM correct!\n\r\n\r");
	else xil_printf("    tc6 test: first block for SNOWV-GCM incorrect :(\n\r\n\r");

  snowv_gcm_HW_next(tc6_block1, output);
  customprint(output, "    Output", 32);
  if (check_correctness(output + 4, tc6_expected_block1, 4) != 1) xil_printf("    tc6 test: second block for SNOWV-GCM correct!\n\r\n\r");
  else xil_printf("    tc6 test: second block for SNOWV-GCM incorrect :(\n\r\n\r");

  snowv_gcm_HW_next(tc6_block2, output);
  customprint(output, "    Output", 32);
  if (check_correctness(output + 4, tc6_expected_block2, 4) != 1) xil_printf("    tc6 test: third block for SNOWV-GCM correct!\n\r\n\r");
  else xil_printf("    tc6 test: third block for SNOWV-GCM incorrect :(\n\r\n\r");

  snowv_gcm_HW_finalize(output);
	customprint(output, "    Output", 32);
	if (check_correctness(output, tc6_expected_tag, 4) != 1) xil_printf("    tc6 test: tag for SNOWV-GCM correct!\n\r\n\r");
	else xil_printf("    tc6 test: tag for SNOWV-GCM incorrect :(\n\r\n\r");

	xil_printf("----------- End SNOWV-GCM test -----------\n\r");

	cleanup_platform();

	return 0;
}
