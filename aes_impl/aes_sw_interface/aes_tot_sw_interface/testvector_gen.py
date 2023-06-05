# encryption test
ctr_enc_auth = "0"
ctr_counter = "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff"
ctr_key = "603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4"
ctr_keylen = "1"
ctr_final_sizes = ["00", "40"]
ctr_blocks = ["6bc1bee22e409f96e93d7e117393172a", "9eb76fac45af8e51".zfill(32)]
ctr_expected_blocks = ["601ec313775789a5b7a7f504bbf3d228", "ca84e990cacaf5c5".zfill(32)]

# MAC test
mac_enc_auth = "1"
mac_counter = "0".zfill(32)
mac_key = "2b7e151628aed2a6abf7158809cf4f3c00000000000000000000000000000000"
mac_keylen = "0"
mac_final_sizes = ["00", "00", "40"]
mac_blocks = ["6bc1bee22e409f96e93d7e117393172a", "ae2d8a571e03ac9c9eb76fac45af8e51", "30c81c46a35ce4110000000000000000"]
mac_expected = "dfa66747de9ae63030ca32611497c827"

def to_bin(hex, num_bits):
    return bin(int(hex, 16))[2:].zfill(num_bits)

def complete_bin(enc_auth, counter, key, keylen, final_size, block):
    return "0".zfill(502) + to_bin(enc_auth, 1) + to_bin(counter, 128) \
           + to_bin(key, 256) + to_bin(keylen, 1) + to_bin(final_size, 8) + to_bin(block, 128)

def convert_string(to_convert):
    length = len(to_convert)
    end = length
    result = ""
    for i in range(length//8):
        result += "0x" + to_convert[end-8:end]
        result += ", "
        end -= 8
    return result[:len(result)-2]

def converted_hex_str(enc_auth, counter, key, keylen, final_size, block):
    return convert_string(hex(int(complete_bin(enc_auth, counter, key, keylen, final_size, block), 2))[2:].zfill(256))

print("// Test encryption")
for i in range(len(ctr_blocks)):
    print(f"uint32_t ctr{i}[32] = {{ {converted_hex_str(ctr_enc_auth, ctr_counter, ctr_key, ctr_keylen, ctr_final_sizes[i], ctr_blocks[i])} }};")
    print(f"uint32_t ctr{i}_expected[4] = {{ {convert_string(ctr_expected_blocks[i])} }};")

print("// Test MAC")
for i in range(len(mac_blocks)):
    print(f"uint32_t mac_block{i}[32] = {{ {converted_hex_str(mac_enc_auth, mac_counter, mac_key, mac_keylen, mac_final_sizes[i], mac_blocks[i])} }};")
print(f"uint32_t mac_expected[4] = {{ {convert_string(mac_expected)} }};")
print("")
