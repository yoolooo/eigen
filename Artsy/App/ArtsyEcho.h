#import <Aerodramus/Aerodramus.h>

@interface ArtsyEcho: Aerodramus

- (instancetype)init;
- (NSDictionary *)featuresMap;
- (BOOL)isFeatureEnabled:(NSString *)featureFlag;

@end
