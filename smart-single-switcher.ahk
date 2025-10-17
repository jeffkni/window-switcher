; Smart Single Switcher - Keyboard-Aware Window Switcher
; External keyboards use Win+Tab, Built-in keyboards use Alt+Tab
; Automatically detects keyboard source using Raw Input API

#Include %A_ScriptDir%\GuiEnhancerKit.ahk

#MaxThreadsPerHotkey 2
TraySetIcon "shell32.dll", 99

;--------------------------------------------------------
; Raw Input API Constants for Keyboard Detection
;--------------------------------------------------------

WM_INPUT := 0x00FF
RIM_TYPEKEYBOARD := 1
RIDEV_INPUTSINK := 0x00000100

;--------------------------------------------------------
; Windows API constants (from original single-switcher)
;--------------------------------------------------------

WM_GETICON := 0x007F
ICON_BIG := 1
ICON_SMALL := 0
ICON_SMALL2 := 2

WS_CHILD := 0x40000000
WS_EX_APPWINDOW := 0x00040000
WS_EX_TOOLWINDOW := 0x00000080

SS_WORDELLIPSIS := 0x0000C000
SS_NOPREFIX := 0x00000080

GCW_ATOM := -32
GCL_CBCLSEXTRA := -20
GCL_CBWNDEXTRA := -18
GCLP_HBRBACKGROUND := -10
GCLP_HCURSOR := -12
GCLP_HICON := -14
GCLP_HICONSM := -34
GCLP_HMODULE := -16
GCLP_MENUNAME := -8
GCL_STYLE := -26
GCLP_WNDPROC := -24

DWMWA_USE_HOSTBACKDROPBRUSH := 16
DWMWA_SYSTEMBACKDROP_TYPE := 38
DWMSBT_TRANSIENTWINDOW := 3

;--------------------------------------------------------
; Global Settings
;--------------------------------------------------------

global LayoutDirection := "horizontal"

;--------------------------------------------------------
; Global variables (from original single-switcher)
;--------------------------------------------------------

global WindowSwitcher := 0
global FocusRingByHWND := Map()
global CurrentWindowIndex := 0
global AllSwitchableWindows := []
global IsWindowSwitcherActive := false
global AltQPressed := false
global TitleDisplay := 0
global TopBorder := 0
global BottomBorder := 0
global LeftBorder := 0
global RightBorder := 0

;--------------------------------------------------------
; Keyboard Detection Variables
;--------------------------------------------------------

global KeyboardDevices := Map()
global LastKeyboardType := "UNKNOWN"
global HiddenGui := 0

;--------------------------------------------------------
; Initialize Keyboard Detection
;--------------------------------------------------------

InitializeKeyboardDetection()

;--------------------------------------------------------
; Keyboard Detection Functions
;--------------------------------------------------------

InitializeKeyboardDetection() {
    ; Create hidden window for raw input
    global HiddenGui := Gui("+ToolWindow", "Keyboard Detector")
    HiddenGui.Show("Hide")
    Sleep(100)
    
    ; Register for raw input
    RAWINPUTDEVICE_SIZE := A_PtrSize == 8 ? 16 : 12
    rid := Buffer(RAWINPUTDEVICE_SIZE, 0)
    NumPut("UShort", 1, rid, 0)
    NumPut("UShort", 6, rid, 2)
    NumPut("UInt", RIDEV_INPUTSINK, rid, 4)
    NumPut("Ptr", HiddenGui.Hwnd, rid, 8)
    
    result := DllCall("user32.dll\RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", RAWINPUTDEVICE_SIZE)
    
    if (result) {
        OnMessage(WM_INPUT, ProcessKeyboardInput)
        TrayTip("Smart Switcher", "Keyboard detection initialized successfully!")
    } else {
        TrayTip("Smart Switcher", "Keyboard detection failed - using fallback mode")
    }
}

