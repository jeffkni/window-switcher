; Requires AutoHotkey v2
#Include %A_ScriptDir%\GuiEnhancerKit.ahk

;--------------------------------------------------------
; Window Switcher
;--------------------------------------------------------
; Alt+Tab to cycle through ALL windows (applications and windows)
; Includes minimized windows and maintains proper window order
; Replaces Windows' built-in Alt+Tab functionality
;--------------------------------------------------------

#MaxThreadsPerHotkey 2 ; Needed to handle tabbing through windows while the switcher is open

TraySetIcon "shell32.dll", 99 ; overlapped windows icon

;--------------------------------------------------------
; Windows API constants
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

; DWM constants for blur effect
DWMWA_USE_HOSTBACKDROPBRUSH := 16
DWMWA_SYSTEMBACKDROP_TYPE := 38
DWMSBT_TRANSIENTWINDOW := 3

;--------------------------------------------------------
; Global Settings
;--------------------------------------------------------

; Layout direction: "vertical" or "horizontal"
; Change layout direction with alt+tab, release then 'w'
global LayoutDirection := "horizontal"

;--------------------------------------------------------
; Global variables
;--------------------------------------------------------

global WindowSwitcher := 0
global FocusRingByHWND := Map()
global CurrentWindowIndex := 0
global AllSwitchableWindows := []
global IsWindowSwitcherActive := false
global AltQPressed := false  ; Flag to track if Alt+Q was pressed
global TitleDisplay := 0  ; Control for displaying window title


;--------------------------------------------------------
; Utility functions
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
    ; This includes ALL windows that would normally appear in Alt+Tab, including minimized ones
    
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
    ; This is similar to how Windows' native Alt+Tab works
    
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
    ; Returns true if Window1 should come before Window2 in the list
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
; Window Switcher UI
;--------------------------------------------------------

ShowWindowSwitcher(Windows, FocusIndex := 1) {
    CloseWindowSwitcher()  ; Close any existing switcher
    
    ; Try GuiExt first, fall back to regular Gui if not available
    try {
        global WindowSwitcher := GuiExt()
    } catch {
        global WindowSwitcher := Gui()
    }
    global FocusRingByHWND := Map()
    global TitleDisplay := 0
    ; Border elements will be declared when created
    
    try {
        WindowSwitcher.SetFont("cWhite s8", "Segoe UI")
        if (HasMethod(WindowSwitcher, "SetDarkTitle")) {
            WindowSwitcher.SetDarkTitle()
        }
        if (HasMethod(WindowSwitcher, "SetDarkMenu")) {
            WindowSwitcher.SetDarkMenu()
        }
    } catch {
        ; Fall back to basic font setting
        WindowSwitcher.SetFont("s8", "Segoe UI")
    }
    WindowSwitcher.BackColor := 0x000000
    
    WindowSwitcher.MarginX := 10
    WindowSwitcher.MarginY := 10
    
    ; Layout settings
    IconSize := 48
    IconSpacing := 8
    
    ; Create selection border elements (4 thin rectangles that form an outline)
    BorderThickness := 2
    global TopBorder := WindowSwitcher.Add("Text", "x0 y0 w10 h" BorderThickness " Background0xFF00FF", "")
    global BottomBorder := WindowSwitcher.Add("Text", "x0 y0 w10 h" BorderThickness " Background0xFF00FF", "")
    global LeftBorder := WindowSwitcher.Add("Text", "x0 y0 w" BorderThickness " h10 Background0xFF00FF", "")
    global RightBorder := WindowSwitcher.Add("Text", "x0 y0 w" BorderThickness " h10 Background0xFF00FF", "")
    
    ; Initially hide all border elements
    TopBorder.Visible := false
    BottomBorder.Visible := false
    LeftBorder.Visible := false
    RightBorder.Visible := false
    
    ; Layout based on direction
    if (LayoutDirection == "horizontal") {
        ; Horizontal layout - icons in a row
        MaxIconsPerRow := 10  ; Adjust as needed
        
        for index, window in Windows {
            ; Position calculation for horizontal layout
            if (index == 1) {
                xPos := "xM"
                yPos := "yM"
            } else {
                xPos := "x+" IconSpacing
                yPos := "yM"
            }
            
            ; Line break if too many icons
            if (index > MaxIconsPerRow) {
                row := Ceil(index / MaxIconsPerRow) - 1
                col := Mod(index - 1, MaxIconsPerRow)
                if (col == 0) {
                    xPos := "xM"
                    yPos := "y+" IconSpacing
                } else {
                    xPos := "x+" IconSpacing
                    yPos := ""
                }
            }
            
            ; Create icon control
            ControlOptions := xPos " " yPos " w" IconSize " h" IconSize " Tabstop vIconForWindowWithHWND" window.HWND
            CreateWindowIcon(window, ControlOptions)
        }
        
        ; Add title display area below icons in horizontal mode
        TitleAreaY := "y+" (IconSpacing + 10)  ; Add some extra spacing below icons
        TitleDisplay := WindowSwitcher.Add("Text", "xM " TitleAreaY " w400 h50 Center cWhite Background0x2D2D30", "")
        TitleDisplay.SetFont("s10", "Segoe UI")
    } else {
        ; Vertical layout - icons in a column (original)
        for index, window in Windows {
            ; Position calculation for vertical layout
            if (index == 1) {
                yPos := "yM"
            } else {
                yPos := "y+" IconSpacing
            }
            
            ; Create icon control
            ControlOptions := "xM " yPos " w" IconSize " h" IconSize " Tabstop vIconForWindowWithHWND" window.HWND
            CreateWindowIcon(window, ControlOptions)
        }
    }
    
    WindowSwitcher.OnEvent("Escape", CloseWindowSwitcher)
    WindowSwitcher.Opt("+AlwaysOnTop -SysMenu -Caption -Border +Owner")
    WindowSwitcher.Show  ; Remove "NoActivate" so GUI gets focus!
    
    ; Focus the GUI and the specified control so Tab cycling works
    WinActivate(WindowSwitcher.HWND)
    try {
        ; Get the control at the specified index and focus it
        TargetControl := ""
        for index, window in Windows {
            if index == FocusIndex {
                ControlName := "IconForWindowWithHWND" window.HWND
                try {
                    TargetControl := WindowSwitcher[ControlName]
                    if TargetControl {
                        TargetControl.Focus()
                        UpdateFocusHighlight()
                        break
                    }
                } catch {
                }
            }
        }
        
        ; If we couldn't focus the target index, focus the first available control
        if !TargetControl {
            for index, window in Windows {
                ControlName := "IconForWindowWithHWND" window.HWND
                try {
                    FirstControl := WindowSwitcher[ControlName]
                    if FirstControl {
                        FirstControl.Focus()
                        UpdateFocusHighlight()
                        break
                    }
                } catch {
                }
            }
        }
    } catch {
    }
    
    ; Enable rounded corners and blur effect (GuiExt features)
    try {
        if (HasMethod(WindowSwitcher, "SetBorderless")) {
            WindowSwitcher.SetBorderless(6)
        }
        if (VerCompare(A_OSVersion, "10.0.22600") >= 0 && HasMethod(WindowSwitcher, "SetWindowAttribute")) {
            WindowSwitcher.SetWindowAttribute(DWMWA_USE_HOSTBACKDROPBRUSH, true)
            WindowSwitcher.SetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE, DWMSBT_TRANSIENTWINDOW)
        }
    } catch {
        ; GuiExt features not available, continue without them
    }
}

