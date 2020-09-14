#import "ARAppDelegate+Emission.h"

#import "ARUserManager.h"
#import "Artist.h"
#import "ArtsyEcho.h"
#import "Gene.h"
#import "ArtsyAPI+Following.h"
#import "ArtsyAPI+Notifications.h"
#import "ARDispatchManager.h"
#import "ARNetworkErrorManager.h"
#import "ARSwitchBoard+Eigen.h"
#import "ARTopMenuViewController.h"
#import "ARAppConstants.h"
#import "AROptions.h"
#import "ARMenuAwareViewController.h"
#import "ARAppNotificationsDelegate.h"
#import "ARAugmentedVIRSetupViewController.h"
#import "ARAugmentedRealityConfig.h"
#import "ARAugmentedFloorBasedVIRViewController.h"
#import "ARInternalMobileWebViewController.h"
#import "ARDefaults.h"
#import "ARNavigationController.h"
#import "ARTopMenuViewController.h"
#import "ARAppStatus.h"
#import "ARRouter.h"
#import "ARReactPackagerHost.h"
#import "AROptions.h"
#import "ARAuthValidator.h"

#import <react-native-config/ReactNativeConfig.h>
#import <Emission/AREmission.h>
#import <Emission/ARTemporaryAPIModule.h>
#import <Emission/ARSwitchBoardModule.h>
#import <Emission/AREventsModule.h>
#import <Emission/ARTakeCameraPhotoModule.h>
#import <Emission/ARRefineOptionsModule.h>
#import <Emission/ARArtistComponentViewController.h>
#import <Emission/ARHomeComponentViewController.h>
#import <Emission/ARMyProfileComponentViewController.h>
#import <Emission/ARInboxComponentViewController.h>
#import <Emission/ARFavoritesComponentViewController.h>
#import <Emission/ARSearchComponentViewController.h>
#import "AREigenMapContainerViewController.h"
#import <Emission/ARSalesComponentViewController.h>
#import <SDWebImage/SDImageCache.h>

// Fairs
#import <Emission/ARFairMoreInfoComponentViewController.h>
#import <Emission/ARFairArtistsComponentViewController.h>
#import <Emission/ARFairArtworksComponentViewController.h>
#import <Emission/ARFairExhibitorsComponentViewController.h>

// Shows
#import <Emission/ARShowComponentViewController.h>
#import <Emission/ARShowArtworksComponentViewController.h>
#import <Emission/ARShowArtistsComponentViewController.h>
#import <Emission/ARShowMoreInfoComponentViewController.h>

#import <React/RCTUtils.h>
#import <React/RCTDevSettings.h>
#import <objc/runtime.h>
#import <ARAnalytics/ARAnalytics.h>
#import "ARAdminNetworkModel.h"
#import "Artsy-Swift.h"

@import Darwin.POSIX.sys.utsname;

static void
FollowRequestSuccess(RCTResponseSenderBlock block, BOOL following)
{
    block(@[ [NSNull null], @(following) ]);
}

static void
FollowRequestFailure(RCTResponseSenderBlock block, BOOL following, NSError *error)
{
    ar_dispatch_main_queue(^{
        [ARNetworkErrorManager presentActiveError:error withMessage:@"Failed to follow artist."];
    });
    block(@[ RCTJSErrorFromNSError(error), @(following) ]);
}

@implementation ARAppDelegate (Emission)

- (void)setupEmission;
{
    if ([AROptions boolForOption:AROptionsStagingReactEnv]) {
        NSURL *packagerURL = [ARAdminNetworkModel fileURLForLatestCommitJavaScript];
        [self setupSharedEmissionWithPackagerURL:packagerURL];

    } else if ([AROptions boolForOption:AROptionsDevReactEnv]) {
        NSString *bundleUrlString = [NSString stringWithFormat:@"http://%@:8081/index.ios.bundle?platform=ios&dev=true", [ARReactPackagerHost hostname]];
        NSURL *packagerURL = [NSURL URLWithString:bundleUrlString];
        [self setupSharedEmissionWithPackagerURL:packagerURL];

    } else {
        // The normal flow for users
        [self setupSharedEmissionWithPackagerURL:nil];
    }
}

