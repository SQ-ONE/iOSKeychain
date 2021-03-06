//
//  Keychain.m
//  Keychain
//
//  Created by Shashank Survase on 03/07/22.
//

#import <Security/Security.h>
#import "Keychain.h"

#if TARGET_OS_IOS
#import <LocalAuthentication/LAContext.h>
#endif

@implementation Keychain

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_queue_create("io.unitor.KeychainQueue", DISPATCH_QUEUE_SERIAL);
}

NSString *messageForError(NSError *error)
{
    switch (error.code) {
        case errSecUnimplemented:
            return @"Function or operation not implemented.";
        case errSecIO:
            return @"I/O error.";
        case errSecOpWr:
            return @"File already open with write permission.";
        case errSecParam:
            return @"One or more parameters passed to a function where not valid.";
        case errSecAllocate:
            return @"Failed to allocate memory.";
        case errSecUserCanceled:
            return @"User cancelled the operation.";
        case errSecBadReq:
            return @"Bad parameter or invalid state of operation.";
        case errSecNotAvailable:
              return @"No keychain is available. You may need to restart your computer.";
        case errSecDuplicateItem:
            return @"The specified item already exists in the keychain.";
        case errSecItemNotFound:
            return @"The specified item could not be found in the keychain.";
        case errSecInteractionNotAllowed:
            return @"User interaction is not allowed.";
        case errSecDecode:
            return @"Unable to decode the provided data.";
        case errSecAuthFailed:
          return @"The user name or passphrase you entered is not correct.";
        case errSecMissingEntitlement:
          return @"Internal error when a required entitlement isn't present.";
        default:
          return error.localizedDescription;
    }
}

NSString *codeForError(NSError *error)
{
    return [NSString stringWithFormat:@"%li", (long)error.code];
}

NSString *rejectWithError(NSError *error)
{
    return messageForError(error);
}

CFStringRef accessibleValue(NSDictionary *options)
{
    if (options && options[@"accessible"] != nil) {
        NSDictionary *keyMap = @ {
            @"AccessibleWhenUnlocked": (__bridge NSString *)kSecAttrAccessibleWhenUnlocked,
            @"AccessibleAfterFirstUnlock": (__bridge NSString *)kSecAttrAccessibleAfterFirstUnlock,
            @"AccessibleWhenPasscodeSetThisDeviceOnly": (__bridge NSString *)kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            @"AccessibleWhenUnlockedThisDeviceOnly": (__bridge NSString *)kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            @"AccessibleAfterFirstUnlockThisDeviceOnly": (__bridge NSString *)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        };
        NSString *result = keyMap[options[@"accessible"]];
        if (result) {
            return (__bridge CFStringRef)result;
        }
    }
    return kSecAttrAccessibleAfterFirstUnlock;
}

NSString *serviceValue(NSDictionary *options)
{
    if (options && options[@"service"] != nil) {
        return options[@"service"];
    }
    return [[NSBundle mainBundle] bundleIdentifier];
}

NSString *accessGroupValue(NSDictionary *options)
{
    if(options && options[@"accessGroup"] != nil) {
        return options[@"accessGroup"];
    }
    return nil;
}

NSString *authenticationPromptValue(NSDictionary *options)
{
    if(options && options[@"authenticationPrompt"] != nil && options[@"authenticationPrompt"][@"title"]) {
        return options[@"authenticationPrompt"][@"title"];
    }
    return nil;
}

#pragma mark - Proposed functionality - Helpers

#define kAuthenticationType @"authenticationType"
#define kAuthenticationTypeBiometrics @"AuthenticationWithBiometrics"

#define kAccessControlType @"accessControl"
#define kAccessControlUserPresence @"UserPresence"
#define kAccessControlBiometryAny @"BiometryAny"
#define kAccessControlBiometryCurrentSet @"BiometryCurrentSet"
#define kAccessControlDevicePasscode @"DevicePasscode"
#define kAccessControlApplicationPassword @"ApplicationPassword"
#define kAccessControlBiometryAnyOrDevicePasscode @"BiometryAnyOrDevicePasscode"
#define kAccessControlBiometryCurrentSetOrDevicePasscode @"BiometryCurrentSetOrDevicePasscode"

#define kBiometryTypeTouchID @"TouchID"
#define kBiometryTypeFaceID @"FaceID"

#if TARGET_OS_IOS
LAPolicy authPolicy(NSDictionary *options)
{
    if (options && options[kAuthenticationType]) {
        if ([options[kAuthenticationType] isEqualToString:kAuthenticationTypeBiometrics]) {
            return LAPolicyDeviceOwnerAuthenticationWithBiometrics;
        }
    }
    return LAPolicyDeviceOwnerAuthentication;
}
#endif

