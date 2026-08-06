#include <stdint.h>

// we need to use the uint16_t* type here since for vga every character is stored as 16bit and not like normally as 8bit
#define VGA ((volatile uint16_t*) 0xB8000)
// width and height of the screen in characters
#define VGA_WIDTH 80
#define VGA_HEIGHT 25
// color
#define WHITE_ON_BLACK 0x0F

void print(const char msg[], const int msg_length, const int color) {
    for (int i = 0; i < msg_length; i++) {
        // here we combine the char and the color of the char into a 16 bit entry which we will use to clear the screen later
        uint16_t combined = msg[i] | (color << 8);
        VGA[i] = combined;
    } 
}

void clear_screen() {
    // here we combine the char and the color of the char into a 16 bit entry which we will use to clear the screen later
    uint16_t blank = ' ' | (WHITE_ON_BLACK << 8);

    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        VGA[i] = blank;
    }
}

void kernel_main() {
    // first thing we do is clear the screen of any leftover text
    clear_screen();

    // this is our success message string
    const char success_msg[] = "Successfully loaded the kernel. 13 10 0";
    const int succ_msg_length = 31;
    const int color = WHITE_ON_BLACK;

    print(success_msg, succ_msg_length, color);

    // while loop so the cpu doesnt run off into memory junk
    while (1) {
        __asm__ volatile("hlt");
    }
}