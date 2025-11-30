#import "TitaniumRootViewController.h"
#import "teamID.h"
#import "fastPathSign/coretrust_bug.h"
#import "fastPathSign/FastPathTeamID.h"
#import "fastPathSign/codesign.h"
#import "fastPathSign/src/MachO.h"
#import "fastPathSign/src/Host.h"
#import "fastPathSign/src/FileStream.h"
#import "fastPathSign/src/MemoryStream.h"
#import "InjectHelper.h"
#import "RootHelper.h"
#import "libproc.h"
#import <QuartzCore/QuartzCore.h>
#import <TargetConditionals.h>
#import <copyfile.h>
#import <errno.h>

static char *TitaniumExtractPreferredSlice(const char *fatPath) {
    if (!fatPath) {
        NSLog(@"[FastPathSign][andrdevv] TitaniumExtractPreferredSlice called with NULL path");
        return NULL;
    }

    Fat *fat = fat_init_from_path(fatPath);
    if (!fat) {
        NSLog(@"[FastPathSign][andrdevv] fat_init_from_path failed for %s", fatPath);
        return NULL;
    }

    MachO *macho = fat_find_preferred_slice(fat);
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
    if (!macho) {
        fat_free(fat);
        NSLog(@"[FastPathSign][andrdevv] fat_find_preferred_slice returned NULL for %s on macOS host", fatPath);
        return NULL;
    }
#else
    if (!macho) {
        fat_free(fat);
        NSLog(@"[FastPathSign][andrdevv] fat_find_preferred_slice returned NULL for %s (no matching slice for host arch)", fatPath);
        return NULL;
    }
#endif

    char *tempPath = strdup("/var/tmp/titanium_slice_XXXXXX");
    if (!tempPath) {
        NSLog(@"[FastPathSign][andrdevv] strdup for temp slice path failed");
        fat_free(fat);
        return NULL;
    }

    int fd = mkstemp(tempPath);
    if (fd < 0) {
        NSLog(@"[FastPathSign][andrdevv] mkstemp failed for pattern %s", tempPath);
        free(tempPath);
        fat_free(fat);
        return NULL;
    }

    MemoryStream *outStream = file_stream_init_from_path(tempPath, 0, 0,
                                                         FILE_STREAM_FLAG_WRITABLE | FILE_STREAM_FLAG_AUTO_EXPAND);
    if (!outStream) {
        NSLog(@"[FastPathSign][andrdevv] file_stream_init_from_path failed for %s", tempPath);
        close(fd);
        unlink(tempPath);
        free(tempPath);
        fat_free(fat);
        return NULL;
    }

    MemoryStream *machoStream = macho_get_stream(macho);
    size_t machoSize = memory_stream_get_size(machoStream);
    if (memory_stream_copy_data(machoStream, 0, outStream, 0, machoSize) != 0) {
        NSLog(@"[FastPathSign][andrdevv] memory_stream_copy_data failed while extracting slice (size=%zu) from %s to %s",
              machoSize, fatPath, tempPath);
        memory_stream_free(outStream);
        close(fd);
        unlink(tempPath);
        free(tempPath);
        fat_free(fat);
        return NULL;
    }

    memory_stream_free(outStream);
    fat_free(fat);
    close(fd);

    NSLog(@"[FastPathSign][andrdevv] Extracted preferred Mach-O slice from %s into %s (size=%zu)",
          fatPath, tempPath, machoSize);
    return tempPath;
}

@interface TitaniumRootViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIDocumentPickerDelegate>
@property (nonatomic, strong) UITableView *processTableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<NSDictionary *> *allProcesses;
@property (nonatomic, strong) NSArray<NSDictionary *> *processes;
@property (nonatomic, strong) NSString *pendingTargetProcessName;
@property (nonatomic, strong) NSDate *pendingRequestDate;
@property (nonatomic, strong) NSTimer *statusTimer;
@property (nonatomic, strong) NSTimer *countdownTimer;
@property (nonatomic, strong) UIAlertController *progressAlert;
@property (nonatomic, assign) NSInteger countdownValue;
@property (nonatomic, assign) BOOL injectCompleted;
@property (nonatomic, copy) NSString *completedProcessName;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIImage *> *iconCache;
@end

