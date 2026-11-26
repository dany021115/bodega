/*
 * Standalone test of rewrite_hookable_thunks(), the byte rewrite in
 * wine/patches/0030-ntdll-hookable-d3dmetal-thunks.patch (sdd d3dmetal-hookable: T2, HW2).
 *
 * run_rewrite_test.sh copies the function out of the patch, byte for byte, into
 * rewrite_hookable_thunks.inc, which is included below after the Windows types it uses.
 *
 * Each case builds its bytes in mmap'd pages with an inaccessible page on each side, so a
 * read or write past them crashes. Under AddressSanitizer, the bytes next to a buffer that
 * the function must not read are poisoned too. Every case checks the count and every byte
 * of its pages; the exit status is 1 if any case fails.
 */
#define _DARWIN_C_SOURCE
#define _DEFAULT_SOURCE
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#if !defined(__BYTE_ORDER__) || __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
#error "the thunks hold little-endian x86_64 addresses: build this on a little-endian host"
#endif

typedef size_t SIZE_T;
typedef uintptr_t ULONG_PTR;
typedef int BOOL;
#define TRUE 1
#define FALSE 0

#include "rewrite_hookable_thunks.inc"

typedef char ulong_ptr_is_64_bits[sizeof(ULONG_PTR) == 8 ? 1 : -1];

#if defined(__has_feature)
#if __has_feature(address_sanitizer)
#define TEST_ASAN 1
#endif
#endif
#if !defined(TEST_ASAN) && defined(__SANITIZE_ADDRESS__)
#define TEST_ASAN 1
#endif
#ifdef TEST_ASAN
#include <sanitizer/asan_interface.h>
#define POISON(p, n) ASAN_POISON_MEMORY_REGION( (p), (n) )
#define UNPOISON(p, n) ASAN_UNPOISON_MEMORY_REGION( (p), (n) )
#else
#define POISON(p, n) ((void)(p), (void)(n))
#define UNPOISON(p, n) ((void)(p), (void)(n))
#endif

#define IMAGE_BASE ((ULONG_PTR)0x180000000)  /* where a 64-bit DLL usually loads */
#define IMAGE_SIZE ((SIZE_T)0x1200000)
#define TARGET     ((ULONG_PTR)0x212cd777e)  /* outside the image, like D3DMetal's native code */
#define THUNKS     1024                      /* per DLL, 16 bytes apart, as D3DMetal writes them */

static const unsigned char thunk_head[8] = { 0x66, 0x90, 0xff, 0x25, 0x00, 0x00, 0x00, 0x00 };

static size_t page_size;
static const char *case_name;
static unsigned int case_count, failed_cases, case_checks, case_failures;

/* ---- pages ---- */

struct area
{
    unsigned char *map;  /* the whole mapping, guard pages included */
    unsigned char *lo;   /* first byte after the guard page in front */
    unsigned char *hi;   /* first byte of the guard page behind */
    size_t len;          /* hi - lo, whole pages */
};

static uint64_t rng_state = UINT64_C(0x9e3779b97f4a7c15);

static unsigned char next_byte( void )
{
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 7;
    rng_state ^= rng_state << 17;
    return (unsigned char)(rng_state >> 24);
}

/* pseudo-random bytes, as in a data section, with no 16-byte slot that starts like a thunk */
static void fill( unsigned char *p, size_t len )
{
    size_t i;

    for (i = 0; i < len; i++) p[i] = next_byte();
    for (i = 0; i + 16 <= len; i += 16)
        if (!memcmp( p + i, thunk_head, sizeof(thunk_head) )) p[i] ^= 1;
}

static struct area area_new( size_t bytes )
{
    struct area a;
    size_t pages = (bytes + page_size - 1) / page_size;

    a.map = mmap( NULL, (pages + 2) * page_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0 );
    if (a.map == MAP_FAILED)
    {
        perror( "mmap" );
        exit( 2 );
    }
    a.lo = a.map + page_size;
    a.len = pages * page_size;
    a.hi = a.lo + a.len;
    if (mprotect( a.map, page_size, PROT_NONE ) || mprotect( a.hi, page_size, PROT_NONE ))
    {
        perror( "mprotect" );
        exit( 2 );
    }
    fill( a.lo, a.len );
    return a;
}

static void area_protect( const struct area *a, int prot )
{
    if (mprotect( a->lo, a->len, prot ))
    {
        perror( "mprotect" );
        exit( 2 );
    }
}

