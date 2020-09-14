#import "ARAppNotificationsDelegate.h"

#import "ArtsyAPI+Notifications.h"
#import "ArtsyAPI+DeviceTokens.h"
#import "ArtsyAPI+CurrentUserFunctions.h"

#import "ARAppDelegate.h"
#import "ARAppConstants.h"
#import "ARAnalyticsConstants.h"
#import "UIApplicationStateEnum.h"
#import "ARNotificationView.h"
#import "ARSwitchBoard.h"
#import "ARTopMenuViewController.h"
#import "ARSerifNavigationViewController.h"
#import "ARLogger.h"
#import "ARDefaults.h"
#import "AROptions.h"
#import "ARDispatchManager.h"

#import <Emission/ARConversationComponentViewController.h>
#import <Emission/ARBidFlowViewController.h>
#import <Emission/AREmission.h>
#import <Emission/ARNotificationsManager.h>
#import <ARAnalytics/ARAnalytics.h>
#import <UserNotifications/UserNotifications.h>
#import <SailthruMobile/SailthruMobile.h>

@implementation ARAppNotificationsDelegate

#pragma mark -
#pragma mark Local Push Notification Alerts

- (void)registerForDeviceNotificationsWithContext:(ARAppNotificationsRequestContext)requestContext
{
    self.requestContext = requestContext;

    if (![AROptions boolForOption:ARPushNotificationsSettingsPromptSeen] &&
        [AROptions boolForOption:ARPushNotificationsAppleDialogueRejected]) {
        // if you've rejected Apple's push notification and you've not seen our prompt to send you to settings
        // lets show you a prompt to go to settings
        [self displayPushNotificationSettingsPrompt];
    } else if (![AROptions boolForOption:ARPushNotificationsAppleDialogueSeen] && [self shouldPresentPushNotificationAgain]) {
        // As long as you've not seen Apple's dialogue already, we will show you our pre-prompt.
        [self displayPushNotificationLocalRequestPrompt];
    }
}

- (void)displayPushNotificationLocalRequestPrompt
{
    UIAlertController *alert = [self pushNotificationPromptAlertController];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
                                                              [self registerUserInterest];
                                                          }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Don't Allow" style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                              [self registerUserDisinterest];
                                                         }];
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];

    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}


- (void)displayPushNotificationSettingsPrompt
{
    UIAlertController *alert = [self pushNotificationPromptAlertController];

    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:@"Go to Settings" style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
                                                              [self presentSettings];
                                                           }];
    [alert addAction:settingsAction];
    alert.preferredAction = settingsAction;
    [alert addAction:[UIAlertAction actionWithTitle:@"No thanks" style:UIAlertActionStyleCancel handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];

    [AROptions setBool:YES forOption:ARPushNotificationsSettingsPromptSeen];
}

- (void)registerUserInterest
{
    NSString *analyticsContext = @"";
    if (self.requestContext == ARAppNotificationsRequestContextArtistFollow) {
        analyticsContext = @"ArtistFollow";
    } else if (self.requestContext == ARAppNotificationsRequestContextOnboarding) {
        analyticsContext = @"Onboarding";
    } else if (self.requestContext == ARAppNotificationsRequestContextLaunch) {
        analyticsContext = @"Launch";
    }

    analyticsContext = [@[@"PushNotification", analyticsContext] componentsJoinedByString:@""];

    [ARAnalytics event:ARAnalyticsPushNotificationLocal withProperties:@{
        @"action_type" : @"Tap",
        @"action_name" : @"Yes",
        @"context_screen" : analyticsContext,
    }];
    [self registerForDeviceNotificationsWithApple];
}

- (void)registerUserDisinterest
{
    // Well, in that case we'll store today's date
    // and prompt the user in a week's time, if they perform certain actions (e.g. follow an artist)

    NSString *analyticsContext = @"";
    if (self.requestContext == ARAppNotificationsRequestContextArtistFollow) {
        analyticsContext = @"ArtistFollow";
    } else if (self.requestContext == ARAppNotificationsRequestContextOnboarding) {
        analyticsContext = @"Onboarding";
    } else if (self.requestContext == ARAppNotificationsRequestContextLaunch) {
        analyticsContext = @"Launch";
    }

    analyticsContext = [@[@"PushNotification", analyticsContext] componentsJoinedByString:@""];

    [ARAnalytics event:ARAnalyticsPushNotificationLocal withProperties:@{
        @"action_type" : @"Tap",
        @"action_name" : @"Cancel",
        @"context_screen"  : analyticsContext
    }];

    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:ARPushNotificationsDialogueLastSeenDate];
}

- (void)presentSettings
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
}

