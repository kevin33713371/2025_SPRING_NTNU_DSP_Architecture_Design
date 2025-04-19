import math, struct

# log2 LUT
with open('log2_lut_128_new.txt', 'w') as f:
    for i in range(128):
        m = (i << 3) / 1024.0                # 10‑bit mantissa前 7 bits
        val = int(round((math.log2(1+m)) * 1024))
        f.write(f"{val:03x}\n")              # 10 位元→3 字 hex
# exp2 LUT
def fp16(v):
    return struct.unpack(">H", struct.pack(">e", v))[0]
with open('exp2_lut_128_new.txt', 'w') as f:
    for i in range(128):
        frac = i / 128.0
        f.write(f"{fp16(2**frac):04x}\n")
