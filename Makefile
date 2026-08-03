ASM := nasm
CAT := cat

ST1  := src/stage1.asm
ST2  := src/stage2.asm
BIN1 := build/stage1.img
BIN2 := build/stage2.img
IMG  := build/disk.img

all: $(IMG)

$(BIN1): $(ST1) | build
	$(ASM) -f bin $(ST1) -o $(BIN1)

$(BIN2): $(ST2) | build
	$(ASM) -f bin $(ST2) -o $(BIN2)

$(IMG): $(BIN1) $(BIN2)
	$(CAT) $(BIN1) $(BIN2) > $(IMG)

build:
	mkdir -p build

clean:
	rm -rf build

.PHONY: all clean