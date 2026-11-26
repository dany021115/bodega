// HC2 of sdd d3dmetal-hookable (specs/checks.md): a real hooking library detours D3DMetal's
// IDXGISwapChain::Present, with or without the thunk rewrite of wine/patches/0030. Until an
// engine with the patch exists, the rewrite is done here, in the program, the way the patch's
// make_thunks_hookable does it after each DLL attaches, with the patch's own function.
//
//   hook_harness.exe polyhook|minhook [rewrite]
//
// It prints the thunks in each DLL, Present's first bytes, the hooking library's trampoline and
// three Present(0, 0) calls made through the detour. Exit codes: 0 done, 1 setup failed, 2 the
// library refused to hook, 3 a fault (its code and address are printed first), 4 still running
// after 60 s. Its 64x64 window is never shown. build_hook_harness.sh builds it and cuts the
// patch's rewrite_hookable_thunks() into hookable_thunks.inc.

#define NOMINMAX
#define INITGUID

#include "MinHook.h"
#include "polyhook2/Detour/x64Detour.hpp"
#include "polyhook2/ErrorLog.hpp"

#include <windows.h>
#include <initguid.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <stdio.h>
#include <string.h>

#include <memory>
#include <string>

// static unsigned int rewrite_hookable_thunks(unsigned char *start, SIZE_T size,
//     ULONG_PTR image_base, SIZE_T image_size, BOOL rewrite), from the patch.
#include "hookable_thunks.inc"

typedef HRESULT(STDMETHODCALLTYPE *PresentFn)(IDXGISwapChain *, UINT, UINT);

static PresentFn original_present;  // the hooking library's trampoline
static volatile LONG detour_calls;

static HRESULT STDMETHODCALLTYPE detour_present(IDXGISwapChain *self, UINT sync, UINT flags) {
  InterlockedIncrement(&detour_calls);
  return original_present(self, sync, flags);
}

// "dxgi.dll+0x1007080", or "not in any module".
static std::string where(const void *address) {
  HMODULE module = NULL;
  char path[MAX_PATH];
  if (!GetModuleHandleExA(
          GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
          (LPCSTR)address, &module) ||
      !GetModuleFileNameA(module, path, sizeof(path)))
    return "not in any module";
  const char *name = strrchr(path, '\\');
  char text[MAX_PATH + 32];
  snprintf(text, sizeof(text), "%s+0x%llx", name ? name + 1 : path,
           (unsigned long long)((const char *)address - (const char *)module));
  return text;
}

static void dump(const char *what, const void *address, size_t size) {
  const unsigned char *bytes = (const unsigned char *)address;
  printf("%s at %p (%s):", what, address, where(address).c_str());
  for (size_t i = 0; i < size; i++) printf(" %02x", bytes[i]);
  printf("\n");
}

static LONG WINAPI on_fault(EXCEPTION_POINTERS *info) {
  const EXCEPTION_RECORD *record = info->ExceptionRecord;
  printf("FAULT: exception 0x%08lx at %p (%s)", (unsigned long)record->ExceptionCode,
         record->ExceptionAddress, where(record->ExceptionAddress).c_str());
  if (record->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && record->NumberParameters >= 2) {
    const ULONG_PTR kind = record->ExceptionInformation[0];
    printf(", %s of %p", kind == 8 ? "execute" : kind == 1 ? "write" : "read",
           (void *)record->ExceptionInformation[1]);
  }
  printf(", rip %p, detour calls %ld\n", (void *)info->ContextRecord->Rip, detour_calls);
  fflush(stdout);
  ExitProcess(3);
  return EXCEPTION_EXECUTE_HANDLER;
}

static DWORD WINAPI watchdog(void *) {
  Sleep(60 * 1000);
  printf("TIMEOUT: still running after 60 s\n");
  fflush(stdout);
  ExitProcess(4);
  return 0;
}