ProcessKeyboardInput(wParam, lParam, msg, hwnd) {
    ; Get raw input data
    size := 0
    DllCall("user32.dll\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", &size, "UInt", A_PtrSize == 8 ? 24 : 16)
    
    if (size == 0) {
        return
    }
    
    rawData := Buffer(size, 0)
    result := DllCall("user32.dll\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", rawData, "UInt*", &size, "UInt", A_PtrSize == 8 ? 24 : 16)
    
    if (result == -1) {
        return
    }
    
    ; Parse raw input
    type := NumGet(rawData, 0, "UInt")
    deviceHandle := NumGet(rawData, 8, "Ptr")
    
    if (type != RIM_TYPEKEYBOARD) {
        return
    }
    
    ; Get or detect keyboard type
    if (!KeyboardDevices.Has(deviceHandle)) {
        deviceName := GetDeviceName(deviceHandle)
        keyboardType := ClassifyKeyboard(deviceName)
        KeyboardDevices[deviceHandle] := keyboardType
    }
    
    global LastKeyboardType := KeyboardDevices[deviceHandle]
}

GetDeviceName(handle) {
    size := 0
    DllCall("user32.dll\GetRawInputDeviceInfoW", "Ptr", handle, "UInt", 0x20000007, "Ptr", 0, "UInt*", &size)
    
    if (size == 0) {
        return "Unknown Device"
    }
    
    nameBuffer := Buffer(size * 2, 0)
    result := DllCall("user32.dll\GetRawInputDeviceInfoW", "Ptr", handle, "UInt", 0x20000007, "Ptr", nameBuffer, "UInt*", &size)
    
    if (result == -1) {
        return "Error Getting Name"
    }
    
    return StrGet(nameBuffer, "UTF-16")
}

ClassifyKeyboard(deviceName) {
    deviceName := StrUpper(deviceName)
    
    ; External keyboard indicators
    if (InStr(deviceName, "USB\VID_") ||
        InStr(deviceName, "USB\\VID_") ||
        InStr(deviceName, "BLUETOOTH") ||
        InStr(deviceName, "WIRELESS") ||
        InStr(deviceName, "LOGITECH") ||
        InStr(deviceName, "MICROSOFT") ||
        InStr(deviceName, "CORSAIR") ||
        InStr(deviceName, "RAZER")) {
        return "EXTERNAL"
    }
    
    ; Built-in keyboard indicators
    if (InStr(deviceName, "ACPI") ||
        InStr(deviceName, "ROOT\\") ||
        InStr(deviceName, "PS2") ||
        InStr(deviceName, "I8042") ||
        InStr(deviceName, "HID\\") && !InStr(deviceName, "USB")) {
        return "BUILT-IN"
    }
    
    ; HID pattern matching
    if (InStr(deviceName, "HID")) {
        if (RegExMatch(deviceName, "VID_[0-9A-F]{4}.*PID_[0-9A-F]{4}")) {
            return "EXTERNAL"
        } else {
            return "BUILT-IN"
        }
    }
    
    return "UNKNOWN"
}

;--------------------------------------------------------
; Smart Hotkeys - Keyboard-Aware
;--------------------------------------------------------

; External keyboard: Win+Tab triggers switcher
#Tab:: {
    if (LastKeyboardType == "EXTERNAL" || LastKeyboardType == "UNKNOWN") {
        HandleAltTab(false)
    } else {
        ; Pass through to Windows Task View
        Send("#Tab")
    }
}

#+Tab:: {
    if (LastKeyboardType == "EXTERNAL" || LastKeyboardType == "UNKNOWN") {
        HandleAltTab(true)
    } else {
        Send("#+Tab")
    }
}

; Built-in keyboard: Alt+Tab triggers switcher
!Tab:: {
    if (LastKeyboardType == "BUILT-IN" || LastKeyboardType == "UNKNOWN") {
        HandleAltTab(false)
    } else {
        ; Pass through to Windows default
        Send("!Tab")
    }
}

!+Tab:: {
    if (LastKeyboardType == "BUILT-IN" || LastKeyboardType == "UNKNOWN") {
        HandleAltTab(true)
    } else {
        Send("!+Tab")
    }
}

; Both keyboards: Q and W work when switcher is active
!q::
#q:: {
    global WindowSwitcher
    if (WindowSwitcher && IsObject(WindowSwitcher)) {
        HandleCloseWindow()
    } else {
        ; Pass through
        if (A_ThisHotkey == "!q") {
            Send("q")
        } else {
            Send("#q")
        }
    }
}

!w::
#w:: {
    global WindowSwitcher
    if (WindowSwitcher && IsObject(WindowSwitcher)) {
        HandleLayoutToggle()
    } else {
        ; Pass through
        if (A_ThisHotkey == "!w") {
            Send("w")
        } else {
            Send("#w")
        }
    }
}

