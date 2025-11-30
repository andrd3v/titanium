#ifndef __DYLD_CACHE_FORMAT__
#define __DYLD_CACHE_FORMAT__

#include <stdint.h>
#include <uuid/uuid.h>

#include "fixup-chains.h"


struct dyld_cache_header
{
    char        magic[16];
    uint32_t    mappingOffset;
    uint32_t    mappingCount;
    uint32_t    imagesOffsetOld;
    uint32_t    imagesCountOld;
    uint64_t    dyldBaseAddress;
    uint64_t    codeSignatureOffset;
    uint64_t    codeSignatureSize;
    uint64_t    slideInfoOffsetUnused;
    uint64_t    slideInfoSizeUnused;
    uint64_t    localSymbolsOffset;
    uint64_t    localSymbolsSize;
    uint8_t     uuid[16];
    uint64_t    cacheType;
    uint32_t    branchPoolsOffset;
    uint32_t    branchPoolsCount;
    uint64_t    dyldInCacheMH;
    uint64_t    dyldInCacheEntry;
    uint64_t    imagesTextOffset;
    uint64_t    imagesTextCount;
    uint64_t    patchInfoAddr;
    uint64_t    patchInfoSize;
    uint64_t    otherImageGroupAddrUnused;
    uint64_t    otherImageGroupSizeUnused;
    uint64_t    progClosuresAddr;
    uint64_t    progClosuresSize;
    uint64_t    progClosuresTrieAddr;
    uint64_t    progClosuresTrieSize;
    uint32_t    platform;
    uint32_t    formatVersion          : 8,
                dylibsExpectedOnDisk   : 1,
                simulator              : 1,
                locallyBuiltCache      : 1,
                builtFromChainedFixups : 1,
                padding                : 20;
    uint64_t    sharedRegionStart;
    uint64_t    sharedRegionSize;
    uint64_t    maxSlide;
    uint64_t    dylibsImageArrayAddr;
    uint64_t    dylibsImageArraySize;
    uint64_t    dylibsTrieAddr;
    uint64_t    dylibsTrieSize;
    uint64_t    otherImageArrayAddr;
    uint64_t    otherImageArraySize;
    uint64_t    otherTrieAddr;
    uint64_t    otherTrieSize;
    uint32_t    mappingWithSlideOffset;
    uint32_t    mappingWithSlideCount;
    uint64_t    dylibsPBLStateArrayAddrUnused;
    uint64_t    dylibsPBLSetAddr;
    uint64_t    programsPBLSetPoolAddr;
    uint64_t    programsPBLSetPoolSize;
    uint64_t    programTrieAddr;
    uint32_t    programTrieSize;
    uint32_t    osVersion;
    uint32_t    altPlatform;
    uint32_t    altOsVersion;
    uint64_t    swiftOptsOffset;
    uint64_t    swiftOptsSize;
    uint32_t    subCacheArrayOffset;
    uint32_t    subCacheArrayCount;
    uint8_t     symbolFileUUID[16];
    uint64_t    rosettaReadOnlyAddr;
    uint64_t    rosettaReadOnlySize;
    uint64_t    rosettaReadWriteAddr;
    uint64_t    rosettaReadWriteSize;
    uint32_t    imagesOffset;
    uint32_t    imagesCount;
    uint32_t    cacheSubType;
    uint64_t    objcOptsOffset;
    uint64_t    objcOptsSize;
    uint64_t    cacheAtlasOffset;
    uint64_t    cacheAtlasSize;
    uint64_t    dynamicDataOffset;
    uint64_t    dynamicDataMaxSize;
};


struct dyld_cache_mapping_info {
    uint64_t    address;
    uint64_t    size;
    uint64_t    fileOffset;
    uint32_t    maxProt;
    uint32_t    initProt;
};

