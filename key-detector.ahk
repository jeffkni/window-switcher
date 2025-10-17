; Key Detector - Shows what key you pressed
; Press Escape to exit

; Create a GUI to display key information
KeyGui := Gui("+Resize +MinSize300x200", "Key Detector - Press any key")
KeyGui.SetFont("s12", "Consolas")
KeyGui.Add("Text", "x10 y10 w280 h30 Center", "Press any key to see its information:")
KeyDisplay := KeyGui.Add("Text", "x10 y50 w280 h100 Center Border BackgroundWhite", "Waiting for key press...")
KeyGui.Add("Text", "x10 y160 w280 h30 Center", "Press Escape to exit")
KeyGui.Show("w300 h200")

; Make the GUI stay on top
KeyGui.Opt("+AlwaysOnTop")

; Hook to capture all key presses
OnMessage(0x0100, KeyDownHandler)  ; WM_KEYDOWN
OnMessage(0x0101, KeyUpHandler)    ; WM_KEYUP

; Variables to track key state
global LastKey := ""
global KeyPressed := false

; Function to handle key down events
KeyDownHandler(wParam, lParam, msg, hwnd) {
    global KeyDisplay, LastKey, KeyPressed
    
    ; Get key information
    vkCode := wParam
    scanCode := (lParam >> 16) & 0xFF
    
    ; Convert to key name
    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vkCode, scanCode))
    if (!keyName) {
        keyName := GetKeyName(Format("vk{:02X}", vkCode))
    }
    if (!keyName) {
        keyName := "Unknown"
    }
    
    ; Get additional information
    isExtended := (lParam >> 24) & 0x01
    
    ; Update display
    displayText := "KEY PRESSED:`n`n"
    displayText .= "Key Name: " keyName "`n"
    displayText .= "VK Code: 0x" Format("{:02X}", vkCode) " (" vkCode ")`n"
    displayText .= "Scan Code: 0x" Format("{:02X}", scanCode) " (" scanCode ")`n"
    displayText .= "Extended: " (isExtended ? "Yes" : "No")
    
    KeyDisplay.Text := displayText
    LastKey := keyName
    KeyPressed := true
    
    ; Exit on Escape
    if (vkCode = 0x1B) {  ; VK_ESCAPE
        ExitApp
    }
}

; Function to handle key up events  
KeyUpHandler(wParam, lParam, msg, hwnd) {
    global KeyDisplay, LastKey, KeyPressed
    
    if (KeyPressed && LastKey != "") {
        ; Show key released info briefly
        displayText := "KEY RELEASED:`n`n"
        displayText .= "Key Name: " LastKey "`n"
        displayText .= "`n(Waiting for next key...)"
        
        KeyDisplay.Text := displayText
        KeyPressed := false
        
        ; Reset to waiting state after 1 second
        SetTimer(ResetDisplay, 1000)
    }
}

; Function to reset display after key release
ResetDisplay() {
    global KeyDisplay, KeyPressed
    if (!KeyPressed) {
        KeyDisplay.Text := "Waiting for key press..."
    }
    SetTimer(ResetDisplay, 0)  ; Stop the timer
}

; Alternative method using Input hook for special keys
~*a::
~*b::
~*c::
~*d::
~*e::
~*f::
~*g::
~*h::
~*i::
~*j::
~*k::
~*l::
~*m::
~*n::
~*o::
~*p::
~*q::
~*r::
~*s::
~*t::
~*u::
~*v::
~*w::
~*x::
~*y::
~*z::
~*0::
~*1::
~*2::
~*3::
~*4::
~*5::
~*6::
~*7::
~*8::
~*9::
~*F1::
~*F2::
~*F3::
~*F4::
~*F5::
~*F6::
~*F7::
~*F8::
~*F9::
~*F10::
~*F11::
~*F12::
~*Space::
~*Tab::
~*Enter::
~*Shift::
~*Ctrl::
~*Alt::
~*LWin::
~*RWin::
~*Up::
~*Down::
~*Left::
~*Right::
~*Home::
~*End::
~*PgUp::
~*PgDn::
~*Insert::
~*Delete::
~*Backspace::
~*CapsLock::
~*NumLock::
~*ScrollLock::
~*PrintScreen::
~*Pause::
{
    ; This ensures we catch keys that might be missed by the message handler
    ; The ~ prefix allows the key to still function normally
    ; The * prefix catches the key regardless of modifier state
}

; Show startup message
TrayTip("Key Detector Started", "Press any key to see its information`nPress Escape to exit", "Iconi")