CreateWindowIcon(window, ControlOptions) {
    global WindowSwitcher, FocusRingByHWND
    
    try {
        if (window.Icon && window.Icon > 1) {
            IconControl := WindowSwitcher.Add("Pic", ControlOptions, "HICON:*" window.Icon)
        } else {
            ; Create a more visible fallback for windows without icons
            ; Use the first 2 letters of the app name
            try {
                ; Try to get a meaningful app name, fallback to process name
                AppName := ""
                try {
                    ProcessPath := WinGetProcessPath(window.HWND)
                    if (ProcessPath && ProcessPath != "") {
                        Info := FileGetVersionInfo_AW(ProcessPath, ["FileDescription", "ProductName"])
                        AppName := Info["FileDescription"] ? Info["FileDescription"] : Info["ProductName"]
                    }
                } catch {
                }
                
                ; If no app name found, use process name
                if (!AppName || AppName == "") {
                    AppName := WinGetProcessName(window.HWND)
                }
                
                ; If still no name, use window title
                if (!AppName || AppName == "") {
                    AppName := WinGetTitle(window.HWND)
                }
                
                ; Extract first 2 letters
                FirstTwoLetters := SubStr(AppName, 1, 2)
                if (FirstTwoLetters) {
                    FirstTwoLetters := StrUpper(FirstTwoLetters)
                } else {
                    FirstTwoLetters := "??"
                }
            } catch {
                FirstTwoLetters := "??"
            }
            
            ; Create a text control with the first 2 letters
            IconControl := WindowSwitcher.Add("Text", ControlOptions " Center cWhite", FirstTwoLetters)
            IconControl.SetFont("s12 Bold", "Segoe UI")
        }
        ; Add click and hover event handlers to the icon control
        IconControl.OnEvent("Click", (*) => OnIconClick(window.HWND))
        IconControl.OnEvent("MouseMove", (*) => OnIconHover(window.HWND))
        
        FocusRingByHWND[window.HWND] := IconControl
    } catch {
        ; Ultimate fallback - use first 2 letters of anything we can get
        try {
            ProcessName := WinGetProcessName(window.HWND)
            FallbackText := SubStr(StrUpper(ProcessName), 1, 2)
            if (!FallbackText || FallbackText == "") {
                FallbackText := "??"
            }
        } catch {
            FallbackText := "??"
        }
        IconControl := WindowSwitcher.Add("Text", ControlOptions " Center cWhite", FallbackText)
        IconControl.SetFont("s12 Bold", "Segoe UI")
        
        ; Add click and hover event handlers to the fallback control too
        IconControl.OnEvent("Click", (*) => OnIconClick(window.HWND))
        IconControl.OnEvent("MouseMove", (*) => OnIconHover(window.HWND))
        
        FocusRingByHWND[window.HWND] := IconControl
    }
}