enum {
    DYLD_CACHE_MAPPING_AUTH_DATA            = 1 << 0U,
    DYLD_CACHE_MAPPING_DIRTY_DATA           = 1 << 1U,
    DYLD_CACHE_MAPPING_CONST_DATA           = 1 << 2U,
    DYLD_CACHE_MAPPING_TEXT_STUBS           = 1 << 3U,
    DYLD_CACHE_DYNAMIC_CONFIG_DATA          = 1 << 4U,
};

struct dyld_cache_mapping_and_slide_info {
    uint64_t    address;
    uint64_t    size;
    uint64_t    fileOffset;
    uint64_t    slideInfoFileOffset;
    uint64_t    slideInfoFileSize;
    uint64_t    flags;
    uint32_t    maxProt;
    uint32_t    initProt;
};

struct dyld_cache_image_info
{
    uint64_t    address;
    uint64_t    modTime;
    uint64_t    inode;
    uint32_t    pathFileOffset;
    uint32_t    pad;
};

struct dyld_cache_image_info_extra
{
    uint64_t    exportsTrieAddr;
    uint64_t    weakBindingsAddr;
    uint32_t    exportsTrieSize;
    uint32_t    weakBindingsSize;
    uint32_t    dependentsStartArrayIndex;
    uint32_t    reExportsStartArrayIndex;
};


struct dyld_cache_accelerator_info
{
    uint32_t    version;
    uint32_t    imageExtrasCount;
    uint32_t    imagesExtrasOffset;
    uint32_t    bottomUpListOffset;
    uint32_t    dylibTrieOffset;
    uint32_t    dylibTrieSize;
    uint32_t    initializersOffset;
    uint32_t    initializersCount;
    uint32_t    dofSectionsOffset;
    uint32_t    dofSectionsCount;
    uint32_t    reExportListOffset;
    uint32_t    reExportCount;
    uint32_t    depListOffset;
    uint32_t    depListCount;
    uint32_t    rangeTableOffset;
    uint32_t    rangeTableCount;
    uint64_t    dyldSectionAddr;
};

struct dyld_cache_accelerator_initializer
{
    uint32_t    functionOffset;
    uint32_t    imageIndex;
};

struct dyld_cache_range_entry
{
    uint64_t    startAddress;
    uint32_t    size;
    uint32_t    imageIndex;
};

struct dyld_cache_accelerator_dof
{
    uint64_t    sectionAddress;
    uint32_t    sectionSize;
    uint32_t    imageIndex;
};

struct dyld_cache_image_text_info
{
    uuid_t      uuid;
    uint64_t    loadAddress;
    uint32_t    textSegmentSize;
    uint32_t    pathOffset;
};

struct dyld_cache_slide_info
{
    uint32_t    version;
    uint32_t    toc_offset;
    uint32_t    toc_count;
    uint32_t    entries_offset;
    uint32_t    entries_count;
    uint32_t    entries_size;
};

struct dyld_cache_slide_info_entry {
    uint8_t  bits[4096/(8*4)];
};


struct dyld_cache_slide_info2
{
    uint32_t    version;
    uint32_t    page_size;
    uint32_t    page_starts_offset;
    uint32_t    page_starts_count;
    uint32_t    page_extras_offset;
    uint32_t    page_extras_count;
    uint64_t    delta_mask;
    uint64_t    value_add;
};
#define DYLD_CACHE_SLIDE_PAGE_ATTRS                0xC000
#define DYLD_CACHE_SLIDE_PAGE_ATTR_EXTRA           0x8000
#define DYLD_CACHE_SLIDE_PAGE_ATTR_NO_REBASE       0x4000
#define DYLD_CACHE_SLIDE_PAGE_ATTR_END             0x8000

struct dyld_cache_slide_info3
{
    uint32_t    version;
    uint32_t    page_size;
    uint32_t    page_starts_count;
    uint64_t    auth_value_add;
    uint16_t    page_starts[];
};

#define DYLD_CACHE_SLIDE_V3_PAGE_ATTR_NO_REBASE    0xFFFF

union dyld_cache_slide_pointer3
{
    uint64_t  raw;
    struct {
        uint64_t    pointerValue        : 51,
                    offsetToNextPointer : 11,
                    unused              :  2;
    }         plain;

