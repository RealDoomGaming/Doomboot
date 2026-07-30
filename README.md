# Doomboot
VERY simple bootloader which is written in x86_64 and will probably be expanded with c as soon as I am able to programm in c.
This is just a learning experience so I really have no idea where this project might go, I may even expand upon this with a kernel later.

## Roadmap
 
- [x] Boot sector skeleton (org, bits, boot signature)
- [x] A20 line detection via the various methods
- [ ] A20 line enabling 
- [ ] GDT setup
- [ ] Switch to 32-bit protected mode
- [ ] Load a second-stage bootloader (when we can work with more then 1MB) -> Maybe
- [ ] Jump into a custom kernel -> Maybe

## Build & Run

### Requirements:
| Tool | What it's for |
|------|----------------|
| `nasm` | Assembles the `.asm` source into a raw binary |
| `qemu-system-x86_64` | Emulates a PC to actually boot the binary |
| `make` | Runs the build |

### Run:
```bash
chmod +x ./run.sh
./run.sh
```
