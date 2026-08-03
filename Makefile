ASM := nasm

SRC := src/boot.asm
BIN := build/boot.img

all: $(BIN)

$(BIN): $(SRC)
	$(ASM) -f bin $(SRC) -o $(BIN)

clean:
	rm -rf $(OBJ) $(BIN)

.PHONY: all run clean