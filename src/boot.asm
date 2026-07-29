[org 0x7c00] ;; tells nasm where the code is located in memory
[bits 16] ;; code runs in 16 bit mode for booting

;; we need to jmp over the bios thingis
jmp start 

start:
    ;; if we want to boot into a kernel later we will need to do some stuff
    ;; first we need to enable the a20 line in order to access memory above 1MB
    ;; then we need to load a gdt (global descriptor table)
    ;; then switch to protected mode so 32 bit
    ;; and then we need to load the kernels main function

    ;; enabeling the a 20 line
    ;; before we do that we need to test if the bios has already enabled it
    jmp check_a20

;; when checking if a20 is on we can follow a specific plan:
;; checking if it is on -> if yes continue 
;; if it isnt on we try it with the BIOS function (int 0x15)
;; check if it is on again
;; if it still isnt on we can do the keyboard controller method
;; then when checking a20 again we do it in a loop with a time out since the keyboard method can take sometime
;; then lastly if it still didnt work we try the fast a20 method, also with a loop since the "fast" a20 can also take some time
;; and then if it still isnt on just give up
a20:
    call check_a20

check_a20:
    ;; we need to push some essential stuff for a20
    pushf
    push ds
    push es
    push di
    push si

    ;; clear input flag -> disables hardware interrupts
    cli

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

    cmp byte [es:di], 0xFF

    ;; then after we are done with the test we pop ax off again 
    ;; and we also restore the original byte of ds:si here because before we read it and pushed it before using it
    ;; its just cleanup basically :D
    pop ax
    mov byte [ds:si], al

    pop ax
    mov byte [es:di], al

;; with this we try to enable the a20 via the bios only, no memory needed
enable_a20_bios:
    mov ax, 0x2403  ;; we try to query the a20 support gate
    int 0x15        ;; and then actually call the bios
    jc a20_nt       ;; if it is not supported we jump to a20 not supported (jc = jump if carry, so if Cf is set jump)

    test ah, ah     ;; check if ah is zero and we try to zero it so if ah != 0 then we know a20 is not supported
    jnz a20_nt

    ret

;; just calls a return so we jump back to the original a20
a20_ns:
    ret
/*
    ;; then after comparing and cleaning up we can finally interpret the result
    ;; if before we found out that a20 was disabled we need to enable it
    mov ax, 0
    je check_a20__exit;; future enabeling here

    ;; else we dont need to enable it (yippie)
    mov ax, 1


check_a20__exit:
    pop si
    pop di
    pop es
    pop ds
    popf

    ret
*/

.halt:
    jmp .halt;; jumps back to halt again and again -> infinite loop, prevents from going off into memory and executing junk

;; ($-$$) is the current size of our programm
times 510-($-$$) db 0 ;; tells nasm to pad everything of our 512 bytes except the last 2, bootloader needs to be 512 bytes

;; only boots when it reads this (boot signature)
dw 0xaa55