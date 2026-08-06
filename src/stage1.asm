[org 0x7c00] ;; tells nasm where the code is located in memory
[bits 16] ;; code runs in 16 bit mode for booting

;; we need this here for our dap later
STAGE2_SEGMENT  equ 0x0000      ;; this will be combined with the offset later so we can just leave it at 0
STAGE2_OFFSET   equ 0x8000      ;; where we will load our second stage
;; how many 512 byte sectors to load when we go into the second stage of our bootloader
;; the Makefile hands this in with -DSTAGE2_SECTORS=... because it also pads the disk
;; image to that exact size, if the two ever disagreed we would load too little and
;; jump into memory that was never read off the disk (that was the old triple fault)
;; the value below is only a fallback for when you assemble this file without make
%ifndef STAGE2_SECTORS
    %define STAGE2_SECTORS 32
%endif
STAGE2_LBA      equ 1           ;; this is where on the disk the second stage starts, sector 0 is always the boot sector and since stage 2 of our bootloader was written directly after our bootloader it has to be at sector 0

;; we need to jmp over the bios thingis
jmp start 

;; here we define our dap (Disk Address Packet)
align 4     ;; this we just do because its best practise, I have never seen it explained tho
dap:
    ;; we will make our package 16 bytes long
    ;; the future int 0x13 (triggers the bios disk service) wants one pointer and not a pile of registers so we need this
    ;; the first byte is the size of this package
    db 0x10
    ;; the second byte is reserved by the bios so we just put 0 here
    db 0
    ;; the next 2 bytes are for how many 512 byte sectors are gonna get loaded
    dw STAGE2_SECTORS
    ;; then the next 2 are for the offset where to put our memory
    dw STAGE2_OFFSET
    ;; then the next 2 bytes are for the segment, this will be combined with the offset to form the actual address of the memory
    dw STAGE2_SEGMENT
    ;; and the last 8 bytes are for which number the file we will load has on the disk
    dq STAGE2_LBA

boot_drive: db 0    

start:
    ;; if we want to boot into a kernel later we will need to do some stuff
    ;; first we need to enable the a20 line in order to access memory above 1MB
    ;; then we load into the second stage of the boothloader where we 
    ;; load a gdt (global descriptor table)
    ;; go into 32bit protected mode
    ;; and then go into 64 bit mode before loading a kernel

    ;; clear input flag -> disables hardware interrupts
    cli

    ;; we have to set up a stack else the bootloader might not even work
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov sp, 0x7c00  ;; why we set it to 0x7c00, because the stack grows downward into free memory

    mov [boot_drive], dl   ;; here we save dl (we need it for the disk) because only at the start we know its right and not some garbage 

    ;; enabeling the a 20 line
    ;; before we do that we need to test if the bios has already enabled it
    ;; jmp a20
    ;; we removes this jmp since we fall through to the a20 label anyways

;; when checking if a20 is on we can follow a specific plan:
;; checking if it is on -> if yes continue 
;; if it isnt on we try it with the BIOS function (int 0x15)
;; check if it is on again
;; if it still isnt on we can do the keyboard controller method
;; then when checking a20 again we do it in a loop with a time out since the keyboard method can take sometime
;; then lastly if it still didnt work we try the fast a20 method, also with a loop since the "fast" a20 can also take some time
;; and then if it still isnt on just give up
a20:
    call check_a20         ;; firstly we check if the a20 gate is enabled by default
    jne a20_enabled         ;; is enabled

    call enable_a20_bios     ;; we try to enable it with the bios method
    call check_a20           ;; check if it worked and is now
    jne a20_enabled           ;; if it is enabled jump

    call enable_a20_keyboard ;; try enabeling a20 with the keyboard controller
    call check_a20           ;; check it again
    jne a20_enabled           ;; is enabled now

    call enable_a20_fast    ;; try enabeling the a20 gate with the fast a20 method
    call check_a20          ;; checking if it worked
    jne a20_enabled          ;; is enabled now

    ;; if it still didnt work we just give up
    jmp a20_completely_failed

a20_enabled:
    mov si, a20_success_msg
    call print_string

    ;; instead of going into protected mode here we go to our second stage bootloader
    ;; before we do anything else we have to actually "load" the sectors starting at 0x8000 into the address
    mov si, dap             ;; we load our dap into si where th bios expects it to be when we do the bios call
    mov ah, 0x42            ;; we have to put 0x42 into ah since then the bios call with 0x13 can recognise this correctly (0x42 means that we want to extend using the dap)
    mov dl, [boot_drive]    ;; this tells the bios which physicall drive to read from
    int 0x13                ;; and then after all that we finally have to call the bios interrupt 0x13 
    jc disk_error           ;; if it didnt work we jump into the error where we will print something and have an infinite loop

    ;; and then finally we can jump
    jmp STAGE2_SEGMENT:STAGE2_OFFSET

