;; file for any flags we may use in the second stage of the bootloader
EFLAGS_ID equ 1 << 21   ;; we use this to detect if the CPUID instruction is available, and we do this by testing if this can be flipped
CPUID_EDX_EXT_FEAT_LM equ 1 << 29   ;; if this is set then we know that the CPU supports long mode

;; we need these flags for the CPUID since you need a "leaf number" for the cpuid, we use only the extended leaves which is everything from 0x80000000 and up
CPUID_EXTENSIONS equ 0x80000000 ;; so then this will be used to see if the cpu even supports extended leaves before we do the next one      
CPUID_EXT_FEATURES equ 0x80000001 ;; this returns the flag which contains if long mode is supported