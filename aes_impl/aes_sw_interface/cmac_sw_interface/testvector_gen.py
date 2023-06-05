# tc3 test based on NIST spec, RFC 4493 (https://www.rfc-editor.org/rfc/rfc4493#appendix-A)
tc3_key = "2b7e151628aed2a6abf7158809cf4f3c00000000000000000000000000000000"
tc3_keylen = "0"

tc3_blocks = ["00000000000000000000000000000000"]
tc3_final_sizes = ["00"]
tc3_finalize = ["1"]
tc3_expected = "bb1d6929e95937287fa37d129b756746"

# tc5 test based on NIST spec, RFC 4493 (https://www.rfc-editor.org/rfc/rfc4493#appendix-A)
tc5_key = "2b7e151628aed2a6abf7158809cf4f3c00000000000000000000000000000000"
tc5_keylen = "0"

tc5_blocks = ["6bc1bee22e409f96e93d7e117393172a", "ae2d8a571e03ac9c9eb76fac45af8e51", "30c81c46a35ce4110000000000000000"]
tc5_final_sizes = ["00", "00", "40"]
tc5_finalize = ["0", "0", "1"]
tc5_expected = "dfa66747de9ae63030ca32611497c827"

# tc7 test based on NIST spec (https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/AES_CMAC.pdf)
tc7_key = "603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4"
tc7_keylen = "1"

tc7_blocks = ["6bc1bee22e409f96e93d7e117393172a", "ae2d8a571e03ac9c9eb76fac45af8e51", "30c81c46a35ce411e5fbc1191a0a52ef", "f69f2445df4f9b17ad2b417be66c3710"]
tc7_final_sizes = ["00", "00", "00", "80"]
tc7_finalize = ["0", "0", "0", "1"]
tc7_expected = "e1992190549f6ed5696a2c056c315410"

def to_bin(hex, num_bits):
    return bin(int(hex, 16))[2:].zfill(num_bits)

def complete_bin_key(key, key_length):
    return "0".zfill(767) + to_bin(key_length, 1) + to_bin(key, 256)

def complete_bin_block(finalize, final_size, block_i):
    return "0".zfill(887) + to_bin(finalize, 1) + to_bin(final_size, 8) + to_bin(block_i, 128)

def convert_string(to_convert):
    length = len(to_convert)
    end = length
    result = ""
    for i in range(length//8):
        result += "0x" + to_convert[end-8:end]
        result += ", "
        end -= 8
    return result[:len(result)-2]

def converted_hex_str_key(key, key_length):
    return convert_string(hex(int(complete_bin_key(key, key_length), 2))[2:].zfill(256))

def converted_hex_str_block(finalize, final_size, block_i):
    return convert_string(hex(int(complete_bin_block(finalize, final_size, block_i), 2))[2:].zfill(256))

def print_test(name_test, key, keylen, blocks, finalize, final_sizes, expected):
    print(f"uint32_t {name_test}_key[32] = {{ {converted_hex_str_key(key, keylen)} }};")
    for i in range(len(blocks)):
        print(f"uint32_t {name_test}_block{i}[32] = {{ {converted_hex_str_block(finalize[i], final_sizes[i], blocks[i])} }};")
    print(f"uint32_t {name_test}_expected[4] = {{ {convert_string(expected)} }};")

print("// Test tc3")
print_test("tc3", tc3_key, tc3_keylen, tc3_blocks, tc3_finalize, tc3_final_sizes, tc3_expected)
print("")
print("// Test tc5")
print_test("tc5", tc5_key, tc5_keylen, tc5_blocks, tc5_finalize, tc5_final_sizes, tc5_expected)
print("")
print("// Test tc7")
print_test("tc7", tc7_key, tc7_keylen, tc7_blocks, tc7_finalize, tc7_final_sizes, tc7_expected)
print("")