OnIconHover(TargetHWND) {
    ; Handle mouse hover over an icon - select it without clicking
    global WindowSwitcher
    
    try {
        ; Find the control for this window and focus it
        ControlName := "IconForWindowWithHWND" TargetHWND
        TargetControl := WindowSwitcher[ControlName]
        
        if TargetControl {
            ; Focus the hovered control (this selects it)
            TargetControl.Focus()
            
            ; Update the visual highlight
            UpdateFocusHighlight()
        }
    } catch {
        ; If focusing fails, just ignore
    }
}

OnIconClick(TargetHWND) {
    ; Handle mouse click on an icon - just select/focus it (don't activate window yet)
    global WindowSwitcher
    
    try {
        ; Find the control for this window and focus it
        ControlName := "IconForWindowWithHWND" TargetHWND
        TargetControl := WindowSwitcher[ControlName]
        
        if TargetControl {
            ; Focus the clicked control (this selects it)
            TargetControl.Focus()
            
            ; Update the visual highlight
            UpdateFocusHighlight()
        }
    } catch {
        ; If focusing fails, just ignore
    }
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

LastFocusHighlight := 0
UpdateFocusHighlight() {
    global TopBorder, BottomBorder, LeftBorder, RightBorder, WindowSwitcher, TitleDisplay, AllSwitchableWindows, LayoutDirection
    
    ; Make sure WindowSwitcher is a valid GUI object
    if !WindowSwitcher || !IsObject(WindowSwitcher) || !TopBorder {
        return
    }
    
    ; Get the currently focused control from the GUI
    try {
        FocusedControl := WindowSwitcher.FocusedCtrl
    } catch {
        ; WindowSwitcher object might be corrupted, exit gracefully
        return
    }
    
    if FocusedControl {
        try {
            ; Get the position of the focused control
            FocusedControl.GetPos(&x, &y, &w, &h)
            
            BorderThickness := 2
            
            ; Position the 4 border elements to form an outline around the control
            ; Top border
            TopBorder.Move(x - BorderThickness, y - BorderThickness, w + (2 * BorderThickness), BorderThickness)
            TopBorder.Visible := true
            
            ; Bottom border  
            BottomBorder.Move(x - BorderThickness, y + h, w + (2 * BorderThickness), BorderThickness)
            BottomBorder.Visible := true
            
            ; Left border
            LeftBorder.Move(x - BorderThickness, y - BorderThickness, BorderThickness, h + (2 * BorderThickness))
            LeftBorder.Visible := true
            
            ; Right border
            RightBorder.Move(x + w, y - BorderThickness, BorderThickness, h + (2 * BorderThickness))
            RightBorder.Visible := true
            
            ; Update title display in horizontal mode
            if (LayoutDirection == "horizontal" && TitleDisplay && IsObject(TitleDisplay)) {
                try {
                    ; Extract HWND from control name (like "IconForWindowWithHWND12345")
                    ControlName := FocusedControl.Name
                    if InStr(ControlName, "IconForWindowWithHWND") {
                        SelectedHWND := Integer(StrReplace(ControlName, "IconForWindowWithHWND", ""))
                        
                        ; Get window title directly
                        WindowTitle := ""
                        try {
                            WindowTitle := WinGetTitle(SelectedHWND)
                        } catch {
                            WindowTitle := "Unknown Window"
                        }
                        
                        ; Clean up the title - very conservative approach
                        if (WindowTitle != "") {
                            OriginalTitle := WindowTitle  ; Keep track of original
                            
                            ; Only do the most basic cleanup - remove trailing " - Microsoft Edge" type patterns
                            ; But only if there's substantial content before the separator
                            TitleParts := StrSplit(WindowTitle, " - ")
                            if (TitleParts.Length >= 2) {
                                FirstPart := Trim(TitleParts[1])
                                LastPart := Trim(TitleParts[TitleParts.Length])
                                
                                ; Only remove the last part if it's a known app name and the first part has content
                                if (StrLen(FirstPart) >= 3) {
                                    CommonApps := ["Microsoft Edge", "Google Chrome", "Mozilla Firefox", "Visual Studio Code", 
                                                  "Microsoft Word", "Microsoft Excel", "File Explorer", "Task Manager"]
                                    
                                    for appName in CommonApps {
                                        if (LastPart = appName) {
                                            WindowTitle := FirstPart
                                            break
                                        }
                                    }
                                }
                            }
                            
                            ; If something went wrong, use original
                            if (StrLen(Trim(WindowTitle)) < 1) {
                                WindowTitle := OriginalTitle
                            }
                        }
                        
                        ; Update the title display
                        TitleDisplay.Text := Trim(WindowTitle)
                    }
                } catch {
                    ; If title update fails, clear the display
                    if (TitleDisplay && IsObject(TitleDisplay)) {
                        TitleDisplay.Text := ""
                    }
                }
            }
            
        } catch {
            ; If positioning fails, hide all borders
            TopBorder.Visible := false
            BottomBorder.Visible := false
            LeftBorder.Visible := false
            RightBorder.Visible := false
        }
    } else {
        ; No focused control, hide all borders and clear title
        TopBorder.Visible := false
        BottomBorder.Visible := false
        LeftBorder.Visible := false
        RightBorder.Visible := false
        
        ; Clear title display
        if (LayoutDirection == "horizontal" && TitleDisplay && IsObject(TitleDisplay)) {
            TitleDisplay.Text := ""
        }
    }
}

;--------------------------------------------------------
; Main Alt+Tab functionality
;--------------------------------------------------------

; Alt+Tab hotkey - revert to original working pattern
!Tab:: {
    global WindowSwitcher, IsWindowSwitcherActive, AllSwitchableWindows, AltQPressed
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Switcher is already open, cycle through windows
        WinActivate(WindowSwitcher.HWND)
        Sleep(20)
        Send "{Tab}"
        UpdateFocusHighlight()
        return
    }
    
    ; First time opening - get all switchable windows
    SwitchableWindows := []
    AllWindows := WinGetList()
    
    for WindowID in AllWindows {
        try {
            WindowTitle := WinGetTitle("ahk_id " WindowID)
            ProcessName := WinGetProcessName("ahk_id " WindowID)
            
            ; Skip windows without titles, system windows, and our own GUI
            if (WindowTitle == "" || 
                ProcessName == "dwm.exe" || 
                ProcessName == "winlogon.exe" || 
                ProcessName == "csrss.exe" ||
                WindowTitle == "Program Manager" ||
                WindowTitle == "Task Switching" ||
                (WindowSwitcher && IsObject(WindowSwitcher) && WindowID == WindowSwitcher.HWND)) {
                continue
            }
            
            ; Get window icon
            WindowIcon := GetWindowIconHandle(WindowID)
            
            ; Add to switchable windows
            SwitchableWindows.Push({HWND: WindowID, Title: WindowTitle, ProcessName: ProcessName, Icon: WindowIcon})
        } catch {
            continue
        }
    }
    
    ; Sort windows by Z-order (most recent first)
    SortedWindows := []
    for window in SwitchableWindows {
        SortedWindows.Push(window)
    }
    
    ; Simple insertion sort by recency
    for i in Range(2, SortedWindows.Length) {
        current := SortedWindows[i]
        j := i - 1
        while j >= 1 && IsWindowOnTop(current.HWND, SortedWindows[j].HWND) {
            SortedWindows[j + 1] := SortedWindows[j]
            j--
        }
        SortedWindows[j + 1] := current
    }
    
    ; Store windows globally for Alt+Q functionality
    AllSwitchableWindows := SortedWindows
    
    ; Show the switcher
    ShowWindowSwitcher(SortedWindows)
    
    ; Initially select the next window (index 2, since index 1 is current)
    Send "{Tab}"
    UpdateFocusHighlight()
    
    ; Handle Alt+Q flag
    if AltQPressed {
        AltQPressed := false
        SetTimer(CheckAltReleaseAfterQ, 50)
        return
    }
    
    ; Wait for Alt to be released
    if GetKeyState("LAlt") {
        KeyWait "LAlt"
    } else if GetKeyState("RAlt") {
        KeyWait "RAlt"
    }
    
    ; Activate the selected window
    try {
        FocusedCtrl := WindowSwitcher.FocusedCtrl
        if FocusedCtrl {
            ControlName := FocusedCtrl.Name
            if RegExMatch(ControlName, "IconForWindowWithHWND(\d+)", &Match) {
                TargetHWND := Integer(Match[1])
                
                ; Restore if minimized
                MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
                if MinMaxState == -1 {
                    WinRestore("ahk_id " TargetHWND)
                    Sleep(100)
                }
                
                WinActivate("ahk_id " TargetHWND)
            }
        }
    } catch {
        ; Fallback - activate the first window
        if AllSwitchableWindows.Length > 1 {
            TargetHWND := AllSwitchableWindows[2].HWND
            MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
            if MinMaxState == -1 {
                WinRestore("ahk_id " TargetHWND)
                Sleep(100)
            }
            WinActivate("ahk_id " TargetHWND)
        }
    }
    
    ; Clean up
    if WindowSwitcher && IsObject(WindowSwitcher) {
        WindowSwitcher.Destroy()
        WindowSwitcher := 0
    }
    IsWindowSwitcherActive := false
}

; Alt+Shift+Tab hotkey - reverse direction
!+Tab:: {
    global WindowSwitcher, IsWindowSwitcherActive, AllSwitchableWindows, AltQPressed
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Switcher is already open, cycle backwards
        WinActivate(WindowSwitcher.HWND)
        Sleep(20)
        Send "+{Tab}"
        UpdateFocusHighlight()
        return
    }
    
    ; First time opening - get all switchable windows (same as !Tab::)
    SwitchableWindows := []
    AllWindows := WinGetList()
    
    for WindowID in AllWindows {
        try {
            WindowTitle := WinGetTitle("ahk_id " WindowID)
            ProcessName := WinGetProcessName("ahk_id " WindowID)
            
            if (WindowTitle == "" || 
                ProcessName == "dwm.exe" || 
                ProcessName == "winlogon.exe" || 
                ProcessName == "csrss.exe" ||
                WindowTitle == "Program Manager" ||
                WindowTitle == "Task Switching" ||
                (WindowSwitcher && IsObject(WindowSwitcher) && WindowID == WindowSwitcher.HWND)) {
                continue
            }
            
            SwitchableWindows.Push({HWND: WindowID, Title: WindowTitle, ProcessName: ProcessName})
        } catch {
            continue
        }
    }
    
    ; Sort windows by Z-order
    SortedWindows := []
    for window in SwitchableWindows {
        SortedWindows.Push(window)
    }
    
    for i in Range(2, SortedWindows.Length) {
        current := SortedWindows[i]
        j := i - 1
        while j >= 1 && IsWindowOnTop(current.HWND, SortedWindows[j].HWND) {
            SortedWindows[j + 1] := SortedWindows[j]
            j--
        }
        SortedWindows[j + 1] := current
    }
    
    AllSwitchableWindows := SortedWindows
    ShowWindowSwitcher(SortedWindows)
    
    ; Start with reverse direction
    Send "+{Tab}"
    UpdateFocusHighlight()
    
    if AltQPressed {
        AltQPressed := false
        SetTimer(CheckAltReleaseAfterQ, 50)
        return
    }
    
    ; Wait for Alt to be released
    if GetKeyState("LAlt") {
        KeyWait "LAlt"
    } else if GetKeyState("RAlt") {
        KeyWait "RAlt"
    }
    
    ; Activate the selected window (same cleanup as !Tab::)
    try {
        FocusedCtrl := WindowSwitcher.FocusedCtrl
        if FocusedCtrl {
            ControlName := FocusedCtrl.Name
            if RegExMatch(ControlName, "IconForWindowWithHWND(\d+)", &Match) {
                TargetHWND := Integer(Match[1])
                
                MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
                if MinMaxState == -1 {
                    WinRestore("ahk_id " TargetHWND)
                    Sleep(100)
                }
                
                WinActivate("ahk_id " TargetHWND)
            }
        }
    } catch {
        if AllSwitchableWindows.Length > 1 {
            TargetHWND := AllSwitchableWindows[2].HWND
            MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
            if MinMaxState == -1 {
                WinRestore("ahk_id " TargetHWND)
                Sleep(100)
            }
            WinActivate("ahk_id " TargetHWND)
        }
    }
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        WindowSwitcher.Destroy()
        WindowSwitcher := 0
    }
    IsWindowSwitcherActive := false
}

