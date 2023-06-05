nist_aes128_key1 = "2b7e151628aed2a6abf7158809cf4f3c00000000000000000000000000000000"
nist_aes256_key1 = "603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4"

nist_counters = ["f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff",
                 "f0f1f2f3f4f5f6f7f8f9fafbfcfdff00",
                 "f0f1f2f3f4f5f6f7f8f9fafbfcfdff01",
                 "f0f1f2f3f4f5f6f7f8f9fafbfcfdff02"]

nist_plaintexts = ["6bc1bee22e409f96e93d7e117393172a",
                   "ae2d8a571e03ac9c9eb76fac45af8e51",
                   "30c81c46a35ce411e5fbc1191a0a52ef",
                   "f69f2445df4f9b17ad2b417be66c3710"]

nist_ctr_256_enc_expected = ["601ec313775789a5b7a7f504bbf3d228",
                             "f443e3ca4d62b59aca84e990cacaf5c5", 
                             "2b0930daa23de94ce87017ba2d84988d",
                             "dfc9c58db67aada613c2dd08457941a6"]

nist_ctr_128_enc_expected = ["874d6191b620e3261bef6864990db6ce",
                             "9806f66b7970fdff8617187bb9fffdff",
                             "5ae4df3edbd5d35e5b4f09020db03eab",
                             "1e031dda2fbe03d1792170a0f3009cee"]

def to_bin(hex, num_bits):
    return bin(int(hex, 16))[2:].zfill(num_bits)

def complete_bin(counter, key, key_length, block_i):
    return "0".zfill(511) + to_bin(counter, 128) + to_bin(key, 256) + to_bin(key_length, 1) + to_bin(block_i, 128)

def convert_string(to_convert):
    length = len(to_convert)
    end = length
    result = ""
    for i in range(length//8):
        result += "0x" + to_convert[end-8:end]
        result += ", "
        end -= 8
    return result[:len(result)-2]

def converted_hex_str(counter, key, key_length, block_i):
    return convert_string(hex(int(complete_bin(counter, key, key_length, block_i), 2))[2:].zfill(256))

print("// Test inputs (128 bit)")
for i in range(2):
    print(f"uint32_t nist_ctr_128_enc_in{i}[32] = {{ {converted_hex_str(nist_counters[i], nist_aes128_key1, '0', nist_plaintexts[i])} }};")
print("")
print("// Test inputs (256 bit)")
for i in range(2):
    print(f"uint32_t nist_ctr_256_enc_in{i}[32] = {{ {converted_hex_str(nist_counters[i], nist_aes256_key1, '1', nist_plaintexts[i])} }};")
print("")
print("// NIST ciphertexts (128 bit)")
for i in range(2):
    print(f"uint32_t nist_ctr_128_enc_expected{i}[4] = {{ {convert_string(nist_ctr_128_enc_expected[i])} }};")
print("")
print("// NIST ciphertexts (256 bit)")
for i in range(2):
    print(f"uint32_t nist_ctr_256_enc_expected{i}[4] = {{ {convert_string(nist_ctr_256_enc_expected[i])} }};")