;--------------------------------------------------------
; Utility functions from single-switcher.ahk
;--------------------------------------------------------

GetWindowIconHandle(hwnd) {
    iconHandle := 0
    
    ; Try different icon sources in order of preference
    if (!iconHandle) {
        try {
            iconHandle := SendMessage(WM_GETICON, ICON_BIG, 0, , hwnd)
        } catch {
        }
    }
    if (!iconHandle) {
        try {
            iconHandle := SendMessage(WM_GETICON, ICON_SMALL2, 0, , hwnd)
        } catch {
        }
    }
    if (!iconHandle) {
        try {
            iconHandle := SendMessage(WM_GETICON, ICON_SMALL, 0, , hwnd)
        } catch {
        }
    }
    if (!iconHandle) {
        try {
            iconHandle := GetClassLongPtrA(hwnd, GCLP_HICON)
        } catch {
        }
    }
    if (!iconHandle) {
        try {
            iconHandle := GetClassLongPtrA(hwnd, GCLP_HICONSM)
        } catch {
        }
    }
    
    ; Try to get icon from executable file as last resort
    if (!iconHandle) {
        try {
            ProcessPath := WinGetProcessPath(hwnd)
            if (ProcessPath && ProcessPath != "") {
                ; Extract the first icon from the executable
                iconHandle := DllCall("Shell32.dll\ExtractIcon", "Ptr", A_ScriptHwnd, "Str", ProcessPath, "UInt", 0, "Ptr")
                if (iconHandle <= 1) {  ; ExtractIcon returns 0 or 1 for failure
                    iconHandle := 0
                }
            }
        } catch {
        }
    }
    
    return iconHandle
}

GetClassLongPtrA(hwnd, nIndex) {
    return DllCall("GetClassLongPtrA", "Ptr", hwnd, "int", nIndex, "Ptr")
}

Switchable(Window) {
    ; Determine if a window should be included in the switcher
    ; Skip invalid windows
    try {
        if !WinExist("ahk_id " Window) {
            return false
        }
    } catch {
        return false
    }
    
    ; Check window styles to determine if it's switchable
    try {
        ExStyle := WinGetExStyle(Window)
        Style := WinGetStyle(Window)
        
        ; Skip tool windows (unless they have WS_EX_APPWINDOW)
        if (ExStyle & WS_EX_TOOLWINDOW) && !(ExStyle & WS_EX_APPWINDOW) {
            return false
        }
        
        ; Skip child windows
        if (Style & WS_CHILD) {
            return false
        }
        
        ; Skip windows without a title (unless they have WS_EX_APPWINDOW)
        WindowTitle := WinGetTitle(Window)
        if (WindowTitle == "" && !(ExStyle & WS_EX_APPWINDOW)) {
            return false
        }
        
        ; Include windows that are explicitly marked as app windows
        if (ExStyle & WS_EX_APPWINDOW) {
            return true
        }
        
        ; Include visible windows (including minimized ones)
        return true
        
    } catch {
        return false
    }
}

GetWindowDisplayName(Window) {
    ; Get a display name for the window
    try {
        ProcessPath := WinGetProcessPath(Window)
        WindowTitle := WinGetTitle(Window)
        
        ; Try to get the application name from version info
        try {
            Info := FileGetVersionInfo_AW(ProcessPath, ["FileDescription", "ProductName"])
            AppName := Info["FileDescription"] ? Info["FileDescription"] : Info["ProductName"]
            if (AppName && AppName != "") {
                ; If we have both app name and window title, combine them
                if (WindowTitle && WindowTitle != "" && WindowTitle != AppName) {
                    return AppName " - " WindowTitle
                } else {
                    return AppName
                }
            }
        } catch {
        }
        
        ; Fall back to window title
        if (WindowTitle && WindowTitle != "") {
            return WindowTitle
        }
        
        ; Last resort: process name
        return WinGetProcessName(Window)
        
    } catch {
        return "Unknown Window"
    }
}

SortWindowsByZOrder(Windows) {
    ; Sort windows by Z-order (most recently used first)
    if (Windows.Length <= 1) {
        return Windows
    }
    
    ; Simple approach: use insertion sort with Z-order comparison
    for i in Range(2, Windows.Length) {
        j := i
        while (j > 1 && IsWindowOnTop(Windows[j].HWND, Windows[j-1].HWND)) {
            ; Swap windows
            temp := Windows[j]
            Windows[j] := Windows[j-1]
            Windows[j-1] := temp
            j--
        }
    }
    
    return Windows
}

