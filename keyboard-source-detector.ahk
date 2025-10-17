; Keyboard Source Detector - Detect which keyboard a key came from
; Uses Windows Raw Input API to distinguish between keyboards

; Constants for Raw Input
RIDEV_INPUTSINK := 0x00000100
RIM_TYPEKEYBOARD := 1
WM_INPUT := 0x00FF

; Structure sizes
RAWINPUTDEVICE_SIZE := 12
RAWINPUTHEADER_SIZE := 24

; Global variables
global KeyboardDevices := Map()
global MainGui := 0

; Create GUI to show results
MainGui := Gui("+Resize", "Keyboard Source Detector")
MainGui.SetFont("s10", "Consolas")
MainGui.Add("Text", "x10 y10 w400 h20", "Press keys to see which keyboard they came from:")
global OutputText := MainGui.Add("Edit", "x10 y40 w400 h200 ReadOnly VScroll")
MainGui.Add("Text", "x10 y250 w400 h20", "Press Escape to exit")
MainGui.Show("w420 h280")

; Register for raw input from all keyboards
RegisterRawInput()

; Hook the WM_INPUT message
OnMessage(WM_INPUT, ProcessRawInput)

; Function to register for raw input
RegisterRawInput() {
    ; Allocate memory for RAWINPUTDEVICE structure
    rid := Buffer(RAWINPUTDEVICE_SIZE, 0)
    
    ; Set up the structure for keyboards
    NumPut("UShort", 1, rid, 0)        ; usUsagePage = 1 (Generic Desktop)
    NumPut("UShort", 6, rid, 2)        ; usUsage = 6 (Keyboard)
    NumPut("UInt", RIDEV_INPUTSINK, rid, 4)  ; dwFlags
    NumPut("Ptr", MainGui.Hwnd, rid, 8)      ; hwndTarget
    
    ; Register the device
    result := DllCall("user32.dll\RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", RAWINPUTDEVICE_SIZE)
    
    if (!result) {
        MsgBox("Failed to register for raw input: " A_LastError)
        return false
    }
    
    ; Enumerate existing keyboards
    EnumerateKeyboards()
    return true
}

; Function to enumerate all keyboard devices
EnumerateKeyboards() {
    ; Get number of devices
    deviceCount := 0
    DllCall("user32.dll\GetRawInputDeviceList", "Ptr", 0, "UInt*", &deviceCount, "UInt", 8)
    
    if (deviceCount = 0) {
        OutputText.Text .= "No input devices found`r`n"
        return
    }
    
    ; Allocate buffer for device list
    deviceList := Buffer(deviceCount * 8, 0)
    result := DllCall("user32.dll\GetRawInputDeviceList", "Ptr", deviceList, "UInt*", &deviceCount, "UInt", 8)
    
    if (result = -1) {
        OutputText.Text .= "Failed to get device list`r`n"
        return
    }
    
    OutputText.Text .= "=== Found Keyboards ===`r`n"
    
    ; Process each device
    Loop deviceCount {
        offset := (A_Index - 1) * 8
        handle := NumGet(deviceList, offset, "Ptr")
        type := NumGet(deviceList, offset + A_PtrSize, "UInt")
        
        ; Only process keyboards
        if (type = RIM_TYPEKEYBOARD) {
            deviceName := GetDeviceName(handle)
            KeyboardDevices[handle] := deviceName
            OutputText.Text .= "Keyboard " A_Index ": " deviceName "`r`n"
        }
    }
    
    OutputText.Text .= "`r`n=== Press keys to test ===`r`n"
}

; Function to get device name from handle
GetDeviceName(handle) {
    ; Get required buffer size
    size := 0
    DllCall("user32.dll\GetRawInputDeviceInfoW", "Ptr", handle, "UInt", 0x20000007, "Ptr", 0, "UInt*", &size)
    
    if (size = 0) {
        return "Unknown Device"
    }
    
    ; Allocate buffer and get device name
    nameBuffer := Buffer(size * 2, 0)  ; Unicode = 2 bytes per char
    result := DllCall("user32.dll\GetRawInputDeviceInfoW", "Ptr", handle, "UInt", 0x20000007, "Ptr", nameBuffer, "UInt*", &size)
    
    if (result = -1) {
        return "Error Getting Name"
    }
    
    deviceName := StrGet(nameBuffer, "UTF-16")
    
    ; Extract meaningful part of the name
    if (InStr(deviceName, "VID_")) {
        ; Extract VID and PID
        RegExMatch(deviceName, "VID_([0-9A-F]{4}).*PID_([0-9A-F]{4})", &match)
        if (match) {
            return "VID_" match[1] " PID_" match[2]
        }
    }
    
    return deviceName
}

; Function to process raw input messages
ProcessRawInput(wParam, lParam, msg, hwnd) {
    ; Get the size of the raw input data
    size := 0
    DllCall("user32.dll\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", &size, "UInt", RAWINPUTHEADER_SIZE)
    
    if (size = 0) {
        return
    }
    
    ; Allocate buffer and get the data
    rawData := Buffer(size, 0)
    result := DllCall("user32.dll\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", rawData, "UInt*", &size, "UInt", RAWINPUTHEADER_SIZE)
    
    if (result = -1) {
        return
    }
    
    ; Parse the raw input header
    type := NumGet(rawData, 0, "UInt")
    dataSize := NumGet(rawData, 4, "UInt")
    deviceHandle := NumGet(rawData, 8, "Ptr")
    
    ; Only process keyboard input
    if (type != RIM_TYPEKEYBOARD) {
        return
    }
    
    ; Parse keyboard data (starts after header)
    keyboardData := rawData.Ptr + RAWINPUTHEADER_SIZE
    makeCode := NumGet(keyboardData, 0, "UShort")
    flags := NumGet(keyboardData, 2, "UShort")
    vkCode := NumGet(keyboardData, 6, "UShort")
    
    ; Only show key down events
    if (flags & 1) {  ; RI_KEY_BREAK = key up
        return
    }
    
    ; Get device name
    deviceName := KeyboardDevices.Has(deviceHandle) ? KeyboardDevices[deviceHandle] : "Unknown"
    
    ; Get key name
    keyName := GetKeyName(Format("vk{:02X}", vkCode))
    if (!keyName) {
        keyName := "VK_" Format("{:02X}", vkCode)
    }
    
    ; Display the result
    timestamp := FormatTime(, "HH:mm:ss")
    OutputText.Text .= timestamp " - " keyName " from: " deviceName "`r`n"
    
    ; Auto-scroll to bottom
    OutputText.Focus()
    Send("^{End}")
    
    ; Exit on Escape
    if (vkCode = 0x1B) {
        ExitApp
    }
}

; Cleanup on exit
OnExit((*) => {
    ; Unregister raw input
    rid := Buffer(RAWINPUTDEVICE_SIZE, 0)
    NumPut("UShort", 1, rid, 0)
    NumPut("UShort", 6, rid, 2)
    NumPut("UInt", 0x00000001, rid, 4)  ; RIDEV_REMOVE
    NumPut("Ptr", 0, rid, 8)
    DllCall("user32.dll\RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", RAWINPUTDEVICE_SIZE)
})

; Show startup message
TrayTip("Keyboard Source Detector", "Press keys to see which keyboard they came from`nPress Escape to exit")
