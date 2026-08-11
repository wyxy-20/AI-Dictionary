<#
.SYNOPSIS
    AI Dictionary single-instance / tray / quick-search smoke test (Windows).
.DESCRIPTION
    1. Launch the app and verify the global hotkey opens the floating search.
    2. Verify search -> select -> main window comes to front, and Esc closes.
    3. Close the main window -> process must stay alive (tray mode), window hidden.
    4. Press the global hotkey while in tray -> floating search still works and
       selecting a term brings the main window back.
    5. Launch a second instance -> no second process; the existing window returns.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\smoke_quick_search.ps1
#>
$ErrorActionPreference = 'Stop'

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class QuickSearchSmoke2 {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int index);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr hWnd);
  public const uint KEYEVENTF_KEYUP = 0x0002;
  public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
  public const uint MOUSEEVENTF_LEFTUP = 0x0004;
  public const uint WM_CLOSE = 0x0010;
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

# Locate the Release exe: project-local build dir first, then the ASCII junction.
$candidates = @(
  (Join-Path $PSScriptRoot '..\build\windows\x64\runner\Release\ai_dictionary.exe'),
  (Join-Path $PSScriptRoot '..\..\ai-dict-build\build\windows\x64\runner\Release\ai_dictionary.exe')
)
$exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $exe) {
  throw 'ai_dictionary.exe not found. Run tool\build_windows.ps1 first.'
}

function Get-AppWindows([int]$appPid) {
  $script:acc = @()
  $cb = [QuickSearchSmoke2+EnumWindowsProc]{ param($h, $l)
    [uint32]$wpid = 0
    [QuickSearchSmoke2]::GetWindowThreadProcessId($h, [ref]$wpid) | Out-Null
    if ($wpid -eq $appPid) {
      $len = [QuickSearchSmoke2]::GetWindowTextLength($h)
      if ($len -gt 0) {
        $sb = New-Object System.Text.StringBuilder ($len + 1)
        [QuickSearchSmoke2]::GetWindowText($h, $sb, $sb.Capacity) | Out-Null
        $style = [QuickSearchSmoke2]::GetWindowLong($h, -20)
        $script:acc += [pscustomobject]@{
          Handle  = $h
          Title   = $sb.ToString()
          Visible = [QuickSearchSmoke2]::IsWindowVisible($h)
          Topmost = (($style -band 0x8) -ne 0)
        }
      }
    }
    return $true
  }
  [QuickSearchSmoke2]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
  return $script:acc
}

function Get-ForegroundTitle {
  $script:fg = ''
  $cb = [QuickSearchSmoke2+EnumWindowsProc]{ param($h, $l)
    if ($h -eq [QuickSearchSmoke2]::GetForegroundWindow()) {
      $sb = New-Object System.Text.StringBuilder 256
      [QuickSearchSmoke2]::GetWindowText($h, $sb, 256) | Out-Null
      $script:fg = $sb.ToString()
    }
    return $true
  }
  [QuickSearchSmoke2]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
  return $script:fg
}

function Get-ChildWindow([int]$appPid) {
  return Get-AppWindows -appPid $appPid |
    Where-Object { $_.Handle -ne $script:mainHandle -and $_.Title -like 'AI Dictionary*' } |
    Select-Object -First 1
}

function Get-MainWindow([int]$appPid) {
  return Get-AppWindows -appPid $appPid |
    Where-Object { $_.Handle -eq $script:mainHandle } |
    Select-Object -First 1
}