IsWindowOnTop(Window1, Window2) {
    ; Check if Window1 is on top of Window2 in Z-order
    try {
        global GroupIDCounter
        GroupIDCounter++
        
        GroupName := "TempZOrderGroup" GroupIDCounter
        GroupAdd(GroupName, "ahk_id " Window1)
        GroupAdd(GroupName, "ahk_id " Window2)
        
        TopWindow := WinGetID("ahk_group " GroupName)
        return TopWindow == Window1
    } catch {
        return false
    }
}

Range(start, end) {
    ; Helper function to create a range for the loop
    result := []
    Loop end - start + 1 {
        result.Push(start + A_Index - 1)
    }
    return result
}

;--------------------------------------------------------
; Main Switcher Logic
;--------------------------------------------------------

HandleAltTab(IsReverse) {
    global WindowSwitcher, IsWindowSwitcherActive, AllSwitchableWindows, AltQPressed, LastKeyboardType
    
    ; Show which keyboard triggered the switcher
    keyboardMsg := LastKeyboardType == "EXTERNAL" ? "External Keyboard (Win+Tab)" : 
                   LastKeyboardType == "BUILT-IN" ? "Built-in Keyboard (Alt+Tab)" : "Unknown Keyboard"
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Cycle through windows in the switcher using GUI's built-in Tab behavior
        WinActivate(WindowSwitcher.HWND)
        Sleep(20)
        
        ; If still no focused control, focus the first one
        try {
            FocusedCtrl := WindowSwitcher.FocusedCtrl
        } catch {
            FocusedCtrl := 0
        }
        if !FocusedCtrl {
            try {
                ; Find and focus the first control
                AllControls := WindowSwitcher.GetControls()
                if AllControls.Length > 0 {
                    AllControls[1].Focus()
                }
            } catch {
            }
        }
        
        if IsReverse {
            Send "+{Tab}"
        } else {
            Send "{Tab}"
        }
        
        Sleep(20)
        UpdateFocusHighlight()
        return
    }
    
    ; First time opening - get all switchable windows
    AllWindows := WinGetList()
    SwitchableWindows := []
    
    for Window in AllWindows {
        if Switchable(Window) {
            ; Get window info
            WindowInfo := {
                HWND: Window,
                Title: GetWindowDisplayName(Window),
                Icon: GetWindowIconHandle(Window)
            }
            SwitchableWindows.Push(WindowInfo)
        }
    }
    
    ; Sort by Z-order (most recent first)
    SortWindowsByZOrder(SwitchableWindows)
    
    if SwitchableWindows.Length <= 1 {
        ; If only one window, just activate it
        if SwitchableWindows.Length == 1 {
            try {
                WinActivate(SwitchableWindows[1].HWND)
                if WinGetMinMax(SwitchableWindows[1].HWND) == -1 {
                    WinRestore(SwitchableWindows[1].HWND)
                }
            } catch {
            }
        }
        return
    }
    
    ; Store windows globally for Alt+Q functionality
    global AllSwitchableWindows := SwitchableWindows
    
    ; Show the switcher with keyboard info
    ShowWindowSwitcher(SwitchableWindows, keyboardMsg)
    
    ; Initially select the next window
    if IsReverse {
        Send "+{Tab}"
    } else {
        Send "{Tab}"
    }
    UpdateFocusHighlight()
    
    ; Wait for Alt/Win to be released
    if AltQPressed {
        AltQPressed := false
        SetTimer(CheckKeyReleaseAfterQ, 50)
        return
    }
    
    ; Wait for the appropriate modifier key based on keyboard type
    if (LastKeyboardType == "EXTERNAL") {
        if GetKeyState("LWin") {
            KeyWait "LWin"
        } else if GetKeyState("RWin") {
            KeyWait "RWin"
        }
    } else {
        if GetKeyState("LAlt") {
            KeyWait "LAlt"
        } else if GetKeyState("RAlt") {
            KeyWait "RAlt"
        }
    }
    
    ; Activate selected window
    if WindowSwitcher && IsObject(WindowSwitcher) {
        try {
            FocusedControl := WindowSwitcher.FocusedCtrl
        } catch {
            FocusedControl := 0
        }
        SelectedHWND := 0
        
        if FocusedControl {
            try {
                ControlName := FocusedControl.Name
                if InStr(ControlName, "IconForWindowWithHWND") {
                    SelectedHWND := Integer(StrReplace(ControlName, "IconForWindowWithHWND", ""))
                }
            } catch {
            }
        }
        
        CloseWindowSwitcher()
        
        if SelectedHWND {
            try {
                if WinGetMinMax(SelectedHWND) == -1 {
                    WinRestore(SelectedHWND)
                }
                WinActivate(SelectedHWND)
            } catch {
            }
        }
    }
}

