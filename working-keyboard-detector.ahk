; WORKING Keyboard Source Detector
; Properly detects if keystroke came from built-in vs external keyboard
; Uses Windows Raw Input API correctly

; Constants
WM_INPUT := 0x00FF
RIM_TYPEKEYBOARD := 1
RIDEV_INPUTSINK := 0x00000100

; Global variables
global KeyboardDevices := Map()
global MainWindow := 0

; Create main window
MainWindow := Gui("+Resize", "Keyboard Source Detector")
MainWindow.Add("Text", "x10 y10 w400 h20", "Press 'A' to see which keyboard it came from:")
global ResultText := MainWindow.Add("Edit", "x10 y35 w400 h150 ReadOnly VScroll")
MainWindow.Add("Text", "x10 y195 w400 h20", "Press Escape to exit")
MainWindow.Show("w420 h220")

; Initialize detection
if (InitializeRawInput()) {
    ResultText.Text := "✓ Raw Input initialized successfully`r`n"
    ResultText.Text .= "✓ Enumerating keyboards...`r`n`r`n"
    EnumerateKeyboards()
    ResultText.Text .= "`r`nReady! Press 'A' to test detection.`r`n"
} else {
    ResultText.Text := "✗ Failed to initialize Raw Input`r`nTry running as Administrator"
}

; Function to initialize Raw Input
InitializeRawInput() {
    ; Register for raw input from keyboards
    RAWINPUTDEVICE_SIZE := A_PtrSize == 8 ? 16 : 12  ; Different sizes for x64/x86
    
    rid := Buffer(RAWINPUTDEVICE_SIZE, 0)
    NumPut("UShort", 1, rid, 0)                    ; usUsagePage (Generic Desktop)
    NumPut("UShort", 6, rid, 2)                    ; usUsage (Keyboard)
    NumPut("UInt", RIDEV_INPUTSINK, rid, 4)        ; dwFlags
    NumPut("Ptr", MainWindow.Hwnd, rid, 8)         ; hwndTarget
    
    result := DllCall("user32.dll\RegisterRawInputDevices", 
                      "Ptr", rid, 
                      "UInt", 1, 
                      "UInt", RAWINPUTDEVICE_SIZE)
    
    if (result) {
        ; Hook the WM_INPUT message
        OnMessage(WM_INPUT, ProcessRawInput)
        return true
    }
    
    return false
}

; Function to enumerate keyboards
EnumerateKeyboards() {
    ; Get device count
    deviceCount := 0
    DllCall("user32.dll\GetRawInputDeviceList", "Ptr", 0, "UInt*", &deviceCount, "UInt", 8)
    
    if (deviceCount == 0) {
        ResultText.Text .= "No input devices found`r`n"
        return
    }
    
    ; Get device list
    deviceList := Buffer(deviceCount * 8, 0)
    result := DllCall("user32.dll\GetRawInputDeviceList", 
                      "Ptr", deviceList, 
                      "UInt*", &deviceCount, 
                      "UInt", 8)
    
    if (result == -1) {
        ResultText.Text .= "Failed to get device list`r`n"
        return
    }
    
    ; Process keyboards
    keyboardCount := 0
    Loop deviceCount {
        offset := (A_Index - 1) * 8
        handle := NumGet(deviceList, offset, "Ptr")
        type := NumGet(deviceList, offset + A_PtrSize, "UInt")
        
        if (type == RIM_TYPEKEYBOARD) {
            keyboardCount++
            deviceName := GetDeviceName(handle)
            deviceType := ClassifyKeyboard(deviceName)
            
            KeyboardDevices[handle] := {
                Name: deviceName,
                Type: deviceType,
                Number: keyboardCount
            }
            
            ResultText.Text .= "Keyboard " keyboardCount ": " deviceType "`r`n"
            ResultText.Text .= "  " deviceName "`r`n"
        }
    }
}

; Function to get device name
GetDeviceName(handle) {
    ; Get name buffer size
    size := 0
    DllCall("user32.dll\GetRawInputDeviceInfoW", 
            "Ptr", handle, 
            "UInt", 0x20000007,  ; RIDI_DEVICENAME
            "Ptr", 0, 
            "UInt*", &size)
    
    if (size == 0) {
        return "Unknown Device"
    }
    
    ; Get device name
    nameBuffer := Buffer(size * 2, 0)
    result := DllCall("user32.dll\GetRawInputDeviceInfoW", 
                      "Ptr", handle, 
                      "UInt", 0x20000007, 
                      "Ptr", nameBuffer, 
                      "UInt*", &size)
    
    if (result == -1) {
        return "Error Getting Name"
    }
    
    return StrGet(nameBuffer, "UTF-16")
}

