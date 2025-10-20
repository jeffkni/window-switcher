# Window Switcher

A custom Alt+Tab window switcher for Windows built with AutoHotkey v2.

## Features

- **Enhanced Alt+Tab** - Replaces Windows' native Alt+Tab with a custom interface
- **All Windows** - Shows all windows including minimized ones
- **Multi-row Layout** - Automatically expands for many windows
- **Keyboard & Mouse** - Navigate with Tab/Shift+Tab or click icons
- **Window Management** - Press Q to close windows while switching
- **External Keyboard Support** - Win+Tab works the same as Alt+Tab
- **Modern UI** - Dark theme with magenta selection indicator

## Requirements

This script requires **AutoHotkey v2** (not v1).

### Download AutoHotkey v2
You can download AutoHotkey v2 from the official website:
**https://www.autohotkey.com/download/**

Make sure to download **AutoHotkey v2**, not the legacy v1 version.

## Running the Script

### Option 1: Run Directly
1. Install AutoHotkey v2
2. Right-click `single-switcher.ahk` and select "Run with AutoHotkey64.exe"
3. Or double-click the file if AutoHotkey is your default handler

### Option 2: Compile to EXE
You can compile the script to a standalone executable using **Ahk2Exe.exe**.

#### Get Ahk2Exe
Ahk2Exe comes with AutoHotkey v2 installation:
- **Location**: `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe`
- **Or download separately**: https://www.autohotkey.com/download/

#### Compile Instructions
1. Run `Ahk2Exe.exe`
2. **Source**: Browse to `single-switcher.ahk`
3. **Destination**: Choose output location (e.g., `window-switcher.exe`)
4. **Base File**: Make sure it points to AutoHotkey v2 executable
   - Usually: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`
5. Click **"Convert"**

#### Command Line Compilation
```bash
Ahk2Exe.exe /in single-switcher.ahk /out window-switcher.exe /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
```

## Usage

### Basic Controls
- **Alt+Tab** / **Win+Tab** - Open window switcher
- **Tab** / **Shift+Tab** - Navigate through windows
- **Enter** / **Release Alt** - Switch to selected window
- **Esc** - Cancel and return to original window

### Advanced Features
- **Q** - Close the selected window (while Alt is held)
- **Mouse Click** - Click any icon to switch to that window
- **CapsLock** - Remapped to Ctrl for convenience

### Multi-Row Layout
When you have more than 10 windows, icons automatically wrap to multiple rows and the window expands accordingly.

## Customization

The script includes several customizable settings at the top of the file:
- Icon size and spacing
- Maximum icons per row
- Colors and styling
- Debug logging (disabled by default)

## Troubleshooting

- **Script won't run**: Make sure you have AutoHotkey v2 installed
- **Compilation fails**: Verify Ahk2Exe is pointing to the correct AutoHotkey v2 executable
- **Icons missing**: The script uses native Windows icons - no external files needed

## License

See LICENSE.txt for license information.
