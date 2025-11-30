#import "InjectHelper.h"

#import "libproc.h"
#import <mach/mach.h>
#import <mach/task_info.h>
#import <mach/mach_host.h>
#import <mach/processor_set.h>

#import "opainject/rop_inject.h"

static task_t TitaniumGetTaskByPid(pid_t pid)
{
    host_t host = mach_host_self();
    processor_set_name_t psDefault = MACH_PORT_NULL;
    kern_return_t kr = processor_set_default(host, &psDefault);
    if (kr != KERN_SUCCESS || !MACH_PORT_VALID(psDefault)) {
        NSLog(@"[Inject][andrdevv] processor_set_default failed for host port %d: %d (%s)", host, kr, mach_error_string(kr));
        return MACH_PORT_NULL;
    }

    processor_set_t psDefaultControl = MACH_PORT_NULL;
    kr = host_processor_set_priv(host, psDefault, &psDefaultControl);
    if (kr != KERN_SUCCESS || !MACH_PORT_VALID(psDefaultControl)) {
        NSLog(@"[Inject][andrdevv] host_processor_set_priv failed for host port %d, pset %d: %d (%s)", host, psDefault, kr, mach_error_string(kr));
        mach_port_deallocate(mach_task_self(), psDefault);
        return MACH_PORT_NULL;
    }

    task_array_t tasks = NULL;
    mach_msg_type_number_t numTasks = 0;
    kr = processor_set_tasks(psDefaultControl, &tasks, &numTasks);
    if (kr != KERN_SUCCESS || !tasks || numTasks == 0) {
        NSLog(@"[Inject][andrdevv] processor_set_tasks failed for pset %d: %d (%s)", psDefaultControl, kr, mach_error_string(kr));
        mach_port_deallocate(mach_task_self(), psDefault);
        mach_port_deallocate(mach_task_self(), psDefaultControl);
        return MACH_PORT_NULL;
    }

    task_t resultTask = MACH_PORT_NULL;
    for (mach_msg_type_number_t i = 0; i < numTasks; i++) {
        pid_t taskPid = 0;
        kr = pid_for_task(tasks[i], &taskPid);
        if (kr != KERN_SUCCESS) {
            continue;
        }
        if (taskPid == pid) {
            resultTask = tasks[i];
            break;
        }
    }

    vm_deallocate(mach_task_self(), (vm_address_t)tasks, numTasks * sizeof(task_t));
    mach_port_deallocate(mach_task_self(), psDefault);
    mach_port_deallocate(mach_task_self(), psDefaultControl);

    if (!MACH_PORT_VALID(resultTask)) {
        NSLog(@"[Inject][andrdevv] TitaniumGetTaskByPid failed to resolve task port for pid %d", pid);
        return MACH_PORT_NULL;
    }

    NSLog(@"[Inject][andrdevv] TitaniumGetTaskByPid resolved task port %d for pid %d", resultTask, pid);
    return resultTask;
}

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
                if (kr != KERN_SUCCESS) {
                    NSLog(@"[Inject][andrdevv] task_for_pid syscall failed for pid %d: %d (%s)", pid, kr, mach_error_string(kr));
                } else {
                    NSLog(@"[Inject][andrdevv] task_for_pid returned invalid task port for pid %d", pid);
                }

                task = TitaniumGetTaskByPid(pid);
            }

            if (!MACH_PORT_VALID(task)) {
                NSLog(@"[Inject][andrdevv] Unable to obtain valid task port for pid %d, skipping", pid);
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
