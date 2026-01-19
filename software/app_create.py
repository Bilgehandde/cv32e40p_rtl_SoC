# Bu script Basys 3'e gömülecek makine kodunu oluşturur (app.bin)
import struct

# RISC-V Makine Kodları (LED YAKMA - 0xAA)
# 1. lui a0, 0x10000
# 2. li a1, 0xAA
# 3. sw a1, 4(a0)
# 4. j .
instructions = [
    0x10000537,
    0x0aa00593,
    0x00b52223,
    0x0000006f
]

# Binary dosyayı yaz (Little Endian)
with open("app.bin", "wb") as f:
    for instr in instructions:
        f.write(struct.pack("<I", instr))

print("app.bin dosyasi olusturuldu! Vivado ile Flash'a gomebilirsin.")