@implementation TitaniumRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.iconCache = [NSMutableDictionary dictionary];
    
    self.processTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.processTableView.dataSource = self;
    self.processTableView.delegate = self;
    [self.view addSubview:self.processTableView];
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.searchBar.placeholder = @"Search by process";
    self.searchBar.delegate = self;
    [self.searchBar sizeToFit];
    self.processTableView.tableHeaderView = self.searchBar;

    self.title = @"Titanium";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Select .dylib (now default)"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(selectDylibButtonTapped)];
    
    NSLog(@"Running Titanium...");
    NSLog(@"[UI] Loading process list...");
    [self reloadProcessList];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.processTableView.frame = self.view.bounds;
}

- (void)selectDylibButtonTapped {
    NSArray<NSString *> *types = @[@"public.data"];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types
                                                                                                   inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)handlePickedDylibURL:(NSURL *)url {
    if (!url) {
        NSLog(@"[UI][andrdevv] handlePickedDylibURL called with nil URL");
        return;
    }

    if (![[[url pathExtension] lowercaseString] isEqualToString:@"dylib"]) {
        NSLog(@"[UI][andrdevv] Selected file does not have .dylib extension: %@", url.path);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invalid file"
                                                                       message:@"Please select a .dylib file."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    BOOL accessing = [url startAccessingSecurityScopedResource];
    NSLog(@"[UI][andrdevv] Started accessing security-scoped resource for URL: %@", url);

    NSString *destPath = TitaniumCustomDylibSourcePath();
    NSFileManager *fm = [NSFileManager defaultManager];

    NSError *error = nil;
    if ([fm fileExistsAtPath:destPath]) {
        [fm removeItemAtPath:destPath error:&error];
        if (error) {
            NSLog(@"[UI][andrdevv] Failed to remove previous selected dylib at %@: %@", destPath, error);
            error = nil;
        }
    }

    NSURL *destURL = [NSURL fileURLWithPath:destPath];
    if (![fm copyItemAtURL:url toURL:destURL error:&error]) {
        NSLog(@"[UI][andrdevv] Failed to copy selected dylib to %@: %@", destPath, error);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Copy failed"
                                                                       message:@"Could not copy selected dylib into the app container."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        NSDictionary *attrs = [fm attributesOfItemAtPath:destPath error:nil];
        unsigned long long fileSize = [attrs fileSize];
        NSLog(@"[UI][andrdevv] Stored user-selected dylib at %@ (size=%llu bytes)", destPath, fileSize);
        NSString *fileName = url.lastPathComponent ?: @"Custom dylib";
        self.navigationItem.rightBarButtonItem.title = fileName;
    }

    if (accessing) {
        [url stopAccessingSecurityScopedResource];
        NSLog(@"[UI][andrdevv] Stopped accessing security-scoped resource for URL: %@", url);
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [self handlePickedDylibURL:urls.firstObject];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    [self handlePickedDylibURL:url];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)signAlertDylibWithTeamID:(NSString *)teamID
               targetProcessName:(NSString *)targetProcessName {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *sourceDylibPath = nil;

    NSString *customPath = TitaniumCustomDylibSourcePath();
    if (customPath.length > 0 && [fm fileExistsAtPath:customPath]) {
        sourceDylibPath = customPath;
        NSLog(@"[FastPathSign][andrdevv] Using user-selected dylib at path %@", sourceDylibPath);
    } else {
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *alertPath = [bundlePath stringByAppendingPathComponent:@"alert.dylib"];
        
        if (![fm fileExistsAtPath:alertPath]) {
            NSLog(@"[FastPathSign][andrdevv] alert.dylib not found at path %@", alertPath);
            return NO;
        }
        sourceDylibPath = alertPath;
        NSLog(@"[FastPathSign][andrdevv] Using bundled alert.dylib at path %@", sourceDylibPath);
    }

    NSDictionary *sourceAttrs = [fm attributesOfItemAtPath:sourceDylibPath error:nil];
    unsigned long long sourceSize = [sourceAttrs fileSize];
    NSString *sourceTeamID = fastpath_get_team_identifier_for_path(sourceDylibPath);
    NSLog(@"[FastPathSign][andrdevv] Preparing CoreTrust bypass for dylib at path %@ (size=%llu bytes, originalTeamID=%@) with Team ID %@",
          sourceDylibPath, sourceSize, sourceTeamID, teamID);

    NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (documentsDir.length == 0) {
        documentsDir = NSTemporaryDirectory();
    }
    NSString *patchedAlertPath = [documentsDir stringByAppendingPathComponent:@"alert_with_ct_bypass.dylib"];

    NSError *fileError = nil;
    if ([fm fileExistsAtPath:patchedAlertPath]) {
        if (![fm removeItemAtPath:patchedAlertPath error:&fileError]) {
            NSLog(@"[FastPathSign][andrdevv] Failed to remove existing patched dylib at %@: %@", patchedAlertPath, fileError);
            return NO;
        }
    }
    fileError = nil;
    if (![fm copyItemAtPath:sourceDylibPath toPath:patchedAlertPath error:&fileError]) {
        NSLog(@"[FastPathSign][andrdevv] Failed to copy dylib to writable location %@: %@", patchedAlertPath, fileError);
        return NO;
    }
    
    NSDictionary *patchedAttrsBeforeSign = [fm attributesOfItemAtPath:patchedAlertPath error:nil];
    unsigned long long patchedSizeBeforeSign = [patchedAttrsBeforeSign fileSize];
    NSString *patchedTeamIDBeforeSign = fastpath_get_team_identifier_for_path(patchedAlertPath);
    NSLog(@"[FastPathSign][andrdevv] Copied dylib to writable path %@ (size=%llu bytes, teamIDBeforeSign=%@)",
          patchedAlertPath, patchedSizeBeforeSign, patchedTeamIDBeforeSign);

    int adhocResult = codesign_sign_adhoc(patchedAlertPath.UTF8String, true, nil);
    if (adhocResult != 0) {
        NSLog(@"[FastPathSign][andrdevv] Ad-hoc signing failed with code %d, continuing anyway", adhocResult);
    } else {
        NSString *patchedTeamIDAfterSign = fastpath_get_team_identifier_for_path(patchedAlertPath);
        NSDictionary *patchedAttrsAfterSign = [fm attributesOfItemAtPath:patchedAlertPath error:nil];
        unsigned long long patchedSizeAfterSign = [patchedAttrsAfterSign fileSize];
        NSLog(@"[FastPathSign][andrdevv] Ad-hoc signing completed successfully for %@ (sizeAfterSign=%llu bytes, teamIDAfterSign=%@)",
              patchedAlertPath, patchedSizeAfterSign, patchedTeamIDAfterSign);
    }

    NSLog(@"[FastPathSign][andrdevv] Preparing to apply CoreTrust bypass to copied dylib at %@ with Team ID %@",
          patchedAlertPath, teamID);

    char *slicePath = TitaniumExtractPreferredSlice(patchedAlertPath.UTF8String);
    if (!slicePath) {
        NSLog(@"[FastPathSign][andrdevv] Failed to extract preferred slice from %@, aborting CoreTrust bypass", patchedAlertPath);
        return NO;
    }

    NSDictionary *sliceAttrs = [fm attributesOfItemAtPath:[NSString stringWithUTF8String:slicePath] error:nil];
    unsigned long long sliceSize = [sliceAttrs fileSize];
    NSLog(@"[FastPathSign][andrdevv] Using extracted slice at %s for CoreTrust bypass (size=%llu bytes)",
          slicePath, sliceSize);

    int ctResult = apply_coretrust_bypass_with_team_id(slicePath, teamID.UTF8String);

    if (ctResult != 0) {
        NSLog(@"[FastPathSign][andrdevv] CoreTrust bypass failed with code %d for slice %s (likely unsupported Mach-O layout or missing SHA256 CodeDirectory)",
              ctResult, slicePath);
        unlink(slicePath);
        free(slicePath);
        return NO;
    } else {
        NSLog(@"[FastPathSign][andrdevv] CoreTrust bypass applied successfully to slice %s", slicePath);
    }

    int copyResult = copyfile(slicePath, patchedAlertPath.UTF8String, 0,
                              COPYFILE_ALL | COPYFILE_MOVE | COPYFILE_UNLINK);
    if (copyResult != 0) {
        NSLog(@"[FastPathSign][andrdevv] copyfile from slice %s back to %@ failed with errno=%d",
              slicePath, patchedAlertPath, errno);
        unlink(slicePath);
        free(slicePath);
        return NO;
    }
    chmod(patchedAlertPath.UTF8String, 0755);

    NSLog(@"[FastPathSign][andrdevv] Replaced original dylib at %@ with patched slice %s", patchedAlertPath, slicePath);

    free(slicePath);

    NSString *patchedTeamIDCD = fastpath_get_team_identifier_for_path(patchedAlertPath);
    NSLog(@"[FastPathSign][andrdevv] CoreTrust bypass applied successfully. Patched dylib path: %@, finalTeamID=%@",
          patchedAlertPath, patchedTeamIDCD);

    NSString *patchedTeamIDCDCheck = fastpath_get_team_identifier_for_path(patchedAlertPath);
    if (patchedTeamIDCDCheck.length > 0) {
        NSLog(@"[FastPathSign][andrdevv] Verified patched dylib CodeDirectory Team ID: %@", patchedTeamIDCDCheck);
    } else {
        NSLog(@"[FastPathSign][andrdevv] Failed to read CodeDirectory Team ID from patched dylib after CoreTrust bypass");
    }

    NSString *bundleRootPath = @"/var/containers/Bundle/Application";
    NSString *bundleRootInjectPath = [bundleRootPath stringByAppendingPathComponent:@"alert_with_ct_bypass.dylib"];

    fileError = nil;
    if ([fm fileExistsAtPath:bundleRootInjectPath]) {
        if (![fm removeItemAtPath:bundleRootInjectPath error:&fileError]) {
            NSLog(@"[FastPathSign][andrdevv] Failed to remove existing inject dylib at %@: %@", bundleRootInjectPath, fileError);
        } else {
            NSLog(@"[FastPathSign][andrdevv] Removed old inject dylib at %@", bundleRootInjectPath);
        }
    }
    fileError = nil;
    if (![fm copyItemAtPath:patchedAlertPath toPath:bundleRootInjectPath error:&fileError]) {
        NSLog(@"[FastPathSign][andrdevv] Failed to copy patched dylib into Bundle/Application root %@: %@", bundleRootInjectPath, fileError);
        return NO;
    } else {
        NSDictionary *rootAttrs = [fm attributesOfItemAtPath:bundleRootInjectPath error:nil];
        unsigned long long rootSize = [rootAttrs fileSize];
        NSLog(@"[FastPathSign][andrdevv] Copied patched dylib into Bundle/Application root at %@ (size=%llu bytes)", bundleRootInjectPath, rootSize);
    }

    NSLog(@"[Inject][andrdevv] Starting injection into process '%@' with dylib path %@", targetProcessName, bundleRootInjectPath);
    BOOL injectOK = injectDylibIntoProcessNamed(targetProcessName, bundleRootInjectPath);
    if (!injectOK) {
        NSLog(@"[FastPathSign][andrdevv] Injection helper reported failure for target process '%@' and dylib %@", targetProcessName, bundleRootInjectPath);
        return NO;
    }

    NSError *cleanupError = nil;
    if ([fm fileExistsAtPath:patchedAlertPath]) {
        if (![fm removeItemAtPath:patchedAlertPath error:&cleanupError]) {
            NSLog(@"[FastPathSign][andrdevv] Failed to remove temporary patched dylib at %@: %@", patchedAlertPath, cleanupError);
        } else {
            NSLog(@"[FastPathSign][andrdevv] Removed temporary patched dylib at %@", patchedAlertPath);
        }
    }
    cleanupError = nil;
    if ([fm fileExistsAtPath:bundleRootInjectPath]) {
        if (![fm removeItemAtPath:bundleRootInjectPath error:&cleanupError]) {
            NSLog(@"[FastPathSign][andrdevv] Failed to remove injected dylib copy at %@: %@", bundleRootInjectPath, cleanupError);
        } else {
            NSLog(@"[FastPathSign][andrdevv] Removed injected dylib copy at %@", bundleRootInjectPath);
        }
    }

    return YES;
}

- (void)reloadProcessList {
    int count = proc_listallpids(NULL, 0);
    if (count <= 0) {
        NSLog(@"[UI] proc_listallpids returned %d", count);
        self.processes = @[];
        [self.processTableView reloadData];
        return;
    }
    
    pid_t *pids = malloc(sizeof(pid_t) * count);
    if (!pids) {
        NSLog(@"[UI] malloc failed for pids buffer");
        self.processes = @[];
        [self.processTableView reloadData];
        return;
    }
    
    int actualCount = proc_listallpids(pids, sizeof(pid_t) * count);
    if (actualCount <= 0) {
        NSLog(@"[UI] proc_listallpids (second call) returned %d", actualCount);
        free(pids);
        self.processes = @[];
        [self.processTableView reloadData];
        return;
    }
    
    NSMutableArray<NSMutableDictionary *> *result = [NSMutableArray array];
    
    for (int i = 0; i < actualCount; i++) {
        pid_t pid = pids[i];
        if (pid <= 0) {
            continue;
        }
        
        char name[1000];
        memset(name, 0, sizeof(name));
        if (proc_name(pid, name, sizeof(name)) <= 0) {
            continue;
        }
        
        if (name[0] == '\0') {
            continue;
        }
        
        NSString *processName = [NSString stringWithUTF8String:name];
        if (processName.length == 0) {
            continue;
        }
        
        NSMutableDictionary *entry = [@{
            @"pid": @(pid),
            @"name": processName
        } mutableCopy];
        [result addObject:entry];
    }
    
    free(pids);
    
    for (NSMutableDictionary *entry in result) {
        NSString *name = entry[@"name"];
        BOOL hasIcon = ([self iconForProcessName:name] != nil);
        entry[@"hasIcon"] = @(hasIcon);
    }
    
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        BOOL hasIcon1 = [obj1[@"hasIcon"] boolValue];
        BOOL hasIcon2 = [obj2[@"hasIcon"] boolValue];
        
        if (hasIcon1 != hasIcon2) {
            return hasIcon1 ? NSOrderedAscending : NSOrderedDescending;
        }
        
        NSString *name1 = obj1[@"name"];
        NSString *name2 = obj2[@"name"];
        return [name1 caseInsensitiveCompare:name2];
    }];
    
    self.allProcesses = result;
    
    NSString *currentSearch = self.searchBar.text ?: @"";
    [self applyFilterWithText:currentSearch];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.processes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ProcessCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *entry = self.processes[indexPath.row];
    NSString *name = entry[@"name"];
    NSNumber *pidNumber = entry[@"pid"];
    
    cell.textLabel.text = name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"pid %@", pidNumber];
    
    UIImage *icon = [self iconForProcessName:name];
    if (icon) {
        CGSize targetSize = CGSizeMake(28.0, 28.0);
        UIGraphicsBeginImageContextWithOptions(targetSize, NO, 0.0);
        [icon drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
        UIImage *scaledIcon = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        cell.imageView.image = scaledIcon;
        cell.imageView.layer.cornerRadius = 10.0;
        cell.imageView.layer.masksToBounds = YES;
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        cell.imageView.image = nil;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row >= self.processes.count) {
        return;
    }
    
    NSDictionary *entry = self.processes[indexPath.row];
    NSString *name = entry[@"name"];
    NSNumber *pidNumber = entry[@"pid"];
    
    NSLog(@"[UI] Selected process %@ (pid %@), spawning root helper...", name, pidNumber);

    self.pendingTargetProcessName = name;
    self.pendingRequestDate = [NSDate date];
    [self.statusTimer invalidate];
    self.statusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(checkInjectStatus)
                                                      userInfo:nil
                                                       repeats:YES];

    self.injectCompleted = NO;
    self.completedProcessName = nil;

    self.countdownValue = 15;
    [self.countdownTimer invalidate];

    NSString *message = [NSString stringWithFormat:@"Injection into the process %@\nRemaining %ld seconds",
                         name, (long)self.countdownValue];
    UIAlertController *progress = [UIAlertController alertControllerWithTitle:@"Inject"
                                                                      message:message
                                                               preferredStyle:UIAlertControllerStyleAlert];
    self.progressAlert = progress;
    [self presentViewController:progress animated:YES completion:nil];

    self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                           target:self
                                                         selector:@selector(countdownTick)
                                                         userInfo:nil
                                                          repeats:YES];
    self.countdownValue--;

    SpawnRootHelperForProcess(name);
}