// make_thunks_hookable of wine/patches/0030 for one DLL, with Win32 calls in place of ntdll's:
// the writable sections, one memory region at a time, each made writable only while it is
// rewritten. Returns the thunks counted (rewrite false) or rewritten (rewrite true), or -1 when
// the DLL is not loaded.
static int walk_thunks(const char *name, bool rewrite) {
  HMODULE module = GetModuleHandleA(name);
  if (!module) return -1;
  const ULONG_PTR base = (ULONG_PTR)module;
  const IMAGE_NT_HEADERS *nt =
      (const IMAGE_NT_HEADERS *)(base + ((const IMAGE_DOS_HEADER *)module)->e_lfanew);
  if (nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC) return 0;
  const SIZE_T image_size = nt->OptionalHeader.SizeOfImage;
  const IMAGE_SECTION_HEADER *sec = IMAGE_FIRST_SECTION(nt);
  int count = 0;
  for (unsigned i = 0; i < nt->FileHeader.NumberOfSections; i++, sec++) {
    if (!(sec->Characteristics & IMAGE_SCN_MEM_WRITE)) continue;
    ULONG_PTR addr = base + sec->VirtualAddress;
    ULONG_PTR end = addr + (sec->Misc.VirtualSize ? sec->Misc.VirtualSize : sec->SizeOfRawData);
    if (end > base + image_size) end = base + image_size;
    while (addr < end) {
      MEMORY_BASIC_INFORMATION mbi;
      unsigned char *start = (unsigned char *)addr;
      if (!VirtualQuery(start, &mbi, sizeof(mbi))) break;
      const ULONG_PTR region_end = (ULONG_PTR)mbi.BaseAddress + mbi.RegionSize;
      const SIZE_T len = (region_end < end ? region_end : end) - addr;
      addr += len;
      if (mbi.State != MEM_COMMIT || (mbi.Protect & (PAGE_NOACCESS | PAGE_GUARD))) continue;
      const unsigned found = rewrite_hookable_thunks(start, len, base, image_size, FALSE);
      if (!found) continue;
      if (!rewrite) {
        count += found;
        continue;
      }
      DWORD old;
      if (!VirtualProtect(start, len, PAGE_EXECUTE_READWRITE, &old)) {
        printf("  %s: VirtualProtect(%p, 0x%llx) failed, error %lu\n", name, (void *)start,
               (unsigned long long)len, GetLastError());
        continue;
      }
      const unsigned done = rewrite_hookable_thunks(start, len, base, image_size, TRUE);
      DWORD ignored;
      VirtualProtect(start, len, old, &ignored);
      FlushInstructionCache(GetCurrentProcess(), start, len);
      printf("  %s: section %.8s, region %p size 0x%llx protection 0x%lx: %u thunks rewritten\n",
             name, (const char *)sec->Name, (void *)start, (unsigned long long)len,
             (unsigned long)old, done);
      count += done;
    }
  }
  return count;
}

// Prints PolyHook's own log, which is what the FIFA 23 mod wrote into the game's log.
class StdoutLogger : public PLH::Logger {
 public:
  void log(const std::string &msg, PLH::ErrorLevel level) override {
    const char *tag = level == PLH::ErrorLevel::SEV    ? "error"
                      : level == PLH::ErrorLevel::WARN ? "warn"
                                                       : "info";
    printf("[polyhook %s] %s\n", tag, msg.c_str());
    fflush(stdout);
  }
};

static int usage() {
  printf("usage: hook_harness.exe polyhook|minhook [rewrite]\n");
  return 1;
}

