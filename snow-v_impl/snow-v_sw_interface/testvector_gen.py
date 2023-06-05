# tc4 test based on https://eprint.iacr.org/2018/1143.pdf
tc4_encdec_only = "0"
tc4_auth_only = "0"
tc4_encdec = "0"
tc4_adj_len = []
tc4_key = "faeadacabaaa9a8a7a6a5a4a3a2a1a0a5f5e5d5c5b5a59585756555453525150"
tc4_iv = "1032547698badcfeefcdab8967452301"
tc4_ad = "66656463626139383736353433323130"
tc4_ad_len = "80"
tc4_blocks = []
tc4_blocks_size = "0"
tc4_expected_blocks = []
tc4_expected_tag = "1abbdc5ab608df7a082c027ad7c80e25"

# tc6 test based on https://eprint.iacr.org/2018/1143.pdf
tc6_encdec_only = "0"
tc6_auth_only = "0"
tc6_encdec = "1"
tc6_adj_len = ["0", "0", "1"]
tc6_key = "faeadacabaaa9a8a7a6a5a4a3a2a1a0a5f5e5d5c5b5a59585756555453525150"
tc6_iv = "1032547698badcfeefcdab8967452301"
tc6_ad = "2165756c6176207473657420444141"
tc6_ad_len = "78"
tc6_blocks = ["66656463626139383736353433323130", "65646f6d20444145412d56776f6e5320", "21".zfill(32)]
tc6_blocks_size = "108"
tc6_expected_blocks = ["c1327ae807275082efa224b4b2017edd", "1be95956a1b53e24127ffd1818d0b052", "4c".zfill(32)]
tc6_expected_tag = "9b02eed99a3e7c74de513ab7a5a67e90"

def to_bin(hex, num_bits):
    return bin(int(hex, 16))[2:].zfill(num_bits)

def complete_bin(encdec_only, auth_only, encdec, adj_len, key, iv, ad, ad_len, block, blocks_size):
    return "0".zfill(252) + to_bin(encdec_only, 1) + to_bin(auth_only, 1) + to_bin(encdec, 1) + to_bin(adj_len, 1) \
           + to_bin(key, 256) + to_bin(iv, 128) + to_bin(ad, 128) + to_bin(ad_len, 64) + to_bin(block, 128) + to_bin(blocks_size, 64)

def convert_string(to_convert):
    length = len(to_convert)
    end = length
    result = ""
    for i in range(length//8):
        result += "0x" + to_convert[end-8:end]
        result += ", "
        end -= 8
    return result[:len(result)-2]

def converted_hex_str(encdec_only, auth_only, encdec, adj_len, key, iv, ad, ad_len, block, blocks_size):
    return convert_string(hex(int(complete_bin(encdec_only, auth_only, encdec, adj_len, key, iv, ad, ad_len, block, blocks_size), 2))[2:].zfill(256))

def print_test(name_test, encdec_only, auth_only, encdec, adj_len, key, iv, ad, ad_len, blocks, blocks_size, expected_blocks, expected_tag):
    print(f"uint32_t {name_test}_init[32] = {{ {converted_hex_str(encdec_only, auth_only, encdec, '0', key, iv, ad, ad_len, '0'.zfill(32), blocks_size)} }};")
    for i in range(len(blocks)):
        print(f"uint32_t {name_test}_block{i}[32] = {{ {converted_hex_str(encdec_only, auth_only, encdec, adj_len[i], key, iv, ad, ad_len, blocks[i], blocks_size)} }};")
        print(f"uint32_t {name_test}_expected_block{i}[4] = {{ {convert_string(expected_blocks[i])} }};")
    print(f"uint32_t {name_test}_expected_tag[4] = {{ {convert_string(expected_tag)} }};")

print("// Test tc4")
print_test("tc4", tc4_encdec_only, tc4_auth_only, tc4_encdec, tc4_adj_len, tc4_key, tc4_iv, tc4_ad, tc4_ad_len, tc4_blocks, tc4_blocks_size, tc4_expected_blocks, tc4_expected_tag)
print("")
print("// Test tc6")
print_test("tc6", tc6_encdec_only, tc6_auth_only, tc6_encdec, tc6_adj_len, tc6_key, tc6_iv, tc6_ad, tc6_ad_len, tc6_blocks, tc6_blocks_size, tc6_expected_blocks, tc6_expected_tag)
print("")
