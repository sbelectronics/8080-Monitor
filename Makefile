ZASM="../rc2014/z80-asm/zasm-4.0/Linux/zasm" 

all: 8080.rom

8080.hex: 8080.asm
	$(ZASM) -u -x --8080 --asm8080 8080.asm

8080.rom: 8080.asm
	$(ZASM) -u -b --8080 --asm8080 8080.asm
	dd if=8080.rom of=00-8080.rom0 bs=1 count=8192
	# there is no second ROM...
	#dd if=8080.rom of=01-8080.rom1 bs=1 skip=8192

clean:
	rm -f 8080.hex *8080.rom*

