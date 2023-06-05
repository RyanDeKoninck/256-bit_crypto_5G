#ifndef _HW_ACCEL_H_
#define _HW_ACCEL_H_

void init_HW_access(void);
void customprint(uint32_t *large_number, char *str, int size);
int check_correctness(uint32_t *expected, uint32_t *calculated, int size);
void snowv_gcm_HW_init(uint32_t *input);
void snowv_gcm_HW_next_ad(uint32_t *input);
void snowv_gcm_HW_next(uint32_t *input, uint32_t *output);
void snowv_gcm_HW_finalize(uint32_t *output);

#endif
