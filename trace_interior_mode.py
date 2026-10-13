from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes())
cpu=MPU(); cpu.memory[:]=m; d=Disassembler(cpu)

def dump(a,b):
 print('\n=== {:04X}-{:04X} ==='.format(a,b))
 pc=a
 while pc<b:
  ln,txt=d.instruction_at(pc)
  bs=' '.join('{:02X}'.format(m[pc+i]) for i in range(ln))
  print('{:04X}: {:<9} {}'.format(pc,bs,txt))
  pc+=ln

for a,b in [(0xE440,0xE4B8),(0xE321,0xE444),(0xE803,0xE8A0),(0xE821,0xE880),(0xE866,0xE920),(0xECD0,0xED40),(0x4D50,0x4DA0),(0xEBE0,0xEC80),(0xF020,0xF140)]:
 dump(a,b)

print('\n=== XREFS TO ZP $46 ===')
zpops={0xA5:'LDA',0x85:'STA',0xA6:'LDX',0x86:'STX',0xA4:'LDY',0x84:'STY',0xC5:'CMP',0xE6:'INC',0xC6:'DEC',0x05:'ORA',0x25:'AND',0x45:'EOR',0x65:'ADC',0xE5:'SBC'}
for a in range(0x0800,0xFFFF):
 op=m[a]
 if op in zpops and m[a+1]==0x46:
  print('{:04X}: {}'.format(a,zpops[op]))

print('\n=== WRITES/READS E442/E443 ===')
absops={0xAD:'LDA',0x8D:'STA',0xAE:'LDX',0x8E:'STX',0xAC:'LDY',0x8C:'STY',0xCD:'CMP',0xED:'SBC',0x6D:'ADC'}
for target in (0xE442,0xE443):
 print('target {:04X}'.format(target))
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in absops and (m[a+1]|m[a+2]<<8)==target:
   print('{:04X}: {}'.format(a,absops[op]))
