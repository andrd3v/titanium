#ifndef HOST_H
#define HOST_H

#include "Fat.h"

#define CPU_SUBTYPE_ARM64E_ABI_V2 0x80000000

int host_get_cpu_information(cpu_type_t *cputype, cpu_subtype_t *cpusubtype);

MachO *fat_find_preferred_slice(Fat *fat);

#endif
