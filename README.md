# Raspberry Zero Dark — Perfect Dark Port for Raspberry Pi Zero 2W & Pi Tin

**Raspberry Zero Dark** is a native ARMv6/ARMv7 OpenGL ES 2.0 / Broadcom VideoCore IV hardware port of the [Perfect Dark PC port (`fgsfdsfgs/perfect_dark`)](https://github.com/fgsfdsfgs/perfect_dark) tailored for the **Raspberry Pi Zero 2W**.

This release package provides **two configurations**:
1. **Generic Raspberry Pi Zero 2W (`generic`)**: For standard Raspberry Pi Zero 2W setups (HDMI, composite, or DPI displays with USB/Bluetooth controllers or keyboard/mouse).
2. **Pi Tin Handheld (`pitin`)**: Purpose-built for the **Pi Tin** handheld (Raspberry Pi Zero 2W + 320x240 ILI9340 SPI TFT via `fbcp` + `GPIOnext` GPIO controller + MAX98357A I2S DAC).

---

## Legal Notice & ROM Requirement

- **No copyrighted material, ROM images (`.z64`), extracted assets, or precompiled binaries are included in this release.**
- You must supply your own legally obtained **Perfect Dark (NTSC-Final v1.1)** ROM image named `pd.ntsc-final.z64` (SHA-1: `af8df8594f2b82a5ecc3ebc0d2f0e699b0ac6e24`, 33,554,432 bytes) and place it inside `<runtime_dir>/data/pd.ntsc-final.z64`.

---

## Package Structure

```text
raspberry-zero-dark/
├── README.md
├── patches/
│   ├── 0001-perfect-dark-rpi-zero2w-generic.patch   # Variant 1: Generic RPi Zero 2W source patch
│   └── 0001-perfect-dark-rpi-zero2w-pi-tin.patch    # Variant 2: Pi Tin handheld source patch
├── config/
│   ├── pd.ini.generic                               # Default configuration for Generic RPi Zero 2W
│   ├── pd.ini.pitin                                 # Default configuration for Pi Tin handheld
│   └── gamecontrollerdb.txt                         # SDL2 GameControllerDB entry for GPIOnext Joypad 1
└── scripts/
    ├── apply_patch.sh                               # Automated patch & config installation helper
    ├── setup_pitin_volume.py                        # Pi Tin GPIOnext Fn + D-Pad Up/Down volume installer
    └── launchers/
        ├── Perfect Dark (Generic).sh                # RetroPie / standalone launcher (Generic)
        └── Perfect Dark (Pi Tin).sh                 # RetroPie Ports launcher (Pi Tin with ES freeze & Fn+Start quit)
```

---

## Key Engine & Hardware Fixes Included

### Both Variants (`generic` & `pitin`)
- **VideoCore IV OpenGL ES 2.0 & GLSL ES 1.00 Renderer (`port/fast3d/gfx_opengl.cpp`, `port/fast3d/gfx_sdl2.cpp`)**:
  - Prioritizes OpenGL ES 2.0 (`SDL_GL_CONTEXT_PROFILE_ES`) on 32-bit/64-bit ARM.
  - **Attribute 0 Hardware Lockup Fix**: Explicitly binds `aVtxPos` to vertex attribute location `0` before `glLinkProgram()`, preventing the Broadcom VideoCore IV hardware tile binner/rasterizer from locking up on complex shaders (e.g., the dataDyne neon logo in *Defection*).
  - **8-Attribute Hardware Limit Packing**: Packs texture clamp parameters (`u`/`v` clamp bounds) into the `.z` and `.w` components of `aTexCoord0` and `aTexCoord1` so shaders never exceed VideoCore IV's 8-attribute hardware ceiling.
  - **GLSL ES 1.00 Compatibility**: Replaces Desktop GLSL `textureSize()` calls with GLSL 100-compatible `wrap()` helpers and client-side vertex attribute submission when VAOs/GL 3.0+ are unavailable.
  - **Startup Optimization**: Loads only valid GLES 2.0 symbols and silences non-fatal Desktop OpenGL extension lookups on startup.
- **ARM Unaligned Access Fix (`src/game/setuppads.c`, `port/src/system.c`)**:
  - Aligns `g_StageSetup.cover` to a 16-byte boundary in `setupPreparePads()`, fixing `SIGBUS` / alignment faults on ARMv6/ARMv7 when loading stages with unaligned pad cover tables.
  - Replaces unsupported ARMv6 `yield` inline assembly with a portable no-op.
- **Intact & Tinted Glass Rendering Fix (`src/game/propobj.c`, `src/lib/model.c`, `port/fast3d/gfx_pc.cpp`)**:
  - Configures 2-cycle combiner pass-through (`G_CC_CUSTOM_00`, `G_CC_CUSTOM_20`) for both opaque and translucent (`xlugdl`) passes in `modelApplyRenderModeType3()` and `modelApplyRenderModeType4()`.
  - Enforces a minimum close-range opacity floor (`0.25f`) and double-sided rendering (`CULLMODE_NONE`) so smoky/tinted glass railings and windows render properly before being shattered.
- **Extended Video Menu Crash Fixes (`src/game/menu.c`, `src/game/menuitem.c`, `src/game/game_1531a0.c`, `port/src/optionsmenu.c`)**:
  - Guards against null `g_Vars.currentplayerstats` pointers when opening dialogs from the title screen, null strings in `textMeasure()`, zero-max slider division by zero (`SIGFPE` in `menuitemSliderRender` / `menuitemSliderTick`), and out-of-bounds dropdown indices when anisotropic filtering or display modes are unsupported.
- **Menu Navigation & `A` Button Fix (`src/game/menu.c`)**:
  - Fixes an upstream PC port bug in `menuProcessInput()` where pressing the controller **A button** (`inputs.select`) while `g_MenuUsingMouse` was active caused the menu to think the user clicked the mouse outside the dialog box—zeroing out `inputs.select = 0` and setting `inputs.leftright = -1/+1` (swiping/cycling menu panels left or right instead of selecting items).
  - Side-of-dialog click swiping now strictly requires an actual left mouse button click (`inputs.mouseheld`), and any gamepad button or D-pad/stick input immediately clears `g_MenuUsingMouse = false`.

### Pi Tin Variant Additional Features (`pitin`)
- **Pi Tin Control Defaults Baked In (`port/src/input.c`, `src/game/menu.c`, `src/game/mplayer/mplayer.c`)**:
  - Automatically registers the `GPIOnext Joypad 1` SDL2 mapping (`030000000f270000b822000001000000`) at engine startup.
  - Disables menu mouse control (`g_MenuMouseControl = false`, `mouseEnabled = 0`) by default so the SPI TFT resistive overlay never steals menu focus.
  - Defaults `SwapSticks = 0` and `ExtendedControls = 0` with Pi Tin button bindings out of the box even if `pd.ini` is regenerated.
- **Dedicated Reload & Alt-Fire on Handheld (`src/game/bondmove.c`)**:
  - Allows dedicated **Reload** (`Y` button) and **Toggle Secondary Fire Mode** (`X` button) to work in standard 1.1 control mode, and maps **Aim** exclusively to `L2` (`R_TRIG`).
- **Native `Fn + Start` Instant Exit & `Fn` Modifier Isolation (`port/src/input.c` & `Perfect Dark (Pi Tin).sh`)**:
  - Holding **Fn** (`BTN_TRIGGER_HAPPY2` / `SDL_CONTROLLER_BUTTON_GUIDE`) + **Start** (`BTN_START`) cleanly exits the game back to EmulationStation (supported both inside the engine input loop and via an `evdev` watchdog in the launcher script).
  - Holding **Fn** suppresses in-game controller input so `Fn + D-Pad Up/Down` (Volume) and `Fn + L2/R2` (Brightness) combos never move the menu cursor or player in-game.
- **EmulationStation Freeze/Resume (`Perfect Dark (Pi Tin).sh`)**:
  - Sends `SIGSTOP` to `emulationstation` before launching and guarantees `SIGCONT` via a shell `trap` on exit so background menus never consume CPU cycles or intercept button presses.

---

## Pi Tin Controller Layout (`pitin` Variant)

| Pi Tin Button | In-Game Action | Menu Action |
| :--- | :--- | :--- |
| **D-Pad Up / Down** | Walk Forward / Walk Backward | Navigate Up / Down |
| **D-Pad Left / Right** | Turn Left / Turn Right | Navigate Left / Right |
| **L1 (`JOY1_LSHOULDER`)** | Strafe Left | Swipe Menu Tab Left |
| **R1 (`JOY1_RSHOULDER`)** | Strafe Right | Swipe Menu Tab Right |
| **R2 (`JOY1_RTRIGGER`)** | Fire Weapon (`Z_TRIG`) | Select |
| **L2 (`JOY1_LTRIGGER`)** | Crosshair Aim (`R_TRIG`) | Hold for Free Look / Preview |
| **A (`JOY1_A`)** | Cycle Weapons | **Select / Confirm** |
| **B (`JOY1_B`)** | Activate / Open Doors / Use | **Back / Cancel** |
| **Y (`JOY1_Y`)** | **Reload Weapon** | — |
| **X (`JOY1_X`)** | **Toggle Secondary Fire Mode (Alt-Fire)** | — |
| **Start (`JOY1_START`)** | Pause / Unpause | Confirm / Close Menu |
| **Fn + D-Pad Up / Down** | System Volume Up (`+5%`) / Down (`-5%`) | System Volume Up / Down |
| **Fn + Start** | **Quit to EmulationStation** | **Quit to EmulationStation** |

---

## Build & Installation Instructions

### 1. Install Dependencies (Raspbian / RetroPie on Raspberry Pi Zero 2W)
```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake git python3 libsdl2-dev zlib1g-dev
```

### 2. Clone the Upstream Repository at Base Commit `32a1cb9f2`
```bash
git clone --branch port https://github.com/fgsfdsfgs/perfect_dark.git ~/perfect_dark
cd ~/perfect_dark
git checkout 32a1cb9f268dd3ac73016801025c6bbbfa20130f
```

### 3. Apply the Desired Variant Patch & Stage Runtime Configs
Use `scripts/apply_patch.sh` to apply either `generic` or `pitin`:

**For Pi Tin Handheld:**
```bash
chmod +x ./scripts/apply_patch.sh
./scripts/apply_patch.sh pitin ~/perfect_dark ~/perfectdark
```

**For Generic Raspberry Pi Zero 2W:**
```bash
chmod +x ./scripts/apply_patch.sh
./scripts/apply_patch.sh generic ~/perfect_dark ~/perfectdark
```

### 4. Compile Perfect Dark
```bash
cd ~/perfect_dark
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j2
cp build/pd.* ~/perfectdark/ 2>/dev/null || cp pd.* ~/perfectdark/
```

### 5. Supply Your Legal ROM & Configure RetroPie Ports
1. Copy your NTSC-Final v1.1 ROM into `~/perfectdark/data/pd.ntsc-final.z64`:
   ```bash
   cp /path/to/your/pd.ntsc-final.z64 ~/perfectdark/data/pd.ntsc-final.z64
   ```
2. Install the launcher into RetroPie's Ports menu:
   ```bash
   cp ~/perfectdark/perfectdark.sh ~/RetroPie/roms/ports/Perfect\ Dark.sh
   chmod +x ~/RetroPie/roms/ports/Perfect\ Dark.sh
   ```
3. *(Pi Tin Only)* Register the `Fn + D-Pad Up/Down` hardware volume combos in `GPIOnext`:
   ```bash
   python3 ./scripts/setup_pitin_volume.py
   ```
