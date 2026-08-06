void kernel_main() {
    // our vga output address so we can print something later
    volatile char* vga = (volatile char*)0xB8000;

    // while loop so the cpu doesnt run off into memory junk
    while (1) {
        __asm__ volatile("hlt");
    }
}