; Simplified ShowWindowSwitcher for now - you can expand this with the full version
ShowWindowSwitcher(Windows, KeyboardInfo := "") {
    global WindowSwitcher
    CloseWindowSwitcher()
    
    try {
        global WindowSwitcher := GuiExt()
    } catch {
        global WindowSwitcher := Gui()
    }
    
    WindowSwitcher.SetFont("cWhite s8", "Segoe UI")
    WindowSwitcher.BackColor := 0x000000
    WindowSwitcher.MarginX := 10
    WindowSwitcher.MarginY := 10
    
    ; Add keyboard info at top
    if (KeyboardInfo) {
        WindowSwitcher.Add("Text", "xM yM w300 h20 Center cYellow", KeyboardInfo)
    }
    
    ; Add window icons
    IconSize := 48
    IconSpacing := 8
    
    for index, window in Windows {
        yPos := KeyboardInfo ? "y+10" : "yM"
        if (index == 1) {
            yPos .= " xM"
        } else {
            yPos .= " x+" IconSpacing
        }
        
        ControlOptions := yPos " w" IconSize " h" IconSize " Tabstop vIconForWindowWithHWND" window.HWND
        
        if (window.Icon && window.Icon > 1) {
            WindowSwitcher.Add("Pic", ControlOptions, "HICON:*" window.Icon)
        } else {
            ; Fallback text
            AppName := WinGetProcessName(window.HWND)
            FirstTwoLetters := StrUpper(SubStr(AppName, 1, 2))
            IconControl := WindowSwitcher.Add("Text", ControlOptions " Center cWhite", FirstTwoLetters)
            IconControl.SetFont("s12 Bold", "Segoe UI")
        }
    }
    
    WindowSwitcher.OnEvent("Escape", CloseWindowSwitcher)
    WindowSwitcher.Opt("+AlwaysOnTop -SysMenu -Caption -Border +Owner")
    WindowSwitcher.Show
    
    WinActivate(WindowSwitcher.HWND)
}

CloseWindowSwitcher(*) {
    global WindowSwitcher, IsWindowSwitcherActive
    IsWindowSwitcherActive := false
    if !WindowSwitcher {
        return
    }
    
    OldWindowSwitcher := WindowSwitcher
    WindowSwitcher := 0
    OldWindowSwitcher.Destroy()
}

UpdateFocusHighlight() {
    ; Simplified version - you can expand with the full highlight system
}

HandleCloseWindow() {
    global WindowSwitcher, AllSwitchableWindows, AltQPressed
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        AltQPressed := true
        
        try {
            FocusedControl := WindowSwitcher.FocusedCtrl
        } catch {
            return
        }
        
        if FocusedControl {
            try {
                ControlName := FocusedControl.Name
                if InStr(ControlName, "IconForWindowWithHWND") {
                    TargetHWND := Integer(StrReplace(ControlName, "IconForWindowWithHWND", ""))
                    WinClose(TargetHWND)
                    Sleep(50)
                    
                    ; Remove closed window and rebuild switcher
                    UpdatedWindows := []
                    for window in AllSwitchableWindows {
                        if window.HWND != TargetHWND {
                            UpdatedWindows.Push(window)
                        }
                    }
                    
                    AllSwitchableWindows := UpdatedWindows
                    
                    if AllSwitchableWindows.Length == 0 {
                        CloseWindowSwitcher()
                        return
                    }
                    
                    ShowWindowSwitcher(AllSwitchableWindows)
                    WinActivate(WindowSwitcher.HWND)
                    Sleep(20)
                }
            } catch {
            }
        }
        return
    }
}

