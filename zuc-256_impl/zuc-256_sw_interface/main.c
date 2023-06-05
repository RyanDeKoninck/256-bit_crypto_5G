#include "common.h"

#include "hw_accelerator.h"

// These variables are defined in the testvector.c
// that is created by the testvector generator python script
extern uint32_t ctr0[32],
                ctr0_expected,
                ctr1[32],
                ctr1_expected,
                ctr2[32],
                ctr2_expected,
                ctr3[32],
                ctr3_expected,
                mac0[32],
                mac1[32],
                mac_expected[4];

uint32_t output[32];

int main()
{
	init_platform();
	init_performance_counters(1);

	xil_printf("----------- Begin ZUC-256 TOT test: -----------\n\r");

	init_HW_access();
	xil_printf("HW initialization successful!\n\r\n\r");

	// -- Test encryption
	xil_printf("Test encryption...\n\r");
	zuc256_tot_HW_init(ctr0);

  // Word 0
  zuc256_tot_HW_next(ctr0, output);
  customprint(output, "    Output", 32);
  if (check_correctness(output, &ctr0_expected, 1) != 1) xil_printf("    encryption test: first block for ZUC-256 TOT correct!\n\r\n\r");
  else xil_printf("    encryption test: first block for ZUC-256 TOT incorrect :(\n\r\n\r");
  // Word 1
  zuc256_tot_HW_next(ctr1, output);
  customprint(output, "    Output", 32);
  if (check_correctness(output, &ctr1_expected, 1) != 1) xil_printf("    encryption test: second block for ZUC-256 TOT correct!\n\r\n\r");
  else xil_printf("    encryption test: second block for ZUC-256 TOT incorrect :(\n\r\n\r");
  // Word 2
  zuc256_tot_HW_next(ctr2, output);
  customprint(output, "    Output", 32);
  if (check_correctness(output, &ctr2_expected, 1) != 1) xil_printf("    encryption test: third block for ZUC-256 TOT correct!\n\r\n\r");
  else xil_printf("    encryption test: third block for ZUC-256 TOT incorrect :(\n\r\n\r");
  // Word 3
  zuc256_tot_HW_next(ctr3, output);
  customprint(output, "    Output", 32);
  if (check_correctness(output, &ctr3_expected, 1) != 1) xil_printf("    encryption test: fourth block for ZUC-256 TOT correct!\n\r\n\r");
  else xil_printf("    encryption test: fourth block for ZUC-256 TOT incorrect :(\n\r\n\r");


	// tc6 test
	xil_printf("Test MAC...\n\r");
  zuc256_tot_HW_init(mac0);
  for (int i = 0; i < 31; i++)
    zuc256_tot_HW_next(mac0, output);
  zuc256_tot_HW_next(mac1, output);
  zuc256_tot_HW_finalize(output);
  customprint(output, "    Output", 32);
	if (check_correctness(output, mac_expected, 4) != 1) xil_printf("    MAC test: tag for ZUC-256 TOT correct!\n\r\n\r");
	else xil_printf("    MAC test: tag for ZUC-256 TOT incorrect :(\n\r\n\r");

	xil_printf("----------- End ZUC-256 TOT test -----------\n\r");

	cleanup_platform();

	return 0;
}
