#import <Foundation/Foundation.h>
#import "TitaniumAppDelegate.h"
#import "RootHelper.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "-root") == 0) {
            StartRootHelper(argc, argv);
            return 0;
        }
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(TitaniumAppDelegate.class));
    }
}
