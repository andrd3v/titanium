#import <Foundation/Foundation.h>

void SpawnRootHelperForProcess(NSString *processName);

NSString *TitaniumStatusFilePath(void);

NSString *TitaniumCustomDylibSourcePath(void);

void StartRootHelper(int argc, char *argv[]);

NSString *FindExecutablePathForBinary(NSString *binaryName);