check_a20:
    ;; we need to push some essential stuff for a20
    pushf
    push ds
    push es
    push di
    push si

    ;; we need to set es and ds to those specific values because we need two segments which are exactly 1MB apart
    xor ax, ax ;; sets ax to 0
    mov es, ax ;; es will also be set to 0

    not ax     ;; this sets ax to 0xFFFF
    mov ds, ax ;; sets ds to 0xFFFF

    ;; we need these to later compute where the physicall addresses point to
    mov di, 0x0500
    mov si, 0x0510

    ;; here we just save the bytes onto the stack at their respective memory addresses
    mov al, byte [es:di]
    push ax

    mov al, byte [ds:si]
    push ax

    ;; we need this so we know if a20 is enabled
    ;; firstly we set the low address to 0x00 and then the high address to 0xFF
    ;; after that we re-read es:di and see if it is 0xFF, it will be 0xFF if a20 is disabled (because it wraps around)
    ;; and else if its not 0xFF then a20 is anabled because it is still 0x00 (didnt wrap around, has more then 1MB)
    ;; we also use byte because it gives us back the address of [segment:offset] and we need exactly 1 byte from that address
    mov byte [es:di], 0x00
    mov byte [ds:si], 0xFF

    ;; we have to compare it now because if we wait until later then popf will remove our compared value
    cmp byte [es:di], 0xFF
    mov bx, 0
    je .done
    mov bx, 1

.done:
    ;; then after we are done with the test we pop ax off again 
    ;; and we also restore the original byte of ds:si here because before we read it and pushed it before using it
    ;; its just cleanup basically :D
    pop ax
    mov byte [ds:si], al

    pop ax
    mov byte [es:di], al

    ;; before we return from this we need to pop everything we just pushed so its cleaned up
    pop si
    pop di
    pop es
    pop ds
    popf

    cmp bx, 0

    ret
;; with this we try to enable the a20 via the bios only, no memory needed
enable_a20_bios:
    mov ax, 0x2403  ;; we try to query the a20 support gate
    int 0x15        ;; and then actually call the bios
    jc a20_ns       ;; if it is not supported by the bios we jump to a20 not supported (jc = jump if carry, so if Cf is set jump)

    test ah, ah     ;; check if ah is zero and we try to zero it so if ah != 0 then we know a20 is not supported
    jnz a20_ns      ;; if int 15 isnt supported  we jump to a20_nt again

    ;; then if we know the bios supports int 15 we check the gates status via the bios
    mov ax, 0x2402  ;; asks the bios what the current status is
    int 0x15        ;; call the bios
    jc a20_failed   ;; then if it fails to get it we return again just like we did when it wasnt supported

    test ah, ah     ;; we do the same compare as before again
    jnz a20_failed  ;; we just check for an error again like we did before

    test al, al     ;; then via check if its now on
    jnz a20_enabled_return ;; if it worked we jump, we could just return and test it like before but this is just simpler and does the same thing

    ;; if its not on we could try to enable it via the bios
    mov ax, 0x2401  ;; 0x2401 is the flag for turning on the a20 gate
    int 0x15        ;; call the bios
    jc a20_failed   ;; then if it failed to enable we jump to our error again

    test ah, ah     ;; same as before
    jnz a20_failed

    ret