int main(int argc, char **argv) {
  setvbuf(stdout, NULL, _IONBF, 0);
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
  SetUnhandledExceptionFilter(on_fault);
  HANDLE timer = CreateThread(NULL, 0, watchdog, NULL, 0, NULL);
  if (timer) CloseHandle(timer);

  bool polyhook = false, minhook = false, rewrite = false;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "polyhook"))
      polyhook = true;
    else if (!strcmp(argv[i], "minhook"))
      minhook = true;
    else if (!strcmp(argv[i], "rewrite"))
      rewrite = true;
    else
      return usage();
  }
  if (polyhook == minhook) return usage();
  printf("hook_harness: %s, %s\n", polyhook ? "PolyHook 2" : "MinHook",
         rewrite ? "thunks rewritten in the program" : "thunks as D3DMetal wrote them");

  HMODULE dxgi = LoadLibraryA("dxgi.dll"), d3d12 = LoadLibraryA("d3d12.dll");
  if (!dxgi || !d3d12) {
    printf("LoadLibrary failed: dxgi %p, d3d12 %p\n", (void *)dxgi, (void *)d3d12);
    return 1;
  }
  static const char *const dlls[] = {"dxgi.dll", "d3d12.dll", "d3d11.dll"};
  for (const char *name : dlls) printf("thunks in %s: %d\n", name, walk_thunks(name, false));
  if (rewrite) {
    for (const char *name : dlls) {
      const int done = walk_thunks(name, true);
      if (done < 0)
        printf("rewrite %s: not loaded\n", name);
      else
        printf("rewrite %s: %d thunks made hookable, %d left\n", name, done,
               walk_thunks(name, false));
    }
  }

  auto create_factory =
      (HRESULT(WINAPI *)(UINT, REFIID, void **))GetProcAddress(dxgi, "CreateDXGIFactory2");
  auto create_device = (HRESULT(WINAPI *)(IUnknown *, D3D_FEATURE_LEVEL, REFIID, void **))
      GetProcAddress(d3d12, "D3D12CreateDevice");
  if (!create_factory || !create_device) {
    printf("missing CreateDXGIFactory2 or D3D12CreateDevice\n");
    return 1;
  }
  IDXGIFactory4 *factory = nullptr;
  HRESULT hr = create_factory(0, IID_IDXGIFactory4, (void **)&factory);
  printf("CreateDXGIFactory2 hr=0x%08lx\n", (unsigned long)hr);
  if (FAILED(hr)) return 1;
  ID3D12Device *device = nullptr;
  hr = create_device(nullptr, D3D_FEATURE_LEVEL_11_0, IID_ID3D12Device, (void **)&device);
  printf("D3D12CreateDevice hr=0x%08lx\n", (unsigned long)hr);
  if (FAILED(hr)) return 1;
  D3D12_COMMAND_QUEUE_DESC queue_desc = {};
  queue_desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
  ID3D12CommandQueue *queue = nullptr;
  hr = device->CreateCommandQueue(&queue_desc, IID_ID3D12CommandQueue, (void **)&queue);
  printf("CreateCommandQueue hr=0x%08lx\n", (unsigned long)hr);
  if (FAILED(hr)) return 1;

  WNDCLASSA wc = {};
  wc.lpfnWndProc = DefWindowProcA;
  wc.hInstance = GetModuleHandleA(NULL);
  wc.lpszClassName = "hook_harness";
  RegisterClassA(&wc);
  // No WS_VISIBLE and no ShowWindow: the window is never shown.
  HWND hwnd = CreateWindowA("hook_harness", "hook_harness", WS_OVERLAPPEDWINDOW, 0, 0, 64, 64,
                            NULL, NULL, wc.hInstance, NULL);
  DXGI_SWAP_CHAIN_DESC1 swap_desc = {};
  swap_desc.Width = 64;
  swap_desc.Height = 64;
  swap_desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
  swap_desc.SampleDesc.Count = 1;
  swap_desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  swap_desc.BufferCount = 2;
  swap_desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
  IDXGISwapChain1 *swap = nullptr;
  hr = factory->CreateSwapChainForHwnd(queue, hwnd, &swap_desc, nullptr, nullptr, &swap);
  printf("CreateSwapChainForHwnd hr=0x%08lx\n", (unsigned long)hr);
  if (FAILED(hr)) return 1;

  void *present = (*(void ***)swap)[8];  // IDXGISwapChain::Present
  dump("Present", present, 16);
  const unsigned char *code = (const unsigned char *)present;
  unsigned long long target = 0;
  if (code[0] == 0x66 && code[1] == 0x90 && code[2] == 0xff && code[3] == 0x25)
    memcpy(&target, code + 8, 8);
  else if (code[0] == 0x48 && code[1] == 0xb8)
    memcpy(&target, code + 2, 8);
  if (target) printf("Present thunk target %p (%s)\n", (void *)target, where((void *)target).c_str());

  if (polyhook) {
    PLH::Log::registerLogger(std::make_shared<StdoutLogger>());
    static uint64_t trampoline;
    // Kept alive: its destructor would unhook.
    auto *detour = new PLH::x64Detour((uint64_t)present, (uint64_t)&detour_present, &trampoline);
    const bool hooked = detour->hook();
    printf("PolyHook x64Detour::hook() = %s, trampoline %p\n", hooked ? "true" : "false",
           (void *)trampoline);
    if (!hooked) {
      printf("RESULT: PolyHook refused to hook Present\n");
      return 2;
    }
    original_present = (PresentFn)trampoline;
  } else {
    MH_STATUS status = MH_Initialize();
    if (status == MH_OK)
      status = MH_CreateHook(present, (LPVOID)&detour_present, (LPVOID *)&original_present);
    if (status == MH_OK) status = MH_EnableHook(present);
    printf("MinHook: %s, trampoline %p\n", MH_StatusToString(status), (void *)original_present);
    if (status != MH_OK) {
      printf("RESULT: MinHook refused to hook Present\n");
      return 2;
    }
  }
  dump("Present after hook", present, 16);
  dump("trampoline", (const void *)original_present, 32);

  int ok = 0;
  for (int i = 1; i <= 3; i++) {
    printf("Present #%d calling\n", i);
    hr = swap->Present(0, 0);
    printf("Present #%d hr=0x%08lx\n", i, (unsigned long)hr);
    if (hr == S_OK) ok++;
  }
  printf("detour calls: %ld\n", detour_calls);
  printf("RESULT: %d of 3 Present calls returned S_OK, the detour ran %ld times\n", ok,
         detour_calls);
  return 0;
}
