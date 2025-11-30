#include <Foundation/Foundation.h>
#include <Security/Security.h>
#include <TargetConditionals.h>
#include <dlfcn.h>

#ifdef __cplusplus
extern "C" {
#endif

#if TARGET_OS_OSX
#include <Security/SecCode.h>
#include <Security/SecStaticCode.h>
#else

typedef struct CF_BRIDGED_TYPE(id) __SecCode const* SecStaticCodeRef;

typedef CF_OPTIONS(uint32_t, SecCSFlags) {
    kSecCSDefaultFlags = 0,

    kSecCSConsiderExpiration = 1U << 31,
    kSecCSEnforceRevocationChecks = 1 << 30,
    kSecCSNoNetworkAccess = 1 << 29,
    kSecCSReportProgress = 1 << 28,
    kSecCSCheckTrustedAnchors = 1 << 27,
    kSecCSQuickCheck = 1 << 26,
    kSecCSApplyEmbeddedPolicy = 1 << 25,
};

OSStatus SecStaticCodeCreateWithPathAndAttributes(CFURLRef path, SecCSFlags flags, CFDictionaryRef attributes,
                                                  SecStaticCodeRef* __nonnull CF_RETURNS_RETAINED staticCode);

CF_ENUM(uint32_t){
    kSecCSInternalInformation = 1 << 0, kSecCSSigningInformation = 1 << 1, kSecCSRequirementInformation = 1 << 2,
    kSecCSDynamicInformation = 1 << 3,  kSecCSContentInformation = 1 << 4, kSecCSSkipResourceDirectory = 1 << 5,
    kSecCSCalculateCMSDigest = 1 << 6,
};

OSStatus SecCodeCopySigningInformation(SecStaticCodeRef code, SecCSFlags flags, CFDictionaryRef* __nonnull CF_RETURNS_RETAINED information);

extern const CFStringRef kSecCodeInfoEntitlements;
extern const CFStringRef kSecCodeInfoIdentifier;
extern const CFStringRef kSecCodeInfoRequirementData;

#endif

typedef CF_OPTIONS(uint32_t, SecPreserveFlags) {
	kSecCSPreserveIdentifier = 1 << 0,
	kSecCSPreserveRequirements = 1 << 1,
	kSecCSPreserveEntitlements = 1 << 2,
	kSecCSPreserveResourceRules = 1 << 3,
	kSecCSPreserveFlags = 1 << 4,
	kSecCSPreserveTeamIdentifier = 1 << 5,
	kSecCSPreserveDigestAlgorithm = 1 << 6,
	kSecCSPreservePreEncryptHashes = 1 << 7,
	kSecCSPreserveRuntime = 1 << 8,
};

#ifdef BRIDGED_SECCODESIGNER
typedef struct CF_BRIDGED_TYPE(id) __SecCodeSigner* SecCodeSignerRef SPI_AVAILABLE(macos(10.5), ios(15.0), macCatalyst(13.0));
#else
typedef struct __SecCodeSigner* SecCodeSignerRef SPI_AVAILABLE(macos(10.5), ios(15.0), macCatalyst(13.0));
#endif

const CFStringRef kSecCodeSignerApplicationData = CFSTR("application-specific");
const CFStringRef kSecCodeSignerDetached =		CFSTR("detached");
const CFStringRef kSecCodeSignerDigestAlgorithm = CFSTR("digest-algorithm");
const CFStringRef kSecCodeSignerDryRun =		CFSTR("dryrun");
const CFStringRef kSecCodeSignerEntitlements =	CFSTR("entitlements");
const CFStringRef kSecCodeSignerFlags =			CFSTR("flags");
const CFStringRef kSecCodeSignerIdentifier =	CFSTR("identifier");
const CFStringRef kSecCodeSignerIdentifierPrefix = CFSTR("identifier-prefix");
const CFStringRef kSecCodeSignerIdentity =		CFSTR("signer");
const CFStringRef kSecCodeSignerPageSize =		CFSTR("pagesize");
const CFStringRef kSecCodeSignerRequirements =	CFSTR("requirements");
const CFStringRef kSecCodeSignerResourceRules =	CFSTR("resource-rules");
const CFStringRef kSecCodeSignerSDKRoot =		CFSTR("sdkroot");
const CFStringRef kSecCodeSignerSigningTime =	CFSTR("signing-time");
const CFStringRef kSecCodeSignerRequireTimestamp = CFSTR("timestamp-required");
const CFStringRef kSecCodeSignerTimestampServer = CFSTR("timestamp-url");
const CFStringRef kSecCodeSignerTimestampAuthentication = CFSTR("timestamp-authentication");
const CFStringRef kSecCodeSignerTimestampOmitCertificates =	CFSTR("timestamp-omit-certificates");
const CFStringRef kSecCodeSignerPreserveMetadata = CFSTR("preserve-metadata");
const CFStringRef kSecCodeSignerTeamIdentifier =	CFSTR("teamidentifier");
const CFStringRef kSecCodeSignerPlatformIdentifier = CFSTR("platform-identifier");

#ifdef BRIDGED_SECCODESIGNER
OSStatus SecCodeSignerCreate(CFDictionaryRef parameters, SecCSFlags flags, SecCodeSignerRef* __nonnull CF_RETURNS_RETAINED signer)
    SPI_AVAILABLE(macos(10.5), ios(15.0), macCatalyst(13.0));
#else
OSStatus SecCodeSignerCreate(CFDictionaryRef parameters, SecCSFlags flags, SecCodeSignerRef* signer)
    SPI_AVAILABLE(macos(10.5), ios(15.0), macCatalyst(13.0));
#endif

OSStatus SecCodeSignerAddSignatureWithErrors(SecCodeSignerRef signer, SecStaticCodeRef code, SecCSFlags flags, CFErrorRef* errors)
    SPI_AVAILABLE(macos(10.5), ios(15.0), macCatalyst(13.0));

extern const CFStringRef kSecCodeInfoResourceDirectory;

#ifdef __cplusplus
}
#endif

