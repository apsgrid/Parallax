from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler

ROOT = Path(r"E:\Projects\Parallax")
RAM = ROOT / "Unpacked" / "playable_ram.bin"
mem = bytearray(RAM.read_bytes())

mpu = MPU()
mpu.memory[:] = mem
dis = Disassembler(mpu)


def dump(start: int, end: int) -> None:
    print(f"\n=== {start:04X}-{end:04X} ===")
    pc = start
    while pc < end:
        length, text = dis.instruction_at(pc)
        raw = " ".join(f"{mem[pc+i]:02X}" for i in range(length))
        print(f"{pc:04X}: {raw:<9} {text}")
        pc += length


def decode_e589_records(start: int = 0x4980, end: int = 0x4A80) -> None:
    print("\n=== SHIP SUPPLY SCREEN RECORDS ===")
    p = start
    record = 0
    while p < end:
        x = mem[p]
        if x == 0xFF:
            print(f"{p:04X}: END")
            break
        y = mem[p + 1]
        color = mem[p + 2]
        record_start = p
        p += 3
        chars = []
        while p < end and mem[p] != 0xFF:
            chars.append(mem[p])
            p += 1
        p += 1
        text = "".join(chr(c) if 32 <= c < 127 else f"<{c:02X}>" for c in chars)
        print(f"{record:02d} @{record_start:04X}: x={x:02d} y={y:02d} color={color:02X} {text}")
        record += 1


def init_cf_table() -> None:
    print("\n=== INITIAL CF STATE TABLE ($2113) ===")
    p = 0x2113
    for i in range(15):
        index = mem[p + i * 2]
        value = mem[p + i * 2 + 1]
        print(f"CF{index:02X} = {value:02X} ({value})")


def supply_transfer_tables() -> None:
    print("\n=== SUPPLY TRANSFER TABLES ===")
    print("ship-side indices E70B:", [f"{x:02X}" for x in mem[0xE70B:0xE710]])
    print("take-away indices E710:", [f"{x:02X}" for x in mem[0xE710:0xE715]])


def cursor_positions() -> None:
    print("\n=== SUPPLY CURSOR POSITION TABLE ($F4C9) ===")
    base = 0xF4C9
    for selection in range(1, 9):
        off = selection * 10
        pairs = [
            (mem[base + off + i], mem[base + off + i + 1])
            for i in range(0, 10, 2)
        ]
        print(selection, " ".join(f"({x:02X},{y:02X})" for x, y in pairs))


def message_record(address: int, label: str) -> None:
    data = bytes(mem[address:address + 34])
    text = "".join(chr(c) if 32 <= c < 127 else " " for c in data)
    print(f"{address:04X} {label}: {text.rstrip()}")


if __name__ == "__main__":
    print("source:", RAM)
    dump(0xE064, 0xE0B0)
    dump(0xE3CF, 0xE43B)
    dump(0xE60D, 0xE7A6)
    decode_e589_records()
    init_cf_table()
    supply_transfer_tables()
    cursor_positions()

    print("\n=== STATUS MESSAGE RECORDS ===")
    message_record(0x6E0C, "scientist-refuses")
    message_record(0x6F40, "need-oxygen")
    message_record(0x4D40, "no-scientist")
    message_record(0x4940, "drugging-scientist")
