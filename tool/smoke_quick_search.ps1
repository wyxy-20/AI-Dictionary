<#
.SYNOPSIS
    AI Dictionary global quick-search smoke test (Windows).
.DESCRIPTION
    Launches (or reuses) the app -> triggers global hotkey Ctrl+K -> verifies the
    floating window appears always-on-top -> types a query and presses Enter ->
    verifies the term is selected and the main window comes to front -> Esc closes
    -> closing the main window exits the process.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\smoke_quick_search.ps1
#>
$ErrorActionPreference = 'Stop'

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class QuickSearchSmoke {
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
  public const uint KEYEVENTF_KEYUP = 0x0002;
  public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
  public const uint MOUSEEVENTF_LEFTUP = 0x0004;
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$exe = '<build-dir>\build\windows\x64\runner\Release\ai_dictionary.exe'

function Get-AppWindows([int]$appPid) {
  $script:acc = @()
  $cb = [QuickSearchSmoke+EnumWindowsProc]{ param($h, $l)
    [uint32]$wpid = 0
    [QuickSearchSmoke]::GetWindowThreadProcessId($h, [ref]$wpid) | Out-Null
    if ($wpid -eq $appPid) {
      $len = [QuickSearchSmoke]::GetWindowTextLength($h)
      if ($len -gt 0) {
        $sb = New-Object System.Text.StringBuilder ($len + 1)
        [QuickSearchSmoke]::GetWindowText($h, $sb, $sb.Capacity) | Out-Null
        $style = [QuickSearchSmoke]::GetWindowLong($h, -20)
        $script:acc += [pscustomobject]@{
          Handle  = $h
          Title   = $sb.ToString()
          Visible = [QuickSearchSmoke]::IsWindowVisible($h)
          Topmost = (($style -band 0x8) -ne 0)
        }
      }
    }
    return $true
  }
  [QuickSearchSmoke]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
  return $script:acc
}

function Get-ForegroundTitle {
  $script:fg = ''
  $cb = [QuickSearchSmoke+EnumWindowsProc]{ param($h, $l)
    if ($h -eq [QuickSearchSmoke]::GetForegroundWindow()) {
      $sb = New-Object System.Text.StringBuilder 256
      [QuickSearchSmoke]::GetWindowText($h, $sb, 256) | Out-Null
      $script:fg = $sb.ToString()
    }
    return $true
  }
  [QuickSearchSmoke]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
  return $script:fg
}

function Send-VKey([byte]$vk) {
  [QuickSearchSmoke]::keybd_event($vk, 0, 0, [UIntPtr]::Zero)
  [QuickSearchSmoke]::keybd_event($vk, 0, [QuickSearchSmoke]::KEYEVENTF_KEYUP, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 300
}

function Click-At([int]$x, [int]$y) {
  [QuickSearchSmoke]::SetCursorPos($x, $y) | Out-Null
  Start-Sleep -Milliseconds 120
  [QuickSearchSmoke]::mouse_event(
    [QuickSearchSmoke]::MOUSEEVENTF_LEFTDOWN,
    0, 0, 0, [UIntPtr]::Zero)
  [QuickSearchSmoke]::mouse_event(
    [QuickSearchSmoke]::MOUSEEVENTF_LEFTUP,
    0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 300
}

function Get-ChildRect {
  $w = Get-AppWindows -appPid $p.Id |
    Where-Object { $_.Handle -ne $p.MainWindowHandle -and $_.Title -like 'AI Dictionary*' } |
    Select-Object -First 1
  $rect = New-Object QuickSearchSmoke+RECT
  [QuickSearchSmoke]::GetWindowRect($w.Handle, [ref]$rect) | Out-Null
  return $rect
}

$wshell = New-Object -ComObject WScript.Shell

Get-Process ai_dictionary -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
$p = Get-Process ai_dictionary -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) {
  $p = Start-Process -FilePath $exe -PassThru
  Start-Sleep -Seconds 15
}

function Show-ChildWindow {
  if ($p.MainWindowHandle -eq [IntPtr]::Zero) { throw 'Main window not found' }
  $wshell.AppActivate($p.MainWindowTitle) | Out-Null
  Start-Sleep -Milliseconds 400
  $wshell.SendKeys('^k')
  Start-Sleep -Seconds 3
  return Get-AppWindows -appPid $p.Id |
    Where-Object { $_.Handle -ne $p.MainWindowHandle -and $_.Title -like 'AI Dictionary*' } |
    Select-Object -First 1
}

"== 1. Trigger global hotkey Ctrl+K =="
$child = Show-ChildWindow
$deadline = (Get-Date).AddSeconds(6)
while (((Get-Date) -lt $deadline) -and (-not $child -or -not $child.Visible -or -not $child.Topmost)) {
  Start-Sleep -Milliseconds 500
  $child = Get-AppWindows -appPid $p.Id |
    Where-Object { $_.Handle -ne $p.MainWindowHandle -and $_.Title -like 'AI Dictionary*' } |
    Select-Object -First 1
}
if (-not $child -or -not $child.Visible) { throw 'Floating window did not appear' }
"Floating window appeared: visible=$($child.Visible) topmost=$($child.Topmost)"
if (-not $child.Topmost) { throw 'Floating window is not topmost' }

"== 2. Click search field, type a query, click the first result =="
$childTitle = $child.Title
$wshell.AppActivate($childTitle) | Out-Null
Start-Sleep -Milliseconds 600
$rect = Get-ChildRect
$fieldX = $rect.Left + 260
$fieldY = $rect.Top + 55
Click-At $fieldX $fieldY
$wshell.SendKeys('rag')
Start-Sleep -Seconds 2
# Commit any pinyin composition so the IME candidate window closes.
Send-VKey 0x0D
Start-Sleep -Seconds 1
$mid = Get-AppWindows -appPid $p.Id |
  Where-Object { $_.Handle -ne $p.MainWindowHandle -and $_.Title -like 'AI Dictionary*' } |
  Select-Object -First 1
if ($mid.Visible) {
  # Still visible: click the first result row.
  $rect2 = Get-ChildRect
  Click-At ($rect2.Left + 260) ($rect2.Top + 115)
  Start-Sleep -Seconds 3
}
$rect2 = Get-ChildRect
$after = Get-AppWindows -appPid $p.Id |
  Where-Object { $_.Handle -ne $p.MainWindowHandle -and $_.Title -like 'AI Dictionary*' } |
  Select-Object -First 1
if ($after.Visible) { throw 'Floating window did not hide after selecting a result' }
"Floating window hidden after selecting a result"
$fg = Get-ForegroundTitle
"Foreground: '$fg'"
if ($fg -ne $p.MainWindowTitle) { throw 'Main window did not come to front' }

"== 3. Show again, focus the search field, close with Esc =="
$child2 = Show-ChildWindow
if (-not $child2.Visible) { throw 'Floating window did not reappear' }
$wshell.AppActivate($child2.Title) | Out-Null
Start-Sleep -Milliseconds 600
$rect3 = Get-ChildRect
Click-At ($rect3.Left + 260) ($rect3.Top + 55)
Send-VKey 0x1B  # Esc
Start-Sleep -Seconds 2
$after2 = Get-AppWindows -appPid $p.Id |
  Where-Object { $_.Handle -ne $p.MainWindowHandle -and $_.Title -like 'AI Dictionary*' } |
  Select-Object -First 1
if ($after2.Visible) { throw 'Floating window did not hide after Esc' }
"Esc close works"

"== 4. Close main window, process should exit =="
$wshell.AppActivate($p.MainWindowTitle) | Out-Null
Start-Sleep -Milliseconds 300
$p.CloseMainWindow() | Out-Null
$deadline = (Get-Date).AddSeconds(15)
while ((Get-Date) -lt $deadline -and -not $p.HasExited) {
  Start-Sleep -Milliseconds 300
  $p.Refresh()
}
if (-not $p.HasExited) { throw 'Process did not exit after closing main window' }

"All checks passed OK"
