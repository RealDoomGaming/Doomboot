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
    call check_a20         ;; firstly we check if the a20 gate is enabled by default
    jne a20_enabled         ;; is enabled

    call enable_a20_bios
    ;; we dont need a jump here if it is enabled now because we have that in the enable_a20_bios

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

    ;; after we have enabled a 20 we have to load a gdt (global descriptor table) in order to
    ;; jump into protected mode (32bit) and then later long mode (64 bit)
    ;; we firstly load our gdt descriptor, we only need to do this once!!
    lgdt [gdt_desc]

    mov eax, cr0    ;; cr0 is a internal register of the cpu which is for its state and configuration, and we copy its value to the eax register
    or eax, 1       ;; this sets bit 0 to 1, bit 0 of cr0 is the protection enabled bit so if we set it to 1 we enable protective mode
    mov cr0, eax    ;; then we just move the new bit sequence back into the cr0 register

    jmp CODE32:protected_mode_entry     ;; here we performe a far jump and force the cpu to throw away whatever it wanted to do and continue in protected mode

;; here we will define our gdt, in our gdt we want to five descriptors
;; 1. null descriptor -> this one is required by the cpu I think, but either way we need it
;; 2. 32 bit code segment   
;; 3. 32 bit data segment
;; 4. 64 bit code segment
;; 5. 64 bit data segment
;; for more info you can refer to this: https://web.archive.org/web/20190424213806/http://www.osdever.net/tutorials/view/the-world-of-protected-mode
;; it helped me a lot and also explains it really well
gdt_start:

gdt_null:
    dq 0

gdt_code_32bit:
    ;; this is our first double word segment in the gdt
    dw 0xFFFF       ;; first 16 bits are set to the max amount so 4GB
    dw 0x00         ;; and the start of our base memory will be set to 0

    ;; and then our 2nd double word segment in the gdt
    db 0x00         ;; the first 8 bit of our 2nd double word are for the base address so we set that to 0 too

    ;; for the next 8 bit, the first 4 are type bits
    ;; the 8th bit is an access flag for the cpu for which we dont have any use right now so we set it to 0
    ;; the 9th bit sets if the segment should be readable, we want that so we set it
    ;; the 10th bit is a conforming bit which determins if a lesser priveleged code segement can call this one and in a realistic case we dont really want that
    ;; and 11th bit spcifies if this gdt segment is a code (1) or a data (0) segment
    ;; then we continue with the 12th bit is set if the segment is either a code or a data segment
    ;; the 13th and 14th bits are for the privelege level, ranging from 0 to 3 where 3 is the least priveleged, since this gdt segment is part of our OS we set both bits to 0 
    ;; and the last bit is the present flag, we also set this bit 
    ;; and we finally get:
    db 10011010b        ;; the b stands for bit and we read it from back to front
    
    ;; and now we have the final 16 bits to set
    ;; bits 16 to 19 are a limit, so we set that to the highest (0Fh or in binary 1111)
    ;; the 20th bit is for is a flag which which is available to programmers, so we can set it to whatever we want (we ignore it for now)
    ;; the 21st bit is reserved for something to do with intel or something so it has to be 0
    ;; the next bit is the size bit, it tells the cpu that we have 32 bit code and not 16 bit code, so we set it 
    ;; the 23rd bit multiplies the limit by 4kB if it is set and we want that
    ;; so finally we get:
    db 11001111b

    ;; the only thing remaining are the last 8 bit responsible for the base address, and we still set them to 0
    db 0 

;; now we can do the same thing with our 32 bit data segment
;; it is basically the same as the one from the code segement with only some tweaks
gdt_data_32bit:
    dw 0xFFFF      
    dw 0x00 

    db 0x00

    ;; the only bits which are different are:
    ;; the only thing different here is the 3rd bit which is the executable bit, and we set it to 0 because this is the data segment and therefor is only storage
    db 10010010b

    ;; this stays the same
    db 11001111b

    db 0