static void area_free( struct area *a )
{
    munmap( a->map, a->len + 2 * page_size );
}

static unsigned char *snapshot( const struct area *a )
{
    unsigned char *copy = malloc( a->len );

    if (!copy)
    {
        perror( "malloc" );
        exit( 2 );
    }
    memcpy( copy, a->lo, a->len );
    return copy;
}

/* ---- thunks ---- */

/* "66 90 ff 25 00 00 00 00 <target>": nop; jmp qword ptr [rip]; .quad target */
static void put_thunk( unsigned char *slot, ULONG_PTR target )
{
    int i;

    memcpy( slot, thunk_head, sizeof(thunk_head) );
    for (i = 0; i < 8; i++) slot[8 + i] = (unsigned char)(target >> (8 * i));
}

/* what the rewrite must leave in place of the thunk orig: "48 b8 <target> ff e0 90 90 90 90" */
static void put_rewritten( unsigned char *slot, const unsigned char *orig )
{
    unsigned char target[8];

    memcpy( target, orig + 8, sizeof(target) );
    slot[0] = 0x48;  /* mov rax, target */
    slot[1] = 0xb8;
    memcpy( slot + 2, target, sizeof(target) );
    slot[10] = 0xff;  /* jmp rax */
    slot[11] = 0xe0;
    slot[12] = slot[13] = slot[14] = slot[15] = 0x90;
}

/* THUNKS thunks in a row, each with its own target outside the image */
static struct area thunk_table( unsigned char **first )
{
    struct area a = area_new( 0x100 + THUNKS * 16 + 0x100 );
    int i;

    *first = a.lo + 0x100;
    for (i = 0; i < THUNKS; i++) put_thunk( *first + 16 * i, TARGET + 0x40 * (ULONG_PTR)i );
    return a;
}

/* ---- checks ---- */

static void start_case( const char *name )
{
    case_name = name;
    case_checks = case_failures = 0;
}

static void failure( void )
{
    if (!case_failures++) printf( "FAIL %s\n", case_name );
}

static void expect_count( const char *what, unsigned int got, unsigned int want )
{
    case_checks++;
    if (got == want) return;
    failure();
    printf( "     %s: count %u, expected %u\n", what, got, want );
}

static void print_slot( const char *label, const unsigned char *p )
{
    int i;

    printf( "       %s", label );
    for (i = 0; i < 16; i++) printf( " %02x", p[i] );
    printf( "\n" );
}

/* every byte of the area must be as in want */
static void expect_bytes( const char *what, const struct area *a, const unsigned char *want )
{
    size_t off, shown = 0;

    case_checks++;
    for (off = 0; off < a->len; off += 16)
    {
        if (!memcmp( a->lo + off, want + off, 16 )) continue;
        failure();
        if (shown++ == 4)
        {
            printf( "     %s: more slots differ\n", what );
            break;
        }
        printf( "     %s: the 16 bytes at +0x%zx differ\n", what, off );
        print_slot( "got: ", a->lo + off );
        print_slot( "want:", want + off );
    }
}

static void finish_case( void )
{
    case_count++;
    if (case_failures) failed_cases++;
    else printf( "ok   %s (%u checks)\n", case_name, case_checks );
}

/* one thunk at +0x40 of a fresh page: the rewrite must return 0 and change nothing */
static void expect_untouched_thunk( const char *what, ULONG_PTR target )
{
    struct area a = area_new( page_size );
    unsigned char *want;

    put_thunk( a.lo + 0x40, target );
    want = snapshot( &a );
    expect_count( what, rewrite_hookable_thunks( a.lo, a.len, IMAGE_BASE, IMAGE_SIZE, TRUE ), 0 );
    expect_bytes( what, &a, want );
    free( want );
    area_free( &a );
}

/* ---- cases ---- */

