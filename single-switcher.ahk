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

; Always use horizontal layout

;--------------------------------------------------------
; Global variables
;--------------------------------------------------------

global WindowSwitcher := 0
global AllSwitchableWindows := []
global IsWindowSwitcherActive := false
global AltQPressed := false
global MouseClickHandled := false
global TitleDisplay := 0
global ControlToHWND := Map()
global OriginalActiveWindow := 0  ; Store the window that was active before Alt+Tab

global WindowToClose := 0  ; Store window handle for asynchronous closing
global MouseHoverTimer := 0  ; Timer for mouse hover detection
global EscapePressed := false  ; Flag to indicate Esc was pressed
global CurrentModifier := ""  ; Track which modifier key is being used (Alt or Win)
global DateTimeTab := 0  ; Date/time tab at the top
global DateTimeTabWindow := 0  ; Separate window for the tab that sticks up
global DebugLoggingEnabled := false  ; Global flag to enable/disable debug logging


;--------------------------------------------------------
; Debug logging
;--------------------------------------------------------

DebugLog(message) {
    global DebugLoggingEnabled
    
    ; Only log if debugging is enabled
    if !DebugLoggingEnabled {
        return
    }
    
    try {
        timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.fff")
        FileAppend(timestamp " | " message "`n", "debug.log")
    } catch {
        ; Ignore logging errors
    }
}

InitDebugLog() {
    global DebugLoggingEnabled
    
    ; Only initialize if debugging is enabled
    if !DebugLoggingEnabled {
        return
    }
    
    try {
        ; Clear previous log
        FileDelete("debug.log")
        DebugLog("=== SCRIPT STARTED ===")
    } catch {
        ; Ignore errors
    }
}

;--------------------------------------------------------
; Utility functions
;--------------------------------------------------------

; Asynchronous window closing to prevent interference with Alt+Tab switcher
AsyncCloseWindow(TargetHWND) {
    global WindowToClose
    WindowToClose := TargetHWND
    ; Use a short timer to close the window asynchronously
    SetTimer(DoAsyncWindowClose, 10)
}

DoAsyncWindowClose() {
    global WindowToClose, WindowSwitcher
    if WindowToClose {
        try {
            ; Debug: Check if we're accidentally closing the switcher itself
            if WindowSwitcher && IsObject(WindowSwitcher) {
                SwitcherHWND := WindowSwitcher.HWND
                if WindowToClose == SwitcherHWND {
                    DebugLog("ERROR: Trying to close switcher window itself!")
                    WindowToClose := 0
                    SetTimer(DoAsyncWindowClose, 0)
                    return
                }
            }
            
            DebugLog("DoAsyncWindowClose: Closing window " WindowToClose)
            WinClose("ahk_id " WindowToClose)
        } catch {
            ; Window might already be closed or invalid
            DebugLog("DoAsyncWindowClose: Error closing window")
        }
        WindowToClose := 0
    }
    ; Stop the timer
    SetTimer(DoAsyncWindowClose, 0)
}

EscapeHandler(*) {
    DebugLog("GUI Escape Event: Closing switcher")
    CloseWindowSwitcher()
}

CloseHandler(*) {
    DebugLog("GUI Close Event Triggered!")
}


GetWindowIconHandle(hwnd) {
    ; Optimized icon retrieval with early returns
    try {
        if (iconHandle := SendMessage(WM_GETICON, ICON_BIG, 0, , hwnd))
            return iconHandle
        if (iconHandle := SendMessage(WM_GETICON, ICON_SMALL2, 0, , hwnd))
            return iconHandle
        if (iconHandle := SendMessage(WM_GETICON, ICON_SMALL, 0, , hwnd))
            return iconHandle
        if (iconHandle := GetClassLongPtrA(hwnd, GCLP_HICON))
            return iconHandle
        if (iconHandle := GetClassLongPtrA(hwnd, GCLP_HICONSM))
            return iconHandle
        
        ; Last resort: extract from executable
        if (ProcessPath := WinGetProcessPath(hwnd)) {
            iconHandle := DllCall("Shell32.dll\ExtractIcon", "Ptr", A_ScriptHwnd, "Str", ProcessPath, "UInt", 0, "Ptr")
            return (iconHandle > 1) ? iconHandle : 0
        }
    } catch {
    }
    return 0
}