; Win+Tab hotkey - same functionality as Alt+Tab for external keyboards
#Tab:: {
    global WindowSwitcher, IsWindowSwitcherActive, AllSwitchableWindows, AltQPressed
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Switcher is already open, cycle through windows
        WinActivate(WindowSwitcher.HWND)
        Sleep(20)
        Send "{Tab}"
        UpdateFocusHighlight()
        return
    }
    
    ; First time opening - get all switchable windows
    SwitchableWindows := []
    AllWindows := WinGetList()
    
    for WindowID in AllWindows {
        try {
            WindowTitle := WinGetTitle("ahk_id " WindowID)
            ProcessName := WinGetProcessName("ahk_id " WindowID)
            
            ; Skip windows without titles, system windows, and our own GUI
            if (WindowTitle == "" || 
                ProcessName == "dwm.exe" || 
                ProcessName == "winlogon.exe" || 
                ProcessName == "csrss.exe" ||
                WindowTitle == "Program Manager" ||
                WindowTitle == "Task Switching" ||
                (WindowSwitcher && IsObject(WindowSwitcher) && WindowID == WindowSwitcher.HWND)) {
                continue
            }
            
            ; Get window icon
            WindowIcon := GetWindowIconHandle(WindowID)
            
            ; Add to switchable windows
            SwitchableWindows.Push({HWND: WindowID, Title: WindowTitle, ProcessName: ProcessName, Icon: WindowIcon})
        } catch {
            continue
        }
    }
    
    ; Sort windows by Z-order (most recent first)
    SortedWindows := []
    for window in SwitchableWindows {
        SortedWindows.Push(window)
    }
    
    ; Simple insertion sort by recency
    for i in Range(2, SortedWindows.Length) {
        current := SortedWindows[i]
        j := i - 1
        while j >= 1 && IsWindowOnTop(current.HWND, SortedWindows[j].HWND) {
            SortedWindows[j + 1] := SortedWindows[j]
            j--
        }
        SortedWindows[j + 1] := current
    }
    
    ; Store windows globally for Alt+Q functionality
    AllSwitchableWindows := SortedWindows
    
    ; Show the switcher
    ShowWindowSwitcher(SortedWindows)
    
    ; Initially select the next window (index 2, since index 1 is current)
    Send "{Tab}"
    UpdateFocusHighlight()
    
    ; Handle Alt+Q flag
    if AltQPressed {
        AltQPressed := false
        SetTimer(CheckWinReleaseAfterQ, 50)
        return
    }
    
    ; Wait for Win to be released
    if GetKeyState("LWin") {
        KeyWait "LWin"
    } else if GetKeyState("RWin") {
        KeyWait "RWin"
    }
    
    ; Activate the selected window
    try {
        FocusedCtrl := WindowSwitcher.FocusedCtrl
        if FocusedCtrl {
            ControlName := FocusedCtrl.Name
            if RegExMatch(ControlName, "IconForWindowWithHWND(\d+)", &Match) {
                TargetHWND := Integer(Match[1])
                
                ; Restore if minimized
                MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
                if MinMaxState == -1 {
                    WinRestore("ahk_id " TargetHWND)
                    Sleep(100)
                }
                
                WinActivate("ahk_id " TargetHWND)
            }
        }
    } catch {
        ; Fallback - activate the first window
        if AllSwitchableWindows.Length > 1 {
            TargetHWND := AllSwitchableWindows[2].HWND
            MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
            if MinMaxState == -1 {
                WinRestore("ahk_id " TargetHWND)
                Sleep(100)
            }
            WinActivate("ahk_id " TargetHWND)
        }
    }
    
    ; Clean up
    if WindowSwitcher && IsObject(WindowSwitcher) {
        WindowSwitcher.Destroy()
        WindowSwitcher := 0
    }
    IsWindowSwitcherActive := false
}