static void case_one_thunk( void )
{
    static const unsigned char thunk[16] = { 0x66, 0x90, 0xff, 0x25, 0x00, 0x00, 0x00, 0x00,
                                             0x7e, 0x77, 0xcd, 0x12, 0x02, 0x00, 0x00, 0x00 };
    static const unsigned char rewritten[16] = { 0x48, 0xb8, 0x7e, 0x77, 0xcd, 0x12, 0x02, 0x00,
                                                 0x00, 0x00, 0xff, 0xe0, 0x90, 0x90, 0x90, 0x90 };
    struct area a = area_new( page_size );
    unsigned char *want;

    start_case( "1  one aligned thunk, target outside the image: 48 b8 <target> ff e0 90 90 90 90" );
    memcpy( a.lo + 0x40, thunk, sizeof(thunk) );
    want = snapshot( &a );
    memcpy( want + 0x40, rewritten, sizeof(rewritten) );
    expect_count( "rewrite", rewrite_hookable_thunks( a.lo, a.len, IMAGE_BASE, IMAGE_SIZE, TRUE ), 1 );
    expect_bytes( "rewrite", &a, want );
    free( want );
    area_free( &a );
    finish_case();
}

static void case_target_inside( void )
{
    start_case( "2  target inside the image: untouched" );
    expect_untouched_thunk( "image start + 0x1000", IMAGE_BASE + 0x1000 );
    expect_untouched_thunk( "image start + 0x1007080", IMAGE_BASE + 0x1007080 );
    finish_case();
}

static void case_target_zero( void )
{
    start_case( "3  target 0: untouched" );
    expect_untouched_thunk( "target 0", 0 );
    finish_case();
}

static void case_misaligned( void )
{
    size_t k;

    start_case( "4  the same 16 bytes at 16n+8, and at every other 16n+1 .. 16n+15: untouched" );
    for (k = 1; k < 16; k++)
    {
        struct area a = area_new( page_size );
        unsigned char *want;
        char what[32];

        snprintf( what, sizeof(what), "thunk at 16n+%zu", k );
        put_thunk( a.lo + 0x40 + k, TARGET );
        want = snapshot( &a );
        expect_count( what, rewrite_hookable_thunks( a.lo, a.len, IMAGE_BASE, IMAGE_SIZE, TRUE ), 0 );
        expect_bytes( what, &a, want );
        free( want );
        area_free( &a );
    }
    finish_case();
}

static void case_near_misses( void )
{
    static const unsigned char listed[3][8] =
    {
        { 0x66, 0x90, 0xff, 0x25, 0x01, 0x00, 0x00, 0x00 },  /* nop; jmp [rip+1] */
        { 0x90, 0x90, 0xff, 0x25, 0x00, 0x00, 0x00, 0x00 },  /* nop; nop; jmp [rip] */
        { 0x66, 0x90, 0xff, 0x15, 0x00, 0x00, 0x00, 0x00 },  /* nop; call [rip] */
    };
    struct area a = area_new( (3 + 64 + 1) * 16 );
    unsigned char *want, *slot = a.lo;
    int i, bit;

    start_case( "5  near misses (the 3 listed, and each 1-bit change of the first 8 bytes): untouched" );
    for (i = 0; i < 3; i++, slot += 16)
    {
        put_thunk( slot, TARGET );
        memcpy( slot, listed[i], sizeof(listed[i]) );
    }
    for (i = 0; i < 8; i++)
        for (bit = 0; bit < 8; bit++, slot += 16)
        {
            put_thunk( slot, TARGET );
            slot[i] ^= (unsigned char)(1 << bit);
        }
    put_thunk( slot, TARGET );  /* a real thunk after them, which must still be found */
    want = snapshot( &a );
    put_rewritten( want + (slot - a.lo), slot );
    expect_count( "67 near misses and 1 thunk", rewrite_hookable_thunks( a.lo, a.len, IMAGE_BASE, IMAGE_SIZE, TRUE ), 1 );
    expect_bytes( "67 near misses and 1 thunk", &a, want );
    free( want );
    area_free( &a );
    finish_case();
}

static void case_table( void )
{
    unsigned char *first, *want;
    struct area a = thunk_table( &first );
    int i;

    start_case( "6  1024 thunks 16 bytes apart, as D3DMetal lays them out: all rewritten" );
    want = snapshot( &a );
    for (i = 0; i < THUNKS; i++) put_rewritten( want + (first - a.lo) + 16 * i, first + 16 * i );
    expect_count( "table", rewrite_hookable_thunks( a.lo, a.len, IMAGE_BASE, IMAGE_SIZE, TRUE ), THUNKS );
    expect_bytes( "table", &a, want );
    free( want );
    area_free( &a );
    finish_case();
}

