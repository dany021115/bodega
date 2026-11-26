# NtLockFile tests

`ntlockfile.c`: does NtLockFile take a lock when the caller passes an IO_STATUS_BLOCK, as Zig's standard library does
for every file lock (no event, no APC, no key)? It takes an exclusive lock that fails at once, checks that a second
handle to the same file is refused while the first holds the range (so the lock is real), releases it, then takes a
waiting exclusive lock and two shared locks, and checks that each lock that succeeds fills the status block (Status 0,
Information 0). On Windows every step passes (OK, exit 0). Wine as shipped returns STATUS_NOT_IMPLEMENTED (c0000002) for
any status block (FAIL, exit 1, one line per step): the failure behind `zig cc`'s "checking cache failed:
manifest_create Unexpected", fixed by `patches/0029`.

```
x86_64-w64-mingw32-gcc -O1 ntlockfile.c -o ntlockfile.exe
wine ntlockfile.exe
```

`zig cc -target x86_64-windows-gnu -O1 ntlockfile.c -o ntlockfile.exe` builds the same program.
