[org 0x8000]
[bits 16]

;; we start here with the second stage of our bootloader
start2:
    ;; after we have enabled a 20 in our stage 1 we have to load a gdt (global descriptor table) in order to
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

    db 0

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
    dd gdt_start            ;; and this is where the table starts


;; we can also define some handy selector contants which we can use later when switiching modes
CODE32 equ gdt_code_32bit-gdt_start     ;; tells the variable where our gdt code segment for the 32bit protected mode starts
DATA32 equ gdt_data_32bit-gdt_start     ;; same as before
CODE64 equ gdt_code_64bit-gdt_start     ;; yeah I think you get it
DATA64 equ gdt_data_64bit-gdt_start     ;; yep


[bits 32] 

%include "flags.asm" 

;; I think these are relatively self explanetory
VIDEO equ 0xB8000
WHITE_ON_BLACK equ 0x0F
SCREEN_WIDTH equ 80
SCREEN_HEIGHT equ 25

protected_mode_entry:
    ;; first thing we do is we have to setup the segment registers
    mov ax, 0x10        ;; why 0x10 here -> it was the data segment selector from our gdt earlier
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000     ; and here we setup the stack

    call clear_screen

    ;; print a success message here later
    mov ebx, pm_success_msg     ;; we have to move it into there

    call pm_print_setup          ;; doing the important setup beforehand

    ;; now after we are in protected mode, the next step would be to go into long mode (64 bit)
    ;; but before going into long mode we have to do some other stuff like:
    ;; check if CPUID can be used since we need it to check if long mode is supported
    ;; checking if long mode is actually supported
    ;; setting up paging
    ;; and only then we can switch
    call check_CPUID    ;; check for CPUID support

    ;; before we can detect the presence of long mode we have to see if the extended functions of the CPUID are supported on the cpu
    call check_long_mode_support

    ;; then we have to lastly set up paging before jumping into long mode


    jmp pm_halt

;; in this function we check if the CPUID instruction is supported by attempting to flip the the ID bit, so bit 21, in the EFLAGS register
;; if it gets flipped then CPUID is available and we can use it
check_CPUID:
    pushfd          ;; firstly we push all eflags onto the stack
    pop eax         ;; and then we pop the eflags into the eax register

    mov ecx, eax    ;; but we also want to save the original value of the elfags in eax for later so we can compare it
    xor eax, EFLAGS_ID  ;; then we try to flip bit 21 in the eax register

    push eax        ;; then we push the changed eflags value
    popfd           ;; and pop it back into the eflags via popfd (with this we try to write the flipped bit into the real eflags register, this only works if the CPU supports CPUID)
    pushfd          ;; here we restore it from the eflags
    pop eax         ;; and pop eax off again

    push ecx        ;; and restore eflags to its original value again
    popfd

    xor eax, ecx    ;; then we test if the bit in eax was successfully flipped (if eax != ecx)
    jnz .supported  ;; if it was flipped then its supported
;; it its not supported we fall into this label here and print an error message + halt
.not_supported:
    mov ebx, CPUID_error_msg
    call pm_print_setup
    jmp pm_halt
;; if its supported we just jump back to continue with the setup of jumping into long mode
.supported:
    ret 

check_long_mode_support:
    mov eax, CPUID_EXTENSIONS       ;; we move our first extended leave into eax to check if the cpu even supports them
    cpuid                           ;; with this eax becomes the max supported extended leaf
    cmp eax, CPUID_EXT_FEATURES     ;; and here we compare if eax is bigger or equal to 0x80000001
    ;; jb stands for jump if below
    jb .lm_not_supported            ;; if the cpu cant report long mode support then it probably doesnt have long mode either so we can just do the same as if we didnt have long mode

    ;; if extended function can be used we can check if long mode is supported
    mov eax, CPUID_EXT_FEATURES     ;; we move the check for long mode into eax 
    cpuid                           ;; query the extended feature
    test edx, CPUID_EDX_EXT_FEAT_LM ;; if bit 29 in edx is 1 then long mode is supported else its not
    jz .lm_not_supported            ;;
    ;; else if it is supported we ret
    ret
.lm_not_supported:
    mov ebx, lm_error_msg
    call pm_print_setup
    jmp pm_halt

clear_screen:
    pusha
    mov edi, VIDEO      ;; move the value from our video constant into the edi register
    mov ecx, SCREEN_HEIGHT * SCREEN_WIDTH ;; same with the screen height and width -> those multiplied represent all characters which can fit on the screen
    mov ax, 0x0F20                        ;; 0x0F stands for attribute and we can combine that with a space char so 0x20

;; then we fall into our clear loop label
.clear_loop:
    mov [edi], ax
    add edi, 2
    loop .clear_loop

    popa
    ret

;; before we can print stuff we need to set where the video memory stuff is located
pm_print_setup:
    pusha
    mov edx, VIDEO   ;; the video memory is at 0xB8000
    xor ecx, ecx     ;; ecx will track our current column so we know when to start a new line

;; we need a new print since we are now in 32 bit mode and cant call bios anymore
.pm_print_string:
    mov al, [ebx]                 ;; we move the character from ebx to the al register
    mov ah, WHITE_ON_BLACK        ;; 0x0F stands for black on white when we print something

    cmp al, 0           ;; check if we are at the end of the string via the null terminator
    je .pm_end_print     ;; if it has ended we jump to a function which returns to where pm_print_string was called

    cmp al, 13          ;; check if we have a carriage return
    jmp .pm_skip_char    ;; if yes then we skip the entire character

    cmp al, 10          ;; check if we have hit a new line
    jmp .pm_print_new_line ;; then we print a line

    mov [edx], ax       ;; we store the character and attribute in the video memory which basically "prints" it
    add edx, 2          ;; we go to the next video memory position
    inc ecx             ;; we have to continue in this row since we printed one more character

    cmp ecx, 80         ;; have we hit the edge of the screen
    jne .pm_skip_char   ;; if not next character
                        ;; else if we have hit a the edge of the screen then we fall through to go to the next line
.pm_print_new_line:
    mov eax, 80     ;; max character in one screen
    sub eax, ecx    ;; calculate how man columns are left in this row
    imul eax, eax, 2    ;; we convert the value in eax to bytes, we have 2 bytes per cell (one char)
    add edx, eax    ;; then we jump to the video pointer at the start of the next row
    xor ecx, ecx    ;; and reset the column counter

.pm_skip_char:
    add ebx, 1      ;; we continue to the next character
    jmp .pm_print_string

.pm_end_print:
    popa
    ret

pm_success_msg db "Successfully entered protected mode.", 13, 10, 0 ;; our success message for enabeling protected mode
CPUID_error_msg db "Couldnt detect the presence of CPUID.", 13, 10, 0 ;; our error message for failing to detect CPUID
lm_error_msg db "Couldnt detect the presence of Long Mode.", 13, 10, 0 ;; our error message for failing to detect Long Mode

pm_halt:
    jmp pm_halt

times 4096-($-$$) db 0   ;; then at the end we pad our img up with 0s so this file is actually 4096 bytes (8 sectors) long and the bios can even load the second stage