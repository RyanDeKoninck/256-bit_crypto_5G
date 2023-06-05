#include "common.h"

#include "hw_accelerator.h"

// These variables are defined in the testvector.c
// that is created by the testvector generator python script
extern uint32_t ctr0[32],
                ctr0_expected[4],
                ctr1[32],
                ctr1_expected[4],
                mac_block0[32],
                mac_block1[32],
                mac_block2[32],
                mac_expected[4];

uint32_t output[32];

int main()
{
	init_platform();
	init_performance_counters(1);

	xil_printf("----------- Begin AES TOT test: -----------\n\r");

	init_HW_access();
	xil_printf("HW initialization successful!\n\r\n\r");

	// -- Test encryption
	xil_printf("Test encryption...\n\r");
  aes_tot_HW_init(ctr0);
	aes_tot_HW_next(ctr0, output);
  customprint(output, "    Output", 32);
  if (check_correctness(output, ctr0_expected, 4) != 1) xil_printf("    encryption test: AES encryption block 0 correct!\n\r\n\r");
  else xil_printf("    encryption test: AES encryption block 0 incorrect :(\n\r\n\r");
  aes_tot_HW_finalize(ctr1, output);
  customprint(output, "    Output", 32);
  if (check_correctness(output, ctr1_expected, 4) != 1) xil_printf("    encryption test: AES encryption block 1 correct!\n\r\n\r");
  else xil_printf("    encryption test: AES encryption block 1 incorrect :(\n\r\n\r");


	// -- Test CMAC
	xil_printf("Test MAC...\n\r");
  aes_tot_HW_init(mac_block0);
  aes_tot_HW_next(mac_block0, output);
  aes_tot_HW_next(mac_block1, output);
  aes_tot_HW_finalize(mac_block2, output);
  customprint(output, "    Output", 32);
	if (check_correctness(output, mac_expected, 4) != 1) xil_printf("    MAC test: tag for AES TOT correct!\n\r\n\r");
	else xil_printf("    MAC test: tag for AES TOT incorrect :(\n\r\n\r");

	xil_printf("----------- End AES TOT test -----------\n\r");

	cleanup_platform();

	return 0;
}
