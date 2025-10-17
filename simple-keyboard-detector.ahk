; Simple Keyboard Detector - Lists all keyboards and monitors key timing
; This method uses device enumeration and timing analysis

; Create GUI
DetectorGui := Gui("+Resize", "Simple Keyboard Detector")
DetectorGui.SetFont("s10", "Consolas")
DetectorGui.Add("Text", "x10 y10 w400 h20", "Detected Keyboards:")
global KeyboardList := DetectorGui.Add("Edit", "x10 y35 w400 h100 ReadOnly VScroll")
DetectorGui.Add("Text", "x10 y145 w400 h20", "Key Events (with timing analysis):")
global EventLog := DetectorGui.Add("Edit", "x10 y170 w400 h150 ReadOnly VScroll")
DetectorGui.Show("w420 h340")

; Variables for timing analysis
global LastKeyTime := 0
global KeySequence := []
global ExternalKeyboardPattern := false

; Enumerate keyboards using WMI
EnumerateKeyboardsWMI()

; Hook all keys to analyze timing
SetTimer(AnalyzeKeyboardPattern, 100)

; Function to enumerate keyboards using WMI
EnumerateKeyboardsWMI() {
    try {
        ; Use WMI to get keyboard information
        output := "=== System Keyboards ===`r`n"
        
        ; Get keyboard devices
        for objItem in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Keyboard") {
            output .= "Name: " objItem.Name "`r`n"
            output .= "Description: " objItem.Description "`r`n"
            output .= "Device ID: " objItem.DeviceID "`r`n"
            output .= "---`r`n"
        }
        
        ; Get USB devices that might be keyboards
        output .= "`r`n=== USB Input Devices ===`r`n"
        for objItem in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_USBControllerDevice") {
            try {
                devicePath := objItem.Dependent
                if (InStr(devicePath, "USB") && (InStr(devicePath, "VID_") || InStr(devicePath, "keyboard"))) {
                    ; Extract device info
                    RegExMatch(devicePath, 'DeviceID="([^"]*)"', &match)
                    if (match) {
                        deviceId := match[1]
                        output .= "USB Device: " deviceId "`r`n"
                        
                        ; Try to get more info about this device
                        for device in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_PnPEntity WHERE DeviceID='" deviceId "'") {
                            if (device.Name) {
                                output .= "  Name: " device.Name "`r`n"
                            }
                        }
                        output .= "---`r`n"
                    }
                }
            } catch {
                ; Skip devices we can't access
            }
        }
        
        KeyboardList.Text := output
        
    } catch as e {
        KeyboardList.Text := "Error enumerating keyboards: " e.Message
    }
}

; Function to analyze keyboard patterns
AnalyzeKeyboardPattern() {
    ; Check if any key is currently pressed
    anyKeyPressed := false
    currentKeys := []
    
    ; Check common keys
    keys := ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", 
             "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
             "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
             "Space", "Enter", "Tab", "Shift", "Ctrl", "Alt", "F1", "F2", "F3", "F4"]
    
    for key in keys {
        if (GetKeyState(key, "P")) {
            anyKeyPressed := true
            currentKeys.Push(key)
        }
    }
    
    if (anyKeyPressed && currentKeys.Length > 0) {
        currentTime := A_TickCount
        
        ; Log the key event with timing
        keyStr := ""
        for key in currentKeys {
            keyStr .= key " "
        }
        
        timeDiff := currentTime - LastKeyTime
        
        ; Analyze patterns (this is heuristic)
        pattern := ""
        if (timeDiff > 0 && timeDiff < 50) {
            pattern .= " [FAST-REPEAT]"
        } else if (timeDiff > 200) {
            pattern .= " [SLOW-TYPE]"
        }
        
        ; Check for external keyboard indicators
        ; External keyboards often have different timing characteristics
        if (timeDiff > 0 && timeDiff < 20) {
            pattern .= " [POSSIBLE-EXTERNAL]"
            ExternalKeyboardPattern := true
        }
        
        timestamp := FormatTime(, "HH:mm:ss.fff")
        logEntry := timestamp " - " keyStr " (+" timeDiff "ms)" pattern "`r`n"
        
        EventLog.Text .= logEntry
        
        ; Auto-scroll
        EventLog.Focus()
        Send("^{End}")
        
        LastKeyTime := currentTime
        
        ; Keep only recent entries to prevent memory issues
        lines := StrSplit(EventLog.Text, "`r`n")
        if (lines.Length > 50) {
            EventLog.Text := ""
            Loop 30 {
                if (A_Index + 20 <= lines.Length) {
                    EventLog.Text .= lines[A_Index + 20] "`r`n"
                }
            }
        }
    }
}

; Hotkey to reset analysis
F5:: {
    EventLog.Text := "=== Analysis Reset ===`r`n"
    ExternalKeyboardPattern := false
    LastKeyTime := 0
}

; Show help
F1:: {
    MsgBox("Keyboard Detection Methods:`n`n" .
           "1. Device List: Shows all keyboards found by Windows`n" .
           "2. Timing Analysis: Analyzes keystroke patterns`n" .
           "3. Pattern Detection: Looks for external keyboard signatures`n`n" .
           "Tips:`n" .
           "- External keyboards often have different timing`n" .
           "- USB keyboards may show different device IDs`n" .
           "- Press F5 to reset analysis`n" .
           "- Press F1 for this help", "Help")
}

TrayTip("Simple Keyboard Detector", "F1=Help, F5=Reset Analysis`nWatch timing patterns to identify external keyboards")
