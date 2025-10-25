; Requires AutoHotkey v2
; Screenshot Tool - Drag Area to Clipboard
; Ctrl+9 to activate drag-area screenshot

#SingleInstance Force

; Global variables for screenshot functionality
global ScreenshotActive := false
global StartX := 0, StartY := 0, EndX := 0, EndY := 0
global OverlayGui := 0
global SelectionGui := 0
global ReferenceGui := 0
global DebugGui := 0
global DPIScaleX := 1.0, DPIScaleY := 1.0, DPIChecked := false

; Debug logging function (disabled for performance)
; Debug logging removed for clean performance

; Ctrl+9 hotkey to start drag-area screenshot
^9::StartDragScreenshot()


StartDragScreenshot() {
    global ScreenshotActive, OverlayGui, StartX, StartY, SelectionGui, DPIChecked
    
    if (ScreenshotActive) {
        return ; Already in screenshot mode
    }
    
    ScreenshotActive := true
    DPIChecked := false  ; Reset DPI check for new session
    
    ; Get current cursor position as the anchor point (FIXED - never changes)
    MouseGetPos(&StartX, &StartY)
    
    ; Create full-screen overlay to capture mouse events
    OverlayGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound +ToolWindow", "Screenshot")
    OverlayGui.BackColor := "Black"
    OverlayGui.MarginX := 0
    OverlayGui.MarginY := 0
    
    ; Make the overlay semi-transparent
    WinSetTransparent(50, OverlayGui.HWND)
    
    ; Get screen dimensions
    MonitorGet(1, &MonLeft, &MonTop, &MonRight, &MonBottom)
    ScreenWidth := MonRight - MonLeft
    ScreenHeight := MonBottom - MonTop
    
    ; Show overlay covering entire screen
    OverlayGui.Show("x" MonLeft " y" MonTop " w" ScreenWidth " h" ScreenHeight " NoActivate")
    
    ; Set up mouse events
    OverlayGui.OnEvent("Close", CancelScreenshot)
    
    ; Add instructions text
    InstructionText := OverlayGui.Add("Text", "x10 y10 cWhite", "Move mouse to select area from anchor point. Click to capture. Press ESC to cancel.")
    InstructionText.SetFont("s12 Bold", "Segoe UI")
    
    ; Create selection rectangle GUI with translucent magenta fill
    global SelectionGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound +ToolWindow -Caption +E0x80000", "Selection")
    SelectionGui.BackColor := "0xFF00FF"  ; Magenta background
    SelectionGui.MarginX := 0
    SelectionGui.MarginY := 0
    
    ; Diagonal lines removed for cleaner appearance
    
    ; Create a small red circle at the exact origin point
    global ReferenceGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound +ToolWindow -Caption +E0x80000", "RedDot")
    ReferenceGui.BackColor := "Red"
    ReferenceGui.MarginX := 0
    ReferenceGui.MarginY := 0
    
    ; Show a small red circle (8x8 pixels)
    ReferenceGui.Show("x" (StartX-4) " y" (StartY-4) " w8 h8 NoActivate")
    
    ; Make it circular by setting a circular region
    DllCall("SetWindowRgn", "Ptr", ReferenceGui.Hwnd, "Ptr", DllCall("CreateEllipticRgn", "Int", 0, "Int", 0, "Int", 8, "Int", 8, "Ptr"), "Int", 1)
    
    ; Debug window disabled for performance
    ; MonitorGet(1, &MonLeft, &MonTop, &MonRight, &MonBottom)
    ; global DebugGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound +ToolWindow", "Debug")
    ; DebugGui.BackColor := "White"
    ; DebugGui.MarginX := 5
    ; DebugGui.MarginY := 5
    
    ; global DebugText := DebugGui.Add("Text", "w350 h200 Left", "Debug Info")
    ; DebugText.SetFont("s9", "Consolas")
    
    ; Position debug window in upper area (moved much further left to stay on screen)
    ; DebugGui.Show("x" (MonRight - 700) " y" (MonTop + 10) " w370 h220 NoActivate")
    
    ; Start tracking mouse movement immediately
    SetTimer(UpdateSelection, 10)
    
    ; Hook mouse events
    SetupMouseHook()
    
    ; Set cursor to crosshair
    DllCall("SetSystemCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32515), "UInt", 32512)
}

SetupMouseHook() {
    ; Set up hotkeys for mouse events during screenshot mode
    Hotkey("LButton", OnMouseDown, "On")
    Hotkey("LButton Up", OnMouseUp, "On")
    Hotkey("Escape", CancelScreenshot, "On")
}

OnMouseDown(*) {
    global ScreenshotActive, StartX, StartY
    
    if (!ScreenshotActive) {
        return
    }
    
    ; Mouse button down - start dragging from anchor point
    ; The selection rectangle should already be showing from anchor to current position
    ; Just continue tracking until mouse button is released
}

OnMouseUp(*) {
    global ScreenshotActive, StartX, StartY
    
    if (!ScreenshotActive) {
        return
    }
    
    ; Mouse button released - take the screenshot
    ; Check if there's been meaningful movement from anchor point
    MouseGetPos(&CurrentX, &CurrentY)
    Width := Abs(CurrentX - StartX)
    Height := Abs(CurrentY - StartY)
    
    ; Stop tracking and take screenshot
    SetTimer(UpdateSelection, 0)
    TakeScreenshot()
}

UpdateSelection() {
    global StartX, StartY, SelectionGui, ScreenshotActive, DPIScaleX, DPIScaleY, DPIChecked
    
    if (!ScreenshotActive) {
        return
    }
    
    ; Debug tooltips removed for clean experience
    
    ; Check if SelectionGui is valid, if not recreate it
    if (!SelectionGui || !IsObject(SelectionGui)) {
        try {
            SelectionGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound +ToolWindow -Caption +E0x80000", "Selection")
            SelectionGui.BackColor := "0xFF00FF"  ; Magenta background
            SelectionGui.MarginX := 0
            SelectionGui.MarginY := 0
        } catch Error as e {
            return  ; If GUI creation fails, skip this update
        }
    }
    
    ; Get current mouse position (this is the far corner of the box)
    MouseGetPos(&CurrentX, &CurrentY)
    
    ; Debug: Show that origin stays fixed
    ToolTip("Origin: " StartX "," StartY " | Mouse: " CurrentX "," CurrentY)
    
    ; KEEP A FIXED! Rectangle GUI positioned so origin A always appears at StartX, StartY
    ; A = origin at (StartX, StartY) - NEVER moves visually
    ; B = mouse at (CurrentX, CurrentY) - follows mouse
    ; 
    ; Quadrants:  W | X
    ;           ----A----  
    ;            Y  | Z
    
    ; FIXED ORIGIN APPROACH: Point A (StartX, StartY) NEVER MOVES
    ; Only calculate Width/Height from A to current mouse position
    ; GUI positioning ensures A appears at StartX, StartY on screen
    
    ; Calculate Width and Height as distances (always positive)
    Width := Abs(CurrentX - StartX)
    Height := Abs(CurrentY - StartY)
    
    ; Determine which quadrant we're in - simple positioning (no border compensation needed with borderless GUI)
    if (CurrentX >= StartX && CurrentY >= StartY) {
        Quadrant := "Z"
        ; Quadrant Z (bottom-right): A is top-left corner
        GuiLeft := StartX
        GuiTop := StartY
    } else if (CurrentX < StartX && CurrentY >= StartY) {
        Quadrant := "Y"
        ; Quadrant Y (bottom-left): A is top-right corner  
        GuiLeft := StartX - Width
        GuiTop := StartY
    } else if (CurrentX >= StartX && CurrentY < StartY) {
        Quadrant := "X"
        ; Quadrant X (top-right): A is bottom-left corner
        GuiLeft := StartX
        GuiTop := StartY - Height
    } else {
        Quadrant := "W"
        ; Quadrant W (top-left): Red dot MUST be at bottom-right corner
        ; Rectangle from mouse (CurrentX, CurrentY) to red dot (StartX, StartY)
        ; So GUI should start at mouse position and end at red dot position
        GuiLeft := CurrentX
        GuiTop := CurrentY
        ; Width and Height are already calculated as distances
    }
    
    ; Log debug info for current quadrant
    ; Calculate box corner coordinates
    ; h = top-left, i = top-right, j = bottom-left, k = bottom-right
    BoxH_X := GuiLeft, BoxH_Y := GuiTop
    BoxI_X := GuiLeft + Width, BoxI_Y := GuiTop
    BoxJ_X := GuiLeft, BoxJ_Y := GuiTop + Height
    BoxK_X := GuiLeft + Width, BoxK_Y := GuiTop + Height
    
    
    ; Calculate expected corner position based on quadrant
    if (Quadrant == "Z") {
        ExpectedCornerX := GuiLeft, ExpectedCornerY := GuiTop  ; Top-left
        CornerName := "top-left"
    } else if (Quadrant == "Y") {
        ExpectedCornerX := GuiLeft + Width, ExpectedCornerY := GuiTop  ; Top-right
        CornerName := "top-right"
    } else if (Quadrant == "X") {
        ExpectedCornerX := GuiLeft, ExpectedCornerY := GuiTop + Height  ; Bottom-left
        CornerName := "bottom-left"
    } else {  ; Quadrant W
        ExpectedCornerX := GuiLeft + Width, ExpectedCornerY := GuiTop + Height  ; Bottom-right
        CornerName := "bottom-right"
    }
    
    
    ; Check if math is correct AND if red dot would be at corner (not inside)
    MathCorrect := (ExpectedCornerX == StartX && ExpectedCornerY == StartY)
    
    ; Additional check: Is red dot inside the rectangle bounds?
    RedDotInsideRect := (StartX > GuiLeft && StartX < GuiLeft + Width && StartY > GuiTop && StartY < GuiTop + Height)
    
    if (MathCorrect && !RedDotInsideRect) {
        MathStatus := "YES - At corner"
    } else if (MathCorrect && RedDotInsideRect) {
        MathStatus := "NO - Math says corner but red dot is INSIDE rectangle"
    } else if (!MathCorrect && RedDotInsideRect) {
        MathStatus := "NO - Math wrong AND red dot is inside"
    } else {
        MathStatus := "NO - Math wrong, red dot outside"
    }
    
    
    ; Debug window updates disabled for performance
    ; if (IsObject(DebugText)) {
    ;     try {
    ;         DebugInfo := "QUADRANT: " Quadrant "`n`n"
    ;         DebugInfo .= "Red dot (A) at: " StartX "," StartY "`n"
    ;         DebugInfo .= "Mouse at: " CurrentX "," CurrentY "`n`n"
    ;         DebugInfo .= "GUI position: " GuiLeft "," GuiTop "`n"
    ;         DebugInfo .= "GUI size: " Width " x " Height "`n`n"
    ;         DebugInfo .= "Box corners:`n"
    ;         DebugInfo .= "h(" BoxH_X "," BoxH_Y ")---i(" BoxI_X "," BoxI_Y ")`n"
    ;         DebugInfo .= "|                    |`n"
    ;         DebugInfo .= "j(" BoxJ_X "," BoxJ_Y ")---k(" BoxK_X "," BoxK_Y ")`n`n"
    ;         DebugInfo .= "A should be " CornerName " corner`n"
    ;         DebugInfo .= "Expected at: " ExpectedCornerX "," ExpectedCornerY "`n`n"
    ;         DebugInfo .= "Status: " MathStatus "`n"
    ;         DebugInfo .= "Red dot inside rect: " (RedDotInsideRect ? "YES (BAD)" : "NO (GOOD)")
    ;         DebugText.Text := DebugInfo
    ;     } catch {
    ;         ; DebugText control was destroyed, skip update
    ;     }
    ; }
    
    ; Debug: Verify A coordinates never change (commented out to see W-specific debug)
    ; ToolTip("A FIXED at (" StartX "," StartY ") | B at (" CurrentX "," CurrentY ")")
    
    ; Show translucent magenta rectangle
    if (Width > 4 && Height > 4) {
        if (!IsObject(SelectionGui)) {
            ; Recreate the GUI
            SelectionGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound +ToolWindow -Caption +E0x80000", "Selection")
            SelectionGui.BackColor := "0xFF00FF"  ; Magenta background
            SelectionGui.MarginX := 0
            SelectionGui.MarginY := 0
        }
        
        try {
            ; Check DPI scaling only once to avoid flickering
            if (!DPIChecked) {
                ; Test with a small GUI to determine DPI scaling
                TestGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound +ToolWindow -Caption +E0x80000", "DPITest")
                TestGui.Show("x0 y0 w100 h100 NoActivate")
                WinGetPos(&TestX, &TestY, &TestW, &TestH, TestGui.HWND)
                TestGui.Destroy()
                
                DPIScaleX := TestW / 100
                DPIScaleY := TestH / 100
                DPIChecked := true
                
            }
            
            ; Use DPI-compensated size if needed
            if (Abs(DPIScaleX - 1) > 0.1 || Abs(DPIScaleY - 1) > 0.1) {
                AdjustedWidth := Round(Width / DPIScaleX)
                AdjustedHeight := Round(Height / DPIScaleY)
                SelectionGui.Show("x" GuiLeft " y" GuiTop " w" AdjustedWidth " h" AdjustedHeight " NoActivate")
            } else {
                ; No scaling needed
                SelectionGui.Show("x" GuiLeft " y" GuiTop " w" Width " h" Height " NoActivate")
            }
            
            ; Make the rectangle translucent so you can see through it
            WinSetTransparent(120, SelectionGui.HWND)  ; Semi-transparent
            
            ; GUI is now showing successfully
            
        } catch Error as e {
        }
    }
}

TakeScreenshot() {
    global StartX, StartY, ScreenshotActive, OverlayGui, SelectionGui
    
    ; Get final mouse position
    MouseGetPos(&EndX, &EndY)
    
    ; Calculate screenshot area using same method as UpdateSelection
    Left := Min(StartX, EndX)
    Top := Min(StartY, EndY)
    Right := Max(StartX, EndX)
    Bottom := Max(StartY, EndY)
    Width := Right - Left
    Height := Bottom - Top
    
    ; Always clean up GUIs first - this ensures we exit screenshot mode
    CleanupScreenshot()
    
    ; Take screenshot if area is meaningful, otherwise show message
    if (Width > 10 && Height > 10) {
        ; Small delay to let GUIs close
        Sleep(100)
        
        ; Take screenshot of selected area and copy to clipboard
        CaptureAreaToClipboard(Left, Top, Width, Height)
        
        ; Also save screenshot to file and open in MS Paint
        SaveScreenshotAndOpenInPaint(Left, Top, Width, Height)
        
        ; Show success message
        ToolTip("Screenshot copied to clipboard and opened in MS Paint!")
        SetTimer(() => ToolTip(), -2000) ; Hide tooltip after 2 seconds
    } else {
        ; Show message for too small selection
        ToolTip("Selection too small - screenshot cancelled")
        SetTimer(() => ToolTip(), -2000) ; Hide tooltip after 2 seconds
    }
}

CaptureAreaToClipboard(X, Y, Width, Height) {
    ; Create a bitmap of the specified screen area and copy to clipboard
    
    ; Get screen DC
    ScreenDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    
    ; Create compatible DC and bitmap
    MemDC := DllCall("CreateCompatibleDC", "Ptr", ScreenDC, "Ptr")
    Bitmap := DllCall("CreateCompatibleBitmap", "Ptr", ScreenDC, "Int", Width, "Int", Height, "Ptr")
    
    ; Select bitmap into memory DC
    OldBitmap := DllCall("SelectObject", "Ptr", MemDC, "Ptr", Bitmap, "Ptr")
    
    ; Copy screen area to bitmap
    DllCall("BitBlt", "Ptr", MemDC, "Int", 0, "Int", 0, "Int", Width, "Int", Height, 
            "Ptr", ScreenDC, "Int", X, "Int", Y, "UInt", 0x00CC0020) ; SRCCOPY
    
    ; Copy bitmap to clipboard
    DllCall("OpenClipboard", "Ptr", 0)
    DllCall("EmptyClipboard")
    DllCall("SetClipboardData", "UInt", 2, "Ptr", Bitmap) ; CF_BITMAP = 2
    DllCall("CloseClipboard")
    
    ; Clean up (don't delete bitmap - clipboard owns it now)
    DllCall("SelectObject", "Ptr", MemDC, "Ptr", OldBitmap)
    DllCall("DeleteDC", "Ptr", MemDC)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", ScreenDC)
}

SaveScreenshotAndOpenInPaint(X, Y, Width, Height) {
    ; Create screenshots directory if it doesn't exist
    ScreenshotDir := "C:\temp\screenshots"
    if (!DirExist(ScreenshotDir)) {
        try {
            DirCreate(ScreenshotDir)
        } catch Error as e {
            ToolTip("Failed to create directory: " e.Message)
            SetTimer(() => ToolTip(), -3000)
            Run("mspaint.exe")
            return
        }
    }
    
    ; Generate unique filename with timestamp
    TimeStamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    FileName := "Screenshot_" TimeStamp ".png"
    FilePath := ScreenshotDir "\" FileName
    
    ; Save clipboard image to file and open in MS Paint
    try {
        ; Use PowerShell to save clipboard image
        PSCmd := 'powershell.exe -Command "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; if ([System.Windows.Forms.Clipboard]::ContainsImage()) { $img = [System.Windows.Forms.Clipboard]::GetImage(); $img.Save(\"' FilePath '\", [System.Drawing.Imaging.ImageFormat]::Png); $img.Dispose() }"'
        
        RunWait(PSCmd, , "Hide")
        Sleep(500)
        
        ; Open in MS Paint
        if (FileExist(FilePath)) {
            Run("mspaint.exe `"" FilePath "`"")
        } else {
            Run("mspaint.exe")
        }
        
    } catch Error as e {
        Run("mspaint.exe")
    }
}

CancelScreenshot(*) {
    CleanupScreenshot()
}

CleanupScreenshot() {
    global ScreenshotActive, OverlayGui, SelectionGui, ReferenceGui, DebugGui
    
    
    ScreenshotActive := false
    
    ; Clear any tooltips
    ToolTip()
    
    ; Remove hotkeys
    try {
        Hotkey("LButton", "Off")
        Hotkey("LButton Up", "Off")
        Hotkey("Escape", "Off")
    } catch {
        ; Hotkeys might not be set
    }
    
    ; Stop any timers
    SetTimer(UpdateSelection, 0)
    
    ; Close SelectionGui forcefully
    if (SelectionGui) {
        try {
            SelectionGui.Destroy()
        } catch {
        }
        SelectionGui := 0
    }
    
    if (ReferenceGui) {
        try {
            ReferenceGui.Destroy()
        } catch {
        }
        ReferenceGui := 0
    }
    
    if (DebugGui) {
        try {
            DebugGui.Destroy()
        } catch {
        }
        DebugGui := 0
    }
    
    ; Diagonal dots cleanup removed (no longer used)
    
    if (OverlayGui) {
        try {
            OverlayGui.Destroy()
        } catch {
        }
        OverlayGui := 0
    }
    
    ; Restore normal cursor
    DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0) ; SPI_SETCURSORS
}

; Clean up on script exit
OnExit((*) => CleanupScreenshot())