; Win+Shift+Tab hotkey - reverse direction for external keyboards
#+Tab:: {
    global WindowSwitcher, IsWindowSwitcherActive, AllSwitchableWindows, AltQPressed
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Switcher is already open, cycle backwards
        WinActivate(WindowSwitcher.HWND)
        Sleep(20)
        Send "+{Tab}"
        UpdateFocusHighlight()
        return
    }
    
    ; First time opening - get all switchable windows (same as #Tab::)
    SwitchableWindows := []
    AllWindows := WinGetList()
    
    for WindowID in AllWindows {
        try {
            WindowTitle := WinGetTitle("ahk_id " WindowID)
            ProcessName := WinGetProcessName("ahk_id " WindowID)
            
            if (WindowTitle == "" || 
                ProcessName == "dwm.exe" || 
                ProcessName == "winlogon.exe" || 
                ProcessName == "csrss.exe" ||
                WindowTitle == "Program Manager" ||
                WindowTitle == "Task Switching" ||
                (WindowSwitcher && IsObject(WindowSwitcher) && WindowID == WindowSwitcher.HWND)) {
                continue
            }
            
            SwitchableWindows.Push({HWND: WindowID, Title: WindowTitle, ProcessName: ProcessName})
        } catch {
            continue
        }
    }
    
    ; Sort windows by Z-order
    SortedWindows := []
    for window in SwitchableWindows {
        SortedWindows.Push(window)
    }
    
    for i in Range(2, SortedWindows.Length) {
        current := SortedWindows[i]
        j := i - 1
        while j >= 1 && IsWindowOnTop(current.HWND, SortedWindows[j].HWND) {
            SortedWindows[j + 1] := SortedWindows[j]
            j--
        }
        SortedWindows[j + 1] := current
    }
    
    AllSwitchableWindows := SortedWindows
    ShowWindowSwitcher(SortedWindows)
    
    ; Start with reverse direction
    Send "+{Tab}"
    UpdateFocusHighlight()
    
    if AltQPressed {
        AltQPressed := false
        SetTimer(CheckWinReleaseAfterQ, 50)
        return
    }
    
    ; Wait for Win to be released
    if GetKeyState("LWin") {
        KeyWait "LWin"
    } else if GetKeyState("RWin") {
        KeyWait "RWin"
    }
    
    ; Activate the selected window (same cleanup as #Tab::)
    try {
        FocusedCtrl := WindowSwitcher.FocusedCtrl
        if FocusedCtrl {
            ControlName := FocusedCtrl.Name
            if RegExMatch(ControlName, "IconForWindowWithHWND(\d+)", &Match) {
                TargetHWND := Integer(Match[1])
                
                MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
                if MinMaxState == -1 {
                    WinRestore("ahk_id " TargetHWND)
                    Sleep(100)
                }
                
                WinActivate("ahk_id " TargetHWND)
            }
        }
    } catch {
        if AllSwitchableWindows.Length > 1 {
            TargetHWND := AllSwitchableWindows[2].HWND
            MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
            if MinMaxState == -1 {
                WinRestore("ahk_id " TargetHWND)
                Sleep(100)
            }
            WinActivate("ahk_id " TargetHWND)
        }
    }
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        WindowSwitcher.Destroy()
        WindowSwitcher := 0
    }
    IsWindowSwitcherActive := false
}

