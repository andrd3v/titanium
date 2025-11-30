#ifndef MACHO_H
#define MACHO_H

#include <stdio.h>
#include <libkern/OSByteOrder.h>
#include <mach/mach.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <sys/stat.h>

#include "MemoryStream.h"
typedef struct MachO MachO;
typedef struct DyldSharedCache DyldSharedCache;
typedef struct DyldSharedCacheImage DyldSharedCacheImage;

typedef struct Fat
{
    MemoryStream *stream;
    MachO **slices;
    uint32_t slicesCount;
    int fileDescriptor;
} Fat;

int fat_read_at_offset(Fat *fat, uint64_t offset, size_t size, void *outBuf);

MemoryStream *fat_get_stream(Fat *fat);

Fat *fat_init_from_memory_stream(MemoryStream *stream);

Fat *fat_dsc_init_from_memory_stream(MemoryStream *stream, DyldSharedCache *containingCache, DyldSharedCacheImage *cacheImage);

Fat *fat_init_from_path(const char *filePath);

MachO *fat_find_slice(Fat *fat, cpu_type_t cputype, cpu_subtype_t cpusubtype);

void fat_enumerate_slices(Fat *fat, void (^enumBlock)(MachO *macho, bool *stop));

MachO *fat_get_single_slice(Fat *fat);

Fat *fat_create_for_macho_array(char *firstInputPath, MachO **machoArray, int machoArrayCount);

int fat_add_macho(Fat *fat, MachO *macho);

void fat_free(Fat *fat);

#endif
