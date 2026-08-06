# commands
ASM := nasm
CAT := cat
CC := x86_64-elf-gcc
LD := x86_64-elf-ld
TRUN := truncate

# flags
CDFLAGS := -ffreestanding -mno-red-zone -m64 -c
LDFLAGS := -nmagic -T linker/linker.ld --oformat binary

# how many 512 byte sectors stage 1 pulls off the disk for stage 2 + the kernel
STAGE2_SECTORS := 32
STAGE2_BYTES := $(shell expr $(STAGE2_SECTORS) \* 512)

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
# -D hands STAGE2_SECTORS to nasm so the dap loads exactly as many sectors as we pad
$(BIN1): $(ST1) Makefile | build
	$(ASM) -f bin -i $(INCDIR) -DSTAGE2_SECTORS=$(STAGE2_SECTORS) $(ST1) -o $(BIN1)

# compiling stage 2 into elf64 object file so we can merge it with the c kernel later
$(OBJ2): $(ST2) | build
	$(ASM) -f elf64 -i $(INCDIR) $(ST2) -o $(OBJ2)

# compile the c kernel into an elf64 object file
$(OBJ_KC): $(KERN_C) | build
	$(CC) $(CDFLAGS) $(KERN_C) -o $(OBJ_KC)

# linking stage 2 and the kernel together
$(BIN2): $(OBJ2) $(OBJ_KC) $(LINKER) | build
	$(LD) $(LDFLAGS) $(OBJ2) $(OBJ_KC) -o $(BIN2)

# combining both stages into an img file
# first we make sure stage 2 + the kernel still fit in the sectors stage 1 loads
# if they dont we stop right here instead of booting into a triple fault
$(IMG): $(BIN1) $(BIN2) Makefile
	@size=$$(stat -c %s $(BIN2)); \
	if [ $$size -gt $(STAGE2_BYTES) ]; then \
		echo "ERROR: $(BIN2) is $$size bytes but stage 1 only loads $(STAGE2_BYTES)"; \
		echo "       bump STAGE2_SECTORS in the Makefile"; \
		exit 1; \
	fi
	$(CAT) $(BIN1) $(BIN2) > $(IMG)
	$(TRUN) -s $$((512 + $(STAGE2_BYTES))) $(IMG)

build:
	mkdir -p build

clean:
	rm -rf build

.PHONY: all clean