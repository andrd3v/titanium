#ifndef MACHO_SLICE_H
#define MACHO_SLICE_H

#include <stdbool.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include "MemoryStream.h"
#include "Fat.h"
#include "DyldSharedCache.h"

typedef struct MachOSegment
{
    struct segment_command_64 command;
    struct section_64 sections[];
} __attribute__((__packed__)) MachOSegment;

typedef struct FilesetMachO {
    char *entry_id;
    uint64_t vmaddr;
    uint64_t fileoff;
	Fat *underlyingMachO;
} FilesetMachO;

typedef struct MachO {
    MemoryStream *stream;
    bool is32Bit;
    struct mach_header machHeader;
    struct fat_arch_64 archDescriptor;
    uint64_t cachedBase;

    uint32_t filesetCount;
    FilesetMachO *filesetMachos;

    uint32_t segmentCount;
    MachOSegment **segments;

    DyldSharedCache *containingCache;
    DyldSharedCacheImage *cacheImage;
} MachO;

int macho_read_at_offset(MachO *macho, uint64_t offset, size_t size, void *outBuf);

int macho_write_at_offset(MachO *macho, uint64_t offset, size_t size, const void *inBuf);

int macho_read_string_at_offset(MachO *macho, uint64_t offset, char **string);

MemoryStream *macho_get_stream(MachO *macho);
uint32_t macho_get_filetype(MachO *macho);
struct mach_header *macho_get_mach_header(MachO *macho);
size_t macho_get_mach_header_size(MachO *macho);
DyldSharedCache *macho_get_containing_cache(MachO *macho);

int macho_translate_fileoff_to_vmaddr(MachO *macho, uint64_t fileoff, uint64_t *vmaddrOut, MachOSegment **segmentOut);
int macho_translate_vmaddr_to_fileoff(MachO *macho, uint64_t vmaddr, uint64_t *fileoffOut, MachOSegment **segmentOut);

int macho_read_at_vmaddr(MachO *macho, uint64_t vmaddr, size_t size, void *outBuf);
int macho_write_at_vmaddr(MachO *macho, uint64_t vmaddr, size_t size, const void *inBuf);
int macho_read_string_at_vmaddr(MachO *macho, uint64_t vmaddr, char **outString);
uint64_t macho_get_base_address(MachO *macho);

int macho_enumerate_load_commands(MachO *macho, void (^enumeratorBlock)(struct load_command loadCommand, uint64_t offset, void *cmd, bool *stop));
int macho_enumerate_segments(MachO *macho, void (^enumeratorBlock)(struct segment_command_64 *segment, bool *stop));
int macho_enumerate_sections(MachO *macho, void (^enumeratorBlock)(struct section_64 *section, struct segment_command_64 *segment, bool *stop));
int macho_enumerate_symbols(MachO *macho, void (^enumeratorBlock)(const char *name, uint8_t type, uint64_t vmaddr, bool *stop));
int macho_enumerate_dependencies(MachO *macho, void (^enumeratorBlock)(const char *dylibPath, uint32_t cmd, struct dylib* dylib, bool *stop));
int macho_enumerate_rpaths(MachO *macho, void (^enumeratorBlock)(const char *rpath, bool *stop));
int macho_enumerate_function_starts(MachO *macho, void (^enumeratorBlock)(uint64_t funcAddr, bool *stop));

MachO *macho_init(MemoryStream *stream, struct fat_arch_64 archDescriptor);

MachO *macho_init_for_writing(const char *filePath);

MachO **macho_array_create_for_paths(char **inputPaths, int inputPathsCount);

bool macho_is_encrypted(MachO *macho);

void macho_free(MachO *macho);

#endif