static void case_short_end( void )
{
    static const size_t sizes[] = { 0, 1, 8, 15, 16 };
    struct area a;
    unsigned char *want;
    unsigned int n;
    size_t i;

    start_case( "7  buffer ending inside a slot: that slot untouched, nothing past the end read" );

    /* ends 8 bytes into the slot at +0x40: its target lies past the end, and is poisoned */
    a = area_new( page_size );
    put_thunk( a.lo + 0x30, TARGET );
    put_thunk( a.lo + 0x40, TARGET );
    want = snapshot( &a );
    put_rewritten( want + 0x30, a.lo + 0x30 );
    POISON( a.lo + 0x48, a.len - 0x48 );
    n = rewrite_hookable_thunks( a.lo, 0x48, IMAGE_BASE, IMAGE_SIZE, TRUE );
    UNPOISON( a.lo + 0x48, a.len - 0x48 );
    expect_count( "size 0x48", n, 1 );
    expect_bytes( "size 0x48", &a, want );
    free( want );
    area_free( &a );

    /* ends right at the guard page: the last slot is whole and is rewritten */
    a = area_new( page_size );
    for (i = 1; i <= 4; i++) put_thunk( a.hi - 16 * i, TARGET );
    want = snapshot( &a );
    for (i = 1; i <= 4; i++) put_rewritten( want + a.len - 16 * i, a.hi - 16 * i );
    expect_count( "end at the guard page", rewrite_hookable_thunks( a.hi - 0x40, 0x40, IMAGE_BASE, IMAGE_SIZE, TRUE ), 4 );
    expect_bytes( "end at the guard page", &a, want );
    free( want );
    area_free( &a );

    /* a thunk at the start of buffers of 0, 1, 8, 15 and 16 bytes */
    for (i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++)
    {
        char what[32];

        snprintf( what, sizeof(what), "size %zu", sizes[i] );
        a = area_new( page_size );
        put_thunk( a.lo, TARGET );
        want = snapshot( &a );
        if (sizes[i] == 16) put_rewritten( want, a.lo );
        POISON( a.lo + sizes[i], a.len - sizes[i] );
        n = rewrite_hookable_thunks( a.lo, sizes[i], IMAGE_BASE, IMAGE_SIZE, TRUE );
        UNPOISON( a.lo + sizes[i], a.len - sizes[i] );
        expect_count( what, n, sizes[i] == 16 );
        expect_bytes( what, &a, want );
        free( want );
        area_free( &a );
    }
    finish_case();
}

static void case_unaligned_start( void )
{
    struct area a;
    unsigned char *want;
    unsigned int n;
    size_t m;

    start_case( "8  start at 16n+3 (and 16n+1 .. 16n+15): bytes before the first aligned slot not read" );

    /* 16n+3 with the 13 bytes before the first aligned slot in the guard page */
    a = area_new( page_size );
    put_thunk( a.lo, TARGET );
    put_thunk( a.lo + 0x20, TARGET );
    want = snapshot( &a );
    put_rewritten( want, a.lo );
    put_rewritten( want + 0x20, a.lo + 0x20 );
    expect_count( "start 13 bytes into the guard page",
                  rewrite_hookable_thunks( a.lo - 13, 13 + 0x30, IMAGE_BASE, IMAGE_SIZE, TRUE ), 2 );
    expect_bytes( "start 13 bytes into the guard page", &a, want );
    free( want );
    area_free( &a );

    /* 16n+m: a thunk starts right at the start, its bytes before the first aligned slot poisoned */
    for (m = 1; m < 16; m++)
    {
        unsigned char *start;
        char what[32];

        snprintf( what, sizeof(what), "start at 16n+%zu", m );
        a = area_new( page_size );
        start = a.lo + 0x40 + m;
        put_thunk( start, TARGET );
        put_thunk( a.lo + 0x60, TARGET );
        want = snapshot( &a );
        put_rewritten( want + 0x60, a.lo + 0x60 );
        POISON( start, (size_t)(a.lo + 0x50 - start) );
        n = rewrite_hookable_thunks( start, (size_t)(a.lo + 0x70 - start), IMAGE_BASE, IMAGE_SIZE, TRUE );
        UNPOISON( start, (size_t)(a.lo + 0x50 - start) );
        expect_count( what, n, 1 );
        expect_bytes( what, &a, want );
        free( want );
        area_free( &a );
    }
    finish_case();
}