enable_a20_keyboard:
    call a20wait    ;; first thing we need to do is see if the controller is empty and isnt processing something else
    mov al, 0xAD    ;; then with 0xAD we disable the keyboard
    out 0x64, al    ;; 0x64 is the controllers command port so we send it to the controller itself and not the actual keyboard

    ;; then after we disabled the keyboard we ask the controller to output its current output-port byte
    ;; we will use the read stuff later
    call a20wait    ;; wait again like before
    mov al, 0xD0    ;; then move the command 0xD0 (read controller output port) to the controller
    out 0x64, al    ;; then we read the controller output port
    ;; we read this because one bit of the stuff we get back from the controller controls the a20 gate
    ;; but we have to be carefull because it controlls really really important stuff

    ;; then we actually have to still read it, not only output it from the controller
    call a20wait2    ;; we wait for something different this time, we wait until the controller has actually put the byte we want in its output buffer
    in al, 0x60      ;; then once we have confirmed that the data is waiting for us we read it
    push ax

    ;; then we tell the controller we are about to write the new output port value
    call a20wait    ;; wait again
    mov al, 0xD1    ;; 0xD1 is the command for writing the next byte to the output port
    out 0x64, al    ;; this tells the controller that we want to write the next byte into the controller output port

    ;; after that we modifiy the a20 bit and send it
    call a20wait    ;; wait wait wait
    pop ax          ;; we pop our byte we read before
    or al, 2        ;; then we set the controller output bit for the a20 gate
    ;; since 2 in binary is 0000 0010 we can set bit 1 to 1 with Oring while leaving everything untouched
    ;; and bit 1 happens to be the a20 gate line, so we only set the specific bit we care about
    out 0x60, al    ;; then we actually set it

    ;; then after doing all that we have to re-enable the keyboard
    call a20wait
    mov al, 0xAE    ;; this is the enable keyboard command
    out 0x64, al    ;; and here we actually call it

    ;; then lastly we have to do some cleanup
    call a20wait
    ret

enable_a20_fast:
    in al, 0x92     ;; firstly we read the first byte from the System control port a on 0x92
    test al, 2      ;; then we check if bit 1 (value 2) is already set
    jnz a20_enabled_return ;; if it is set we know a20 is enabled
    or al, 2        ;; if its not set then we have to set it with the same way as before 
    and al, 0xFE    ;; we need to do this because we want the bit 0 to always be 0 else **bad** things will happen
    out 0x92, al    ;; now write it back onto the controller

    ret

a20_enabled_return:
    ret

;; this just waits until the input buffer is clear
a20wait:
    in al, 0x64     ;; we read from the port 0x64 which gives us the controllers status bytes
    test al, 2      ;; bit 1 (value 2) of the status byte is the "input type full" flag, its 1 if its still processing something
    jnz a20wait     ;; if its still busy with something else we wait in a loop
    ret             ;; else we can return

;; this is the same as the a20wait but waits until the bit we requested has arrived in the controller
a20wait2:
    in al, 0x64     ;; we read from the port 0x64 again like before
    test al, 1      ;; bit 0 (value 1) has the status byte "output byte full", and its 1 when the controller has the data ready for you
    jz a20wait2     ;; then our loop again
    ret             ;; and the return

;; just calls a return so we jump back to the original a20
a20_ns:
    ret

;; just calls a return so we jump back to the original a20
a20_failed:
    ret

;; we use the bios function for this because it is the easiest when we are still in 16 bit mode
print_string:
    lodsb        ;; this loads the byte at [si] into al and also increments si
    or al, al    ;; here we check if al is equal to 0, so in other words if we have reached the end of a string
    jz .done     ;; if we are finished with the string we just jump to something which returns to where print_string was called
    mov ah, 0x0E ;; then we select the teletype output subfunction from the bios which prints a single character to the screen
    mov bh, 0    ;; this defines on which "page" we want the output to be, its really oldschool but it will work
    int 0x10     ;; and then with 0x10 we call the bios and tell it to print whatever character is in al 
    jmp print_string  ;; then we ofc have to make it a loop
.done:
    ret

a20_completely_failed:
    ;; here we know we couldnt enable a20 at all so we just print an error message and halt the cpu forever
    mov si, a20_failed_err_msg
    cld          ;; with this instruction we clear the df which we use at lodsb, we clear it so a forward direction is garunteed and df doesnt grow down into some random memory
    call print_string
    jmp halt

disk_error:
    mov si, disk_error_msg
    cld
    call print_string
    jmp halt

halt:
    jmp halt

;; the 13 and 10 move the cursor where stuff gets printed to a newline
;; error message for when we fail to read the disk
disk_error_msg db "Couldnt read the disk.", 13, 10, 0
;; error message for when we completely failed to enable the a20 gate
a20_failed_err_msg db "Couldnt enable the a20 gate.", 13, 10, 0
;; success message for when we successfully activated the a20 gate
a20_success_msg db "Successfully enabled the a20 gate.", 13, 10, 0

pm_halt:
    jmp pm_halt

;; ($-$$) is the current size of our programm
times 510-($-$$) db 0 ;; tells nasm to pad everything of our 512 bytes except the last 2, bootloader needs to be 512 bytes

;; only boots when it reads this (boot signature)
dw 0xaa55