- (UIAlertController *)pushNotificationPromptAlertController
{
    return [UIAlertController alertControllerWithTitle:@"Artsy Would Like to Send You Notifications"
                                               message:@"Turn on notifications to get important updates about artists you follow."
                                        preferredStyle:UIAlertControllerStyleAlert];
}

- (BOOL)shouldPresentPushNotificationAgain
{
    // we don't want to ask too often
    // currently, we make sure at least a week has passed by since you last saw the dialogue

    NSDate *lastSeenPushNotification = [[NSUserDefaults standardUserDefaults] objectForKey:ARPushNotificationsDialogueLastSeenDate];

    if (lastSeenPushNotification) {
        NSDate *currentDate = [NSDate date];

        NSTimeInterval timePassed = [currentDate timeIntervalSinceDate:lastSeenPushNotification];
        NSTimeInterval weekInSeconds = (60 * 60 * 24 * 7);

        return timePassed >= weekInSeconds;
    } else {
        // if you've never seen one before, we'll show you ;)
        return YES;
    }
}

#pragma mark -
#pragma mark Push Notification Register

- (void)registerForDeviceNotificationsWithApple
{
    ARActionLog(@"Registering with Apple for remote notifications.");
    UNAuthorizationOptions authOptions = (UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert);
    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) {
        NSString *grantedString = granted ? @"YES" : @"NO";
        [[[ARAppDelegate sharedInstance] sailThru] syncNotificationSettings];
        [ARAnalytics event:ARAnalyticsPushNotificationsRequested withProperties:@{@"granted" : grantedString}];
    }];

    [[UIApplication sharedApplication] registerForRemoteNotifications];
    [AROptions setBool:YES forOption:ARPushNotificationsAppleDialogueSeen];
}

#pragma mark -
#pragma mark Push Notification Delegate

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSString *analyticsContext = @"";
    if (self.requestContext == ARAppNotificationsRequestContextArtistFollow) {
        analyticsContext = @"ArtistFollow";
    } else if (self.requestContext == ARAppNotificationsRequestContextOnboarding) {
        analyticsContext = @"Onboarding";
    } else if (self.requestContext == ARAppNotificationsRequestContextLaunch) {
        analyticsContext = @"Launch";
    }
    analyticsContext = [@[@"PushNotification", analyticsContext] componentsJoinedByString:@""];
    [ARAnalytics event:ARAnalyticsPushNotificationApple withProperties:@{
        @"action_type" : @"Tap",
        @"action_name" : @"Cancel",
        @"context_screen"  : analyticsContext
    }];
    [AROptions setBool:YES forOption:ARPushNotificationsAppleDialogueRejected];
#if (TARGET_IPHONE_SIMULATOR == 0)
    ARErrorLog(@"Error registering for remote notifications: %@", error.localizedDescription);
#endif
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceTokenData
{
    NSString *analyticsContext = @"";
    if (self.requestContext == ARAppNotificationsRequestContextArtistFollow) {
        analyticsContext = @"ArtistFollow";
    } else if (self.requestContext == ARAppNotificationsRequestContextOnboarding) {
        analyticsContext = @"Onboarding";
    } else if (self.requestContext == ARAppNotificationsRequestContextLaunch) {
        analyticsContext = @"Launch";
    }
    analyticsContext = [@[@"PushNotification", analyticsContext] componentsJoinedByString:@""];

    [ARAnalytics event:ARAnalyticsPushNotificationApple withProperties:@{
        @"action_type" : @"Tap",
        @"action_name" : @"Yes",
        @"context_screen"  : analyticsContext
    }];

    // http://stackoverflow.com/questions/9372815/how-can-i-convert-my-device-token-nsdata-into-an-nsstring
    const unsigned *tokenBytes = [deviceTokenData bytes];
    NSString *deviceToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                                                       ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                                                       ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                                                       ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];

    ARActionLog(@"Got device notification token: %@", deviceToken);

    // Save device token purely for the admin settings view.
    [[NSUserDefaults standardUserDefaults] setValue:deviceToken forKey:ARAPNSDeviceTokenKey];
    
    [[[ARAppDelegate sharedInstance] sailThru] setDeviceTokenInBackground:deviceTokenData];

// We only record device tokens on the Artsy service in case of Beta or App Store builds.
#ifndef DEBUG
    [ARAnalytics setUserProperty:ARAnalyticsEnabledNotificationsProperty toValue:@"true"];

    // Apple says to always save the device token, as it may change. In addition, since we allow a device to register
    // for notifications even if the user has not signed-in, we must be sure to always update this to ensure the Artsy
    // service always has an up-to-date record of devices and associated users.
    //
    // https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/IPhoneOSClientImp.html#//apple_ref/doc/uid/TP40008194-CH103-SW2
    [ArtsyAPI setAPNTokenForCurrentDevice:deviceToken success:^(id response) {
        ARActionLog(@"Pushed device token to Artsy's servers");
    } failure:^(NSError *error) {
        ARErrorLog(@"Couldn't push the device token to Artsy, error: %@", error.localizedDescription);
    }];
