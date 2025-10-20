# Chip-8 Interpreter in Zig
This is an implementation of Chip-8 interpreter in Zig. 

For more informations about Chip-8:
- [Cowgod's Chip-8 Technical Reference v1.0](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
- [Awesome Chip-8](https://chip-8.github.io/links/)

## Test Suite Status
This is the current status of every test case in [Timendus/chip8-test-suite](https://github.com/Timendus/chip8-test-suite):
- [X] Chip-8 Logo (`./chip_8_emu roms/1-chip8-logo.ch8`)

  ![](docs/1-chip-8-logo.png)
- [X] IBM Logo (`./chip_8_emu roms/2-ibm-logo.ch8`)
  
  ![](docs/2-ibm-logo.png)
- [X] Corax+ Opcode Test (`./chip_8_emu roms/3-corax+.ch8`)
  
  ![](docs/3-corax+.png)
- [X] Flags Test (`./chip_8_emu roms/4-flags.ch8`)
  
  ![](docs/4-flags.png)
- [X] Quirks Test
  
  - [X] Chip-8 (`./chip_8_emu -m 1FF=1 roms/5-quirks.ch8`)
  
    ![](docs/5-quirks-chip-8.png)

  - [X] Super-Chip (Modern) (`./chip_8_emu -t 20 -b schip -m 1FF=2 roms/5-quirks.ch8`)
  
    ![](docs/5-quirks-super-chip-modern.png)

  - [X] Super-Chip (Legacy) (`./chip_8_emu -b schip -m 1FF=4 roms/5-quirks.ch8`)
  
    ![](docs/5-quirks-super-chip-legacy.png)

  - [X] XO-Chip (`./chip_8_emu -t 20 -b xochip -m 1FF=3 roms/5-quirks.ch8`)
  
    ![](docs/5-quirks-xo-chip.png)
  
- [X] Keypad Test
  - [X] KeyUp (`./chip_8_emu -t 20 -m 1FF=1 roms/6-keypad.ch8`)
  
    ![](docs/6-keypad-up.gif)

  - [X] KeyDown (`./chip_8_emu -t 20 -m 1FF=2 roms/6-keypad.ch8`)
  
    ![](docs/6-keypad-down.gif)

  - [X] GetKey (`./chip_8_emu -t 20 -m 1FF=3 roms/6-keypad.ch8`)
  
    ![](docs/6-keypad-getkey.gif)
- [X] Beep Test (Sound emitted according to test specification) (`./chip_8_emu roms/7-beep.ch8`)
  
  ![](docs/7-beep.gif)
- [ ] Scrolling Test (`./chip_8_emu roms/8-scrolling.ch8`)
  - [ ] Super-Chip (Modern + lores) (`./chip_8_emu -m 1FF=1 roms/8-scrolling.ch8`)
  
    ![](docs/8-scrolling-super-chip-modern-lores.gif)

  - [ ] Super-Chip (Legacy + lores)  (`./chip_8_emu -m 1FF=2 roms/8-scrolling.ch8`)
  
    ![](docs/8-scrolling-super-chip-legacy-lores.gif)

  - [ ] Super-Chip (hires) (`./chip_8_emu -m 1FF=3 roms/8-scrolling.ch8`)
  
    ![](docs/8-scrolling-super-chip-hires.gif)

  - [ ] XO-Chip (lores) (`./chip_8_emu -m 1FF=4 roms/8-scrolling.ch8`)
  
    ![](docs/8-scrolling-xo-chip-lores.gif)

  - [ ] XO-Chip (hires) (`./chip_8_emu -m 1FF=5 roms/8-scrolling.ch8`)
  
    ![](docs/8-scrolling-xo-chip-hires.gif)
