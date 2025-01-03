ZASM="../rc2014/z80-asm/zasm-4.0/Linux/zasm"

# for building nascom basic
ZCC = ../z88dk/bin/zcc
export PATH := $(PATH):../z88dk/bin

all: 8080.rom basic.rom forth.rom

8080.hex: 8080.asm
	$(ZASM) -u -x --8080 --asm8080 8080.asm

8080.rom: 8080.asm
	$(ZASM) -u -b --8080 --asm8080 8080.asm
	dd if=8080.rom of=00-8080.rom bs=1 count=8192

basic.rom: nascom32k.asm
	echo "nascom32k.asm" > nascom32k.lst
	$(ZCC) +micro8085 -m8085 --no-crt -v -m --list -Ca-f0xFF @nascom32k.lst -o basic.rom
	cp basic.rom 01-basic.rom

forth.rom: forth.asm
	$(ZASM) -u -b --8080 --asm8080 forth.asm
	cp forth.rom 02-forth.rom

clean:
	rm -f 8080.hex *.rom

