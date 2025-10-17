# External Keyboard Setup Guide

This guide shows how to set up hotkeys that only work on your external keyboard using AutoHotInterception.

## Setup Steps

### 1. Download AutoHotInterception
1. Download from: https://github.com/evilC/AutoHotInterception
2. Extract to `AutoHotInterception` folder in your window-switcher directory

### 2. Find Your Keyboard's HID
1. Run `find-keyboard-hid.ahk` 
2. Note the VID and PID values for your external keyboard
3. Update the values in `single-switcher.ahv`:

```autohotkey
EXTERNAL_KEYBOARD_VID := 0x1234  ; Replace with your keyboard's VID
EXTERNAL_KEYBOARD_PID := 0x5678  ; Replace with your keyboard's PID
```

### 3. Test the Setup
- Alt+Tab on your **external keyboard** should trigger the window switcher
- Alt+Tab on your **laptop/built-in keyboard** should work normally
- If setup correctly, only the external keyboard will trigger your custom switcher

## Adding More External-Only Hotkeys

### Example: F1 Key Only on External Keyboard
```autohotkey
; Uncomment this line to enable F1 on external keyboard only
AddExternalKeyboardHotkey(59, ExternalF1)  ; 59 = F1 scancode

ExternalF1() {
    MsgBox("F1 pressed on external keyboard!", "External Keyboard")
}
```

### Example: Custom Function Keys
```autohotkey
; F2 for external keyboard only
AddExternalKeyboardHotkey(60, () => Run("calc.exe"))  ; F2 = Calculator

; F3 for external keyboard only  
AddExternalKeyboardHotkey(61, () => Run("notepad.exe"))  ; F3 = Notepad
```

### Common Scancodes
- F1 = 59, F2 = 60, F3 = 61, F4 = 62
- F5 = 63, F6 = 64, F7 = 65, F8 = 66
- F9 = 67, F10 = 68, F11 = 87, F12 = 88
- Tab = 15, Enter = 28, Space = 57
- A = 30, B = 48, C = 46, D = 32, E = 18

## Benefits

✅ **Laptop keyboard**: Works normally with Windows default Alt+Tab  
✅ **External keyboard**: Uses your custom unified switcher  
✅ **No conflicts**: Each keyboard has its own hotkey behavior  
✅ **Extensible**: Easy to add more external-only hotkeys

## Troubleshooting

- **"External keyboard not detected"**: Update VID/PID values from step 2
- **AutoHotInterception errors**: Make sure the library is in the correct folder
- **Keys not working**: Check scancodes and ensure external keyboard is connected