; Alt+Q and Win+Q to close/kill the currently selected window while switcher is open
!q::
#q:: {
    global WindowSwitcher, AllSwitchableWindows, AltQPressed
    
    ; Only work if the switcher is currently active
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Set flag to prevent main Alt+Tab logic from closing switcher
        AltQPressed := true
        
        ; Get the currently focused control
        try {
            FocusedControl := WindowSwitcher.FocusedCtrl
        } catch {
            ; WindowSwitcher object might be corrupted, exit gracefully
            return
        }
        
        if FocusedControl {
            try {
                ; Extract HWND from control name
                ControlName := FocusedControl.Name
                if InStr(ControlName, "IconForWindowWithHWND") {
                    TargetHWND := Integer(StrReplace(ControlName, "IconForWindowWithHWND", ""))
                    
                    ; Find the index of the current window in our list
                    CurrentIndex := 0
                    for index, window in AllSwitchableWindows {
                        if window.HWND == TargetHWND {
                            CurrentIndex := index
                            break
                        }
                    }
                    
                    ; Close the window
                    WinClose(TargetHWND)
                    
                    ; Small delay to let the window close
                    Sleep(50)
                    
                    ; Remove the closed window from our list
                    UpdatedWindows := []
                    for window in AllSwitchableWindows {
                        if window.HWND != TargetHWND {
                            UpdatedWindows.Push(window)
                        }
                    }
                    
                    ; Update the global list
                    AllSwitchableWindows := UpdatedWindows
                    
                    ; If no windows left, close the switcher
                    if AllSwitchableWindows.Length == 0 {
                        CloseWindowSwitcher()
                        return
                    }
                    
                    ; Calculate which window should be selected next
                    NewIndex := CurrentIndex
                    if NewIndex > AllSwitchableWindows.Length {
                        NewIndex := AllSwitchableWindows.Length
                    }
                    
                    ; Rebuild the switcher with the remaining windows
                    ShowWindowSwitcher(AllSwitchableWindows, NewIndex)
                    
                    ; Ensure the switcher is active
                    WinActivate(WindowSwitcher.HWND)
                    Sleep(20)
                }
            } catch {
                ; Error closing window - could show a message or just ignore
            }
        }
        return
    }
    
    ; If switcher is not active, send normal Q
    Send "q"
}