SecAccessControlCreateFlags accessControlValue(NSDictionary *options)
{
    if (options && options[kAccessControlType] && [options[kAccessControlType] isKindOfClass:[NSString class]]) {
        if ([options[kAccessControlType] isEqualToString: kAccessControlUserPresence]) {
            return kSecAccessControlUserPresence;
        }
        else if ([options[kAccessControlType] isEqualToString:kAccessControlBiometryAny]) {
            return kSecAccessControlBiometryAny;
        }
        else if ([options[kAccessControlType] isEqualToString: kAccessControlBiometryCurrentSet]) {
            return kSecAccessControlBiometryCurrentSet;
        }
        else if ([options[kAccessControlType] isEqualToString: kAccessControlDevicePasscode]) {
            return kSecAccessControlDevicePasscode;
        }
        else if ([options[kAccessControlType] isEqualToString: kAccessControlBiometryAnyOrDevicePasscode]) {
            return kSecAccessControlBiometryAny|kSecAccessControlOr|kSecAccessControlDevicePasscode;
        }
        else if ([options[kAccessControlType] isEqualToString: kAccessControlBiometryCurrentSetOrDevicePasscode]) {
            return kSecAccessControlBiometryCurrentSet|kSecAccessControlOr|kSecAccessControlDevicePasscode;
        }
        else if ([options[kAccessControlType] isEqualToString: kAccessControlApplicationPassword]) {
          return kSecAccessControlApplicationPassword;
        }
    }
    return 0;
}

- (NSDictionary *)insertKeychainEntry:(NSDictionary *)attributes
                withOptions:(NSDictionary * __nullable)options
{
    NSString *accessGroup = accessGroupValue(options);
    CFStringRef accessible = accessibleValue(options);
    SecAccessControlCreateFlags accessControl = accessControlValue(options);
    
    NSMutableDictionary *mAttributes = attributes.mutableCopy;
    
    if (@available(macOS 10.15, *)) {
        mAttributes[(__bridge NSString *)kSecUseDataProtectionKeychain] = @(YES);
    }
    
    if(accessControl) {
        NSError *err = nil;
#if TARGET_OS_IOS
        BOOL canAuthenticate = [[LAContext new] canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&err];
        if (err || !canAuthenticate) {
            @throw err;
        }
#endif
        CFErrorRef error = NULL;
        SecAccessControlRef sacRef = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                     accessible,
                                                                     accessControl,
                                                                     &error);
        
        if (error) {
            @throw err;
        }
        mAttributes[(__bridge NSString *)kSecAttrAccessControl] = (__bridge id)sacRef;
    } else {
        mAttributes[(__bridge NSString *)kSecAttrAccessible] = (__bridge id)accessible;
    }
    
    if (accessGroup != nil) {
        mAttributes[(__bridge NSString *)kSecAttrAccessGroup] = accessGroup;
    }
    
    attributes = [NSDictionary dictionaryWithDictionary:mAttributes];
    
    OSStatus osStatus = SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
    
    if (osStatus != noErr && osStatus != errSecItemNotFound) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:osStatus userInfo:nil];
        @throw error;
    } else {
        NSString *service = serviceValue(options);
        return @{
            @"service": service,
            @"storage": @"keychain"
        };
    }
}

- (OSStatus)deletePasswordsForService:(NSString *)service
{
    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge id)(kSecClassGenericPassword),
        (__bridge NSString *)kSecAttrService: service,
        (__bridge NSString *)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
        (__bridge NSString *)kSecReturnData: (__bridge id)kCFBooleanFalse,
    };
    
    return SecItemDelete((__bridge CFDictionaryRef) query);
}

- (OSStatus)deleteCredentialsForServer:(NSString *)server
{
    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge id)(kSecClassInternetPassword),
        (__bridge NSString *)kSecAttrServer: server,
        (__bridge NSString *)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
        (__bridge NSString *)kSecReturnData: (__bridge id)kCFBooleanFalse
    };
    
    return  SecItemDelete((__bridge CFDictionaryRef) query);
}

- (NSArray<NSString*>*)getAllServicesForSecurityClasses:(NSArray *)secItemClasses
{
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  (__bridge id)kCFBooleanTrue, (__bridge id)kSecReturnAttributes,
                                  (__bridge id)kSecMatchLimitAll, (__bridge id)kSecMatchLimit,
                                  nil];
    
    NSMutableArray<NSString*> *services = [NSMutableArray<NSString*> new];
    for (id secItemClass in secItemClasses) {
        [query setObject:secItemClass forKey:(__bridge id)kSecClass];
        NSArray *result = nil;
        CFTypeRef resultRef = NULL;
        OSStatus osStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&resultRef);
        if (osStatus != noErr && osStatus != errSecItemNotFound) {
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:osStatus userInfo:nil];
            @throw error;
        } else if (osStatus != errSecItemNotFound) {
            result = (__bridge NSArray*)(resultRef);
            if(result != NULL) {
                for (id entry in result) {
                    NSString *service = [entry objectForKey:(__bridge NSString *)kSecAttrService];
                    [services addObject:service];
                }
            }
        }
    }
    return services;
}