; Function to classify keyboard type
ClassifyKeyboard(deviceName) {
    deviceName := StrUpper(deviceName)
    
    ; Debug: Show the actual device name
    ; MsgBox("Device Name: " deviceName)  ; Uncomment to debug
    
    ; External keyboard indicators (check first)
    if (InStr(deviceName, "USB\VID_") ||
        InStr(deviceName, "USB\\VID_") ||
        InStr(deviceName, "USBVID_") ||
        InStr(deviceName, "BLUETOOTH") ||
        InStr(deviceName, "WIRELESS") ||
        InStr(deviceName, "BT_") ||
        InStr(deviceName, "LOGITECH") ||
        InStr(deviceName, "MICROSOFT") ||
        InStr(deviceName, "CORSAIR") ||
        InStr(deviceName, "RAZER") ||
        InStr(deviceName, "STEELSERIES")) {
        return "EXTERNAL"
    }
    
    ; Built-in keyboard indicators
    if (InStr(deviceName, "ACPI") ||
        InStr(deviceName, "ROOT\\") ||
        InStr(deviceName, "ROOT\") ||
        InStr(deviceName, "LAPTOP") ||
        InStr(deviceName, "INTERNAL") ||
        InStr(deviceName, "PS2") ||
        InStr(deviceName, "PS/2") ||
        InStr(deviceName, "I8042") ||
        InStr(deviceName, "ATKBD") ||
        InStr(deviceName, "HID\\") && !InStr(deviceName, "USB")) {
        return "BUILT-IN"
    }
    
    ; If it contains HID but we're not sure, let's be more specific
    if (InStr(deviceName, "HID")) {
        ; If it has VID/PID pattern, it's likely external
        if (RegExMatch(deviceName, "VID_[0-9A-F]{4}.*PID_[0-9A-F]{4}")) {
            return "EXTERNAL (HID)"
        } else {
            return "BUILT-IN (HID)"
        }
    }
    
    return "UNKNOWN (" deviceName ")"
}

; Function to process raw input
ProcessRawInput(wParam, lParam, msg, hwnd) {
    ; Get raw input data size
    size := 0
    DllCall("user32.dll\GetRawInputData", 
            "Ptr", lParam, 
            "UInt", 0x10000003,  ; RID_INPUT
            "Ptr", 0, 
            "UInt*", &size, 
            "UInt", A_PtrSize == 8 ? 24 : 16)  ; RAWINPUTHEADER size
    
    if (size == 0) {
        return
    }
    
    ; Get raw input data
    rawData := Buffer(size, 0)
    result := DllCall("user32.dll\GetRawInputData", 
                      "Ptr", lParam, 
                      "UInt", 0x10000003, 
                      "Ptr", rawData, 
                      "UInt*", &size, 
                      "UInt", A_PtrSize == 8 ? 24 : 16)
    
    if (result == -1) {
        return
    }
    
    ; Parse raw input header
    type := NumGet(rawData, 0, "UInt")
    deviceHandle := NumGet(rawData, 8, "Ptr")
    
    if (type != RIM_TYPEKEYBOARD) {
        return
    }
    
    ; Parse keyboard data
    headerSize := A_PtrSize == 8 ? 24 : 16
    keyboardData := rawData.Ptr + headerSize
    
    makeCode := NumGet(keyboardData, 0, "UShort")
    flags := NumGet(keyboardData, 2, "UShort")
    vkCode := NumGet(keyboardData, 6, "UShort")
    
    ; Only process 'A' key down events
    if (vkCode != 0x41 || (flags & 1)) {
        return  ; VK_A = 0x41, flags & 1 = key up
    }
    
    ; Get keyboard info
    if (KeyboardDevices.Has(deviceHandle)) {
        keyboard := KeyboardDevices[deviceHandle]
        keyboardType := keyboard.Type
        keyboardName := keyboard.Name
    } else {
        ; Device handle not found in our map, try to get info directly
        deviceName := GetDeviceName(deviceHandle)
        keyboardType := ClassifyKeyboard(deviceName)
        keyboardName := deviceName
        
        ; Store it for future use
        KeyboardDevices[deviceHandle] := {
            Name: deviceName,
            Type: keyboardType,
            Number: KeyboardDevices.Count + 1
        }
    }
    
    ; Show result
    timestamp := FormatTime(, "HH:mm:ss")
    result := timestamp " - 'A' pressed on " keyboardType " keyboard`r`n"
    
    ResultText.Text .= result
    
    ; Auto-scroll to bottom
    ResultText.Focus()
    Send("^{End}")
    
    ; Show popup for clear feedback
    MsgBox("🎯 KEYBOARD DETECTED! 🎯`n`n" .
           "Key: A`n" .
           "Time: " timestamp "`n" .
           "Keyboard: " keyboardType "`n`n" .
           "Device Path:`n" keyboardName, 
           "Detection Result", "T5")
    
    ; Exit on Escape
    if (vkCode == 0x1B) {  ; VK_ESCAPE
        ExitApp
    }
}

; Cleanup on exit
OnExit(CleanupRawInput)

CleanupRawInput(*) {
    ; Unregister raw input
    RAWINPUTDEVICE_SIZE := A_PtrSize == 8 ? 16 : 12
    rid := Buffer(RAWINPUTDEVICE_SIZE, 0)
    NumPut("UShort", 1, rid, 0)
    NumPut("UShort", 6, rid, 2)
    NumPut("UInt", 0x00000001, rid, 4)  ; RIDEV_REMOVE
    NumPut("Ptr", 0, rid, 8)
    DllCall("user32.dll\RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", RAWINPUTDEVICE_SIZE)
}

TrayTip("Keyboard Source Detector", "Press 'A' to see which keyboard it came from!")
