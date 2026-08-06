ENTRY(kernel_main)
OUTPUT_FORMAT("binary")

SECTIONS
{
    . = 0x8000;

    .text : {
        *(.text)
    }
    .rodata : {
        *(.rodata)
    }
    .data : {
        *(.data)
    }
    .bss : {
        *(.bss)
    }
}