import numpy as np

# Number of entries
NUM_ENTRIES = 128

# Empty lists
log2_lut = []
exp2_lut = []

for i in range(NUM_ENTRIES):
    m = i / NUM_ENTRIES  # Step: 1/128
    log2_val = np.log2(1.0 + m)
    exp2_val = 2 ** m

    # 轉為 IEEE 754 float16 的 hex string
    log2_hex = np.float16(log2_val).view(np.uint16)
    exp2_hex = np.float16(exp2_val).view(np.uint16)

    log2_lut.append(f"{log2_hex:04x}")
    exp2_lut.append(f"{exp2_hex:04x}")

# 儲存檔案
with open("log2_lut_128.txt", "w") as f:
    f.write("\n".join(log2_lut))

with open("exp2_lut_128.txt", "w") as f:
    f.write("\n".join(exp2_lut))
