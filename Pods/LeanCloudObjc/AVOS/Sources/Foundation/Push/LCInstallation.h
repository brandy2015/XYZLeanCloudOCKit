//
//  LCInstallation.h
//  LeanCloud
//

#import <Foundation/Foundation.h>
#import "LCQuery.h"

/// LeanCloud installation type.
@interface LCInstallation : LCObject

/// The badge for the installation.
@property (nonatomic, assign) NSInteger badge;

/// The timeZone for the installation.
@property (nonatomic, copy, nullable) NSString *timeZone;

/// The device type for the installation.
@property (nonatomic, copy, nullable) NSString *deviceType;

/// The installation ID for the installation.
@property (nonatomic, copy, nullable) NSString *installationId;

/// The device profile for the installation.
@property (nonatomic, copy, nullable) NSString *deviceProfile;

/// The APNs topic, typically is the bundle ID for the App.
@property (nonatomic, copy, nullable) NSString *apnsTopic;

/// The channels for the installation.
@property (nonatomic, strong, nullable) NSArray *channels;

/// The hex string of the APNs device token.
@property (nonatomic, copy, readonly, nullable) NSString *deviceToken;

/// The team id of the apple developer account.
@property (nonatomic, copy, readonly, nullable) NSString *apnsTeamId;

NS_ASSUME_NONNULL_BEGIN

/// Query for installation
+ (LCQuery *)query;

/// Default installation instance.
+ (instancetype)defaultInstallation;

/// For compatibility, same as the `defaultInstallation`.
+ (instancetype)currentInstallation;

/// Clear default/current installation's Persistent Cache.
+ (void)clearPersistentCache;

/// Create a new installation instance.
+ (instancetype)installation;

/// Set device token.
/// @param deviceTokenData The device token.
/// @param teamId The team id of the apple developer account.
- (void)setDeviceTokenFromData:(NSData *)deviceTokenData
                        teamId:(NSString *)teamId;

/// Set hex string of the device token.
/// @param deviceTokenString The hex string of the device token.
/// @param teamId The team id of the apple developer account.
- (void)setDeviceTokenHexString:(NSString *)deviceTokenString
                         teamId:(NSString *)teamId;

NS_ASSUME_NONNULL_END

@end
