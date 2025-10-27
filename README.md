# Window Switcher & Screenshot Suite

A powerful productivity suite for Windows built with AutoHotkey v2, featuring:
- **Enhanced Window Switcher** - Custom Alt+Tab replacement with advanced features
- **Drag-Area Screenshot Tool** - Precise screenshot capture with fixed anchor points

## 📋 Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Window Switcher](#window-switcher)
- [Screenshot Tool](#screenshot-tool)
- [Workflow Diagrams](#workflow-diagrams)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)

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
- **Location**: `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe`
- **Or download separately**: https://www.autohotkey.com/download/

#### Compilation Commands
```bash
# Compile Window Switcher
Ahk2Exe.exe /in single-switcher.ahk /out window-switcher.exe /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

# Compile Screenshot Tool
Ahk2Exe.exe /in screenshoter.ahk /out screenshoter.exe /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
```

---

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
- **Alt+Tab** / **Win+Tab** - Open window switcher
- **Tab** / **Shift+Tab** - Navigate through windows
- **Enter** / **Release Alt** - Switch to selected window
- **Esc** / **Alt+Esc** - Cancel and return to original window

#### Advanced Window Management
- **Q** / **Alt+Q** - Close the selected window (while Alt is held)
- **Mouse Click** - Click any icon to switch to that window

### Visual Layout

```
Window Switcher Interface:
┌─────────────────────────────────────────────────────────────┐
│  [A] [B] [C] [D] [E] [F] [G] [H] [I] [J]                   │
│  [K] [L] [M] [N] [O] [P] [Q] [R] [S] [T]                   │
│                                                             │
│  Currently Selected: Chrome - Gmail                        │
│  14:32 NY | 19:32 UK                                      │
└─────────────────────────────────────────────────────────────┘

Legend:
[X] = Window icon (with app icon or first 2 letters)
Magenta border around selected window
Dark semi-transparent background
```

---

## 📸 Screenshot Tool

### Features
- **Fixed Anchor Point** - Click once to set anchor, drag to define area
- **Visual Feedback** - Red dot shows anchor point, magenta rectangle shows selection
- **Precise Selection** - Drag from anchor in any direction (all 4 quadrants)
- **Dual Output** - Copies to clipboard AND saves to file
- **Auto-Open in Paint** - Immediately opens screenshot in MS Paint for editing
- **DPI Aware** - Handles high-DPI displays correctly
- **Organized Storage** - Saves to `C:\temp\screenshots\` with timestamps

### Controls
- **Ctrl+9** - Activate screenshot mode
- **Move Mouse** - Drag selection area from anchor point
- **Left Click** - Capture the selected area
- **Escape** - Cancel screenshot mode

### Visual Workflow

```
Screenshot Process:

1. Activation (Ctrl+9):
   ┌─────────────────────────────────────────┐
   │ [Semi-transparent dark overlay]         │
   │                                         │
   │ Move mouse to select area from anchor   │
   │ point. Click to capture. ESC to cancel. │
   │                                         │
   │         🔴 ← Red anchor dot             │
   │                                         │
   └─────────────────────────────────────────┘

2. Selection Phase:
   ┌─────────────────────────────────────────┐
   │ [Dark overlay with magenta selection]   │
   │                                         │
   │        🔴●━━━━━━━━━┓                     │
   │        ┃ Magenta  ┃                     │
   │        ┃Selection ┃                     │
   │        ┃Rectangle ┃                     │
   │        ┗━━━━━━━━━━┛                     │
   │                                         │
   └─────────────────────────────────────────┘

3. Capture Result:
   • Image copied to clipboard
   • Saved to: C:\temp\screenshots\Screenshot_YYYYMMDD_HHMMSS.png
   • MS Paint opens with the image ready for editing
```

---

## 🔄 Workflow Diagrams

### Window Switcher Flow

```
Alt+Tab Pressed
       │
       ▼
┌─────────────────┐    ┌──────────────────┐
│ Collect All     │───▶│ Create Multi-Row │
│ Switchable      │    │ Visual Layout    │
│ Windows         │    │                  │
└─────────────────┘    └──────────────────┘
       │                        │
       ▼                        ▼
┌─────────────────┐    ┌──────────────────┐
│ Filter Out:     │    │ Show Switcher    │
│ • Hidden        │    │ • Dark theme     │
│ • System        │    │ • Icons/letters  │
│ • Zoom utils    │    │ • Time display   │
└─────────────────┘    └──────────────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       ▼                       ▼                       ▼
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Tab/Shift   │    │ Click Icon       │    │ Alt+Q: Close    │
│ Navigate    │    │ Direct Switch    │    │ Selected Window │
└─────────────┘    └──────────────────┘    └─────────────────┘
       │                       │                       │
       ▼                       ▼                       ▼
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Alt Release │    │ Immediate        │    │ Remove Icon,    │
│ Activates   │    │ Activation       │    │ Re-layout,      │
│ Selection   │    │                  │    │ Focus Next      │
└─────────────┘    └──────────────────┘    └─────────────────┘
```

### Screenshot Tool Flow

```
Ctrl+9 Pressed
       │
       ▼
┌─────────────────┐    ┌──────────────────┐
│ Capture Mouse   │───▶│ Create Overlay   │
│ Position as     │    │ • Dark semi-     │
│ Fixed Anchor    │    │   transparent    │
└─────────────────┘    │ • Red dot at     │
                       │   anchor         │
                       └──────────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │ Track Mouse      │
                    │ Movement         │
                    │ (10ms updates)   │
                    └──────────────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       ▼                       ▼                       ▼
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Mouse Move  │    │ Left Click       │    │ Escape Key      │
│ Updates     │    │ Capture Area     │    │ Cancel Mode     │
│ Selection   │    │                  │    │                 │
└─────────────┘    └──────────────────┘    └─────────────────┘
       │                       │                       │
       ▼                       ▼                       ▼
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Show        │    │ Screenshot       │    │ Clean Up        │
│ Magenta     │    │ • Copy to        │    │ • Close GUIs    │
│ Rectangle   │    │   clipboard      │    │ • Restore       │
│             │    │ • Save to file   │    │   cursor        │
│             │    │ • Open MS Paint  │    │                 │
└─────────────┘    └──────────────────┘    └─────────────────┘
```

### Quadrant Selection Logic

The screenshot tool handles dragging in all four quadrants from the anchor point:

```
Selection Quadrants (Anchor at center ●):

    W Quadrant  │  X Quadrant
   ┌─────────┐  │  ┌─────────┐
   │    ╔════●══╗  │
   │    ║    │  ║  │     
   │    ║    │  ║  │
   ────────────●────────────── 
   │    ║    │  ║  │
   │    ║    │  ║  │
   │    ╚════●══╝  │
   └─────────┘  │  └─────────┘
    Y Quadrant  │  Z Quadrant

● = Fixed anchor point (red dot)
╔═╗ = Magenta selection rectangle
║ ║ = Grows in any direction from anchor

Anchor Position in Rectangle:
• W: Anchor at bottom-right corner
• X: Anchor at bottom-left corner  
• Y: Anchor at top-right corner
• Z: Anchor at top-left corner
```

---

## ⚙️ Customization

### Window Switcher Settings
Located at the top of `single-switcher.ahk`:

```ahk
; Layout settings
IconSize := 48                ; Size of window icons
IconSpacing := 8             ; Space between icons
MaxIconsPerRow := 10         ; Icons per row before wrapping

; Debug logging
DebugLoggingEnabled := false  ; Set to true for troubleshooting
```

### Screenshot Tool Settings
Located at the top of `screenshoter.ahk`:

```ahk
; Hotkey (change Ctrl+9 to something else)
^9::StartDragScreenshot()

; Output directory
ScreenshotDir := "C:\temp\screenshots"

; Transparency levels
WinSetTransparent(50, OverlayGui.HWND)     ; Dark overlay
WinSetTransparent(120, SelectionGui.HWND)  ; Selection rectangle
```

### Color Customization

#### Window Switcher Colors
```ahk
WindowSwitcher.BackColor := 0x404040     ; Dark gray background
BorderColor := 0xFF00FF                   ; Magenta selection border
TextColor := "cWhite"                     ; White text
```

#### Screenshot Tool Colors
```ahk
SelectionGui.BackColor := "0xFF00FF"      ; Magenta selection
ReferenceGui.BackColor := "Red"           ; Red anchor dot
OverlayGui.BackColor := "Black"           ; Dark overlay
```

---

## 🔍 Troubleshooting

### Window Switcher Issues

**Script won't run**
- Ensure AutoHotkey v2 is installed (not v1)
- Right-click → "Run with AutoHotkey64.exe"

**Icons are missing or show letters**
- Normal behavior for apps without icons
- First 2 letters of app name are shown instead

**Zoom windows cluttering the switcher**
- The script automatically filters out Zoom utility windows
- If you see unwanted windows, check the `IsValidSwitchableWindow()` function

**Alt+Q closes wrong window**
- Make sure the magenta border is around the intended window
- Use Tab/Shift+Tab to navigate before pressing Q

### Screenshot Tool Issues

**Ctrl+9 doesn't work**
- Another application might be using this hotkey
- Change `^9::` to a different key combination in the script

**Selection rectangle appears in wrong position**
- This can happen on high-DPI displays
- The script automatically detects and compensates for DPI scaling

**Screenshots are too small/large**
- DPI scaling issue - the script detects this automatically
- If problems persist, try running as administrator

**MS Paint doesn't open with screenshot**
- Screenshots are still saved to `C:\temp\screenshots\`
- Manually open the file or change the output application

### General Issues

**Scripts conflict with each other**
- Both scripts can run simultaneously without issues
- Use `#SingleInstance Force` if you need to reload

**High CPU usage**
- Disable debug logging in both scripts
- The screenshot tool only uses CPU during active selection

**Permission errors**
- Run as administrator if accessing protected areas
- Change screenshot output directory if `C:\temp\` is restricted

---

## 📁 File Structure

```
window-switcher/
├── single-switcher.ahk      # Window switcher main script
├── screenshoter.ahk         # Screenshot tool main script  
├── README.md                # This documentation
├── LICENSE.txt              # License information
└── Ahk2Exe.exe             # AutoHotkey compiler
```

## 🔗 Integration

Both tools are designed to work together as a productivity suite:

1. **Use the Window Switcher** to quickly navigate between applications
2. **Use Alt+Q** to close unnecessary windows and keep your workspace clean
3. **Use the Screenshot Tool** to capture specific areas for documentation or sharing
4. **CapsLock as Ctrl** makes keyboard shortcuts more comfortable

This combination provides a complete window management and screenshot workflow optimized for productivity.

---

## 📄 License

See LICENSE.txt for license information.

---

*Built with AutoHotkey v2 for enhanced Windows productivity*