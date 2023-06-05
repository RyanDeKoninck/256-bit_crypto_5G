# encryption test based on http://www.is.cas.cn/ztzl2016/zouchongzhi/201801/W020230201389233346416.pdf
ctr_enc_auth = "0"
ctr_key = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
ctr_iv = "ffffffffffffffffffffffffffffffff"
ctr_blocks = ["01020304".zfill(32), "05060708".zfill(32), "090a0b0c".zfill(32), "0d0e0f00".zfill(32)]
ctr_i_len = "00"
ctr_tag_len = "00"
ctr_expected_blocks = ["3887e1ab", "3035d321", "3a8f8bfc", "edd603e9"]

# MAC test based on http://www.is.cas.cn/ztzl2016/zouchongzhi/201801/W020230201389233346416.pdf
mac_enc_auth = "1"
mac_key = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
mac_iv = "ffffffffffffffffffffffffffffffff"
mac_blocks = ["11111111111111111111111111111111", "11111111000000000000000000000000"]
mac_i_len = "20"
mac_tag_len = "80"
mac_expected_tag = "dd3a4017357803a51c3fb9a57a96feda"

def to_bin(hex, num_bits):
    return bin(int(hex, 16))[2:].zfill(num_bits)

def complete_bin(enc_auth, key, iv, block, i_len, tag_len):
    return "0".zfill(495) + to_bin(enc_auth, 1) \
           + to_bin(key, 256) + to_bin(iv, 128) + to_bin(block, 128) + to_bin(i_len, 8) + to_bin(tag_len, 8)

def convert_string(to_convert):
    length = len(to_convert)
    end = length
    result = ""
    for i in range(length//8):
        result += "0x" + to_convert[end-8:end]
        result += ", "
        end -= 8
    return result[:len(result)-2]

def converted_hex_str(enc_auth, key, iv, block, i_len, tag_len):
    return convert_string(hex(int(complete_bin(enc_auth,key, iv, block, i_len, tag_len), 2))[2:].zfill(256))

print("// Test encryption")
for i in range(len(ctr_blocks)):
    print(f"uint32_t ctr{i}[32] = {{ {converted_hex_str(ctr_enc_auth, ctr_key, ctr_iv, ctr_blocks[i], ctr_i_len, ctr_tag_len)} }};")
    print(f"uint32_t ctr{i}_expected = {convert_string(ctr_expected_blocks[i])};")

print("// Test MAC")
for i in range(len(mac_blocks)):
    print(f"uint32_t mac{i}[32] = {{ {converted_hex_str(mac_enc_auth, mac_key, mac_iv, mac_blocks[i], mac_i_len, mac_tag_len)} }};")
print(f"uint32_t mac_expected[4] = {{ {convert_string(mac_expected_tag)} }};")
print("")