static void case_count_only( void )
{
    unsigned char *first, *want;
    struct area a = thunk_table( &first );
    unsigned int n;

    start_case( "9  rewrite=FALSE: the count, and no byte changed (pages read-only)" );
    want = snapshot( &a );
    area_protect( &a, PROT_READ );
    n = rewrite_hookable_thunks( a.lo, a.len, IMAGE_BASE, IMAGE_SIZE, FALSE );
    area_protect( &a, PROT_READ | PROT_WRITE );
    expect_count( "count only", n, THUNKS );
    expect_bytes( "count only", &a, want );
    free( want );
    area_free( &a );
    finish_case();
}

static void case_twice( void )
{
    unsigned char *first, *want;
    struct area a = thunk_table( &first );
    unsigned int n, n_count;

    start_case( "10 a second rewrite finds nothing and changes nothing (pages read-only)" );
    expect_count( "first", rewrite_hookable_thunks( a.lo, a.len, IMAGE_BASE, IMAGE_SIZE, TRUE ), THUNKS );
    want = snapshot( &a );
    area_protect( &a, PROT_READ );
    n = rewrite_hookable_thunks( a.lo, a.len, IMAGE_BASE, IMAGE_SIZE, TRUE );
    n_count = rewrite_hookable_thunks( a.lo, a.len, IMAGE_BASE, IMAGE_SIZE, FALSE );
    area_protect( &a, PROT_READ | PROT_WRITE );
    expect_count( "second", n, 0 );
    expect_count( "second, count only", n_count, 0 );
    expect_bytes( "second", &a, want );
    free( want );
    area_free( &a );
    finish_case();
}

/* thunks with these targets in a row: those marked outside are rewritten, the others stay */
static void expect_targets( const char *what, ULONG_PTR image_base, SIZE_T image_size,
                            const ULONG_PTR *targets, const int *outside, int count )
{
    struct area a = area_new( (size_t)count * 16 );
    unsigned char *want;
    unsigned int expected = 0;
    int i;

    for (i = 0; i < count; i++) put_thunk( a.lo + 16 * i, targets[i] );
    want = snapshot( &a );
    for (i = 0; i < count; i++)
    {
        if (!outside[i]) continue;
        put_rewritten( want + 16 * i, a.lo + 16 * i );
        expected++;
    }
    expect_count( what, rewrite_hookable_thunks( a.lo, a.len, image_base, image_size, TRUE ), expected );
    expect_bytes( what, &a, want );
    free( want );
    area_free( &a );
}

static void case_boundaries( void )
{
    const ULONG_PTR targets[] = { IMAGE_BASE, IMAGE_BASE + IMAGE_SIZE - 1, IMAGE_BASE + IMAGE_SIZE, IMAGE_BASE - 1 };
    const int outside[] = { 0, 0, 1, 1 };

    start_case( "11 target = base, base+size-1: untouched; base+size, base-1: rewritten" );
    expect_targets( "boundaries", IMAGE_BASE, IMAGE_SIZE, targets, outside, 4 );
    finish_case();
}

static void case_top_of_memory( void )
{
    const ULONG_PTR base = UINTPTR_MAX - 0xfff;
    const ULONG_PTR targets[] = { 0x1000, base, UINTPTR_MAX, base - 1 };
    const int outside[] = { 1, 0, 0, 1 };

    start_case( "12 image at UINTPTR_MAX-0xfff, size 0x1000 (base+size wraps): 0x1000 rewritten" );
    expect_targets( "top of memory", base, 0x1000, targets, outside, 4 );
    finish_case();
}

int main( void )
{
    setvbuf( stdout, NULL, _IOLBF, 0 );  /* the lines before a crash reach a log too */
    page_size = (size_t)sysconf( _SC_PAGESIZE );
    printf( "rewrite_hookable_thunks on %s, %zu-byte pages, AddressSanitizer %s\n",
#if defined(__x86_64__)
            "x86_64",
#elif defined(__aarch64__)
            "arm64",
#else
            "this cpu",
#endif
            page_size,
#ifdef TEST_ASAN
            "on"
#else
            "off"
#endif
            );

    case_one_thunk();
    case_target_inside();
    case_target_zero();
    case_misaligned();
    case_near_misses();
    case_table();
    case_short_end();
    case_unaligned_start();
    case_count_only();
    case_twice();
    case_boundaries();
    case_top_of_memory();

    printf( "%u cases, %u failed\n", case_count, failed_cases );
    return failed_cases ? 1 : 0;
}