/*
deviceId taken from https://github.com/react-native-community/react-native-device-info/blob/d08f7f6db0407de5dc5252ebf2aa2ec58bd78dfc/ios/RNDeviceInfo/RNDeviceInfo.m
The MIT License (MIT)
Copyright (c) 2015 Rebecca Hughes
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
- (NSString *)deviceId;
{
  struct utsname systemInfo;
  uname(&systemInfo);
  NSString* deviceId = [NSString stringWithCString:systemInfo.machine
                                          encoding:NSUTF8StringEncoding];
  if ([deviceId isEqualToString:@"i386"] || [deviceId isEqualToString:@"x86_64"] ) {
    deviceId = [NSString stringWithFormat:@"%s", getenv("SIMULATOR_MODEL_IDENTIFIER")];
  }
  return deviceId;
}

- (void)setupSharedEmissionWithPackagerURL:(NSURL *)packagerURL;
{
    NSString *userID = [[[ARUserManager sharedManager] currentUser] userID];
    NSString *authenticationToken = [[ARUserManager sharedManager] userAuthenticationToken];

    NSString *sentryDSN = nil;
    if (![ARAppStatus isDev]) {
        sentryDSN = [ReactNativeConfig envFor:[ARAppStatus isBeta] ? @"SEGMENT_STAGING_DSN" : @"SEGMENT_PRODUCTION_DSN"];
    }

    // Don't let the JS raise an error about Sentry's DSN being a stub on OSS builds
    if ([sentryDSN isEqualToString:@"-"]) {
        sentryDSN = nil;
    }

    NSString *gravity = [[ARRouter baseApiURL] absoluteString];
    NSString *metaphysics = [ARRouter baseMetaphysicsApiURLString];

    NSString *liveAuctionsURL = [[[ARSwitchBoard sharedInstance] liveAuctionsURL] absoluteString];

    // Grab echo features and make that the base of all options
    ArtsyEcho *aero = [[ArtsyEcho alloc] init];
    [aero setup];

    NSString *stripePublishableKey;
    if ([AROptions boolForOption:ARUseStagingDefault]) {
        stripePublishableKey = [aero.messages[@"StripeStagingPublishableKey"] content];
    } else {
        stripePublishableKey = [aero.messages[@"StripeProductionPublishableKey"] content];
    }

    NSString *env;
    if ([AROptions boolForOption:ARUseStagingDefault]) {
      env = @"staging";
    } else {
      env = @"production";
    }

    NSInteger launchCount = [[NSUserDefaults standardUserDefaults] integerForKey:ARAnalyticsAppUsageCountProperty];
    AROnboardingUserProgressStage onboardingState = [[NSUserDefaults standardUserDefaults] integerForKey:AROnboardingUserProgressionStage];

    NSDictionary *options = [self getOptionsForEmission:[aero featuresMap] labOptions:[AROptions labOptionsMap]];

    AREmission *emission = [[AREmission alloc] initWithState: @{
        [ARStateKey userID]: (userID ?: [NSNull null]),
        [ARStateKey authenticationToken]: (authenticationToken ?: [NSNull null]),
        [ARStateKey launchCount]: @(launchCount),
        [ARStateKey onboardingState]: onboardingState == AROnboardingStageDefault ? @"none" : onboardingState == AROnboardingStageOnboarded ? @"complete" : @"incomplete",
        [ARStateKey sentryDSN]: (sentryDSN ?: [NSNull null]),
        [ARStateKey stripePublishableKey]: (stripePublishableKey ?: [NSNull null]),
        [ARStateKey gravityURL]: gravity,
        [ARStateKey metaphysicsURL]: metaphysics,
        [ARStateKey predictionURL]: liveAuctionsURL,
        [ARStateKey webURL]: [[ARRouter baseWebURL] absoluteString],
        [ARStateKey userAgent]: ARRouter.userAgent,
        [ARStateKey env]: env,
        [ARStateKey options]: options,
        [ARStateKey deviceId]: self.deviceId
    } packagerURL:packagerURL];

    // Disable default React Native dev menu shake motion handler
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        RCTSwapInstanceMethods([UIWindow class], @selector(RCT_motionEnded:withEvent:), @selector(motionEnded:withEvent:));
    });

    [AREmission setSharedInstance:emission];

#pragma mark - Native Module: Push Notification Permissions

    emission.APIModule.notificationPermissionPrompter = ^() {
        ARAppNotificationsDelegate *delegate = [[JSDecoupledAppDelegate sharedAppDelegate] remoteNotificationsDelegate];
        [delegate registerForDeviceNotificationsWithApple];
    };

#pragma mark - Native Module: Follow status

    emission.APIModule.notificationReadStatusAssigner = ^(RCTResponseSenderBlock block) {
        [ArtsyAPI markUserNotificationsReadWithSuccess:^(id response) {
            block(@[[NSNull null]]);
        } failure:^(NSError *error) {
            block(@[ RCTJSErrorFromNSError(error)]);
        }];
    };

    emission.APIModule.augmentedRealityVIRPresenter = ^(NSString *imgUrl, CGFloat widthIn, CGFloat heightIn, NSString *artworkSlug, NSString *artworkId) {
        // A bit weird, eh? Normally CGSize stores width+height in terms of pixels, but this one is stored in inches instead.
        CGSize size = CGSizeMake(widthIn, heightIn);
        NSURL *url = [NSURL URLWithString:imgUrl];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showARVIRWithImageURL:url size:size artworkSlug:artworkSlug artworkID:artworkId defaults:[NSUserDefaults standardUserDefaults]];
        });
    };

#pragma mark - Native Module: Refine filter

    emission.refineModule.triggerRefine = ^(NSDictionary *_Nonnull initial, NSDictionary *_Nonnull current, UIViewController *_Nonnull controller, RCTPromiseResolveBlock resolve, RCTPromiseRejectBlock reject) {
        [RefineSwiftCoordinator showRefineSettingForGeneSettings:controller
                                                         initial:initial
                                                         current:current
                                                      completion:^(NSDictionary<NSString *,id> * _Nullable newRefineSettings) {
            resolve(newRefineSettings);
        }];
    };

# pragma mark - Native Module: URL resolver

        emission.APIModule.urlResolver = ^(NSString *path, RCTPromiseResolveBlock resolve, RCTPromiseRejectBlock reject) {
            NSURL *resolvedURL = [[ARSwitchBoard sharedInstance] resolveRelativeUrl:path];
            if (resolvedURL) {
                resolve(resolvedURL.absoluteString);
            } else {
                NSString *errorMessage = [NSString stringWithFormat:@"Could not resolve relative route in eigen %@", path];
                NSError *error = [NSError errorWithDomain:@"net.artsy.artsy" code:404 userInfo:@{ @"text": errorMessage }];
                reject(@"404", errorMessage, error);
            }
        };

#pragma mark - Native Module: SwitchBoard

    emission.switchBoardModule.updateShouldHideBackButton = ^(BOOL shouldHide) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[ARTopMenuViewController sharedController] rootNavigationController] showBackButton:!shouldHide animated:YES];
        });
    };

    emission.switchBoardModule.presentNavigationViewController = ^(UIViewController *_fromViewController,
                                                                   NSString *_Nonnull route) {
        UIViewController *viewController = [[ARSwitchBoard sharedInstance] loadPath:route];
        [[ARTopMenuViewController sharedController] pushViewController:viewController];
    };

    emission.switchBoardModule.presentModalViewController = ^(UIViewController *_fromViewController,
                                                              NSString *_Nonnull route) {
        UIViewController *viewController = [[ARSwitchBoard sharedInstance] loadPath:route];
        UIViewController *targetViewController = [ARTopMenuViewController sharedController];

        // We need to accomodate presenting a modal _on top_ of an existing modal view controller. Consignments
        // and BidFlow are presented modally, and we want to let them present modal view controllers on top of themselves.
        if (targetViewController.presentedViewController) {
            targetViewController = targetViewController.presentedViewController;
        }

        // When presenting modally, view controller generally have to be wrapped in a navigation controller
        // so the user can hit the close button. Consignments is the exception, and it has its own close button.
        if (!([viewController isKindOfClass:[UINavigationController class]] || [viewController isKindOfClass:[LiveAuctionViewController class]])) {
            viewController = [[ARSerifNavigationViewController alloc] initWithRootViewController:viewController];
        }
        // Explanation for this behaviour is described in ARTopMenuViewController's
        // pushViewController:animated: method. Once that is removed, we can remove this.
        if ([UIDevice isPhone]) {
            viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        } else {
            // BNMO goes through this code path instead of the one in ARTopMenuViewController.
            if ([viewController isKindOfClass:ARSerifNavigationViewController.class] &&
                [[[(ARInternalMobileWebViewController *)[(ARSerifNavigationViewController *)viewController topViewController] initialURL] absoluteString] containsString:@"/orders/"]) {
                viewController.modalPresentationStyle = UIModalPresentationFormSheet;
            }
        }

        [targetViewController presentViewController:viewController
                                           animated:ARPerformWorkAsynchronously
                                         completion:nil];
    };

    emission.APIModule.authValidationChecker = ^() {
        if ([User currentUser]) {
            [ARAuthValidator validateAuthCredentialsAreCorrect];
        };
    };


#pragma mark - Native Module: Events/Analytics
    emission.eventsModule.eventOccurred = ^(NSDictionary *_Nonnull info) {
        NSMutableDictionary *properties = [info mutableCopy];
        if (info[@"action_type"] ) {
            // Track event
            [properties removeObjectForKey:@"action_type"];
            [ARAnalytics event:info[@"action_type"] withProperties:[properties copy]];
        } else if (info[@"action"]) {
            // Track event
            [ARAnalytics event:info[@"action"] withProperties:[properties copy]];
        } else {
            // Screen event
            [properties removeObjectForKey:@"context_screen"];
            [ARAnalytics pageView:info[@"context_screen"]  withProperties:[properties copy]];
        }
    };

}

- (void)updateEmissionOptions
{
    ArtsyEcho *aero = [[ArtsyEcho alloc] init];
    [aero setup];
    [[AREmission sharedInstance] updateState:@{[ARStateKey options]: [self getOptionsForEmission:[aero featuresMap] labOptions:[AROptions labOptionsMap]]}];
}

- (NSDictionary *)getOptionsForEmission:(NSDictionary *)echoFeatures labOptions:(NSDictionary *)labOptions
{
    // Set up all the difference places we get settings to merge into one place
    NSMutableDictionary *options = [NSMutableDictionary dictionary];

    [options addEntriesFromDictionary:echoFeatures];

    // Lab options come last (as they are admin/dev controlled, giving them a chance to override)
    [options addEntriesFromDictionary:labOptions];

    options[@"AROptionsPriceTransparency"] = @([options[@"AROptionsPriceTransparency"] boolValue] || [labOptions[AROptionsPriceTransparency] boolValue]);
    options[@"AROptionsArtistSeries"] = @([options[@"AROptionsArtistSeries"] boolValue] || [labOptions[AROptionsArtistSeries] boolValue]);

    return options;
}

#pragma mark - AR View-in-Room Experience

- (void)showARVIRWithImageURL:(NSURL *)url size:(CGSize)size artworkSlug:(NSString *)artworkSlug artworkID:(NSString *)artworkId defaults:(NSUserDefaults *)userDefauls
{
    BOOL supportsARVIR = [ARAugmentedVIRSetupViewController canOpenARView];
    if (supportsARVIR) {
        [ARAugmentedVIRSetupViewController canSkipARSetup:userDefauls callback:^(bool allowedAccess) {
            // The image can come from either the SDWebImage cache or from the internet.
            // In either case, this block gets called with that image.
            void (^gotImageBlock)(UIImage *image) = ^void(UIImage *image) {
                ARAugmentedRealityConfig *config = [[ARAugmentedRealityConfig alloc] initWithImage:image size:size];
                config.artworkID = artworkId;
                config.artworkSlug = artworkSlug;
                config.floorBasedVIR = YES;
                config.debugMode =  [AROptions boolForOption:AROptionsDebugARVIR];

                if (allowedAccess) {
                    id viewInRoomVC = [[ARAugmentedFloorBasedVIRViewController alloc] initWithConfig:config];
                    [[ARTopMenuViewController sharedController] pushViewController:viewInRoomVC animated:ARPerformWorkAsynchronously];
                } else {
                    ArtsyEcho *echo = [[ArtsyEcho alloc] init];
                    [echo setup];

                    Message *setupURL = echo.messages[@"ARVIRVideo"];

                    NSURL *movieURL = setupURL.content.length ? [NSURL URLWithString:setupURL.content] : nil;
                    ARAugmentedVIRSetupViewController *setupVC = [[ARAugmentedVIRSetupViewController alloc] initWithMovieURL:movieURL config:config];
                    [[ARTopMenuViewController sharedController] pushViewController:setupVC animated:ARPerformWorkAsynchronously];
                }
            };

            // Try to get a cached image from SDWebImage. This will succeed under normal runtime conditions.
            // But in case there is severe RAM or disk pressure, the image might already be evicted from the cache.
            // In the rare occurence that a cache lookup fails, download the image into the cache first.
            SDWebImageManager *manager = [SDWebImageManager sharedManager];
            if ([manager cachedImageExistsForURL:url]) {
                NSString *key = [manager cacheKeyForURL:url];
                UIImage *image = [manager.imageCache imageFromDiskCacheForKey:key];
                // TODO: Verify that this _does_ actually get a cache hit most often.
                gotImageBlock(image);
            } else {
                [manager downloadImageWithURL:url options:(SDWebImageHighPriority) progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                    if (finished && !error) {
                        gotImageBlock(image);
                    } else {
                        // Errors are unlikely to happen, but we should handle them just in case.
                        // This represents both an image cache-miss _and_ a failure to
                        // download the image on its own. Very unlikely.
                        NSLog(@"[ARAppDelegate+Emission] Couldn't download image for AR VIR (%@, %@): %@", artworkSlug, imageURL, error);
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Failed to Load Image" message:@"We could not download the image to present in View-in-Room." preferredStyle:UIAlertControllerStyleAlert];
                        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
                        [alert addAction:defaultAction];
                        [[ARTopMenuViewController sharedController] presentViewController:alert animated:YES completion:nil];
                    }
                }];
            }
        }];
    } else {
        // nop: we don't expect Emission to call this on non-AR devices.
    }
}

@end

/// Utilities to extend a view controller class to conform to ARMenuAwareViewController, with an
/// implementation of menuAwareScrollView that uses UIViewController callbacks to work. This is
/// helpful for Emission view controllers.
#pragma mark - ARMenuAwareViewController additions

static UIScrollView *
FindFirstScrollView(UIView *view)
{
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:UIScrollView.class]) {
            return (UIScrollView *)subview;
        }
    }
    for (UIView *subview in view.subviews) {
        UIScrollView *result = FindFirstScrollView(subview);
        if (result) return result;
    }
    return nil;
}
static char menuAwareScrollViewKey;

/// Macro to extend view controller classes to conform to ARMenuAwareViewController.
#define MakeMenuAware(ControllerClass) @interface ControllerClass (ARMenuAwareViewController) <ARMenuAwareViewController>\
@end\
@implementation ControllerClass (ARMenuAwareViewController)\
- (void)viewDidLayoutSubviews {\
    [super viewDidLayoutSubviews];\
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{\
        self.menuAwareScrollView = FindFirstScrollView(self.view);\
        NSLog(@"Making menu-aware scroll view: %@", self.menuAwareScrollView);\
    });\
}\
- (void)setMenuAwareScrollView:(UIScrollView *)scrollView {\
    if (scrollView != self.menuAwareScrollView) {\
        [self willChangeValueForKey:@"menuAwareScrollView"];\
        objc_setAssociatedObject(self, &menuAwareScrollViewKey, scrollView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);\
        [self didChangeValueForKey:@"menuAwareScrollView"];\
    }\
}\
- (UIScrollView *)menuAwareScrollView {\
    return objc_getAssociatedObject(self, &menuAwareScrollViewKey);\
}\
@end

MakeMenuAware(ARArtistComponentViewController)

// Make Shows menu-aware
MakeMenuAware(ARShowComponentViewController)
MakeMenuAware(ARShowArtworksComponentViewController)
MakeMenuAware(ARShowArtistsComponentViewController)
MakeMenuAware(ARShowMoreInfoComponentViewController)

// Make Fairs menu-aware
MakeMenuAware(ARFairMoreInfoComponentViewController)
MakeMenuAware(ARFairArtistsComponentViewController)
MakeMenuAware(ARFairArtworksComponentViewController)
MakeMenuAware(ARFairExhibitorsComponentViewController)
