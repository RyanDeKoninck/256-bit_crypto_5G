#include "common.h"

#include "hw_accelerator.h"

// These variables are defined in the testvector.c
// that is created by the testvector generator python script
extern uint32_t nist_ctr_128_enc_in0[32],
                nist_ctr_128_enc_expected0[4],
                nist_ctr_128_enc_in1[32],
                nist_ctr_128_enc_expected1[4],
                nist_ctr_256_enc_in0[32],
                nist_ctr_256_enc_expected0[4],
                nist_ctr_256_enc_in1[32],
                nist_ctr_256_enc_expected1[4];

uint32_t output[32];

int main()
{
	init_platform();
	init_performance_counters(1);

	xil_printf("----------- Begin CTR-mode test: -----------\n\r");

	init_HW_access();
	xil_printf("HW initialization successful!\n\r\n\r");

	// First 128 bit test
	xil_printf("First 128 bit test...\n\r");
START_TIMING
	ctr_HW(nist_ctr_128_enc_in0, output);
STOP_TIMING
	customprint(output, "    Output", 32);
	if (check_correctness(output, nist_ctr_128_enc_expected0, 4) != 1) xil_printf("    First 128 bit test for CTR-mode correct!\n\r\n\r");
	else xil_printf("    First 128 bit test for CTR-mode incorrect :(\n\r\n\r");

	// Second 128 bit test
	xil_printf("Second 128 bit test...\n\r");
START_TIMING
	ctr_HW(nist_ctr_128_enc_in1, output);
STOP_TIMING
	customprint(output, "    Output", 32);
	if (check_correctness(output, nist_ctr_128_enc_expected1, 4) != 1) xil_printf("    Second 128 bit test for CTR-mode correct!\n\r\n\r");
	else xil_printf("    Second 128 bit test for CTR-mode incorrect :(\n\r\n\r");

	// First 256 bit test
	xil_printf("First 256 bit test...\n\r");
START_TIMING
	ctr_HW(nist_ctr_256_enc_in0, output);
STOP_TIMING
	customprint(output, "    Output", 32);
	if (check_correctness(output, nist_ctr_256_enc_expected0, 4) != 1) xil_printf("    First 256 bit test for CTR-mode correct!\n\r\n\r");
	else xil_printf("    First 256 bit test for CTR-mode incorrect :(\n\r\n\r");

	// Second 256 bit test
	xil_printf("Second 256 bit test...\n\r");
START_TIMING
	ctr_HW(nist_ctr_256_enc_in1, output);
STOP_TIMING
	customprint(output, "    Output", 32);
	if (check_correctness(output, nist_ctr_256_enc_expected1, 4) != 1) xil_printf("    Second 256 bit test for CTR-mode correct!\n\r\n\r");
	else xil_printf("    Second 256 bit test for CTR-mode incorrect :(\n\r\n\r");

	xil_printf("----------- End CTR-mode test -----------\n\r");

	cleanup_platform();

	return 0;
}