;; this is the same as the 32 bit one but its for 64 bit, some things will change but not a lot
gdt_code_64bit:
    dw 0x0000       ;; this si the first thing which changes, when we were in protected mode before the cpu enforced a 4GB limit but this time when we are in long mode the cpu completely ingores any limit
    dw 0x00

    db 0x00

    db 10011010b

    ;; the only thing which changes is that we set the long mode bit and unset the size bit bit (before: 11001111b)
    db 10101111b

;; same with this one, it only changed a bit
gdt_data_64bit:
    dw 0x0000       ;; the limit gets unset again      
    dw 0x00 

    db 0x00

    db 10010010b    ;; stays the same

    db 00000000b    ;; gets completely unset because there is nothing meaningfull to set here with the 64 bit data
    ;; the granularity doesnt matter since we have no limit
    ;; the size bit doesnt matter because for data segments its not importent
    ;; the long mode bit doesnt matter since it gets only checked if the segment is a code segment

    db 0

;; here we set the end of our gdt segments because later we need the difference between the end and beginning to calucluate something
gdt_end:

;; after defining all the gdt segments we need to make a gdt descriptor
gdt_desc:
    dw gdt_end - gdt_start - 1  ;; here we just calculate the size of the global descriptor table
    dq gdt_start            ;; and this is where the table starts


;; we can also define some handy selector contants which we can use later when switiching modes
CODE32 equ gdt_code_32bit-gdt_start     ;; tells the variable where our gdt code segment for the 32bit protected mode starts
DATA32 equ gdt_data_32bit-gdt_start     ;; same as before
CODE64 equ gdt_code_64bit-gdt_start     ;; yeah I think you get it
DATA64 equ gdt_data_64bit-gdt_start     ;; yep


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

    ;; before we return from this we need to pop everything we just pushed so its cleaned up
    pop si
    pop di
    pop es
    pop ds
    popf

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
    jnz a20_enabled ;; if it worked we jump, we could just return and test it like before but this is just simpler and does the same thing

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
    jnz a20_enabled ;; if it is set we know a20 is enabled
    or al, 2        ;; if its not set then we have to set it with the same way as before 
    and al, 0xFE    ;; we need to do this because we want the bit 0 to always be 0 else **bad** things will happen
    out 0x92, al    ;; now write it back onto the controller

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
    call print_string
    jmp halt

halt:
    jmp halt;; jumps back to halt again and again -> infinite loop, prevents from going off into memory and executing junk

;; error message for when we completely failed to enable the a20 gate
a20_failed_err_msg db "Couldnt enable the a20 gate.", 0
;; success message for when we successfully activated the a20 gate
a20_success_msg db "Successfully enabled the a20 gate.", 0

[bits 32] 
protected_mode_entry:
    ;; print a success message here later
    mov ebx, pm_success_msg     ;; we have to move it into there

    call pm_print_setup          ;; doing the important setup beforehand

    jmp pm_halt

;; before we can print stuff we need to set where the video memory stuff is located
pm_print_setup:
    pusha
    mov edx, 0xB8000   ;; the video memory is at 0xB8000

;; we need a new print since we are now in 32 bit mode and cant call bios anymore
.pm_print_string:
    mov al, [ebx]       ;; we move the character from ebx to the al register
    mov ah, 0x0f        ;; 0x0f stands for black on white when we print something

    cmp al, 0           ;; check if we are at the end of the string via the null terminator
    je .pm_end_print     ;; if it has ended we jump to a function which returns to where pm_print_string was called

    mov [edx], ax       ;; we store the character and attribute in the video memory which basically "prints" it
    add ebx, 1          ;; we go to the next character in our string
    add edx, 2          ;; we go to the next video memory position

    jmp .pm_print_string ;; and then we have our loop

.pm_end_print:
    popa
    ret

pm_success_msg db "Successfully entered protected mode.", 0 ;; our success message

pm_halt:
    jmp pm_halt

;; ($-$$) is the current size of our programm
times 510-($-$$) db 0 ;; tells nasm to pad everything of our 512 bytes except the last 2, bootloader needs to be 512 bytes

;; only boots when it reads this (boot signature)
dw 0xaa55