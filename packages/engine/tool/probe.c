// Headless probe for `bodega backend test`: creates a real D3D11 or D3D12 device and prints the adapter.
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <stdio.h>
#include <dxgi.h>
#include <d3d11.h>
#include <d3d12.h>
typedef HRESULT (WINAPI *cf_t)(REFIID, void**);
typedef HRESULT (WINAPI *c11_t)(IDXGIAdapter*, D3D_DRIVER_TYPE, HMODULE, UINT, const D3D_FEATURE_LEVEL*, UINT, UINT, ID3D11Device**, D3D_FEATURE_LEVEL*, ID3D11DeviceContext**);
typedef HRESULT (WINAPI *c12_t)(IUnknown*, D3D_FEATURE_LEVEL, REFIID, void**);
static void path(const char *n, HMODULE m){ char b[MAX_PATH]; GetModuleFileNameA(m,b,MAX_PATH); printf("%s: %s\n",n,b); }
int main(int argc, char **argv){
  setvbuf(stdout,NULL,_IONBF,0);
  const char *which = argc>1?argv[1]:"11";
  HMODULE hd=LoadLibraryA("dxgi.dll"); if(!hd){puts("dxgi load FAIL");return 2;} path("dxgi",hd);
  cf_t cf=(cf_t)GetProcAddress(hd,"CreateDXGIFactory1"); IDXGIFactory1 *f=NULL; IDXGIAdapter1 *a=NULL;
  HRESULT hr=cf?cf(&IID_IDXGIFactory1,(void**)&f):E_FAIL; printf("CreateDXGIFactory1 hr=%08lx\n",hr);
  if(f && SUCCEEDED(IDXGIFactory1_EnumAdapters1(f,0,&a))){ DXGI_ADAPTER_DESC1 d; IDXGIAdapter1_GetDesc1(a,&d); printf("adapter: %ls vendor=%04x device=%04x vram=%lluMB\n",d.Description,d.VendorId,d.DeviceId,(unsigned long long)d.DedicatedVideoMemory/1048576); }
  if(which[0]=='1'&&which[1]=='1'){
    HMODULE h=LoadLibraryA("d3d11.dll"); if(!h){puts("d3d11 load FAIL");return 2;} path("d3d11",h);
    c11_t c=(c11_t)GetProcAddress(h,"D3D11CreateDevice"); ID3D11Device *dev=NULL; ID3D11DeviceContext *ctx=NULL; D3D_FEATURE_LEVEL fl=0;
    hr=c?c(NULL,D3D_DRIVER_TYPE_HARDWARE,NULL,0,NULL,0,D3D11_SDK_VERSION,&dev,&fl,&ctx):E_FAIL; printf("D3D11CreateDevice hr=%08lx level=%x\n",hr,fl);
    if(FAILED(hr)) return 1;
    D3D11_TEXTURE2D_DESC td={64,64,1,1,DXGI_FORMAT_R8G8B8A8_UNORM,{1,0},D3D11_USAGE_DEFAULT,D3D11_BIND_RENDER_TARGET,0,0}; ID3D11Texture2D *t=NULL; ID3D11RenderTargetView *rtv=NULL;
    hr=ID3D11Device_CreateTexture2D(dev,&td,NULL,&t); printf("CreateTexture2D hr=%08lx\n",hr); if(FAILED(hr)) return 1;
    hr=ID3D11Device_CreateRenderTargetView(dev,(ID3D11Resource*)t,NULL,&rtv); printf("CreateRTV hr=%08lx\n",hr); if(FAILED(hr)) return 1;
    float col[4]={1,0,0,1}; ID3D11DeviceContext_ClearRenderTargetView(ctx,rtv,col); ID3D11DeviceContext_Flush(ctx); puts("clear+flush ok");
  } else {
    HMODULE h=LoadLibraryA("d3d12.dll"); if(!h){puts("d3d12 load FAIL");return 2;} path("d3d12",h);
    c12_t c=(c12_t)GetProcAddress(h,"D3D12CreateDevice"); ID3D12Device *dev=NULL;
    hr=c?c(NULL,D3D_FEATURE_LEVEL_11_0,&IID_ID3D12Device,(void**)&dev):E_FAIL; printf("D3D12CreateDevice hr=%08lx\n",hr); if(FAILED(hr)) return 1;
    D3D12_COMMAND_QUEUE_DESC qd={D3D12_COMMAND_LIST_TYPE_DIRECT,0,D3D12_COMMAND_QUEUE_FLAG_NONE,0}; ID3D12CommandQueue *q=NULL;
    hr=ID3D12Device_CreateCommandQueue(dev,&qd,&IID_ID3D12CommandQueue,(void**)&q); printf("CreateCommandQueue hr=%08lx\n",hr); if(FAILED(hr)) return 1;
    ID3D12Fence *fe=NULL; hr=ID3D12Device_CreateFence(dev,0,D3D12_FENCE_FLAG_NONE,&IID_ID3D12Fence,(void**)&fe); printf("CreateFence hr=%08lx\n",hr); if(FAILED(hr)) return 1;
    hr=ID3D12CommandQueue_Signal(q,fe,1); printf("Signal hr=%08lx\n",hr);
    for(int i=0;i<200&&ID3D12Fence_GetCompletedValue(fe)<1;i++) Sleep(10);
    printf("fence completed=%llu\n",(unsigned long long)ID3D12Fence_GetCompletedValue(fe));
  }
  puts("OK"); return 0; }