- (void)checkInjectStatus {
    if (self.pendingTargetProcessName.length == 0) {
        return;
    }

    NSString *statusPath = TitaniumStatusFilePath();
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:statusPath];
    if (!info) {
        return;
    }

    NSString *processName = info[@"processName"];
    NSNumber *timestampNumber = info[@"timestamp"];
    if (![processName isKindOfClass:[NSString class]] ||
        ![timestampNumber isKindOfClass:[NSNumber class]]) {
        return;
    }

    if (![processName isEqualToString:self.pendingTargetProcessName]) {
        return;
    }

    NSTimeInterval ts = [timestampNumber doubleValue];
    if (self.pendingRequestDate &&
        ts < [self.pendingRequestDate timeIntervalSince1970]) {
        return;
    }

    [[NSFileManager defaultManager] removeItemAtPath:statusPath error:nil];

    [self.statusTimer invalidate];
    self.statusTimer = nil;

    self.pendingTargetProcessName = nil;
    self.pendingRequestDate = nil;

    self.injectCompleted = YES;
    self.completedProcessName = processName;

    if (!self.countdownTimer && !self.progressAlert) {
        [self presentSuccessAlertForProcess:processName];
        self.injectCompleted = NO;
        self.completedProcessName = nil;
    }
}

- (void)presentSuccessAlertForProcess:(NSString *)processName {
    if (processName.length == 0) {
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Injection completed"
                                                                   message:[NSString stringWithFormat:@"Successfully injected into the process %@", processName]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)countdownTick {
    if (!self.progressAlert) {
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;
        return;
    }

    if (self.countdownValue <= 0) {
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;

        UIAlertController *alertToDismiss = self.progressAlert;
        self.progressAlert = nil;

        [alertToDismiss dismissViewControllerAnimated:YES completion:^{
            if (self.injectCompleted && self.completedProcessName.length > 0) {
                [self presentSuccessAlertForProcess:self.completedProcessName];
                self.injectCompleted = NO;
                self.completedProcessName = nil;
            }
        }];
        return;
    }

    self.progressAlert.message = [NSString stringWithFormat:@"Injection into the process %@\nRemaining %ld seconds",
                                  self.pendingTargetProcessName ?: @"", (long)self.countdownValue];
    self.countdownValue--;
}

- (UIImage *)iconForProcessName:(NSString *)processName {
    if (processName.length == 0) {
        return nil;
    }
    
    UIImage *cached = self.iconCache[processName];
    if (cached) {
        return cached;
    }
    
    NSString *execPath = FindExecutablePathForBinary(processName);
    if (execPath.length == 0) {
        return nil;
    }
    
    NSString *appPath = [execPath stringByDeletingLastPathComponent];
    NSString *infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
    if (!infoPlist) {
        return nil;
    }
    
    NSString *iconName = nil;
    NSDictionary *iconsDict = infoPlist[@"CFBundleIcons"];
    NSDictionary *primaryIcon = iconsDict[@"CFBundlePrimaryIcon"];
    NSArray *iconFiles = primaryIcon[@"CFBundleIconFiles"];
    if ([iconFiles isKindOfClass:[NSArray class]] && iconFiles.count > 0) {
        iconName = [iconFiles lastObject];
    }
    if (iconName.length == 0) {
        iconName = infoPlist[@"CFBundleIconFile"];
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *iconPath = nil;
    
    if (iconName.length > 0) {
        NSString *candidate = [appPath stringByAppendingPathComponent:iconName];
        if ([fm fileExistsAtPath:candidate]) {
            iconPath = candidate;
        } else {
            candidate = [[appPath stringByAppendingPathComponent:iconName] stringByAppendingPathExtension:@"png"];
            if ([fm fileExistsAtPath:candidate]) {
                iconPath = candidate;
            }
        }
    }
    
    if (!iconPath) {
        NSArray *contents = [fm contentsOfDirectoryAtPath:appPath error:nil];
        for (NSString *item in contents) {
            if ([[item pathExtension] isEqualToString:@"png"] &&
                [item rangeOfString:@"AppIcon" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                iconPath = [appPath stringByAppendingPathComponent:item];
                break;
            }
        }
    }
    
    if (!iconPath) {
        return nil;
    }
    
    UIImage *image = [UIImage imageWithContentsOfFile:iconPath];
    if (image) {
        self.iconCache[processName] = image;
    }
    return image;
}

- (void)applyFilterWithText:(NSString *)text {
    NSString *query = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (query.length == 0) {
        self.processes = self.allProcesses ?: @[];
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSDictionary *entry in self.allProcesses) {
            NSString *name = entry[@"name"];
            if ([name rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [filtered addObject:entry];
            }
        }
        self.processes = filtered;
    }
    [self.processTableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applyFilterWithText:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

@end
