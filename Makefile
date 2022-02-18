FILE = game

all:
	riscv64-unknown-elf-as $(FILE).S -g -march=rv32im -mabi=ilp32 -o $(FILE).elf
	riscv64-unknown-elf-ld -T qemu-riscv32-virt.ld -o $(FILE).linked.elf $(FILE).elf

run:
	qemu-system-riscv32 -machine virt -kernel $(FILE).linked.elf -nographic -bios none

