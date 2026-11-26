/* NtLockFile called with an IO_STATUS_BLOCK, as Zig's standard library does for every file lock
 * (std.os.windows.LockFile: no event, no APC, no key, a status block). Windows takes and releases the
 * lock and fills the block; Wine as shipped returns STATUS_NOT_IMPLEMENTED for any status block.
 * OK: exit 0. FAIL: exit 1, with the step and the status. */
#include <windows.h>
#include <winternl.h>
#include <stdio.h>

#ifndef STATUS_SUCCESS
#define STATUS_SUCCESS ((NTSTATUS)0x00000000)
#endif
#ifndef STATUS_LOCK_NOT_GRANTED
#define STATUS_LOCK_NOT_GRANTED ((NTSTATUS)0xC0000054)
#endif

typedef NTSTATUS(NTAPI *lock_fn)(HANDLE, HANDLE, PIO_APC_ROUTINE, PVOID, PIO_STATUS_BLOCK, PLARGE_INTEGER,
                                 PLARGE_INTEGER, PULONG, BOOLEAN, BOOLEAN);
typedef NTSTATUS(NTAPI *unlock_fn)(HANDLE, PIO_STATUS_BLOCK, PLARGE_INTEGER, PLARGE_INTEGER, PULONG);

static lock_fn pNtLockFile;
static unlock_fn pNtUnlockFile;
static int failures;

static void expect(const char *step, NTSTATUS got, NTSTATUS want) {
    if (got == want) return;
    printf("FAIL: %s: status 0x%08lx, expected 0x%08lx\n", step, (unsigned long)got, (unsigned long)want);
    failures++;
}

/* A lock that succeeds fills the block: Status = the returned status, Information = 0. */
static void lock(const char *step, HANDLE file, BOOLEAN dont_wait, BOOLEAN exclusive, NTSTATUS want) {
    IO_STATUS_BLOCK io;
    LARGE_INTEGER offset = {.QuadPart = 0}, count = {.QuadPart = 1};
    io.Status = (NTSTATUS)0xdeadbeef;
    io.Information = 0x1234;
    NTSTATUS status = pNtLockFile(file, NULL, NULL, NULL, &io, &offset, &count, NULL, dont_wait, exclusive);
    expect(step, status, want);
    if (status == STATUS_SUCCESS && (io.Status != STATUS_SUCCESS || io.Information != 0)) {
        printf("FAIL: %s: status block 0x%08lx / %lu, expected 0 / 0\n", step, (unsigned long)io.Status,
               (unsigned long)io.Information);
        failures++;
    }
}

static void unlock(const char *step, HANDLE file) {
    IO_STATUS_BLOCK io;
    LARGE_INTEGER offset = {.QuadPart = 0}, count = {.QuadPart = 1};
    expect(step, pNtUnlockFile(file, &io, &offset, &count, NULL), STATUS_SUCCESS);
}

int main(void) {
    HMODULE ntdll = GetModuleHandleA("ntdll.dll");
    pNtLockFile = (lock_fn)(void *)GetProcAddress(ntdll, "NtLockFile");
    pNtUnlockFile = (unlock_fn)(void *)GetProcAddress(ntdll, "NtUnlockFile");
    if (!pNtLockFile || !pNtUnlockFile) {
        printf("FAIL: NtLockFile or NtUnlockFile missing from ntdll\n");
        return 1;
    }

    WCHAR dir[MAX_PATH], path[MAX_PATH];
    GetTempPathW(MAX_PATH, dir);
    GetTempFileNameW(dir, L"nlf", 0, path);
    DWORD share = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
    HANDLE a = CreateFileW(path, GENERIC_READ | GENERIC_WRITE, share, NULL, OPEN_EXISTING, 0, NULL);
    HANDLE b = CreateFileW(path, GENERIC_READ | GENERIC_WRITE, share, NULL, OPEN_EXISTING, FILE_FLAG_DELETE_ON_CLOSE, NULL);
    if (a == INVALID_HANDLE_VALUE || b == INVALID_HANDLE_VALUE) {
        printf("FAIL: could not open the temporary file (error %lu)\n", GetLastError());
        return 1;
    }

    lock("exclusive lock, fail at once", a, TRUE, TRUE, STATUS_SUCCESS);
    lock("second handle while held", b, TRUE, TRUE, STATUS_LOCK_NOT_GRANTED);  /* the lock is real */
    unlock("unlock", a);
    lock("second handle once released", b, TRUE, TRUE, STATUS_SUCCESS);
    unlock("unlock second handle", b);
    lock("exclusive lock, waiting", a, FALSE, TRUE, STATUS_SUCCESS);  /* Zig's blocking File.lock */
    unlock("unlock after waiting", a);
    lock("shared lock", a, TRUE, FALSE, STATUS_SUCCESS);
    lock("shared lock, second handle", b, TRUE, FALSE, STATUS_SUCCESS);
    unlock("unlock shared", a);
    unlock("unlock shared, second handle", b);

    CloseHandle(a);
    CloseHandle(b);
    if (failures) return 1;
    printf("OK\n");
    return 0;
}