int codesign_sign_adhoc(const char *path, bool preserveMetadata, NSDictionary *customEntitlements)
{
	OSStatus (*__SecCodeSignerCreate)(CFDictionaryRef parameters, SecCSFlags flags, SecCodeSignerRef *signerRef) = dlsym(RTLD_DEFAULT, "SecCodeSignerCreate");
	OSStatus (*__SecCodeSignerAddSignatureWithErrors)(SecCodeSignerRef signerRef, SecStaticCodeRef codeRef, SecCSFlags flags, CFErrorRef *errors) = dlsym(RTLD_DEFAULT, "SecCodeSignerAddSignatureWithErrors");
	if (!__SecCodeSignerCreate) return 404;
	if (!__SecCodeSignerAddSignatureWithErrors) return 404;

	NSString *filePath = [NSString stringWithUTF8String:path];
	OSStatus status = 0;
	int retval = 200;

	SecIdentityRef identity = (SecIdentityRef)kCFNull;
	NSMutableDictionary* parameters = [[NSMutableDictionary alloc] init];
	parameters[(__bridge NSString*)kSecCodeSignerIdentity] = (__bridge id)identity;
	uint64_t preserveMetadataFlags = 0;
	if (preserveMetadata) {
		preserveMetadataFlags = (kSecCSPreserveIdentifier | kSecCSPreserveRequirements | kSecCSPreserveResourceRules);
		if (!customEntitlements) {
			preserveMetadataFlags |= kSecCSPreserveEntitlements;
		}
		parameters[(__bridge NSString*)kSecCodeSignerPreserveMetadata] = @(preserveMetadataFlags);
	}
	
	if (customEntitlements) {
		NSError *error;
		NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:customEntitlements format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
		if (!xmlData) {
			NSLog(@"Failed to encode entitlements: %@", error);
			return -1;
		}
		else {
			uint32_t entitlementsData[xmlData.length+8];
			entitlementsData[0] = OSSwapHostToBigInt32(0xFADE7171);
			entitlementsData[1] = OSSwapHostToBigInt32(xmlData.length+8);
			[xmlData getBytes:&entitlementsData[2] length:xmlData.length];
			parameters[(__bridge NSString*)kSecCodeSignerEntitlements] = [NSData dataWithBytes:entitlementsData length:xmlData.length+8];
		}
	}

	SecCodeSignerRef signerRef;
	status = __SecCodeSignerCreate((__bridge CFDictionaryRef)parameters, kSecCSDefaultFlags, &signerRef);
	if (status == 0) {
		SecStaticCodeRef code;
		status = SecStaticCodeCreateWithPathAndAttributes((__bridge CFURLRef)[NSURL fileURLWithPath:filePath], kSecCSDefaultFlags, (__bridge CFDictionaryRef)@{}, &code);
		if (status == 0) {
			CFErrorRef errors;
			status = __SecCodeSignerAddSignatureWithErrors(signerRef, code, kSecCSDefaultFlags, &errors);
			if (status == 0) {
				CFDictionaryRef newSigningInformation;
				status = SecCodeCopySigningInformation(code, kSecCSDefaultFlags | kSecCSSigningInformation | kSecCSRequirementInformation | kSecCSInternalInformation, &newSigningInformation);
				if (status == 0) {
					retval = 0;
					CFRelease(newSigningInformation);
				} else {
					retval = 203;
				}
			}
			else {
				printf("Error while signing: %s\n", ((__bridge NSError *)errors).description.UTF8String);
			}
			CFRelease(code);
		}
		else {
			retval = 202;
		}
		CFRelease(signerRef);
	}
	else {
		retval = 201;
	}

	return retval;
}
