#import "InjectHelper.h"

#import "libproc.h"
#import <mach/mach.h>
#import <mach/task_info.h>

#import "opainject/rop_inject.h"

BOOL injectDylibIntoProcessNamed(NSString *processNameSubstring, NSString *dylibPath)
{
    if (processNameSubstring.length == 0 || dylibPath.length == 0) {
        NSLog(@"[Inject][andrdevv] Invalid arguments for injection (processName='%@', dylibPath='%@')",
              processNameSubstring, dylibPath);
        return NO;
    }

    const char *targetName = [processNameSubstring UTF8String];
    const char *dylibFSPath = [dylibPath fileSystemRepresentation];

    NSLog(@"[Inject][andrdevv] Starting scan for process containing '%s' to inject dylib '%s'",
          targetName, dylibFSPath);

    int count = proc_listallpids(NULL, 0);
    if (count <= 0) {
        NSLog(@"[Inject][andrdevv] proc_listallpids returned %d", count);
        return NO;
    }

    pid_t *pids = malloc(sizeof(pid_t) * count);
    if (!pids) {
        NSLog(@"[Inject][andrdevv] malloc failed for pids buffer (count=%d)", count);
        return NO;
    }

    int actualCount = proc_listallpids(pids, sizeof(pid_t) * count);
    if (actualCount <= 0) {
        NSLog(@"[Inject][andrdevv] proc_listallpids (second call) returned %d", actualCount);
        free(pids);
        return NO;
    }

    BOOL success = NO;

    for (int i = 0; i < actualCount; i++) {
        pid_t pid = pids[i];
        if (pid <= 0) continue;

        char name[1000];
        memset(name, 0, sizeof(name));
        if (proc_name(pid, name, sizeof(name)) <= 0) {
            continue;
        }

        if (strstr(name, targetName) != NULL) {
            NSLog(@"[Inject][andrdevv] Found target process: pid=%d, name=%s", pid, name);

            task_t task = MACH_PORT_NULL;
            kern_return_t kr = task_for_pid(mach_task_self(), pid, &task);
            if (kr != KERN_SUCCESS || !MACH_PORT_VALID(task)) {
                NSLog(@"[Inject][andrdevv] task_for_pid failed for pid %d: %d (%s)", pid, kr, mach_error_string(kr));
                continue;
            }

            task_dyld_info_data_t dyldInfo;
            mach_msg_type_number_t infoCount = TASK_DYLD_INFO_COUNT;
            kr = task_info(task, TASK_DYLD_INFO, (task_info_t)&dyldInfo, &infoCount);
            if (kr != KERN_SUCCESS) {
                NSLog(@"[Inject][andrdevv] task_info(TASK_DYLD_INFO) failed for pid %d: %d (%s)", pid, kr, mach_error_string(kr));
                mach_port_deallocate(mach_task_self(), task);
                continue;
            }

            NSLog(@"[Inject][andrdevv] Injecting dylib %s into pid %d (all_image_info_addr=0x%llx)",
                  dylibFSPath, pid, (unsigned long long)dyldInfo.all_image_info_addr);

            injectDylibViaRop(task, pid, dylibFSPath, dyldInfo.all_image_info_addr);

            mach_port_deallocate(mach_task_self(), task);

            success = YES;
            break;
        }
    }

    if (!success) {
        NSLog(@"[Inject][andrdevv] Failed to find matching process for substring '%s'; injection aborted", targetName);
    } else {
        NSLog(@"[Inject][andrdevv] Injection routine completed and reported success for target substring '%s'", targetName);
    }

    free(pids);
    return success;
}
