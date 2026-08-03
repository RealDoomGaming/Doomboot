ASM := nasm

SRC := src/boot.asm
BIN := build/boot.img

all: $(BIN)

$(BIN): $(SRC)
	$(ASM) -f bin $(SRC) -o $(BIN)

clean:
	mkdir -p ./build
	rm -rf $(BIN)

.PHONY: all clean