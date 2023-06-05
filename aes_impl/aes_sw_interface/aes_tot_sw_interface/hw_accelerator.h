#ifndef _HW_ACCEL_H_
#define _HW_ACCEL_H_

void init_HW_access(void);
void customprint(uint32_t *large_number, char *str, int size);
int check_correctness(uint32_t *expected, uint32_t *calculated, int size);
void aes_tot_HW_init(uint32_t *input);
void aes_tot_HW_next(uint32_t *input, uint32_t *output);
void aes_tot_HW_finalize(uint32_t *input, uint32_t *output);

#endif
