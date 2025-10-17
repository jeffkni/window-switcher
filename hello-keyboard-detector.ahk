; HELLO WORLD - Keyboard Source Detector
; Press 'A' to see if it came from internal or external keyboard

; Constants for Raw Input API
RIDEV_INPUTSINK := 0x00000100
RIM_TYPEKEYBOARD := 1
WM_INPUT := 0x00FF
RAWINPUTDEVICE_SIZE := 12
RAWINPUTHEADER_SIZE := 24

; Global variables to track keyboards
global KeyboardDevices := Map()
global InternalKeyboardHandle := 0
global ExternalKeyboardHandles := []

; Initialize the detector
InitializeKeyboardDetector()

; Simple hotkey for the letter A
~a:: {
    ; This will be overridden by raw input detection
    ; The ~ allows the key to still function normally
}

; Function to initialize keyboard detection
InitializeKeyboardDetector() {
    ; Create a hidden window to receive raw input messages
    global HiddenGui := Gui("+ToolWindow -MaximizeBox -MinimizeBox", "Keyboard Detector")
    HiddenGui.Show("Hide")
    
    ; Give the GUI time to be created
    Sleep(100)
    
    ; Get the window handle
    try {
        guiHwnd := HiddenGui.Hwnd
        if (!guiHwnd) {
            MsgBox("Failed to get GUI handle!")
            return
        }
    } catch as e {
        MsgBox("Error getting GUI handle: " e.Message)
        return
    }
    
    ; Debug: Show the handle value
    MsgBox("GUI Handle: " guiHwnd " (Type: " Type(guiHwnd) ")")
    
    ; Register for raw input from all keyboards
    rid := Buffer(RAWINPUTDEVICE_SIZE, 0)
    
    try {
        NumPut("UShort", 1, rid, 0)        ; usUsagePage = 1 (Generic Desktop)
        NumPut("UShort", 6, rid, 2)        ; usUsage = 6 (Keyboard)  
        NumPut("UInt", RIDEV_INPUTSINK, rid, 4)  ; dwFlags
        NumPut("UInt", guiHwnd, rid, 8)    ; hwndTarget (try UInt instead of Ptr)
        
        result := DllCall("user32.dll\RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", RAWINPUTDEVICE_SIZE)
    } catch as e {
        MsgBox("Error in NumPut or DllCall: " e.Message)
        return
    }
    
    if (result) {
        ; Enumerate keyboards to identify internal vs external
        EnumerateKeyboards()
        
        ; Hook the WM_INPUT message
        OnMessage(WM_INPUT, ProcessKeyPress)
        
        TrayTip("Hello Keyboard Detector", "Press 'A' to test keyboard detection!", "Iconi")
    } else {
        lastError := A_LastError
        MsgBox("Failed to initialize keyboard detection!`nError code: " lastError "`n`nTry running as Administrator or use simple-hello-detector.ahk instead.")
        return
    }
}

; Function to enumerate and categorize keyboards
EnumerateKeyboards() {
    ; Get number of devices
    deviceCount := 0
    DllCall("user32.dll\GetRawInputDeviceList", "Ptr", 0, "UInt*", &deviceCount, "UInt", 8)
    
    if (deviceCount = 0) {
        return
    }
    
    ; Get device list
    deviceList := Buffer(deviceCount * 8, 0)
    DllCall("user32.dll\GetRawInputDeviceList", "Ptr", deviceList, "UInt*", &deviceCount, "UInt", 8)
    
    ; Process each device
    Loop deviceCount {
        offset := (A_Index - 1) * 8
        handle := NumGet(deviceList, offset, "Ptr")
        type := NumGet(deviceList, offset + A_PtrSize, "UInt")
        
        ; Only process keyboards
        if (type = RIM_TYPEKEYBOARD) {
            deviceName := GetDeviceName(handle)
            KeyboardDevices[handle] := deviceName
            
            ; Simple heuristic: if device name contains certain keywords, it's likely internal
            if (InStr(deviceName, "HID") && !InStr(deviceName, "USB")) {
                ; Likely internal keyboard (HID but not USB)
                InternalKeyboardHandle := handle
            } else if (InStr(deviceName, "USB") || InStr(deviceName, "VID_")) {
                ; Likely external keyboard (USB device)
                ExternalKeyboardHandles.Push(handle)
            }
        }
    }
}

; Function to get device name
GetDeviceName(handle) {
    ; Get required buffer size
    size := 0
    DllCall("user32.dll\GetRawInputDeviceInfoW", "Ptr", handle, "UInt", 0x20000007, "Ptr", 0, "UInt*", &size)
    
    if (size = 0) {
        return "Unknown"
    }
    
    ; Get device name
    nameBuffer := Buffer(size * 2, 0)
    DllCall("user32.dll\GetRawInputDeviceInfoW", "Ptr", handle, "UInt", 0x20000007, "Ptr", nameBuffer, "UInt*", &size)
    
    return StrGet(nameBuffer, "UTF-16")
}

; Function to process key presses
ProcessKeyPress(wParam, lParam, msg, hwnd) {
    ; Get raw input data size
    size := 0
    DllCall("user32.dll\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", &size, "UInt", RAWINPUTHEADER_SIZE)
    
    if (size = 0) {
        return
    }
    
    ; Get raw input data
    rawData := Buffer(size, 0)
    DllCall("user32.dll\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", rawData, "UInt*", &size, "UInt", RAWINPUTHEADER_SIZE)
    
    ; Parse header
    type := NumGet(rawData, 0, "UInt")
    deviceHandle := NumGet(rawData, 8, "Ptr")
    
    if (type != RIM_TYPEKEYBOARD) {
        return
    }
    
    ; Parse keyboard data
    keyboardData := rawData.Ptr + RAWINPUTHEADER_SIZE
    flags := NumGet(keyboardData, 2, "UShort")
    vkCode := NumGet(keyboardData, 6, "UShort")
    
    ; Only process key down events for the letter 'A'
    if (flags & 1) {
        return  ; Skip key up events
    }
    if (vkCode != 0x41) {
        return  ; Only process 'A' key (VK_A = 0x41)
    }
    
    ; Determine if it's internal or external
    keyboardType := "UNKNOWN"
    deviceName := KeyboardDevices.Has(deviceHandle) ? KeyboardDevices[deviceHandle] : "Unknown Device"
    
    if (deviceHandle = InternalKeyboardHandle) {
        keyboardType := "INTERNAL"
    } else {
        for externalHandle in ExternalKeyboardHandles {
            if (deviceHandle = externalHandle) {
                keyboardType := "EXTERNAL"
                break
            }
        }
    }
    
    ; Show the debug dialog
    timestamp := FormatTime(, "HH:mm:ss")
    MsgBox("🎉 HELLO WORLD - Key Detection! 🎉`n`n" .
           "Key Pressed: A`n" .
           "Time: " timestamp "`n" .
           "Keyboard Type: " keyboardType "`n" .
           "Device: " deviceName, 
           "Keyboard Detector", "T5")  ; Auto-close after 5 seconds
}

; Show initial message
MsgBox("🎹 Hello World Keyboard Detector! 🎹`n`n" .
       "This script will detect when you press the letter 'A'`n" .
       "and show whether it came from an INTERNAL or EXTERNAL keyboard.`n`n" .
       "Press 'A' to test it!", 
       "Hello World", "T10")