    struct {
        uint64_t    offsetFromSharedCacheBase : 32,
                    diversityData             : 16,
                    hasAddressDiversity       :  1,
                    key                       :  2,
                    offsetToNextPointer       : 11,
                    unused                    :  1,
                    authenticated             :  1;
    }         auth;
};



struct dyld_cache_slide_info4
{
    uint32_t    version;
    uint32_t    page_size;
    uint32_t    page_starts_offset;
    uint32_t    page_starts_count;
    uint32_t    page_extras_offset;
    uint32_t    page_extras_count;
    uint64_t    delta_mask;
    uint64_t    value_add;
};
#define DYLD_CACHE_SLIDE4_PAGE_NO_REBASE           0xFFFF
#define DYLD_CACHE_SLIDE4_PAGE_INDEX               0x7FFF
#define DYLD_CACHE_SLIDE4_PAGE_USE_EXTRA           0x8000
#define DYLD_CACHE_SLIDE4_PAGE_EXTRA_END           0x8000
struct dyld_cache_slide_info5
{
    uint32_t    version;
    uint32_t    page_size;
    uint32_t    page_starts_count;
    uint64_t    value_add;
    uint16_t    page_starts[];
};

#define DYLD_CACHE_SLIDE_V5_PAGE_ATTR_NO_REBASE    0xFFFF

union dyld_cache_slide_pointer5
{
    uint64_t  raw;
    struct dyld_chained_ptr_arm64e_shared_cache_rebase      regular;
    struct dyld_chained_ptr_arm64e_shared_cache_auth_rebase auth;
};


struct dyld_cache_local_symbols_info
{
    uint32_t    nlistOffset;
    uint32_t    nlistCount;
    uint32_t    stringsOffset;
    uint32_t    stringsSize;
    uint32_t    entriesOffset;
    uint32_t    entriesCount;
};

struct dyld_cache_local_symbols_entry
{
    uint32_t    dylibOffset;
    uint32_t    nlistStartIndex;
    uint32_t    nlistCount;
};

struct dyld_cache_local_symbols_entry_64
{
    uint64_t    dylibOffset;
    uint32_t    nlistStartIndex;
    uint32_t    nlistCount;
};

struct dyld_subcache_entry_v1
{
    uint8_t     uuid[16];
    uint64_t    cacheVMOffset;
};

struct dyld_subcache_entry
{
    uint8_t     uuid[16];
    uint64_t    cacheVMOffset;
    char        fileSuffix[32];
};

struct dyld_cache_dynamic_data_header
{
    char        magic[16];
    uint64_t    fsId;
    uint64_t    fsObjId;
};

#define MACOSX_MRM_DYLD_SHARED_CACHE_DIR   "/System/Library/dyld/"

#define MACOSX_DYLD_SHARED_CACHE_DIR       MACOSX_MRM_DYLD_SHARED_CACHE_DIR

#define IPHONE_DYLD_SHARED_CACHE_DIR       "/System/Library/Caches/com.apple.dyld/"

#define DRIVERKIT_DYLD_SHARED_CACHE_DIR    "/System/DriverKit/System/Library/dyld/"

#define EXCLAVEKIT_DYLD_SHARED_CACHE_DIR   "/System/ExclaveKit/System/Library/dyld/"

#define DYLD_SHARED_CACHE_DEVELOPMENT_EXT  ".development"

#define DYLD_SHARED_CACHE_DYNAMIC_DATA_MAGIC    "dyld_data    v0"

static const char* cryptexPrefixes[] = {
    "/System/Volumes/Preboot/Cryptexes/OS/",
    "/private/preboot/Cryptexes/OS/",
    "/System/Cryptexes/OS"
};

static const uint64_t kDyldSharedCacheTypeDevelopment = 0;
static const uint64_t kDyldSharedCacheTypeProduction = 1;
static const uint64_t kDyldSharedCacheTypeUniversal = 2;




#endif
