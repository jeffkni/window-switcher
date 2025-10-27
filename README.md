# Window Switcher & Screenshot Suite

A powerful productivity suite for Windows built with AutoHotkey v2, featuring:
- **Enhanced Window Switcher** - Custom Alt+Tab replacement with advanced features
- **Drag-Area Screenshot Tool** - Precise screenshot capture with fixed anchor points

## 📋 Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Window Switcher](#window-switcher)
- [Screenshot Tool](#screenshot-tool)
- [License](#license)

---

## 🔧 Requirements

This suite requires **AutoHotkey v2** (not v1).

### Download AutoHotkey v2
**https://www.autohotkey.com/download/**

⚠️ **Important**: Make sure to download **AutoHotkey v2**, not the legacy v1 version.

---

## 🚀 Installation

### Option 1: Run Scripts Directly
1. Install AutoHotkey v2
2. Right-click the `.ahk` files and select "Run with AutoHotkey64.exe"
3. Or double-click if AutoHotkey is your default handler

### Option 2: Compile to Executables
You can compile scripts to standalone executables using **Ahk2Exe.exe**.

#### Get Ahk2Exe
- https://www.autohotkey.com/download/

#### Compilation Commands
```bash
# Compile Window Switcher
Ahk2Exe.exe /in switcher.ahk /out window-switcher.exe /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

# Compile Screenshot Tool
Ahk2Exe.exe /in screenshooter.ahk /out screenshooter.exe /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
```

## 🪟 Window Switcher

### Features
- **Enhanced Alt+Tab** - Replaces Windows' native Alt+Tab with a modern interface
- **All Windows** - Shows all windows including minimized ones
- **Multi-row Layout** - Automatically expands for many windows (10+ icons per row)
- **Keyboard & Mouse Navigation** - Use Tab/Shift+Tab or click icons
- **Window Management** - Press Q to close windows while switching
- **External Keyboard Support** - Win+Tab works the same as Alt+Tab
- **Modern Dark UI** - Dark theme with magenta selection indicator
- **Time Display** - Shows NY and UK times for global productivity
- **CapsLock Remap** - CapsLock acts as Ctrl for convenience

### Controls

#### Basic Navigation
- **Alt or LWIN +Tab** - Open window switcher
- **Tab** / **Shift+Tab** - Navigate through windows (shift to reverse)
- **Enter** / **Release Alt** - Switch to selected window
- **Esc** - Cancel and return to original window

#### Advanced Window Management
- **Q** / **Alt+Q** - Close the selected window (while Alt is held)
- **Mouse Click** - Click any icon to switch to that window

### Visual Layout

Window ALT+Tab Switcher Interface:

```
┌────────────────────────────────────────────────────────────┐
│  A  B  C  D  [E]  F  G  H  I  J                            │
│                                                            │
│  Currently Selected: Chrome - Gmail                        │
│  14:32 NY | 19:32 UK                                       │
└────────────────────────────────────────────────────────────┘
```

## 📸 Screenshot Tool

### Features
- **Fixed Anchor Point** - CTL+9 to set anchor then drag to define area
- **Dual Output** - Copies to clipboard, saves to file, and opens in MS Pain
- **DPI Aware** - Handles high-DPI displays correctly
- **Organized Storage** - Saves to `C:\temp\screenshots\` with timestamps
- **Escape** - Cancel screenshot mode

**Permission errors**
- Run as administrator if accessing protected areas
- Change screenshot output directory if `C:\temp\` is restricted

## 📄 License

See LICENSE.txt for license information.