; Alt+W and Win+W to toggle layout direction while switcher is open
!w::
#w:: {
    global WindowSwitcher, AllSwitchableWindows, LayoutDirection
    
    ; Only work if the switcher is currently active
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Get the currently focused control to preserve selection
        try {
            FocusedControl := WindowSwitcher.FocusedCtrl
        } catch {
            FocusedControl := 0
        }
        CurrentSelectedHWND := 0
        
        if FocusedControl {
            try {
                ; Extract HWND from control name
                ControlName := FocusedControl.Name
                if InStr(ControlName, "IconForWindowWithHWND") {
                    CurrentSelectedHWND := Integer(StrReplace(ControlName, "IconForWindowWithHWND", ""))
                }
            } catch {
            }
        }
        
        ; Toggle layout direction
        if (LayoutDirection == "vertical") {
            LayoutDirection := "horizontal"
        } else {
            LayoutDirection := "vertical"
        }
        
        ; Refresh the switcher with new layout
        ShowWindowSwitcher(AllSwitchableWindows)
        
        ; Ensure the switcher is active and focused
        WinActivate(WindowSwitcher.HWND)
        Sleep(50)
        
        ; Try to restore focus to the same window that was selected
        if CurrentSelectedHWND != 0 {
            try {
                ; Find the index of the window we want to focus
                TargetIndex := 1
                for index, window in AllSwitchableWindows {
                    if window.HWND == CurrentSelectedHWND {
                        TargetIndex := index
                        break
                    }
                }
                
                ; Focus the control at the target index by calling ShowWindowSwitcher again with the correct index
                ShowWindowSwitcher(AllSwitchableWindows, TargetIndex)
                WinActivate(WindowSwitcher.HWND)
                Sleep(20)
            } catch {
                ; If we can't restore the specific selection, just use the default (first item)
            }
        }
        return
    }
    
    ; If switcher is not active, send normal W
    Send "w"
}

