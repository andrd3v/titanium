#import "TitaniumAppDelegate.h"
#import "TitaniumSplashViewController.h"

@implementation TitaniumAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    TitaniumSplashViewController *splashViewController = [[TitaniumSplashViewController alloc] init];
    self.rootViewController = [[UINavigationController alloc] initWithRootViewController:splashViewController];
    self.window.rootViewController = self.rootViewController;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
