#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Name of the system-wide mutex used to detect a running instance.
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"TimerCounter_SingleInstance_Mutex_{4d2f7a51-6c8e-4b3a-9f0d-2e1c3a7b9d44}";

// Registered window message broadcast by a second instance to ask the running
// instance to show/restore and focus its window. Registered messages share the
// same value across processes for the same string, so only our app reacts.
constexpr const wchar_t kShowMeMessageName[] = L"TimerCounter_ShowMeMessage";

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  // Enforce a single running instance. If another instance is already running,
  // ask it to surface its window and exit immediately.
  HANDLE single_instance_mutex =
      ::CreateMutex(nullptr, FALSE, kSingleInstanceMutexName);
  if (single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS)
  {
    // Allow the already-running instance to take foreground focus.
    ::AllowSetForegroundWindow(ASFW_ANY);
    UINT show_me_message = ::RegisterWindowMessage(kShowMeMessageName);
    if (show_me_message != 0)
    {
      ::PostMessage(HWND_BROADCAST, show_me_message, 0, 0);
    }
    ::CloseHandle(single_instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Timer Counter", origin, size))
  {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(false);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
