// Spike: are a D3DMetal DLL's thunks written during its own load?
#include <windows.h>
#include <stdio.h>
#include <string.h>
static const unsigned char thunk[8] = {0x66, 0x90, 0xFF, 0x25, 0, 0, 0, 0};
static int count(const char *name) {
  HMODULE m = GetModuleHandleA(name);
  if (!m) return -1;
  IMAGE_NT_HEADERS64 *nt = (IMAGE_NT_HEADERS64 *)((char *)m + ((IMAGE_DOS_HEADER *)m)->e_lfanew);
  unsigned char *p = (unsigned char *)m, *end = p + nt->OptionalHeader.SizeOfImage;
  int n = 0;
  MEMORY_BASIC_INFORMATION mbi;
  for (unsigned char *page = p; page < end; page = (unsigned char *)mbi.BaseAddress + mbi.RegionSize) {
    if (!VirtualQuery(page, &mbi, sizeof mbi)) break;
    if (mbi.State != MEM_COMMIT || (mbi.Protect & (PAGE_NOACCESS | PAGE_GUARD))) continue;
    unsigned char *a = mbi.BaseAddress, *b = a + mbi.RegionSize;
    if (b > end) b = end;
    for (unsigned char *q = a; q + 16 <= b; q += 16)
      if (!memcmp(q, thunk, 8)) n++;
  }
  return n;
}
static void show(const char *after) {
  printf("%-22s dxgi=%d d3d12=%d d3d11=%d d3d12core=%d nvapi64=%d\n", after, count("dxgi.dll"),
         count("d3d12.dll"), count("d3d11.dll"), count("d3d12core.dll"), count("nvapi64.dll"));
  fflush(stdout);
}
int main(int argc, char **argv) {
  for (int i = 1; i < argc; i++) {
    HMODULE m = LoadLibraryA(argv[i]);
    char what[64];
    snprintf(what, sizeof what, "after %s%s", argv[i], m ? "" : " (FAILED)");
    show(what);
  }
  return 0;
}