CheckAltReleaseAfterQ() {
    global WindowSwitcher
    
    ; Check if Alt is still pressed
    keyReleased := !GetKeyState("LAlt") && !GetKeyState("RAlt")
    
    if keyReleased {
        ; Alt was released, activate the selected window
        if WindowSwitcher && IsObject(WindowSwitcher) {
            ; Get the focused control and extract window HWND from its name
            try {
                FocusedControl := WindowSwitcher.FocusedCtrl
            } catch {
                FocusedControl := 0
            }
            SelectedHWND := 0
            
            if FocusedControl {
                try {
                    ; Extract HWND from control name (like "IconForWindowWithHWND12345")
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
                    ; Restore window if it's minimized
                    if WinGetMinMax(SelectedHWND) == -1 {
                        WinRestore(SelectedHWND)
                    }
                    WinActivate(SelectedHWND)
                } catch {
                }
            }
        }
        ; Stop the timer
        SetTimer(CheckAltReleaseAfterQ, 0)
    }
}

CheckWinReleaseAfterQ() {
    global WindowSwitcher
    
    ; Check if Win is still pressed
    keyReleased := !GetKeyState("LWin") && !GetKeyState("RWin")
    
    if keyReleased {
        ; Win was released, activate the selected window
        if WindowSwitcher && IsObject(WindowSwitcher) {
            ; Get the focused control and extract window HWND from its name
            try {
                FocusedControl := WindowSwitcher.FocusedCtrl
            } catch {
                FocusedControl := 0
            }
            SelectedHWND := 0
            
            if FocusedControl {
                try {
                    ; Extract HWND from control name (like "IconForWindowWithHWND12345")
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
                    ; Restore window if it's minimized
                    if WinGetMinMax(SelectedHWND) == -1 {
                        WinRestore(SelectedHWND)
                    }
                    WinActivate(SelectedHWND)
                } catch {
                }
            }
        }
        ; Stop the timer
        SetTimer(CheckWinReleaseAfterQ, 0)
    }
}


;--------------------------------------------------------
; Utility functions from original scripts
;--------------------------------------------------------

GroupIDCounter := 0

SortArray(Array, ComparisonFunction) {
    ; Insertion sort
    i := 1
    while (i < Array.Length) {
        j := i
        while (j > 0 && ComparisonFunction(Array[j], Array[j + 1]) > 0) {
            Tmp := Array[j]
            Array[j] := Array[j + 1]
            Array[j + 1] := Tmp
            j--
        }
        i++
    }
    return Array
}

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
; AUTO RELOAD THIS SCRIPT
;--------------------------------------------------------
~^s:: {
    if WinActive(A_ScriptName) {
        MakeSplash("AHK Auto-Reload", "`n  Reloading " A_ScriptName "  `n", 500)
        Reload
    }
}

MakeSplash(Title, Text, Duration := 0) {
    SplashGui := Gui(, Title)
    SplashGui.Opt("+AlwaysOnTop +Disabled -SysMenu +Owner")
    SplashGui.Add("Text", , Text)
    SplashGui.Show("NoActivate")
    if Duration {
        Sleep(Duration)
        SplashGui.Destroy()
    }
    return SplashGui
}

;--------------------------------------------------------
; Status Display
;--------------------------------------------------------