GetClassLongPtrA(hwnd, nIndex) {
    return DllCall("GetClassLongPtrA", "Ptr", hwnd, "int", nIndex, "Ptr")
}

; Optimized window filtering function
IsValidSwitchableWindow(WindowID, WindowTitle, ProcessName) {
    return !(WindowTitle == "" || 
             ProcessName == "dwm.exe" || 
             ProcessName == "winlogon.exe" || 
             ProcessName == "csrss.exe" ||
             WindowTitle == "Program Manager" ||
             WindowTitle == "Task Switching" ||
             (WindowSwitcher && IsObject(WindowSwitcher) && WindowID == WindowSwitcher.HWND))
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

; Optimized window collection and sorting function
CollectAndSortWindows() {
    SwitchableWindows := []
    AllWindows := WinGetList()
    
    for WindowID in AllWindows {
        try {
            WindowTitle := WinGetTitle("ahk_id " WindowID)
            ProcessName := WinGetProcessName("ahk_id " WindowID)
            
            ; Skip invalid windows using optimized filter
            if (!IsValidSwitchableWindow(WindowID, WindowTitle, ProcessName)) {
                continue
            }
            
            ; Get window icon
            WindowIcon := GetWindowIconHandle(WindowID)
            
            ; Create window object
            SwitchableWindows.Push({
                HWND: WindowID,
                Title: WindowTitle,
                ProcessName: ProcessName,
                Icon: WindowIcon
            })
        } catch {
            continue
        }
    }
    
    ; Sort windows by Z-order using insertion sort (optimized for small arrays)
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
    
    return SortedWindows
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

RemoveWindowFromSwitcher(TargetHWND, NewFocusIndex) {
    global WindowSwitcher, ControlToHWND, AllSwitchableWindows, TitleDisplay
    
    ; Find and remove the control for this HWND
    ControlToRemove := ""
    for Control, HWND in ControlToHWND {
        if HWND == TargetHWND {
            ControlToRemove := Control
            break
        }
    }
    
    if ControlToRemove {
        ; Remove the control from the GUI (this leaves a gap)
        try {
            ControlToRemove.Destroy()
        } catch {
            ; Control might already be destroyed
        }
        
        ; Remove from our mapping
        ControlToHWND.Delete(ControlToRemove)
    }
    
    ; Get all remaining controls and reposition them to remove gaps
    RemainingControls := []
    for Control, HWND in ControlToHWND {
        ; Verify this window still exists in our updated list
        WindowExists := false
        for window in AllSwitchableWindows {
            if window.HWND == HWND {
                WindowExists := true
                break
            }
        }
        if WindowExists {
            RemainingControls.Push({Control: Control, HWND: HWND})
        }
    }
    
    ; Reposition remaining controls to remove gaps
    IconSize := 48
    IconSpacing := 10
    StartX := 10
    StartY := 10
    
    for index, item in RemainingControls {
        xPos := StartX + ((index - 1) * (IconSize + IconSpacing))
        try {
            item.Control.Move(xPos, StartY, IconSize, IconSize)
        } catch {
            ; Control might be invalid
        }
    }
    
    ; Update focus to the next available control
    if RemainingControls.Length > 0 {
        FocusIndex := NewFocusIndex
        if FocusIndex > RemainingControls.Length {
            FocusIndex := RemainingControls.Length
        }
        if FocusIndex < 1 {
            FocusIndex := 1
        }
        
        try {
            TargetControl := RemainingControls[FocusIndex].Control
            WindowSwitcher.FocusedCtrl := TargetControl
            UpdateFocusHighlight()
        } catch {
            ; Focus update failed - try the first available control
            if RemainingControls.Length > 0 {
                try {
                    WindowSwitcher.FocusedCtrl := RemainingControls[1].Control
                    UpdateFocusHighlight()
                } catch {
                    ; Complete focus failure
                }
            }
        }
    }
    
    ; Resize the switcher window to fit remaining controls (preserve position)
    if RemainingControls.Length > 0 {
        NewWidth := (RemainingControls.Length * (IconSize + IconSpacing)) + IconSpacing
        NewHeight := IconSize + (IconSpacing * 2) + 60  ; Extra space for title
        
        try {
            ; Get current position to preserve it
            WindowSwitcher.GetPos(&CurrentX, &CurrentY, &CurrentW, &CurrentH)
            WindowSwitcher.Move(CurrentX, CurrentY, NewWidth, NewHeight)
        } catch {
            ; Resize failed, try without position preservation
            try {
                WindowSwitcher.Move(, , NewWidth, NewHeight)
            } catch {
                ; Complete resize failure
            }
        }
    }
}

ShowWindowSwitcher(Windows, FocusIndex := 1) {
    global OriginalActiveWindow
    
    ; Capture the currently active window before opening switcher
    try {
        OriginalActiveWindow := WinGetID("A")
    } catch {
        OriginalActiveWindow := 0
    }
    
    CloseWindowSwitcher()  ; Close any existing switcher
    
    ; Small delay to ensure GUI is fully destroyed
    Sleep(50)
    
    ; Try GuiExt first, fall back to regular Gui if not available
    try {
        global WindowSwitcher := GuiExt()
    } catch {
        global WindowSwitcher := Gui()
    }
    global TitleDisplay := 0
    global ControlToHWND := Map()  ; Reset the mapping
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
    
    ; Create selection underline element
    BorderThickness := 3
    global UnderlineBorder := WindowSwitcher.Add("Text", "x0 y0 w10 h" BorderThickness " Background0xFF00FF", "")
    
    ; Initially hide the underline
    UnderlineBorder.Visible := false
    
    ; Add date/time text at the top of the window, left-aligned
    CurrentDateTime := FormatTime(A_Now, "HH:mm ddd MMM dd")
    global DateTimeTab := WindowSwitcher.Add("Text", "x10 y5 w400 h20 Left Background0x000000 cWhite", CurrentDateTime)
    DateTimeTab.SetFont("s9", "Segoe UI")
    
        ; Horizontal layout - icons in a row
        MaxIconsPerRow := 10  ; Adjust as needed
    
        
        for index, window in Windows {
        
        ; Position calculation for horizontal layout - use absolute coordinates
        ; Move icons down to make room for the date/time at the top
        AbsoluteX := 10 + (index - 1) * (IconSize + IconSpacing)
        AbsoluteY := 30  ; Moved down to make room for date/time
        
        xPos := "x" AbsoluteX
        yPos := "y" AbsoluteY
        
            
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
            
        ; Create icon control without naming it - make sure it can receive focus and mouse events
        ControlOptions := xPos " " yPos " w" IconSize " h" IconSize " Tabstop +0x200"  ; Add SS_NOTIFY for mouse events
        
        
            CreateWindowIcon(window, ControlOptions)
        }
        
    ; Add title display area below icons
        TitleAreaY := "y+" (IconSpacing + 10)  ; Add some extra spacing below icons
    TitleDisplay := WindowSwitcher.Add("Text", "x10 y" (30 + IconSize + 10) " w400 h50 cWhite Background0x2D2D30", "")
        TitleDisplay.SetFont("s10", "Segoe UI")
    
    WindowSwitcher.OnEvent("Escape", EscapeHandler)
    WindowSwitcher.OnEvent("Close", CloseHandler)
    WindowSwitcher.Opt("+AlwaysOnTop -SysMenu -Caption -Border +Owner")
    
    ; Simple center positioning - use primary monitor
    try {
        MonitorGet(1, &MonLeft, &MonTop, &MonRight, &MonBottom)
        ScreenWidth := MonRight - MonLeft
        ScreenHeight := MonBottom - MonTop
        ScreenCenterX := MonLeft + (ScreenWidth // 2)
        ScreenCenterY := MonTop + (ScreenHeight // 2)
        CenterX := ScreenCenterX - 200  ; Estimate window width/2
        CenterY := ScreenCenterY - 85   ; Estimate window height/2 + extra for tab
        DebugLog("Monitor: " MonLeft "," MonTop " to " MonRight "," MonBottom)
        DebugLog("Screen center: " ScreenCenterX "," ScreenCenterY " GUI: " CenterX "," CenterY)
    } catch {
        ; Fallback to simple center
        CenterX := 960
        CenterY := 525  ; Adjusted for tab
        DebugLog("Using fallback center: " CenterX "," CenterY)
    }
    
    WindowSwitcher.Show("x" CenterX " y" CenterY)
    
    ; Date/time is now part of the main window (no separate tab needed)
    
    ; Mouse hover detection disabled due to coordinate issues
    ; MouseHoverTimer := SetTimer(CheckMouseHover, 100)
    
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
    global WindowSwitcher, ControlToHWND
    
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
        ; Store the mapping between control object and HWND
        ControlToHWND[IconControl] := window.HWND
        
        ; Add click event handler to the icon control
        IconControl.OnEvent("Click", (*) => OnIconClick(window.HWND))
        
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
        
        ; Store the mapping between control object and HWND
        ControlToHWND[IconControl] := window.HWND
        
        ; Add click event handler to the fallback control too
        IconControl.OnEvent("Click", (*) => OnIconClick(window.HWND))
        
    }
}

GetHWNDFromControl(control) {
    ; Helper function to get HWND from a focused control
    global ControlToHWND
    
    if !control {
        return 0
    }
    
    try {
        return ControlToHWND[control]
    } catch {
        return 0
    }
}







OnIconClick(TargetHWND) {
    ; Handle mouse click on an icon - immediately activate window and close switcher
    global WindowSwitcher, MouseClickHandled
    
    ; Set flag to prevent Alt release from activating a different window
    MouseClickHandled := true
    
    try {
        ; Close the switcher immediately
        CloseWindowSwitcher()
        
        ; Restore window if it's minimized
        MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
        if MinMaxState == -1 {
            WinRestore("ahk_id " TargetHWND)
            Sleep(100)
        }
        
        ; Activate the clicked window
        WinActivate("ahk_id " TargetHWND)
    } catch {
        ; If activation fails, just close the switcher
        CloseWindowSwitcher()
    }
}

; Mouse hover detection disabled due to coordinate system issues
; CheckMouseHover() {
;     ; Function disabled
; }

; CreateDateTimeTab function removed - date/time is now part of the main window

CloseWindowSwitcher(*) {
    global WindowSwitcher, IsWindowSwitcherActive, ControlToHWND, MouseHoverTimer, DateTimeTabWindow
    
    DebugLog("CloseWindowSwitcher: Starting cleanup")
    IsWindowSwitcherActive := false
    
    ; Stop mouse hover timer
    if MouseHoverTimer {
        SetTimer(MouseHoverTimer, 0)
        MouseHoverTimer := 0
    }
    
    ; Date/time is now part of the main window (no separate cleanup needed)
    
    if !WindowSwitcher {
        return
    }
    
    
    ; Clear control mapping
    ControlToHWND := Map()
    
    OldWindowSwitcher := WindowSwitcher
    WindowSwitcher := 0
    OldWindowSwitcher.Destroy()
}

LastFocusHighlight := 0
UpdateFocusHighlight() {
    global UnderlineBorder, WindowSwitcher, TitleDisplay, AllSwitchableWindows
    
    ; Make sure WindowSwitcher is a valid GUI object
    if !WindowSwitcher || !IsObject(WindowSwitcher) || !UnderlineBorder {
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
            
            BorderThickness := 3
            
            ; Position the underline below the control
            UnderlineBorder.Move(x, y + h + 2, w, BorderThickness)
            UnderlineBorder.Visible := true
            
            ; Update title display
            if (TitleDisplay && IsObject(TitleDisplay)) {
                try {
                    ; Get HWND from the focused control
                    SelectedHWND := GetHWNDFromControl(FocusedControl)
                    
                    if (SelectedHWND) {
                        ; Get window title directly
                        WindowTitle := ""
                        try {
                            WindowTitle := WinGetTitle(SelectedHWND)
                        } catch {
                            WindowTitle := "Unknown Window"
                        }
                        
                        ; Clean up the title - show only the first part when separated by " - "
                        if (WindowTitle != "") {
                            ; Split by " - " and only show the first part if there are multiple parts
                            TitleParts := StrSplit(WindowTitle, " - ")
                            if (TitleParts.Length >= 2) {
                                FirstPart := Trim(TitleParts[1])
                                ; Only use the first part if it has meaningful content
                                if (StrLen(FirstPart) >= 1) {
                                            WindowTitle := FirstPart
                                }
                            }
                        }
                        
                        ; Update the title display (with leading space for margin)
                        TitleDisplay.Text := " " . Trim(WindowTitle)
                    }
                } catch {
                    ; If title update fails, clear the display
                    if (TitleDisplay && IsObject(TitleDisplay)) {
                        TitleDisplay.Text := ""
                    }
                }
            }
            
        } catch {
            ; If positioning fails, hide the underline
            UnderlineBorder.Visible := false
        }
    } else {
        ; No focused control, hide underline and clear title
        UnderlineBorder.Visible := false
        
        ; Clear title display
        if (TitleDisplay && IsObject(TitleDisplay)) {
            TitleDisplay.Text := ""
        }
    }
}

;--------------------------------------------------------
; Main Alt+Tab functionality
;--------------------------------------------------------

; Alt+Tab hotkey - revert to original working pattern
; Unified Tab switching function for both Alt+Tab and Win+Tab
HandleTabSwitching() {
    global WindowSwitcher, IsWindowSwitcherActive, AllSwitchableWindows, AltQPressed, MouseClickHandled, EscapePressed
    
    ; Reset flags at the start
    MouseClickHandled := false
    EscapePressed := false
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Switcher is already open, cycle through windows
        WinActivate(WindowSwitcher.HWND)
        Sleep(20)
        Send "{Tab}"
        UpdateFocusHighlight()
        
        ; Just cycle through windows - no timer needed
        DebugLog("HandleTabSwitching: Cycling through windows")
        return
    }
    
    
    ; Collect and sort all switchable windows using optimized function
    SortedWindows := CollectAndSortWindows()
    AllSwitchableWindows := SortedWindows
    ShowWindowSwitcher(SortedWindows)
    
    ; Initially select the next window (index 2, since index 1 is current)
            Send "{Tab}"
        UpdateFocusHighlight()
    
    ; Wait for the appropriate modifier key to be released, then activate selected window
    if CurrentModifier == "Win" {
        KeyWait "LWin"
    } else {
        KeyWait "LAlt"
    }
    
    ; Check if Esc was pressed - if so, don't activate any window
    if EscapePressed {
        ; Esc was pressed, just close switcher without activating
        CloseWindowSwitcher()
        return
    }
    
    ; Check if mouse click already handled activation
    if MouseClickHandled {
        ; Mouse click already activated a window, don't activate again
        CloseWindowSwitcher()
        return
    }
    
    ; Activate the selected window
        try {
            FocusedCtrl := WindowSwitcher.FocusedCtrl
        if FocusedCtrl {
            TargetHWND := GetHWNDFromControl(FocusedCtrl)
            
            if (TargetHWND) {
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
        ; Fallback - activate the first available window
        if AllSwitchableWindows.Length > 1 {
            try {
                TargetHWND := AllSwitchableWindows[2].HWND
                MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
                if MinMaxState == -1 {
                    WinRestore("ahk_id " TargetHWND)
                    Sleep(100)
                }
                WinActivate("ahk_id " TargetHWND)
            } catch {
                ; Window no longer exists, just close switcher
                CloseWindowSwitcher()
            }
        }
    }
    
    ; Close the switcher
    CloseWindowSwitcher()
}

!Tab:: {
    global CurrentModifier
    CurrentModifier := "Alt"
    HandleTabSwitching()
}

; Alt+Shift+Tab hotkey - reverse direction
; Unified reverse Tab switching function for both Alt+Shift+Tab and Win+Shift+Tab
HandleReverseTabSwitching() {
    global WindowSwitcher, IsWindowSwitcherActive, AllSwitchableWindows, AltQPressed, MouseClickHandled, EscapePressed
    
    ; Reset flags at the start
    MouseClickHandled := false
    EscapePressed := false
    
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Switcher is already open, cycle backwards through windows
        WinActivate(WindowSwitcher.HWND)
        Sleep(20)
        Send "+{Tab}"  ; Shift+Tab for reverse
        UpdateFocusHighlight()
        
        return
    }
    
    ; First time opening - get all switchable windows using optimized function
    SortedWindows := CollectAndSortWindows()
    AllSwitchableWindows := SortedWindows
    ShowWindowSwitcher(SortedWindows)
    
    ; Start with reverse direction
        Send "+{Tab}"
    UpdateFocusHighlight()
    
    ; Wait for the appropriate modifier key to be released, then activate selected window
    if CurrentModifier == "Win" {
        KeyWait "LWin"
    } else {
        KeyWait "LAlt"
    }
    
    ; Check if Esc was pressed - if so, don't activate any window
    if EscapePressed {
        ; Esc was pressed, just close switcher without activating
        CloseWindowSwitcher()
        return
    }
    
    ; Check if mouse click already handled activation
    if MouseClickHandled {
        ; Mouse click already activated a window, don't activate again
        CloseWindowSwitcher()
        return
    }
    
    ; Activate the selected window
    try {
        FocusedCtrl := WindowSwitcher.FocusedCtrl
        if FocusedCtrl {
            TargetHWND := GetHWNDFromControl(FocusedCtrl)
            
            if (TargetHWND) {
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
        ; Fallback - activate the second available window
        if AllSwitchableWindows.Length > 1 {
            try {
                TargetHWND := AllSwitchableWindows[2].HWND
                MinMaxState := WinGetMinMax("ahk_id " TargetHWND)
                if MinMaxState == -1 {
                    WinRestore("ahk_id " TargetHWND)
                    Sleep(100)
                }
                WinActivate("ahk_id " TargetHWND)
            } catch {
                ; Window no longer exists, just close switcher
                CloseWindowSwitcher()
            }
        }
    }
    
    ; Close the switcher
    CloseWindowSwitcher()
    
    ; Function ends here
}

!+Tab:: {
    global CurrentModifier
    CurrentModifier := "Alt"
    HandleReverseTabSwitching()
}

; Win+Tab hotkey - same functionality as Alt+Tab for external keyboards
#Tab:: {
    global CurrentModifier
    CurrentModifier := "Win"
    HandleTabSwitching()
}

; Win+Shift+Tab hotkey - reverse direction for external keyboards
#+Tab:: {
    global CurrentModifier
    CurrentModifier := "Win"
    HandleReverseTabSwitching()
}

; Alt+Esc and Win+Esc to close the Alt+Tab window without switching
!Escape::
#Escape:: {
    global WindowSwitcher, OriginalActiveWindow, EscapePressed
    
    DebugLog("=== ALT+ESCAPE HOTKEY TRIGGERED! ===")
    DebugLog("Alt+Escape: WindowSwitcher exists = " (WindowSwitcher ? "true" : "false"))
    
    ; Only work if the switcher is currently active
    if WindowSwitcher && IsObject(WindowSwitcher) {
        ; Set flag to prevent window activation after Alt release
        EscapePressed := true
        
        ; Close the switcher first
        DebugLog("Alt+Escape: Closing switcher normally")
                        CloseWindowSwitcher()
        
        ; Return to the original window that was active before Alt+Tab
        if OriginalActiveWindow {
            try {
                ; Restore if minimized
                MinMaxState := WinGetMinMax("ahk_id " OriginalActiveWindow)
                if MinMaxState == -1 {
                    WinRestore("ahk_id " OriginalActiveWindow)
                    Sleep(100)
                }
                WinActivate("ahk_id " OriginalActiveWindow)
            } catch {
                ; Original window might not exist anymore, do nothing
            }
        }
    }
}

; Alt+Q and Win+Q to close/kill the currently selected window while switcher is open
!q::
#q:: {
    global WindowSwitcher, AllSwitchableWindows, ControlToHWND, CurrentModifier
    
    ; Only work if the switcher is currently active
    if WindowSwitcher && IsObject(WindowSwitcher) {
        DebugLog("Alt+Q: Close window and refresh switcher")
        
        ; Get the currently focused control and close its window
        try {
            FocusedControl := WindowSwitcher.FocusedCtrl
            if FocusedControl {
                TargetHWND := GetHWNDFromControl(FocusedControl)
                
                if (TargetHWND) {
                    DebugLog("Alt+Q: Closing window " TargetHWND)
                    
                    ; Close the window
                    WinClose("ahk_id " TargetHWND)
                    Sleep(150)  ; Wait for window to close
                    
                    ; Close the current switcher
                    CloseWindowSwitcher()
                    
                    ; Brief pause then reopen the switcher with updated window list
                    Sleep(50)
                    
                    ; Reopen the switcher (same as Alt+Tab)
                    HandleTabSwitching()
                }
            }
        } catch {
            DebugLog("Alt+Q: Error during window close")
        }
        
        return
    }
    
    ; If switcher is not active, send normal Q
    Send "q"
    return
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
; Caps Lock to Ctrl Remap Configuration
;--------------------------------------------------------

; Remap Caps Lock to act as Ctrl
CapsLock::Ctrl

; Ensure Caps Lock state is off at startup (so it acts as modifier, not toggle)
SetCapsLockState("Off")

; Initialize debug logging
InitDebugLog()

;--------------------------------------------------------
; Status Display
;--------------------------------------------------------

