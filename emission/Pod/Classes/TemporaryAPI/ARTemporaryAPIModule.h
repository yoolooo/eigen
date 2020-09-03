#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

typedef void(^ARHandoffRegisterer)(NSDictionary *entity);

typedef void(^ARNotificationReadStatusAssigner)(RCTResponseSenderBlock block);

typedef void(^ARNotificationPermissionsPrompter)();

typedef void(^ARAuthValidationChecker)();

typedef void(^ARAugmentedRealityVIRPresenter)(NSString *imgUrl, CGFloat widthIn, CGFloat heightIn, NSString *artworkSlug, NSString *artworkId);

/// While metaphysics is read-only, we need to rely on Eigen's
/// v1 API access to get/set these bits of information.

@interface ARTemporaryAPIModule : NSObject <RCTBridgeModule>

@property (nonatomic, copy, readwrite) ARHandoffRegisterer handoffRegisterer;

@property (nonatomic, copy, readwrite) ARNotificationPermissionsPrompter notificationPermissionPrompter;

@property (nonatomic, copy, readwrite) ARNotificationReadStatusAssigner notificationReadStatusAssigner;

@property (nonatomic, copy, readwrite) ARAugmentedRealityVIRPresenter augmentedRealityVIRPresenter;

@property (nonatomic, copy, readwrite) ARAuthValidationChecker authValidationChecker;

@end
