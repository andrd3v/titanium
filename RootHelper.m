#import "RootHelper.h"

#import <spawn.h>
#import <mach-o/dyld.h>

#import "TitaniumRootViewController.h"
#import "teamID.h"

extern char **environ;

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

NSString *TitaniumStatusFilePath(void)
{
    NSString *tmpDir = NSTemporaryDirectory();
    if (tmpDir.length == 0) {
        tmpDir = @"/var/tmp/";
    }
    return [tmpDir stringByAppendingPathComponent:@"titanium_last_inject.plist"];
}

NSString *TitaniumCustomDylibSourcePath(void)
{
    NSString *tmpDir = NSTemporaryDirectory();
    if (tmpDir.length == 0) {
        tmpDir = @"/var/tmp/";
    }
    NSString *path = [tmpDir stringByAppendingPathComponent:@"titanium_selected.dylib"];
    NSLog(@"[RootHelper][andrdevv] TitaniumCustomDylibSourcePath resolved to %@", path);
    return path;
}

NSString *FindExecutablePathForBinary(NSString *binaryName)
{
    if (binaryName.length == 0) return nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *appsRoot = @"/var/containers/Bundle/Application";

    NSError *error = nil;
    NSArray<NSString *> *appDirs = [fm contentsOfDirectoryAtPath:appsRoot error:&error];
    if (!appDirs) {
        NSLog(@"[RootHelper] Failed to list %@: %@", appsRoot, error);
        return nil;
    }

    for (NSString *uuidDir in appDirs) {
        NSString *uuidPath = [appsRoot stringByAppendingPathComponent:uuidDir];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:uuidPath isDirectory:&isDir] || !isDir) {
            continue;
        }

        NSError *subError = nil;
        NSArray<NSString *> *subItems = [fm contentsOfDirectoryAtPath:uuidPath error:&subError];
        if (!subItems) {
            continue;
        }

        for (NSString *item in subItems) {
            if (![[item pathExtension] isEqualToString:@"app"]) {
                continue;
            }
            NSString *appPath = [uuidPath stringByAppendingPathComponent:item];
            NSString *candidateExec = [appPath stringByAppendingPathComponent:binaryName];
            if ([fm fileExistsAtPath:candidateExec]) {
                return candidateExec;
            }
        }
    }

    NSLog(@"[RootHelper] Failed to find executable for binary name %@", binaryName);
    return nil;
}

void SpawnRootHelperForProcess(NSString *processName)
{
    if (processName.length == 0) {
        NSLog(@"[RootHelper] Refusing to spawn root helper with empty process name");
        return;
    }

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);

    posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(&attr, 0);
    posix_spawnattr_set_persona_gid_np(&attr, 0);

    uint32_t executablePathSize = 0;
    _NSGetExecutablePath(NULL, &executablePathSize);
    char *executablePath = (char *)calloc(1, executablePathSize);
    if (!executablePath) {
        NSLog(@"[RootHelper] Failed to allocate buffer for executable path");
        posix_spawnattr_destroy(&attr);
        return;
    }
    _NSGetExecutablePath(executablePath, &executablePathSize);

    const char *targetProcessName = [processName UTF8String];

    pid_t task_pid = 0;
    const char *args[] = { executablePath, "-root", targetProcessName, NULL };
    int ret = posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
    posix_spawnattr_destroy(&attr);

    if (ret != 0) {
        NSLog(@"[RootHelper] posix_spawn failed: %d", ret);
    } else {
        NSLog(@"[RootHelper] Spawned root helper pid %d for process %@", task_pid, processName);
    }
    free(executablePath);
}

void StartRootHelper(int argc, char *argv[])
{
    @autoreleasepool {
        NSLog(@"[RootHelper][andrdevv] Root helper starting");

        NSString *targetProcessName = nil;
        if (argc > 2 && argv[2] != NULL) {
            targetProcessName = [NSString stringWithUTF8String:argv[2]];
        }

        if (targetProcessName.length == 0) {
            targetProcessName = @"DuolingoMobile";
            NSLog(@"[RootHelper][andrdevv] No target process name provided, falling back to %@", targetProcessName);
        } else {
            NSLog(@"[RootHelper][andrdevv] Target process name from argv: %@", targetProcessName);
        }

        NSString *execPath = FindExecutablePathForBinary(targetProcessName);
        if (execPath.length == 0) {
            NSLog(@"[RootHelper][andrdevv] Failed to resolve executable path for %@, aborting", targetProcessName);
            return;
        }

        NSString *teamID = get_team_identifier_NSString(execPath);
        if (teamID.length == 0) {
            NSLog(@"[RootHelper][andrdevv] No TeamID for %@, proceeding without TeamID", execPath);
        } else {
            NSLog(@"[RootHelper][andrdevv] Resolved target execPath=%@, teamID=%@", execPath, teamID);
        }

        TitaniumRootViewController *vc = [TitaniumRootViewController new];
        BOOL ok = [vc signAlertDylibWithTeamID:teamID targetProcessName:targetProcessName];
        if (!ok) {
            NSLog(@"[RootHelper][andrdevv] Signing or injection failed for %@", targetProcessName);
            return;
        }

        NSString *statusPath = TitaniumStatusFilePath();
        NSDictionary *info = @{
            @"processName": targetProcessName,
            @"timestamp": @([[NSDate date] timeIntervalSince1970])
        };
        if (![info writeToFile:statusPath atomically:YES]) {
            NSLog(@"[RootHelper][andrdevv] Failed to write status file at %@", statusPath);
        } else {
            NSLog(@"[RootHelper][andrdevv] Wrote inject status file at %@", statusPath);
        }
    }
}
