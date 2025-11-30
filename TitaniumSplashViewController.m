#import "TitaniumSplashViewController.h"
#import "TitaniumRootViewController.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const kTitaniumProfileName = @"andrd3v";
static NSString *const kTitaniumXURLString = @"https:" "/" "/x.com/andrd3v";
static NSString *const kTitaniumTelegramURLString = @"https:" "/" "/t.me/andrdevv";
static NSString *const kTitaniumGitHubURLString = @"https:" "/" "/github.com/andrd3v";
static NSString *const kTitaniumAvatarImageName = @"avatar";

@interface TitaniumSplashViewController ()
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nicknameLabel;
@property (nonatomic, strong) UIButton *xButton;
@property (nonatomic, strong) UIButton *telegramButton;
@property (nonatomic, strong) UIButton *githubButton;
@property (nonatomic, strong) UIButton *openInjectorButton;
@end

@implementation TitaniumSplashViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.10 alpha:1.0];
    
    UIImage *avatarImage = [UIImage imageNamed:kTitaniumAvatarImageName];
    self.avatarImageView = [[UIImageView alloc] initWithImage:avatarImage];
    if (!self.avatarImageView.image) {
        self.avatarImageView.backgroundColor = [UIColor colorWithRed:0.25 green:0.27 blue:0.32 alpha:1.0];
    }
    self.avatarImageView.layer.cornerRadius = 64.0;
    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    [self.view addSubview:self.avatarImageView];
    
    self.nicknameLabel = [[UILabel alloc] init];
    self.nicknameLabel.text = kTitaniumProfileName;
    self.nicknameLabel.textColor = [UIColor whiteColor];
    self.nicknameLabel.font = [UIFont boldSystemFontOfSize:28.0];
    self.nicknameLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.nicknameLabel];
    
    self.xButton = [self linkButtonWithTitle:@"X" selector:@selector(openX)];
    self.telegramButton = [self linkButtonWithTitle:@"Telegram" selector:@selector(openTelegram)];
    self.githubButton = [self linkButtonWithTitle:@"GitHub" selector:@selector(openGitHub)];
    [self.view addSubview:self.xButton];
    [self.view addSubview:self.telegramButton];
    [self.view addSubview:self.githubButton];
    
    self.openInjectorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.openInjectorButton setTitle:@"Continue" forState:UIControlStateNormal];
    self.openInjectorButton.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    [self.openInjectorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.openInjectorButton.backgroundColor = [UIColor colorWithRed:0.30 green:0.55 blue:1.0 alpha:1.0];
    self.openInjectorButton.layer.cornerRadius = 14.0;
    self.openInjectorButton.layer.masksToBounds = YES;
    [self.openInjectorButton addTarget:self action:@selector(openInjector) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.openInjectorButton];
}

- (UIButton *)linkButtonWithTitle:(NSString *)title selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    [button setTitleColor:[UIColor colorWithRed:0.60 green:0.80 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor colorWithRed:0.14 green:0.16 blue:0.22 alpha:1.0];
    button.layer.cornerRadius = 10.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:0.35 alpha:1.0].CGColor;
    button.layer.masksToBounds = YES;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGRect bounds = self.view.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    
    CGFloat avatarSize = 128.0;
    CGFloat topInset = 120.0;
    self.avatarImageView.frame = CGRectMake((width - avatarSize) * 0.5, topInset, avatarSize, avatarSize);
    
    CGFloat labelHeight = 34.0;
    self.nicknameLabel.frame = CGRectMake(20.0, CGRectGetMaxY(self.avatarImageView.frame) + 20.0, width - 40.0, labelHeight);
    
    CGFloat linksTop = CGRectGetMaxY(self.nicknameLabel.frame) + 30.0;
    CGFloat horizontalPadding = 20.0;
    CGFloat totalWidth = width - horizontalPadding * 2.0;
    CGFloat spacing = 12.0;
    CGFloat linkButtonWidth = (totalWidth - spacing * 2.0) / 3.0;
    CGFloat linkButtonHeight = 40.0;
    
    self.xButton.frame = CGRectMake(horizontalPadding, linksTop, linkButtonWidth, linkButtonHeight);
    self.telegramButton.frame = CGRectMake(CGRectGetMaxX(self.xButton.frame) + spacing, linksTop, linkButtonWidth, linkButtonHeight);
    self.githubButton.frame = CGRectMake(CGRectGetMaxX(self.telegramButton.frame) + spacing, linksTop, linkButtonWidth, linkButtonHeight);
    
    CGFloat openButtonHeight = 52.0;
    CGFloat bottomPadding = 60.0;
    CGFloat openButtonWidth = width - 40.0;
    CGFloat openButtonX = 20.0;
    CGFloat openButtonY = CGRectGetHeight(bounds) - bottomPadding - openButtonHeight;
    self.openInjectorButton.frame = CGRectMake(openButtonX, openButtonY, openButtonWidth, openButtonHeight);
}

- (void)openURLString:(NSString *)urlString {
    if (urlString.length == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        return;
    }
    UIApplication *application = [UIApplication sharedApplication];
    [application openURL:url options:@{} completionHandler:nil];
}

- (void)openX {
    [self openURLString:kTitaniumXURLString];
}

- (void)openTelegram {
    [self openURLString:kTitaniumTelegramURLString];
}

- (void)openGitHub {
    [self openURLString:kTitaniumGitHubURLString];
}

- (void)openInjector {
    UINavigationController *navigationController = self.navigationController;
    if (!navigationController) {
        TitaniumRootViewController *root = [[TitaniumRootViewController alloc] init];
        [self presentViewController:root animated:YES completion:nil];
        return;
    }
    TitaniumRootViewController *rootViewController = [[TitaniumRootViewController alloc] init];
    [navigationController setViewControllers:@[rootViewController] animated:YES];
}

@end
