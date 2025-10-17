; Working AutoHotInterception keyboard finder
#Include %A_ScriptDir%\AutoHotInterception\AutoHotInterception.ahk

try {
    ; Create AutoHotInterception instance
    AHI := AutoHotInterception()
    
    ; Get all devices
    deviceList := AHI.GetDeviceList()
    
    output := "=== Found Keyboards ===`n`n"
    keyboardCount := 0
    
    ; Filter for keyboards only (IsMouse = false)
    for deviceId, device in deviceList {
        if (!device.IsMouse) {  ; This is a keyboard
            keyboardCount++
            output .= "Keyboard #" keyboardCount "`n"
            output .= "  Device ID: " device.ID "`n"
            output .= "  VID: 0x" Format("{:04X}", device.VID) "`n"
            output .= "  PID: 0x" Format("{:04X}", device.PID) "`n"
            output .= "  Handle: " device.Handle "`n"
            output .= "  ---`n"
        }
    }
    
    if (keyboardCount = 0) {
        output .= "No keyboards found!`n"
        output .= "Total devices: " deviceList.Count "`n"
        output .= "`nAll devices:`n"
        for deviceId, device in deviceList {
            output .= "ID " device.ID ": VID=0x" Format("{:04X}", device.VID) 
            output .= " PID=0x" Format("{:04X}", device.PID) 
            output .= " Mouse=" (device.IsMouse ? "Yes" : "No") "`n"
        }
    } else {
        output .= "`nTo use a keyboard in single-switcher.ahk:`n"
        output .= "1. Pick your external keyboard from the list above`n"
        output .= "2. Update these lines in single-switcher.ahk:`n"
        output .= "   EXTERNAL_KEYBOARD_VID := 0x[VID]`n"
        output .= "   EXTERNAL_KEYBOARD_PID := 0x[PID]`n"
        output .= "3. Uncomment the AutoHotInterception setup code`n"
    }
    
} catch as e {
    output := "Error: " e.Message "`n`nStack:`n" e.Stack
}

MsgBox(output, "Keyboard List", "T60")
