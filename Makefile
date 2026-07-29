ASM := nasm
QEMU := qemu-system-x86-64

SRC := src/boot.asm
BIN := build/boot.bin

all: $(BIN)

$(BIN): $(SRC)
	$(ASM) -f bin $(SRC) -o $(BIN)

run: $(BIN)
	$(QEMU) -drive format=raw,file=$(BIN)

clean:
	rm -rf $(OBJ) $(BIN)

.PHONY: all run clean