#endif
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler;
{
    [self applicationDidReceiveRemoteNotification:userInfo inApplicationState:application.applicationState];
    [[[ARAppDelegate sharedInstance] sailThru] handleNotificationPayload:userInfo];
    handler(UIBackgroundFetchResultNoData);
}

- (void)applicationDidReceiveRemoteNotification:(NSDictionary *)userInfo inApplicationState:(UIApplicationState)applicationState;
{
    NSString *uiApplicationState = [UIApplicationStateEnum toString:applicationState];
    ARActionLog(@"Incoming notification in the %@ application state: %@", uiApplicationState, userInfo);

    NSMutableDictionary *notificationInfo = [[NSMutableDictionary alloc] initWithDictionary:userInfo];
    [notificationInfo setObject:uiApplicationState forKey:@"UIApplicationState"];

    NSString *url = userInfo[@"url"];
    id message = userInfo[@"aps"][@"alert"] ?: url;
    BOOL isConversation = url && [[[NSURL URLWithString:url] path] hasPrefix:@"/conversation/"];

    if (isConversation) {
        [[[AREmission sharedInstance] notificationsManagerModule] notificationReceived];
    }

    if (applicationState == UIApplicationStateBackground) {
        // A notification was received while the app is in the background.
        [self receivedNotification:notificationInfo];

    } else {
        
        if (applicationState == UIApplicationStateActive) {
            // A notification was received while the app was already active, so we show our own notification view.
            [self receivedNotification:notificationInfo];

//            UIViewController *controller = [self getGlobalTopViewController];
//
//            NSString *conversationID = [notificationInfo[@"conversation_id"] stringValue];
//            NSString *saleID = notificationInfo[@"sale_slug"];
//            NSString *artworkID = notificationInfo[@"artwork_slug"];
//            NSString *action = notificationInfo[@"action"];
//
//            // We check whether a notification coming through has this as its action
//            NSString *outbidNotificationLabel = @"bid outbid";

//            ARConversationComponentViewController *conversationVC = (id)controller;
//            ARBidFlowViewController *bidFlowVC;
//            ARSerifNavigationViewController *serifNavigationController = (id)[controller presentedViewController];
//            if ([serifNavigationController isKindOfClass:[ARSerifNavigationViewController class]]) {
//                bidFlowVC = [[serifNavigationController viewControllers] firstObject];
//            }
//
//            if ([controller isKindOfClass:ARConversationComponentViewController.class] && [conversationVC.conversationID isEqualToString:conversationID]) {
//                [[NSNotificationCenter defaultCenter] postNotificationName:@"notification_received" object:notificationInfo];
//            } else if ([bidFlowVC isKindOfClass:ARBidFlowViewController.class] && [action isEqualToString:outbidNotificationLabel] && [bidFlowVC.artworkID isEqualToString:artworkID] && [bidFlowVC.saleID isEqualToString:saleID]) {
//                // NO-OP, so that we don't show notifications about bidding activity currently on screen
//            } else {
                NSString *title = [message isKindOfClass:[NSString class]] ? message : message[@"title"];
                [ARNotificationView showNoticeInView:[self findVisibleWindow]
                                               title:title
                                            response:^{
                                                [self tappedNotification:notificationInfo url:url];
                                            }];
//            }

        } else if (applicationState == UIApplicationStateInactive) {
            // The user tapped a notification while the app was in background.
            [self tappedNotification:notificationInfo url:url];
        }
    }
}

- (UIViewController *)getGlobalTopViewController
{
    return [[[[ARTopMenuViewController sharedController] rootNavigationController] viewControllers] lastObject];
}

- (void)receivedNotification:(NSDictionary *)notificationInfo;
{
    [ARAnalytics event:ARAnalyticsNotificationReceived withProperties:notificationInfo];
}

- (void)tappedNotification:(NSDictionary *)notificationInfo url:(NSString *)url;
{
    [ARAnalytics event:ARAnalyticsNotificationTapped withProperties:notificationInfo];

    [[[AREmission sharedInstance] notificationsManagerModule] requestNavigation:url];
}

- (UIWindow *)findVisibleWindow
{
    NSArray *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow *window in [windows reverseObjectEnumerator]) {
        if (!window.hidden) {
            return window;
        }
    }
    return nil;
}

@end
