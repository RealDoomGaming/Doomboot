;; file for any flags we may use in the second stage of the bootloader
EFLAGS_ID equ 1 << 21   ;; we use this to detect if the CPUID instruction is available, and we do this by testing if this can be flipped
CPUID_EDX_EXT_FEAT_LM equ 1 << 29   ;; if this is set then we know that the CPU supports long mode

;; we need these flags for the CPUID since you need a "leaf number" for the cpuid, we use only the extended leaves which is everything from 0x80000000 and up
CPUID_EXTENSIONS equ 0x80000000 ;; so then this will be used to see if the cpu even supports extended leaves before we do the next one      
CPUID_EXT_FEATURES equ 0x80000001 ;; this returns the flag which contains if long mode is supported

;; all the flags for the paging in 64 bit 
PML4T_ADDR equ 0x1000           ;; this is just the starting address of our page tables
SIZEOF_PAGE_TABLE equ 4096      ;; I think this is relatively self explanetory
;; these are the four addresses where the four levels of page hierchy live (the hiearchy is top down so: PML4T->PDPT->PDT->PT)
PML4T_ADDR equ 0x1000
PDPT_ADDR equ 0x2000
PDT_ADDR equ 0x3000
PT_ADDR equ 0x4000
;; these next 3 are bit masks/flags the table entry uses and I think they are self explanetory
PT_ADDR_MASK equ 0xffffffffff000
PT_PRESENT equ 1        ;; this one masks the entry as in use or not
PT_READABLE equ 2
;; these next 3 will be used for when we fill up every entry
ENTRIES_PER_PT equ 512      ;; this is 2MB since each entry has 8 bytes and each table is 4KB
SIZEOF_PT_ENTRY equ 8       ;; each entry in a 64bit page table is 8 byte
PAGE_SIZE equ 0x1000        ;; this is the size of the physical memory of all pages (4096MB)