# commands
ASM := nasm
CAT := cat
CC := x86_64-elf-gcc
LD := x86_64-elf-ld

# flags
CDFLAGS := -ffreestanding -mno-red-zone -m64 -c
LDFLAGS := -nmagic -T src/linker.ld --oformat binary

# files
ST1  := src/stage1.asm
ST2  := src/stage2.asm
KERN_C := src/kernel.c
LINKER := linker/linker.ld

# targets
BIN1 := build/stage1.img
OBJ2 := build/stage2.o
OBJ_KC := build/kernel.o
BIN2 := build/stage2.img
IMG  := build/disk.img
INCDIR := src/

all: $(IMG)

# compiling stage 1
$(BIN1): $(ST1) | build
	$(ASM) -f bin -i $(INCDIR) $(ST1) -o $(BIN1)

# compiling stage 2 into elf64 object file so we can merge it with the c kernel later
$(OBJ2): $(ST2) | build
	$(ASM) -f elf64 -i $(INCDIR) $(ST2) -o $(OBJ2)

# compile the c kernel into an elf64 object file
$(OBJ_KC): $(KERN_C) | build
	$(CC) $(CDFLAGS) $(KERN_C) -o $(OBJ_KC)

# linking stage 2 and the kernel together
$(BIN2): $(OBJ2) $(OBJ_KC) $(LINKER) | build
	$(LD) $(LDFLAGS) $(OBJ2) $(OBJ_KC) -o (BIN2)

# combining both stages into an img file
$(IMG): $(BIN1) $(BIN2)
	$(CAT) $(BIN1) $(BIN2) > $(IMG)

build:
	mkdir -p build

clean:
	rm -rf build

.PHONY: all clean