function Send-VKey([byte]$vk) {
  [QuickSearchSmoke2]::keybd_event($vk, 0, 0, [UIntPtr]::Zero)
  [QuickSearchSmoke2]::keybd_event($vk, 0, [QuickSearchSmoke2]::KEYEVENTF_KEYUP, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 300
}

function Send-HotkeyCtrlK {
  [QuickSearchSmoke2]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
  Send-VKey 0x4B
  [QuickSearchSmoke2]::keybd_event(0x11, 0, [QuickSearchSmoke2]::KEYEVENTF_KEYUP, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 300
}

function Click-At([int]$x, [int]$y) {
  [QuickSearchSmoke2]::SetCursorPos($x, $y) | Out-Null
  Start-Sleep -Milliseconds 120
  [QuickSearchSmoke2]::mouse_event(
    [QuickSearchSmoke2]::MOUSEEVENTF_LEFTDOWN,
    0, 0, 0, [UIntPtr]::Zero)
  [QuickSearchSmoke2]::mouse_event(
    [QuickSearchSmoke2]::MOUSEEVENTF_LEFTUP,
    0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 300
}

function Get-ChildRect([int]$appPid) {
  $w = Get-ChildWindow $appPid
  $rect = New-Object QuickSearchSmoke2+RECT
  [QuickSearchSmoke2]::GetWindowRect($w.Handle, [ref]$rect) | Out-Null
  return $rect
}

function Activate-ChildWindow([int]$appPid) {
  $w = Get-ChildWindow $appPid
  if (-not $w) { throw 'Child window not found' }
  [QuickSearchSmoke2]::SetForegroundWindow($w.Handle) | Out-Null
  [QuickSearchSmoke2]::SetFocus($w.Handle) | Out-Null
  Start-Sleep -Milliseconds 500
}

$wshell = New-Object -ComObject WScript.Shell

"== 0. Clean start =="
Get-Process ai_dictionary -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
$p = Start-Process -FilePath $exe -PassThru
# Wait for the main window (cold start can be slow), then wait for bootstrap.
$deadline = (Get-Date).AddSeconds(40)
$mainWnd = $null
while ((Get-Date) -lt $deadline -and -not $mainWnd) {
  Start-Sleep -Milliseconds 1000
  $mainWnd = Get-AppWindows -appPid $p.Id |
    Where-Object { $_.Title -like 'AI Dictionary*' } |
    Select-Object -First 1
}
if (-not $mainWnd) { throw 'Main window not found at startup' }
$script:mainHandle = $mainWnd.Handle
$script:mainTitle = $mainWnd.Title
"Main window handle: $script:mainHandle"
Start-Sleep -Seconds 5

"== 1. Global hotkey opens the floating search =="
Send-HotkeyCtrlK
$deadline = (Get-Date).AddSeconds(6)
$child = Get-ChildWindow $p.Id
while (((Get-Date) -lt $deadline) -and (-not $child -or -not $child.Visible -or -not $child.Topmost)) {
  Start-Sleep -Milliseconds 500
  $child = Get-ChildWindow $p.Id
}
if (-not $child -or -not $child.Visible) { throw 'Floating window did not appear' }
"Floating window appeared: visible=$($child.Visible) topmost=$($child.Topmost)"
if (-not $child.Topmost) { throw 'Floating window is not topmost' }

"== 2. Search -> select -> main to front; Esc close =="
Activate-ChildWindow $p.Id
$rect = Get-ChildRect $p.Id
Click-At ($rect.Left + 260) ($rect.Top + 55)
$wshell.SendKeys('rag')
Start-Sleep -Seconds 2
Send-VKey 0x0D   # commit any pinyin composition (IME)
Start-Sleep -Seconds 1
$mid = Get-ChildWindow $p.Id
if ($mid.Visible) {
  $rect2 = Get-ChildRect $p.Id
  Click-At ($rect2.Left + 260) ($rect2.Top + 115)
  Start-Sleep -Seconds 3
}
$after = Get-ChildWindow $p.Id
if ($after.Visible) { throw 'Floating window did not hide after selecting a result' }
$fg = Get-ForegroundTitle
if ($fg -ne $script:mainTitle) { throw 'Main window did not come to front' }
"Selection flow OK, main window in front"

Send-HotkeyCtrlK
Start-Sleep -Seconds 3
$child2 = Get-ChildWindow $p.Id
if (-not $child2.Visible) { throw 'Floating window did not reappear' }
Activate-ChildWindow $p.Id
$rect3 = Get-ChildRect $p.Id
Click-At ($rect3.Left + 260) ($rect3.Top + 55)
Send-VKey 0x1B   # Esc
Start-Sleep -Seconds 2
$after2 = Get-ChildWindow $p.Id
if ($after2.Visible) { throw 'Esc did not close the floating window' }
"Esc close OK"

"== 3. Close main window -> stays in tray (process alive) =="
[QuickSearchSmoke2]::PostMessage(
  $script:mainHandle, [QuickSearchSmoke2]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
Start-Sleep -Seconds 3
$p.Refresh()
if ($p.HasExited) { throw 'Process exited instead of staying in tray' }
$mainHidden = Get-MainWindow $p.Id
if ($mainHidden.Visible) { throw 'Main window should be hidden in tray mode' }
"Main window hidden, process still running (tray mode)"

"== 3b. Tray icon left-click restores the main window =="
[QuickSearchSmoke2]::PostMessage(
  $script:mainHandle, 0x0401, [IntPtr]::Zero, [IntPtr]0x0202) | Out-Null
Start-Sleep -Seconds 2
$mainRestored = Get-MainWindow $p.Id
if (-not $mainRestored.Visible) { throw 'Tray icon click did not restore the main window' }
"Tray icon click restored the main window"
[QuickSearchSmoke2]::PostMessage(
  $script:mainHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
Start-Sleep -Seconds 2

"== 4. Hotkey still works while in tray =="
Send-HotkeyCtrlK
Start-Sleep -Seconds 3
$child3 = Get-ChildWindow $p.Id
if (-not $child3 -or -not $child3.Visible) { throw 'Floating search did not open while in tray' }
Activate-ChildWindow $p.Id
$rect4 = Get-ChildRect $p.Id
Click-At ($rect4.Left + 260) ($rect4.Top + 55)
$wshell.SendKeys('rag')
Start-Sleep -Seconds 2
Send-VKey 0x0D
Start-Sleep -Seconds 1
$mid2 = Get-ChildWindow $p.Id
if ($mid2.Visible) {
  $rect5 = Get-ChildRect $p.Id
  Click-At ($rect5.Left + 260) ($rect5.Top + 115)
  Start-Sleep -Seconds 3
}
$mainBack = Get-MainWindow $p.Id
if (-not $mainBack.Visible) { throw 'Main window did not come back from tray' }
"Hotkey works in tray; main window restored"

"== 5. Second launch focuses the existing instance =="
$p2 = Start-Process -FilePath $exe -PassThru
Start-Sleep -Seconds 4
$p2.Refresh()
if (-not $p2.HasExited) { throw 'Second instance did not exit' }
$processes = @(Get-Process ai_dictionary -ErrorAction SilentlyContinue)
if ($processes.Count -ne 1) { throw "Expected 1 process, found $($processes.Count)" }
"Single instance OK (1 process)"

"All checks passed OK"
Get-Process ai_dictionary -ErrorAction SilentlyContinue | Stop-Process -Force
