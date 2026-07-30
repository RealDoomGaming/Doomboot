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

    ;; clear input flag -> disables hardware interrupts
    cli

    ;; enabeling the a 20 line
    ;; before we do that we need to test if the bios has already enabled it
    jmp a20

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
    je ;; is enabled
    call enable_a20_bios
    ;; we dont need a jump here if it is enabled now because we have that in the enable_a20_bios


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

    cmp byte [es:di], 0xFF

    ;; then after we are done with the test we pop ax off again 
    ;; and we also restore the original byte of ds:si here because before we read it and pushed it before using it
    ;; its just cleanup basically :D
    pop ax
    mov byte [ds:si], al

    pop ax
    mov byte [es:di], al

    ret

;; with this we try to enable the a20 via the bios only, no memory needed
enable_a20_bios:
    mov ax, 0x2403  ;; we try to query the a20 support gate
    int 0x15        ;; and then actually call the bios
    jc a20_nt       ;; if it is not supported by the bios we jump to a20 not supported (jc = jump if carry, so if Cf is set jump)

    test ah, ah     ;; check if ah is zero and we try to zero it so if ah != 0 then we know a20 is not supported
    jnz a20_nt      ;; if int 15 isnt supported  we jump to a20_nt again

    ;; then if we know the bios supports int 15 we check the gates status via the bios
    mov ax, 0x2402  ;; asks the bios what the current status is
    int 0x15        ;; call the bios
    jc a20_failed   ;; then if it fails to get it we return again just like we did when it wasnt supported

    test ah, ah     ;; we do the same compare as before again
    jnz a20_failed  ;; we just check for an error again like we did before
    
    test al, al     ;; then via check if its now on
    jnz             ;; if it worked we jump, we could just return and test it like before but this is just simpler and does the same thing

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