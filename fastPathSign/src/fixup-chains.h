#ifndef __MACH_O_FIXUP_CHAINS__
#define __MACH_O_FIXUP_CHAINS__ 6


#include <stdint.h>


struct dyld_chained_fixups_header
{
    uint32_t    fixups_version;
    uint32_t    starts_offset;
    uint32_t    imports_offset;
    uint32_t    symbols_offset;
    uint32_t    imports_count;
    uint32_t    imports_format;
    uint32_t    symbols_format;
};

struct dyld_chained_starts_in_image
{
    uint32_t    seg_count;
    uint32_t    seg_info_offset[1];
};

struct dyld_chained_starts_in_segment
{
    uint32_t    size;
    uint16_t    page_size;
    uint16_t    pointer_format;
    uint64_t    segment_offset;
    uint32_t    max_valid_pointer;
    uint16_t    page_count;
    uint16_t    page_start[1];
};

enum {
    DYLD_CHAINED_PTR_START_NONE   = 0xFFFF,
    DYLD_CHAINED_PTR_START_MULTI  = 0x8000,
    DYLD_CHAINED_PTR_START_LAST   = 0x8000,
};

struct dyld_chained_starts_offsets
{
    uint32_t    pointer_format;
    uint32_t    starts_count;
    uint32_t    chain_starts[1];
};


enum {
    DYLD_CHAINED_PTR_ARM64E                 =  1,
    DYLD_CHAINED_PTR_64                     =  2,
    DYLD_CHAINED_PTR_32                     =  3,
    DYLD_CHAINED_PTR_32_CACHE               =  4,
    DYLD_CHAINED_PTR_32_FIRMWARE            =  5,
    DYLD_CHAINED_PTR_64_OFFSET              =  6,
    DYLD_CHAINED_PTR_ARM64E_OFFSET          =  7,
    DYLD_CHAINED_PTR_ARM64E_KERNEL          =  7,
    DYLD_CHAINED_PTR_64_KERNEL_CACHE        =  8,
    DYLD_CHAINED_PTR_ARM64E_USERLAND        =  9,
    DYLD_CHAINED_PTR_ARM64E_FIRMWARE        = 10,
    DYLD_CHAINED_PTR_X86_64_KERNEL_CACHE    = 11,
    DYLD_CHAINED_PTR_ARM64E_USERLAND24      = 12,
    DYLD_CHAINED_PTR_ARM64E_SHARED_CACHE    = 13,
};


struct dyld_chained_ptr_arm64e_rebase
{
    uint64_t    target   : 43,
                high8    :  8,
                next     : 11,
                bind     :  1,
                auth     :  1;
};

struct dyld_chained_ptr_arm64e_bind
{
    uint64_t    ordinal   : 16,
                zero      : 16,
                addend    : 19,
                next      : 11,
                bind      :  1,
                auth      :  1;
};

struct dyld_chained_ptr_arm64e_auth_rebase
{
    uint64_t    target    : 32,
                diversity : 16,
                addrDiv   :  1,
                key       :  2,
                next      : 11,
                bind      :  1,
                auth      :  1;
};

struct dyld_chained_ptr_arm64e_auth_bind
{
    uint64_t    ordinal   : 16,
                zero      : 16,
                diversity : 16,
                addrDiv   :  1,
                key       :  2,
                next      : 11,
                bind      :  1,
                auth      :  1;
};

struct dyld_chained_ptr_64_rebase
{
    uint64_t    target    : 36,
                high8     :  8,
                reserved  :  7,
                next      : 12,
                bind      :  1;
};


struct dyld_chained_ptr_arm64e_bind24
{
    uint64_t    ordinal   : 24,
                zero      :  8,
                addend    : 19,
                next      : 11,
                bind      :  1,
                auth      :  1;
};

struct dyld_chained_ptr_arm64e_auth_bind24
{
    uint64_t    ordinal   : 24,
                zero      :  8,
                diversity : 16,
                addrDiv   :  1,
                key       :  2,
                next      : 11,
                bind      :  1,
                auth      :  1;
};


struct dyld_chained_ptr_64_bind
{
    uint64_t    ordinal   : 24,
                addend    :  8,
                reserved  : 19,
                next      : 12,
                bind      :  1;
};

struct dyld_chained_ptr_64_kernel_cache_rebase
{
    uint64_t    target     : 30,
                cacheLevel :  2,
                diversity  : 16,
                addrDiv    :  1,
                key        :  2,
                next       : 12,
                isAuth     :  1;
};

struct dyld_chained_ptr_32_rebase
{
    uint32_t    target    : 26,
                next      :  5,
                bind      :  1;
};

struct dyld_chained_ptr_32_bind
{
    uint32_t    ordinal   : 20,
                addend    :  6,
                next      :  5,
                bind      :  1;
};

struct dyld_chained_ptr_32_cache_rebase
{
    uint32_t    target    : 30,
                next      :  2;
};


struct dyld_chained_ptr_32_firmware_rebase
{
    uint32_t    target   : 26,
                next     :  6;
};

struct dyld_chained_ptr_arm64e_shared_cache_rebase
{
    uint64_t    runtimeOffset   : 34,
                high8           :  8,
                unused          : 10,
                next            : 11,
                auth            :  1;
};

struct dyld_chained_ptr_arm64e_shared_cache_auth_rebase
{
    uint64_t    runtimeOffset   : 34,
                diversity       : 16,
                addrDiv         :  1,
                keyIsData       :  1,
                next            : 11,
                auth            :  1;
};


enum {
    DYLD_CHAINED_IMPORT          = 1,
    DYLD_CHAINED_IMPORT_ADDEND   = 2,
    DYLD_CHAINED_IMPORT_ADDEND64 = 3,
};

struct dyld_chained_import
{
    uint32_t    lib_ordinal :  8,
                weak_import :  1,
                name_offset : 23;
};

struct dyld_chained_import_addend
{
    uint32_t    lib_ordinal :  8,
                weak_import :  1,
                name_offset : 23;
    int32_t     addend;
};

struct dyld_chained_import_addend64
{
    uint64_t    lib_ordinal : 16,
                weak_import :  1,
                reserved    : 15,
                name_offset : 32;
    uint64_t    addend;
};

#endif
