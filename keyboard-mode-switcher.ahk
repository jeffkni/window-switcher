; Keyboard Mode Switcher - Toggle between unified switcher and Windows default
; Press F12 to toggle modes

; Global flag to track if we're using external keyboard mode
global UsingExternalKeyboard := false

; Monitor for external keyboard connection
F12:: {
    global UsingExternalKeyboard
    UsingExternalKeyboard := !UsingExternalKeyboard
    
    if (UsingExternalKeyboard) {
        ; Stop single-switcher if it's running and start it fresh
        try {
            WinClose("ahk_exe single-switcher.exe")
        } catch {
        }
        
        ; Start the unified switcher
        Run(A_ScriptDir "\single-switcher.ahk")
        
        MsgBox("🎹 EXTERNAL KEYBOARD MODE: ON`n`n✅ Alt+Tab will use unified switcher`n✅ Enhanced window switching active", "Keyboard Mode", "T3")
        TrayTip("External Keyboard Mode ON", "Alt+Tab will use unified switcher")
    } else {
        ; Stop the unified switcher to restore Windows default
        try {
            WinClose("ahk_exe single-switcher.exe")
            ; Also try to close by script name
            DetectHiddenWindows(true)
            WinClose("single-switcher.ahk")
            DetectHiddenWindows(false)
        } catch {
        }
        
        MsgBox("💻 LAPTOP KEYBOARD MODE: ON`n`n🔄 Alt+Tab will use Windows default`n🔄 Standard window switching active", "Keyboard Mode", "T3")
        TrayTip("External Keyboard Mode OFF", "Alt+Tab will use Windows default")
    }
}

; Show current status
^F12:: {
    global UsingExternalKeyboard
    status := UsingExternalKeyboard ? "ON" : "OFF"
    MsgBox("External Keyboard Mode: " status "`n`nPress F12 to toggle", "Status")
}

; Initialize
TrayTip("Keyboard Mode Switcher", "Press F12 to toggle between modes`nCtrl+F12 to check status`n`nCurrent: Windows Default", "Iconi")