HandleLayoutToggle() {
    global WindowSwitcher, AllSwitchableWindows, LayoutDirection
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Toggle layout direction
        LayoutDirection := (LayoutDirection == "vertical") ? "horizontal" : "vertical"
        
        ; Rebuild switcher with new layout
        ShowWindowSwitcher(AllSwitchableWindows)
        WinActivate(WindowSwitcher.HWND)
        Sleep(50)
    }
}

CheckKeyReleaseAfterQ() {
    global WindowSwitcher, LastKeyboardType
    
    ; Check appropriate modifier key based on keyboard type
    keyReleased := false
    if (LastKeyboardType == "EXTERNAL") {
        keyReleased := !GetKeyState("LWin") && !GetKeyState("RWin")
    } else {
        keyReleased := !GetKeyState("LAlt") && !GetKeyState("RAlt")
    }
    
    if keyReleased {
        ; Key was released, activate the selected window
        if WindowSwitcher && IsObject(WindowSwitcher) {
            try {
                FocusedControl := WindowSwitcher.FocusedCtrl
            } catch {
                FocusedControl := 0
            }
            SelectedHWND := 0
            
            if FocusedControl {
                try {
                    ControlName := FocusedControl.Name
                    if InStr(ControlName, "IconForWindowWithHWND") {
                        SelectedHWND := Integer(StrReplace(ControlName, "IconForWindowWithHWND", ""))
                    }
                } catch {
                }
            }
            
            CloseWindowSwitcher()
            
            if SelectedHWND {
                try {
                    if WinGetMinMax(SelectedHWND) == -1 {
                        WinRestore(SelectedHWND)
                    }
                    WinActivate(SelectedHWND)
                } catch {
                }
            }
        }
        SetTimer(CheckKeyReleaseAfterQ, 0)
    }
}

;--------------------------------------------------------
; Utility functions
;--------------------------------------------------------

GroupIDCounter := 0

FileGetVersionInfo_AW(PEFile := "", Fields := ["FileDescription"]) {
    ; Written by SKAN, updated for AHK v2
    DLL := "Version\"
    if !FVISize := DllCall(DLL "GetFileVersionInfoSizeW", "Str", PEFile, "UInt", 0) {
        throw Error("Unable to retrieve size of file version information.")
    }
    FVI := Buffer(FVISize, 0)
    Translation := 0
    DllCall(DLL "GetFileVersionInfoW", "Str", PEFile, "Int", 0, "UInt", FVISize, "Ptr", FVI)
    if !DllCall(DLL "VerQueryValueW", "Ptr", FVI, "Str", "\VarFileInfo\Translation", "UInt*", &Translation, "UInt", 0) {
        throw Error("Unable to retrieve file version translation information.")
    }
    TranslationHex := Buffer(16 + 2)
    if !DllCall("wsprintf", "Ptr", TranslationHex, "Str", "%08X", "UInt", NumGet(Translation + 0, "UPtr"), "Cdecl") {
        throw Error("Unable to format number as hexadecimal.")
    }
    TranslationHex := StrGet(TranslationHex, , "UTF-16")
    TranslationCode := SubStr(TranslationHex, -4) SubStr(TranslationHex, 1, 4)
    PropertiesMap := Map()
    for Field in Fields {
        SubBlock := "\StringFileInfo\" TranslationCode "\" Field
        InfoPtr := 0
        if !DllCall(DLL "VerQueryValueW", "Ptr", FVI, "Str", SubBlock, "UIntP", &InfoPtr, "UInt", 0) {
            continue
        }
        Value := DllCall("MulDiv", "UInt", InfoPtr, "Int", 1, "Int", 1, "Str")
        PropertiesMap[Field] := Value
    }
    return PropertiesMap
}

;--------------------------------------------------------
; Status Display
;--------------------------------------------------------

F12:: {
    MsgBox("🎹 Smart Single Switcher Status 🎹`n`n" .
           "Last Keyboard Used: " LastKeyboardType "`n`n" .
           "Hotkey Mapping:`n" .
           "• External Keyboard: Win+Tab`n" .
           "• Built-in Keyboard: Alt+Tab`n`n" .
           "Detection: " (KeyboardDevices.Count > 0 ? "Active" : "Inactive"),
           "Smart Switcher Status")
}

TrayTip("Smart Single Switcher", "External: Win+Tab | Built-in: Alt+Tab | F12=Status")
