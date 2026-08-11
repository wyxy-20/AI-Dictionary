#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // ---- Single instance ----
  // 第二个实例启动时，找到已有的主窗口并唤起它，然后直接退出；
  // 互斥锁句柄保持打开直到进程结束（进程退出时系统自动释放）。
  HANDLE single_instance_mutex =
      ::CreateMutexW(nullptr, FALSE, L"Local\\AI_Dictionary_SingleInstance");
  (void)single_instance_mutex;  // 仅用于持有句柄，防编译器警告。
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = ::FindWindowW(nullptr, L"AI Dictionary · AI时代词典");
    if (existing != nullptr) {
      if (::IsIconic(existing)) {
        ::ShowWindow(existing, SW_RESTORE);
      }
      ::ShowWindow(existing, SW_SHOW);
      ::SetForegroundWindow(existing);
    }
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"AI Dictionary · AI时代词典", origin, size)) {
    return EXIT_FAILURE;
  }
  // Multiple windows share one process; let desktop_multi_window decide when
  // to quit (it posts WM_QUIT once every window is destroyed).
  window.SetQuitOnClose(false);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