#pragma mark - Keychain

#if TARGET_OS_IOS
- (BOOL)canCheckAuthentication:(NSDictionary * __nullable)options
{
    LAPolicy policyToEvaluate = authPolicy(options);
    
    NSError *err = nil;
    BOOL canBeProtected = [[LAContext new] canEvaluatePolicy:policyToEvaluate error:&err];
    
    if(err || !canBeProtected) {
        return NO;
    } else {
        return YES;
    }
}
#endif

#if TARGET_OS_IOS
- (NSString *)getSupportedBiometryType
{
    NSError *err = nil;
    LAContext *context = [LAContext new];
    BOOL canBeProtected = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&err];
    
    if (!err & canBeProtected) {
        if (@available(iOS 11, *)) {
            if (context.biometryType == LABiometryTypeFaceID) {
                return kBiometryTypeFaceID;
            }
        }
        if (context.biometryType == LABiometryTypeTouchID) {
            return kBiometryTypeTouchID;
        }
    }
    return nil;
}
#endif

- (void)setGenericPasswordForOptions: (NSDictionary *)options
                    withUsername: (NSString *)username
                    withPassword: (NSString *)password
{
    NSString *service = serviceValue(options);
    NSDictionary *attributes = @{
        (__bridge NSString *)kSecClass: (__bridge id)(kSecClassGenericPassword),
        (__bridge NSString *)kSecAttrService: service,
        (__bridge NSString *)kSecAttrAccount: username,
        (__bridge NSString *)kSecValueData: [password dataUsingEncoding:NSUTF8StringEncoding]
    };
    
    [self deletePasswordsForService:service];
    
    [self insertKeychainEntry:attributes withOptions:options];
}

- (NSObject *)getGenericPasswordForOptions:(NSDictionary * __nullable)options
{
    NSString *service = serviceValue(options);
    NSString *authenticationPrompt = authenticationPromptValue(options);
    
    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge id)(kSecClassGenericPassword),
        (__bridge NSString *)kSecAttrService: service,
        (__bridge NSString *)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
        (__bridge NSString *)kSecReturnData: (__bridge id)kCFBooleanTrue,
        (__bridge NSString *)kSecMatchLimit: (__bridge NSString *)kSecMatchLimitOne,
        (__bridge NSString *)kSecUseOperationPrompt: authenticationPrompt
    };
    
    NSDictionary *found = nil;
    CFTypeRef foundTypeRef = NULL;
    OSStatus osStatus = SecItemCopyMatching((__bridge CFDictionaryRef) query, (CFTypeRef*)&foundTypeRef);
    
    if(osStatus != noErr && osStatus != errSecItemNotFound) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:osStatus userInfo:nil];
        @throw error;
    }
    
    found = (__bridge NSDictionary*)(foundTypeRef);
    if (!found) {
        return @(NO);
    }
    
    NSString *username = (NSString *) [found objectForKey:(__bridge id)(kSecAttrAccount)];
    NSString *password = [[NSString alloc] initWithData:[found objectForKey:(__bridge id)(kSecValueData)] encoding:NSUTF8StringEncoding];
    
    CFRelease(foundTypeRef);
      NSMutableDictionary* result = [@{@"storage": @"keychain"} mutableCopy];
      if (service) {
          result[@"service"] = service;
      }
      if (username) {
          result[@"username"] = username;
      }
      if (password) {
          result[@"password"] = password;
      }
      return [result copy];
    }

- (BOOL)resetGenericPasswordForOptions:(NSDictionary *)options
    {
      NSString *service = serviceValue(options);

      OSStatus osStatus = [self deletePasswordsForService:service];

      if (osStatus != noErr && osStatus != errSecItemNotFound) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:osStatus userInfo:nil];
        @throw error;
      }

      return YES;
    }

- (NSArray *)getAllGenericPasswordServices
{
    @try {
        NSArray *secItemClasses = [NSArray arrayWithObjects:(__bridge id)kSecClassGenericPassword, nil];
        NSArray *services = [self getAllServicesForSecurityClasses:secItemClasses];
        return services;
    } @catch (NSError *nsError) {
        @throw nsError;
        
    }
}

@end
