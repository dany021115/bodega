// Spike for sdd d3dmetal-hookable: when does D3DMetal write its
// `66 90 FF 25 00000000 <abs64>` thunks, and does a thunk rewritten to
// `48 B8 <abs64> FF E0 90 90` (mov rax, imm64; jmp rax) still work?
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <d3d12.h>
#include <dxgi1_4.h>

static const unsigned char thunk[8] = {0x66, 0x90, 0xFF, 0x25, 0, 0, 0, 0};

static void image_range(HMODULE m, unsigned char **lo, unsigned char **hi) {
  IMAGE_DOS_HEADER *dos = (IMAGE_DOS_HEADER *)m;
  IMAGE_NT_HEADERS64 *nt = (IMAGE_NT_HEADERS64 *)((char *)m + dos->e_lfanew);
  *lo = (unsigned char *)m;
  *hi = *lo + nt->OptionalHeader.SizeOfImage;
}

static int count(const char *name) {
  HMODULE m = GetModuleHandleA(name);
  if (!m) return -1;
  unsigned char *p, *end;
  image_range(m, &p, &end);
  int n = 0;
  MEMORY_BASIC_INFORMATION mbi;
  for (unsigned char *page = p; page < end; page = (unsigned char *)mbi.BaseAddress + mbi.RegionSize) {
    if (!VirtualQuery(page, &mbi, sizeof mbi)) break;
    if (mbi.State != MEM_COMMIT || (mbi.Protect & (PAGE_NOACCESS | PAGE_GUARD))) continue;
    unsigned char *a = (unsigned char *)mbi.BaseAddress, *b = a + mbi.RegionSize;
    if (b > end) b = end;
    for (unsigned char *q = a; q + 16 <= b; q++)
      if (!memcmp(q, thunk, 8)) n++;
  }
  return n;
}

static void stage(const char *what) {
  printf("%-28s dxgi=%d d3d12=%d d3d12core=%d d3d11=%d\n", what, count("dxgi.dll"),
         count("d3d12.dll"), count("d3d12core.dll"), count("d3d11.dll"));
  fflush(stdout);
}

static const char *where(void *fn) {
  static char buf[160];
  HMODULE m = NULL;
  char name[MAX_PATH] = "?";
  if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                             GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         fn, &m))
    GetModuleFileNameA(m, name, sizeof name);
  const char *base = strrchr(name, '\\');
  unsigned char *b = fn;
  snprintf(buf, sizeof buf, "%s+0x%llx bytes %02x %02x %02x %02x %02x %02x %02x %02x",
           base ? base + 1 : name, (unsigned long long)((char *)fn - (char *)m), b[0], b[1],
           b[2], b[3], b[4], b[5], b[6], b[7]);
  return buf;
}

int main(void) {
  stage("start");
  HMODULE dxgi = LoadLibraryA("dxgi.dll"), d3d12 = LoadLibraryA("d3d12.dll");
  stage("after LoadLibrary");
  HRESULT(WINAPI * createFactory)(UINT, REFIID, void **) =
      (void *)GetProcAddress(dxgi, "CreateDXGIFactory2");
  HRESULT(WINAPI * createDevice)(IUnknown *, D3D_FEATURE_LEVEL, REFIID, void **) =
      (void *)GetProcAddress(d3d12, "D3D12CreateDevice");
  printf("CreateDXGIFactory2 %s\nD3D12CreateDevice  %s\n", where(createFactory), where(createDevice));
  IDXGIFactory4 *factory = NULL;
  HRESULT hr = createFactory(0, &IID_IDXGIFactory4, (void **)&factory);
  printf("factory hr=0x%lx\n", hr);
  stage("after CreateDXGIFactory2");
  ID3D12Device *device = NULL;
  hr = createDevice(NULL, D3D_FEATURE_LEVEL_11_0, &IID_ID3D12Device, (void **)&device);
  printf("device hr=0x%lx\n", hr);
  if (FAILED(hr)) return 1;
  stage("after D3D12CreateDevice");
  D3D12_COMMAND_QUEUE_DESC qd = {D3D12_COMMAND_LIST_TYPE_DIRECT};
  ID3D12CommandQueue *queue = NULL;
  hr = ID3D12Device_CreateCommandQueue(device, &qd, &IID_ID3D12CommandQueue, (void **)&queue);
  printf("queue hr=0x%lx\n", hr);
  stage("after CreateCommandQueue");
  WNDCLASSA wc = {0};
  wc.lpfnWndProc = DefWindowProcA;
  wc.hInstance = GetModuleHandleA(NULL);
  wc.lpszClassName = "hookspike";
  RegisterClassA(&wc);
  HWND hwnd = CreateWindowA("hookspike", "hookspike", WS_OVERLAPPEDWINDOW, 0, 0, 64, 64, NULL, NULL,
                            wc.hInstance, NULL);  // never shown
  DXGI_SWAP_CHAIN_DESC1 sd = {0};
  sd.Width = 64;
  sd.Height = 64;
  sd.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
  sd.SampleDesc.Count = 1;
  sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  sd.BufferCount = 2;
  sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
  IDXGISwapChain1 *swap = NULL;
  hr = IDXGIFactory4_CreateSwapChainForHwnd(factory, (IUnknown *)queue, hwnd, &sd, NULL, NULL, &swap);
  printf("swapchain hr=0x%lx\n", hr);
  stage("after CreateSwapChainForHwnd");
  if (FAILED(hr)) return 1;
  void **vt = *(void ***)swap;
  void **qvt = *(void ***)queue;
  printf("Present            %s\n", where(vt[8]));
  printf("ResizeBuffers      %s\n", where(vt[13]));
  printf("ExecuteCommandLists %s\n", where(qvt[10]));
  hr = IDXGISwapChain1_Present(swap, 0, 0);
  printf("Present before rewrite hr=0x%lx\n", hr);
  // The rewrite: same target, no RIP-relative operand in the first bytes.
  unsigned char *p = vt[8];
  if (!memcmp(p, thunk, 8)) {
    unsigned char repl[16] = {0x48, 0xB8};
    memcpy(repl + 2, p + 8, 8);
    repl[10] = 0xFF, repl[11] = 0xE0, repl[12] = 0x90, repl[13] = 0x90, repl[14] = 0x90,
    repl[15] = 0x90;
    DWORD old;
    BOOL ok = VirtualProtect(p, 16, PAGE_EXECUTE_READWRITE, &old);
    printf("protect was 0x%lx (ok=%d)\n", old, ok);
    memcpy(p, repl, 16);
    VirtualProtect(p, 16, old, &old);
    FlushInstructionCache(GetCurrentProcess(), p, 16);
    printf("rewritten          %s\n", where(p));
    for (int i = 0; i < 3; i++) {
      hr = IDXGISwapChain1_Present(swap, 0, 0);
      printf("Present after rewrite #%d hr=0x%lx\n", i, hr);
    }
  } else {
    printf("Present is not a thunk\n");
  }
  stage("end");
  return 0;
}
