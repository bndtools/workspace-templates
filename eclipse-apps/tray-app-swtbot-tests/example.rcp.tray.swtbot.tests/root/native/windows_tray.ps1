# Copyright (c) 2026 Kirschners GmbH and others.
# SPDX-License-Identifier: EPL-2.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

try {
    Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, WindowsBase
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class TrayNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT {
        public int dx, dy;
        public uint mouseData, dwFlags, time;
        public UIntPtr dwExtraInfo;
    }
    [StructLayout(LayoutKind.Explicit)] public struct INPUTUNION {
        [FieldOffset(0)] public MOUSEINPUT mi;
    }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT {
        public uint type;
        public INPUTUNION data;
    }
    public delegate bool EnumProc(IntPtr window, IntPtr parameter);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr window);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string className, string title);
    [DllImport("user32.dll")] public static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr desktop);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool GetUserObjectInformation(IntPtr handle, int index, StringBuilder name, int length, out int needed);
    [DllImport("user32.dll")] public static extern IntPtr GetThreadDesktop(uint thread);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", SetLastError=true)] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint count, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern uint GetDoubleClickTime();
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
    [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr menu);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetMenuString(IntPtr menu, uint index, StringBuilder text, int length, uint flags);
    [DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr menu, uint index, uint flags);
    [DllImport("user32.dll")] public static extern bool GetMenuItemRect(IntPtr window, IntPtr menu, uint index, out RECT rect);

    public static string Text(IntPtr window) {
        var text = new StringBuilder(2048);
        GetWindowText(window, text, text.Capacity);
        return text.ToString();
    }
    public static string ClassName(IntPtr window) {
        var text = new StringBuilder(256);
        GetClassName(window, text, text.Capacity);
        return text.ToString();
    }
    public static string DesktopName(IntPtr desktop) {
        var text = new StringBuilder(256);
        int needed;
        if (!GetUserObjectInformation(desktop, 2, text, text.Capacity * 2, out needed))
            throw new InvalidOperationException("Cannot query desktop name: " + Marshal.GetLastWin32Error());
        return text.ToString();
    }
    public static IntPtr[] Windows(uint pid, string className) {
        var found = new List<IntPtr>();
        EnumWindows((window, parameter) => {
            uint owner;
            GetWindowThreadProcessId(window, out owner);
            if ((pid == 0 || owner == pid) && IsWindowVisible(window) &&
                (String.IsNullOrEmpty(className) || ClassName(window) == className)) found.Add(window);
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
    public static IntPtr[] Children(IntPtr parent) {
        var found = new List<IntPtr>();
        EnumChildWindows(parent, (window, parameter) => {
            if (IsWindowVisible(window)) found.Add(window);
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
    public static void Click(int x, int y, bool right) {
        if (!SetCursorPos(x, y)) throw new InvalidOperationException(
            "SetCursorPos failed; unlock/reconnect the interactive desktop. Win32 error: " + Marshal.GetLastWin32Error());
        var inputs = new INPUT[2];
        inputs[0].data.mi.dwFlags = right ? 0x0008u : 0x0002u;
        inputs[1].data.mi.dwFlags = right ? 0x0010u : 0x0004u;
        if (SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT))) != 2)
            throw new InvalidOperationException("SendInput failed; desktop locked or process integrity differs: " + Marshal.GetLastWin32Error());
    }
}
'@
    [void][TrayNative]::SetProcessDPIAware()
    if (-not [Environment]::UserInteractive) {
        throw 'Interactive Windows desktop required; services/session 0 are unsupported.'
    }
    $desktop = [TrayNative]::OpenInputDesktop(0, $false, 0x0101)
    if ($desktop -eq [IntPtr]::Zero) {
        throw 'Cannot open input desktop. Unlock the session; secure desktops cannot be automated.'
    }
    try {
        $inputName = [TrayNative]::DesktopName($desktop)
        $threadName = [TrayNative]::DesktopName([TrayNative]::GetThreadDesktop([TrayNative]::GetCurrentThreadId()))
        if ($inputName -ne $threadName) {
            throw "Input desktop '$inputName' differs from process desktop '$threadName'. Unlock the session."
        }
    } finally {
        [void][TrayNative]::CloseDesktop($desktop)
    }
    $cursor = New-Object TrayNative+POINT
    if (-not [TrayNative]::GetCursorPos([ref]$cursor)) {
        throw "Cannot access input cursor (Win32 error $([Runtime.InteropServices.Marshal]::GetLastWin32Error())). Unlock/reconnect the interactive session."
    }
    $appProcessId = [uint32]$env:NATIVE_TRAY_APP_PID
    if ($appProcessId -eq 0) { throw 'NATIVE_TRAY_APP_PID must identify the running application JVM.' }
    if ([TrayNative]::FindWindow('Shell_TrayWnd', $null) -eq [IntPtr]::Zero) {
        throw 'Explorer notification area unavailable (Shell_TrayWnd missing).'
    }

    function Wait-Until($description, [scriptblock]$condition, $seconds = 15) {
        $end = [DateTime]::UtcNow.AddSeconds($seconds)
        do {
            $result = & $condition
            if ($result) { return $result }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $end)
        throw "Timed out waiting for $description"
    }

    function Click-Rect([scriptblock]$rectProvider, [bool]$right = $false, [string]$description = 'element', $seconds = 5) {
        # Elements can exist before their bounds are laid out (new tray icon,
        # not-yet-rendered dialog button), so retry instead of failing once.
        $rect = Wait-Until "clickable bounds for $description" {
            $candidate = & $rectProvider
            if ($candidate -and $candidate.Right -gt $candidate.Left -and $candidate.Bottom -gt $candidate.Top) {
                return $candidate
            }
        } $seconds
        [TrayNative]::Click([int](($rect.Left + $rect.Right) / 2),
            [int](($rect.Top + $rect.Bottom) / 2), $right)
    }

    function Tray-Elements {
        foreach ($window in [TrayNative]::Windows(0, $null)) {
            $class = [TrayNative]::ClassName($window)
            if ($class -notin @('Shell_TrayWnd', 'Shell_SecondaryTrayWnd',
                    'NotifyIconOverflowWindow', 'TopLevelWindowForOverflowXamlIsland')) { continue }
            $element = [System.Windows.Automation.AutomationElement]::FromHandle($window)
            $element.FindAll([System.Windows.Automation.TreeScope]::Descendants,
                [System.Windows.Automation.Condition]::TrueCondition) |
                Where-Object { -not $_.Current.IsOffscreen }
        }
    }

    function Find-TrayIcon {
        $matches = @(Tray-Elements | Where-Object { $_.Current.Name.Trim() -ceq 'Tray App' })
        if ($matches.Count -gt 1) { throw "Ambiguous tray: $($matches.Count) visible 'Tray App' elements" }
        if ($matches.Count -eq 1) { return $matches[0] }
    }

    $icon = $null
    $expanded = $false
    $icon = Wait-Until "'Tray App' in Explorer's notification area or overflow" {
        $found = Find-TrayIcon
        if ($found) { return $found }
        if (-not $script:expanded) {
            $overflow = @(Tray-Elements | Where-Object {
                $_.Current.AutomationId -in @('SystemTray.OverflowButton', 'NotificationChevron') -or
                $_.Current.Name -eq 'Show hidden icons'
            })
            if ($overflow.Count -eq 1) {
                Click-Rect ({ $overflow[0].Current.BoundingRectangle }).GetNewClosure() $false 'overflow button'
                $script:expanded = $true
            }
        }
    }

    function Open-TrayMenu([bool]$right, [string[]]$expected, [bool]$doubleClick = $false) {
        # Reopen the overflow if Explorer closed it after a dialog.
        $icon = Find-TrayIcon
        if (-not $icon) {
            $script:expanded = $false
            $icon = Wait-Until 'tray overflow icon' {
                $found = Find-TrayIcon
                if ($found) { return $found }
                if (-not $script:expanded) {
                    $buttons = @(Tray-Elements | Where-Object {
                        $_.Current.AutomationId -in @('SystemTray.OverflowButton', 'NotificationChevron') -or
                        $_.Current.Name -eq 'Show hidden icons'
                    })
                    if ($buttons.Count -eq 1) {
                        Click-Rect ({ $buttons[0].Current.BoundingRectangle }).GetNewClosure() $false 'overflow button'
                        $script:expanded = $true
                    }
                }
            }
        }
        Start-Sleep -Milliseconds ([TrayNative]::GetDoubleClickTime() + 100)
        Click-Rect ({ $icon.Current.BoundingRectangle }).GetNewClosure() $right 'tray icon'
        if ($doubleClick) {
            Start-Sleep -Milliseconds ([Math]::Max(1, [int]([TrayNative]::GetDoubleClickTime() / 4)))
            Click-Rect ({ $icon.Current.BoundingRectangle }).GetNewClosure() $right 'tray icon'
            return
        }
        $popup = Wait-Until "application popup after right=$right" {
            $windows = @([TrayNative]::Windows($appProcessId, '#32768'))
            if ($windows.Count -eq 1) { return $windows[0] }
        }
        $menu = [TrayNative]::SendMessage($popup, 0x01E1, [IntPtr]::Zero, [IntPtr]::Zero)
        if ($menu -eq [IntPtr]::Zero) { throw 'MN_GETHMENU returned no native menu handle.' }
        $actual = @()
        for ($i = 0; $i -lt [TrayNative]::GetMenuItemCount($menu); $i++) {
            $state = [TrayNative]::GetMenuState($menu, $i, 0x400)
            if (($state -band 0x800) -ne 0) {
                $actual += '<separator>'
            } else {
                $text = New-Object Text.StringBuilder 512
                [void][TrayNative]::GetMenuString($menu, $i, $text, $text.Capacity, 0x400)
                $actual += $text.ToString().Replace('&', '')
            }
        }
        if (($actual -join '|') -cne ($expected -join '|')) {
            throw "Unexpected popup: [$($actual -join ', ')] expected [$($expected -join ', ')]"
        }
        return $menu
    }

    function Click-MenuItem($menu, [uint32]$index) {
        $state = [TrayNative]::GetMenuState($menu, $index, 0x400)
        if ($state -eq [uint32]::MaxValue -or ($state -band 3) -ne 0) {
            throw "Menu item $index disabled or unavailable."
        }
        Click-Rect ({
            $candidate = New-Object TrayNative+RECT
            if ([TrayNative]::GetMenuItemRect([IntPtr]::Zero, $menu, $index, [ref]$candidate)) { $candidate }
        }).GetNewClosure() $false "menu item $index"
    }

    function Check-Dialog([string]$title, [string]$message) {
        # The dialog, its message label and its OK button can appear across
        # several redraws, so wait for all three together instead of once.
        $state = Wait-Until "native '$title' dialog with message and OK button" {
            foreach ($window in [TrayNative]::Windows($appProcessId, '#32770')) {
                if ([TrayNative]::Text($window) -cne $title) { continue }
                $children = @([TrayNative]::Children($window))
                $texts = @($children | ForEach-Object { [TrayNative]::Text($_) })
                if ($texts -cnotcontains $message) { continue }
                $buttons = @($children | Where-Object {
                    [TrayNative]::ClassName($_) -eq 'Button' -and
                    [TrayNative]::Text($_).Replace('&', '') -eq 'OK' -and [TrayNative]::IsWindowEnabled($_)
                })
                if ($buttons.Count -eq 1) { return @{ Dialog = $window; Button = $buttons[0] } }
            }
        }
        [void][TrayNative]::SetForegroundWindow($state.Dialog)
        Click-Rect ({
            $candidate = New-Object TrayNative+RECT
            if ([TrayNative]::GetWindowRect($state.Button, [ref]$candidate)) { $candidate }
        }).GetNewClosure() $false 'OK button'
        [void](Wait-Until "'$title' dialog to close" { -not [TrayNative]::IsWindow($state.Dialog) })
    }

    $left = @('Hello World...', 'About', 'Exit')
    $right = @('Hello World...', 'Preferences...', '<separator>', 'Exit')
    Click-MenuItem (Open-TrayMenu $false $left) 0
    Check-Dialog 'Hello World' 'Hello World!'
    Click-MenuItem (Open-TrayMenu $false $left) 1
    Check-Dialog 'About' 'SWT system tray example.'
    Click-MenuItem (Open-TrayMenu $true $right) 0
    Check-Dialog 'Hello World' 'Hello World!'
    Click-MenuItem (Open-TrayMenu $true $right) 1
    Check-Dialog 'Preferences' 'Preferences are not implemented.'
    Open-TrayMenu $false $left $true
    Check-Dialog 'Hello World' 'Hello World!'
    Click-MenuItem (Open-TrayMenu $false $left) 2
    [void](Wait-Until 'application windows to close after Exit' {
        @([TrayNative]::Windows($appProcessId, $null)).Count -eq 0
    })
    Write-Output 'Native Windows tray menus, dialogs and Exit passed'
} catch {
    [Console]::Error.WriteLine("Native Windows tray automation failed: " + $_.Exception.Message)
    [Console]::Error.WriteLine($_.ScriptStackTrace)
    if ('TrayNative' -as [type]) {
        foreach ($window in [TrayNative]::Windows(0, $null)) {
            $owner = [uint32]0
            [void][TrayNative]::GetWindowThreadProcessId($window, [ref]$owner)
            if (($env:NATIVE_TRAY_APP_PID -and $owner -eq [uint32]$env:NATIVE_TRAY_APP_PID) -or
                    [TrayNative]::ClassName($window) -match 'Tray|Overflow') {
                [Console]::Error.WriteLine("window=0x{0:X} pid={1} class={2} title={3}",
                    $window.ToInt64(), $owner, [TrayNative]::ClassName($window), [TrayNative]::Text($window))
            }
        }
    }
    exit 1
}
