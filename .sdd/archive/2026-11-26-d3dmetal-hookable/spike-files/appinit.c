#include <windows.h>
BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID r) {
  if (reason == DLL_PROCESS_ATTACH) {
    DWORD n; const char m[] = "APPINIT DLL LOADED\n";
    WriteFile(GetStdHandle(STD_ERROR_HANDLE), m, sizeof m - 1, &n, NULL);
  }
  return TRUE;
}
