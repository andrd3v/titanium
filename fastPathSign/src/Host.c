#include "Host.h"

#include "MachO.h"

#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/machine.h>
#include <sys/utsname.h>

int host_get_cpu_information(cpu_type_t *cputype, cpu_subtype_t *cpusubtype)
{
    size_t len;
    
    len = sizeof(cputype);
    if (sysctlbyname("hw.cputype", cputype, &len, NULL, 0) == -1) { printf("Error: no cputype.\n"); return -1; }
    
    len = sizeof(cpusubtype);
    if (sysctlbyname("hw.cpusubtype", cpusubtype, &len, NULL, 0) == -1) { printf("Error: no cpusubtype.\n"); return -1; }
    
    return 0;
}

int host_supported_arm64e_abi(void)
{
    struct utsname name;
    if (uname(&name) != 0) return -1;
    if (strcmp(name.release, "20.0.0") >= 0) {
        return 2;
    }
    else {
        return 1;
    }
}

MachO *fat_find_preferred_slice(Fat *fat)
{
    cpu_type_t cputype;
    cpu_subtype_t cpusubtype;
    if (host_get_cpu_information(&cputype, &cpusubtype) != 0) { return NULL; }

    MachO *preferredMacho = NULL;

    if (cputype == CPU_TYPE_ARM64) {
        if (cpusubtype == CPU_SUBTYPE_ARM64E) {
            int supportedArm64eABI = host_supported_arm64e_abi();
            if (supportedArm64eABI != -1) {
                if (supportedArm64eABI == 2) {
                    preferredMacho = fat_find_slice(fat, cputype, (CPU_SUBTYPE_ARM64E | CPU_SUBTYPE_ARM64E_ABI_V2));
                }
                if (!preferredMacho) {
                    preferredMacho = fat_find_slice(fat, cputype, CPU_SUBTYPE_ARM64E);
                    if (preferredMacho) {
                        if (macho_get_filetype(preferredMacho) == MH_EXECUTE && supportedArm64eABI == 2) {
                            preferredMacho = NULL;
                        }
                    }
                }
            }
        }

        if (!preferredMacho) {
            preferredMacho = fat_find_slice(fat, cputype, CPU_SUBTYPE_ARM64_V8);
            if (!preferredMacho) {
                preferredMacho = fat_find_slice(fat, cputype, CPU_SUBTYPE_ARM64_ALL);
            }
        }
    }

    if (!preferredMacho) {
        printf("Error: failed to find a preferred MachO slice that matches the host architecture.\n");
    }
    return preferredMacho;
}
