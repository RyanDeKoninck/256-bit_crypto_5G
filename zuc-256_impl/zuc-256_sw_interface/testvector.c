#include <stdint.h>

// This file's content is created by the testvector generator Python script,
// which uses the test vectors from http://www.is.cas.cn/ztzl2016/zouchongzhi/201801/W020230201389233346416.pdf

// Test encryption
uint32_t ctr0[32] = { 0x03040000, 0x00000102, 0x00000000, 0x00000000, 0xffff0000, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x0000ffff, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 };
uint32_t ctr0_expected = 0x3887e1ab;
uint32_t ctr1[32] = { 0x07080000, 0x00000506, 0x00000000, 0x00000000, 0xffff0000, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x0000ffff, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 };
uint32_t ctr1_expected = 0x3035d321;
uint32_t ctr2[32] = { 0x0b0c0000, 0x0000090a, 0x00000000, 0x00000000, 0xffff0000, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x0000ffff, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 };
uint32_t ctr2_expected = 0x3a8f8bfc;
uint32_t ctr3[32] = { 0x0f000000, 0x00000d0e, 0x00000000, 0x00000000, 0xffff0000, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x0000ffff, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 };
uint32_t ctr3_expected = 0xedd603e9;
// Test MAC
uint32_t mac0[32] = { 0x11112080, 0x11111111, 0x11111111, 0x11111111, 0xffff1111, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x0001ffff, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 };
uint32_t mac1[32] = { 0x00002080, 0x00000000, 0x00000000, 0x11110000, 0xffff1111, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0x0001ffff, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000 };
uint32_t mac_expected[4] = { 0x7a96feda, 0x1c3fb9a5, 0x357803a5, 0xdd3a4017 };