#if !defined(__CORESYMBOLICATION_CORESYMBOLICATION__)
#define __CORESYMBOLICATION_CORESYMBOLICATION__ 1
#define __CORESYMBOLICATION__ 1

#ifdef __cplusplus
extern "C" {
#endif

#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach.h>

struct sCSTypeRef {
	void* csCppData;
	void* csCppObj;
};
typedef struct sCSTypeRef CSTypeRef;


typedef CSTypeRef CSSymbolicatorRef;
typedef CSTypeRef CSSourceInfoRef;
typedef CSTypeRef CSSymbolOwnerRef;
typedef CSTypeRef CSSectionRef;
typedef CSTypeRef CSSegmentRef;
typedef CSTypeRef CSSymbolRef;
typedef CSTypeRef CSRegionRef;
typedef CSTypeRef CSUUIDRef;


struct sCSRange {
   unsigned long long location;
   unsigned long long length;
};
typedef struct sCSRange CSRange;

typedef struct sCSNotificationData {
	CSSymbolicatorRef symbolicator;
	union {
		struct {
			long value;
		} ping;
		
		struct {
			CSSymbolOwnerRef symbolOwner;
		} dyldLoad;
	} u;
} CSNotificationData;


typedef void* CSDictionaryKeyCallBacks;
typedef void* CSDictionaryValueCallBacks;
typedef void* CSSetCallBacks;


typedef int (^CSNotification)(uint32_t notification_type, CSNotificationData data);
typedef int (^CSRegionIterator)(CSRegionRef region);
typedef int (^CSSymbolOwnerIterator)(CSSymbolOwnerRef owner);
typedef int (^CSSectionIterator)(CSSectionRef section);
typedef int (^CSSourceInfoIterator)(CSSourceInfoRef sourceInfo);
typedef int (^CSSymbolIterator)(CSSymbolRef symbol);
typedef int (^CSSegmentIterator)(CSSegmentRef segment);

#define kCSNull								((CSTypeRef) {NULL, NULL})
#define kCSNow								0x8000000000000000ull
#define kCSSymbolOwnerDataFoundDsym			0
#define kCSSymbolOwnerIsAOut				0
#define kCSSymbolicatorTrackDyldActivity	1

#define kCSNotificationPing					1
#define kCSNotificationInitialized			0x0010
#define kCSNotificationDyldLoad				0x0100
#define kCSNotificationDyldUnload			0x0101
#define kCSNotificationTimeout				0x1002
#define kCSNotificationTaskExit				0x1000
#define kCSNotificationFini					0x80000000

extern const char* kCSRegionMachHeaderName;
extern const CSDictionaryKeyCallBacks kCSTypeDictionaryKeyCallBacks;
extern const CSDictionaryValueCallBacks kCSTypeDictionaryValueCallBacks;
extern const CSDictionaryKeyCallBacks kCSTypeDictionaryWeakKeyCallBacks;
extern const CSDictionaryValueCallBacks kCSTypeDictionaryWeakValueCallBacks;
extern const CSSetCallBacks kCSTypeSetCallBacks;
extern const CSSetCallBacks kCSTypeSetWeakCallBacks;

cpu_type_t CSArchitectureGetArchitectureForName(const char* arch);
cpu_type_t CSArchitectureGetCurrent();
cpu_type_t CSArchitectureGetFamily(cpu_type_t type);
const char* CSArchitectureGetFamilyName(cpu_type_t type);

Boolean CSArchitectureIs32Bit(cpu_type_t type);
Boolean CSArchitectureIs64Bit(cpu_type_t type);
Boolean CSArchitectureIsArm(cpu_type_t type);
Boolean CSArchitectureIsBigEndian(cpu_type_t type);
Boolean CSArchitectureIsI386(cpu_type_t type);
Boolean CSArchitectureIsLittleEndian(cpu_type_t type);
Boolean CSArchitectureIsPPC(cpu_type_t type);
Boolean CSArchitectureIsPPC64(cpu_type_t type);
Boolean CSArchitectureIsX86_64(cpu_type_t type);

Boolean CSArchitectureMatchesArchitecture(cpu_type_t a, cpu_type_t b);


CFStringRef CSCopyDescription(CSTypeRef cs);
CFStringRef CSCopyDescriptionWithIndent(CSTypeRef cs, unsigned int indent);


Boolean CSEqual(CSTypeRef cs1, CSTypeRef cs2);
CFIndex CSGetRetainCount(CSTypeRef cs);
Boolean CSIsNull(CSTypeRef cs);
CSTypeRef CSRetain(CSTypeRef cs);
void CSRelease(CSTypeRef cs);
void CSShow(CSTypeRef cs);


vm_address_t CSGetDyldSharedCacheSlide(mach_port_t port);
CSUUIDRef CSGetDyldSharedCacheUUID(mach_port_t port);


Boolean CSRangeContainsRange(CSRange r1, CSRange r2);
Boolean CSRangeIntersectsRange(CSRange r1, CSRange r2);


CFStringRef CSRegionCopyDescriptionWithIndent(CSRegionRef region, unsigned int indent);
int CSRegionForeachSourceInfo(CSRegionRef region, CSSourceInfoIterator each);
int CSRegionForeachSymbol(CSRegionRef region, CSSymbolIterator each);
const char* CSRegionGetName(CSRegionRef region);
CSRange CSRegionGetRange(CSRegionRef region);
CSSymbolOwnerRef CSRegionGetSymbolOwner(CSRegionRef region);
CSSymbolicatorRef CSRegionGetSymbolicator(CSRegionRef region);


CFStringRef CSSourceInfoCopyDescriptionWithIndent(CSSourceInfoRef info, unsigned int indent);
int CSSourceInfoGetColumn(CSSourceInfoRef info);
const char* CSSourceInfoGetFilename(CSSourceInfoRef info);
int CSSourceInfoGetLineNumber(CSSourceInfoRef info);
const char* CSSourceInfoGetPath(CSSourceInfoRef info);
CSRange CSSourceInfoGetRange(CSSourceInfoRef info);
CSRegionRef CSSourceInfoGetRegion(CSSourceInfoRef info);
CSSymbolRef CSSourceInfoGetSymbol(CSSourceInfoRef info);
CSSymbolOwnerRef CSSourceInfoGetSymbolOwner(CSSourceInfoRef info);
CSSymbolicatorRef CSSourceInfoGetSymbolicator(CSSourceInfoRef info);


CFStringRef CSSymbolCopyDescriptionWithIndent(CSSymbolRef sym, unsigned int indent);
int CSSymbolForeachSourceInfo(CSSymbolRef sym, CSSourceInfoIterator);
long CSSymbolGetFlags(CSSymbolRef sym);
CSTypeRef CSSymbolGetInstructionData(CSSymbolRef sym);
const char* CSSymbolGetMangledName(CSSymbolRef sym);
const char* CSSymbolGetName(CSSymbolRef sym);
CSRange CSSymbolGetRange(CSSymbolRef sym);
CSRegionRef CSSymbolGetRegion(CSSymbolRef sym);
CSSectionRef CSSymbolGetSection(CSSymbolRef sym);
CSSegmentRef CSSymbolGetSegment(CSSymbolRef sym);
CSSymbolOwnerRef CSSymbolGetSymbolOwner(CSSymbolRef sym);
CSSymbolicatorRef CSSymbolGetSymbolicator(CSSymbolRef sym);
Boolean CSSymbolIsArm(CSSymbolRef sym);
Boolean CSSymbolIsDebugMap(CSSymbolRef sym);
Boolean CSSymbolIsDwarf(CSSymbolRef sym);
Boolean CSSymbolIsDyldStub(CSSymbolRef sym);
Boolean CSSymbolIsExternal(CSSymbolRef sym);
Boolean CSSymbolIsFunction(CSSymbolRef sym);
Boolean CSSymbolIsFunctionStarts(CSSymbolRef sym);
Boolean CSSymbolIsKnownLength(CSSymbolRef sym);
Boolean CSSymbolIsMangledNameSourceDwarf(CSSymbolRef sym);
Boolean CSSymbolIsMangledNameSourceDwarfMIPSLinkage(CSSymbolRef sym);
Boolean CSSymbolIsMangledNameSourceNList(CSSymbolRef sym);
Boolean CSSymbolIsMerged(CSSymbolRef sym);
Boolean CSSymbolIsNList(CSSymbolRef sym);
Boolean CSSymbolIsNameSourceDwarf(CSSymbolRef sym);
Boolean CSSymbolIsNameSourceDwarfMIPSLinkage(CSSymbolRef sym);
Boolean CSSymbolIsNameSourceNList(CSSymbolRef sym);
Boolean CSSymbolIsObjcMethod(CSSymbolRef sym);
Boolean CSSymbolIsOmitFramePointer(CSSymbolRef sym);
Boolean CSSymbolIsPrivateExternal(CSSymbolRef sym);
Boolean CSSymbolIsThumb(CSSymbolRef sym);
Boolean CSSymbolIsUnnamed(CSSymbolRef sym);


const char *CSSymbolOwnerGetPath(CSSymbolOwnerRef owner);

CFStringRef CSSymbolicatorCopyDescriptionWithIndent(CSSymbolicatorRef cs, unsigned int indent);
CFDataRef CSSymbolicatorCreateSignature(CSSymbolicatorRef cs);

CSSymbolicatorRef CSSymbolicatorCreateWithMachKernel(void);
CSSymbolicatorRef CSSymbolicatorCreateWithMachKernelFlagsAndNotification(long flags, CSNotification notification);
CSSymbolicatorRef CSSymbolicatorCreateWithPathAndArchitecture(const char* path, cpu_type_t type);
CSSymbolicatorRef CSSymbolicatorCreateWithPathArchitectureFlagsAndNotification(const char* path, cpu_type_t type, long flags, CSNotification notification);
CSSymbolicatorRef CSSymbolicatorCreateWithPid(pid_t pid);
CSSymbolicatorRef CSSymbolicatorCreateWithPidFlagsAndNotification(pid_t pid, long flags, CSNotification notification);
CSSymbolicatorRef CSSymbolicatorCreateWithSignature(CFDataRef sig);
CSSymbolicatorRef CSSymbolicatorCreateWithSignatureAndNotification(CFDataRef sig, CSNotification notification);
CSSymbolicatorRef CSSymbolicatorCreateWithTask(task_t task);
CSSymbolicatorRef CSSymbolicatorCreateWithTaskFlagsAndNotification(task_t task, long flags, CSNotification notification);
CSSymbolicatorRef CSSymbolicatorCreateWithURLAndArchitecture(CFURLRef url, cpu_type_t type);
CSSymbolicatorRef CSSymbolicatorCreateWithURLArchitectureFlagsAndNotification(CFURLRef url, cpu_type_t type, long flags, CSNotification notification);

int CSSymbolicatorForceFullSymbolExtraction(CSSymbolicatorRef cs);
int CSSymbolicatorForeachRegionAtTime(CSSymbolicatorRef cs, uint64_t time, CSRegionIterator it);
int CSSymbolicatorForeachRegionWithNameAtTime(CSSymbolicatorRef cs, const char* name, uint64_t time, CSRegionIterator it);
int CSSymbolicatorForeachSectionAtTime(CSSymbolicatorRef cs, uint64_t time, CSSectionIterator it);
int CSSymbolicatorForeachSegmentAtTime(CSSymbolicatorRef cs, uint64_t time, CSSegmentIterator it);
int CSSymbolicatorForeachSourceInfoAtTime(CSSymbolicatorRef cs, uint64_t time, CSSourceInfoIterator it);
int CSSymbolicatorForeachSymbolAtTime(CSSymbolicatorRef cs, uint64_t time, CSSymbolIterator it);
int CSSymbolicatorForeachSymbolOwnerAtTime(CSSymbolicatorRef cs, uint64_t time, CSSymbolOwnerIterator it);

int CSSymbolicatorForeachSymbolOwnerWithFlagsAtTime(CSSymbolicatorRef symbolicator, long flags, uint64_t time, CSSymbolOwnerIterator it);
int CSSymbolicatorForeachSymbolOwnerWithNameAtTime(CSSymbolicatorRef cs, const char* name, uint64_t time, CSSymbolOwnerIterator it);
int CSSymbolicatorForeachSymbolOwnerWithPathAtTime(CSSymbolicatorRef cs, const char* name, uint64_t time, CSSymbolOwnerIterator it);
int CSSymbolicatorForeachSymbolWithMangledNameAtTime(CSSymbolicatorRef cs, const char* name, uint64_t time, CSSymbolIterator it);
int CSSymbolicatorForeachSymbolWithNameAtTime(CSSymbolicatorRef cs, const char* name, uint64_t time, CSSymbolIterator it);

CSSymbolOwnerRef CSSymbolicatorGetAOutSymbolOwner(CSSymbolicatorRef cs);
cpu_type_t CSSymbolicatorGetArchitecture(CSSymbolicatorRef cs);
vm_address_t CSSymbolicatorGetDyldAllImageInfosAddress(CSSymbolicatorRef cs);

long CSSymbolicatorGetFlagsForDebugMapOnlyData(void);
long CSSymbolicatorGetFlagsForDsymOnlyData(void);
long CSSymbolicatorGetFlagsForDwarfOnlyData(void);
long CSSymbolicatorGetFlagsForFunctionStartsOnlyData(void);
long CSSymbolicatorGetFlagsForNListOnlyData(void);
long CSSymbolicatorGetFlagsForNoSymbolOrSourceInfoData(void);

pid_t CSSymbolicatorGetPid(CSSymbolicatorRef cs);
int CSSymbolicatorGetRegionCountAtTime(CSSymbolicatorRef cs, uint64_t time);
CSRegionRef CSSymbolicatorGetRegionWithAddressAtTime(CSSymbolicatorRef cs, vm_address_t addr, uint64_t time);
CSRegionRef CSSymbolicatorGetRegionWithNameAtTime(CSSymbolicatorRef cs, const char* name, uint64_t time);
CSSectionRef CSSymbolicatorGetSectionWithAddressAtTime(CSSymbolicatorRef cs, vm_address_t addr, uint64_t time);
CSSegmentRef CSSymbolicatorGetSegmentWithAddressAtTime(CSSymbolicatorRef cs, vm_address_t addr, uint64_t time);
vm_address_t CSSymbolicatorGetSharedCacheSlide(CSSymbolicatorRef cs);
CSUUIDRef CSSymbolicatorGetSharedCacheUUID(CSSymbolicatorRef cs);
int CSSymbolicatorGetSourceInfoCountAtTime(CSSymbolicatorRef cs, uint64_t time);
CSSourceInfoRef CSSymbolicatorGetSourceInfoWithAddressAtTime(CSSymbolicatorRef cs, vm_address_t addr, uint64_t time);
int CSSymbolicatorGetSymbolCountAtTime(CSSymbolicatorRef cs, uint64_t time);
CSSymbolOwnerRef CSSymbolicatorGetSymbolOwner(CSSymbolicatorRef cs);
int CSSymbolicatorGetSymbolOwnerCountAtTime(CSSymbolicatorRef cs, uint64_t time);
CSSymbolOwnerRef CSSymbolicatorGetSymbolOwnerWithAddressAtTime(CSSymbolicatorRef cs, vm_address_t addr, uint64_t time);
CSSymbolOwnerRef CSSymbolicatorGetSymbolOwnerWithNameAtTime(CSSymbolicatorRef cs, const char* name, uint64_t time);
CSSymbolOwnerRef CSSymbolicatorGetSymbolOwnerWithUUIDAtTime(CSSymbolicatorRef symbolicator, CFUUIDRef uuid, uint64_t time);
CSSymbolRef CSSymbolicatorGetSymbolWithAddressAtTime(CSSymbolicatorRef cs, vm_address_t addr, uint64_t time);
CSSymbolRef CSSymbolicatorGetSymbolWithMangledNameAtTime(CSSymbolicatorRef cs, const char* name, uint64_t time);
CSSymbolRef CSSymbolicatorGetSymbolWithMangledNameFromSymbolOwnerWithNameAtTime(CSSymbolicatorRef cs, CSSymbolOwnerRef owner, const char* name, uint64_t time);
CSSymbolRef CSSymbolicatorGetSymbolWithNameAtTime(CSSymbolicatorRef cs, const char* name, uint64_t time);
CSSymbolRef CSSymbolicatorGetSymbolWithNameFromSymbolOwnerWithNameAtTime(CSSymbolicatorRef cs, CSSymbolOwnerRef owner, const char* name, uint64_t time);
mach_port_t CSSymbolicatorGetTask(CSSymbolicatorRef cs);
Boolean CSSymbolicatorIsKernelSymbolicator(CSSymbolicatorRef cs);
Boolean CSSymbolicatorIsTaskTranslated(CSSymbolicatorRef cs);
Boolean CSSymbolicatorIsTaskValid(CSSymbolicatorRef cs);
void CSSymbolicatorResymbolicate(CSSymbolicatorRef cs);
void CSSymbolicatorResymbolicateFail(CSSymbolicatorRef cs);
int CSSymbolicatorSetForceGlobalSafeMachVMReads(CSSymbolicatorRef cs);


const char* CSSymbolOwnerGetPath(CSSymbolOwnerRef symbol);
const char* CSSymbolOwnerGetName(CSSymbolOwnerRef symbol);
vm_address_t CSSymbolOwnerGetBaseAddress(CSSymbolOwnerRef owner);
cpu_type_t CSSymbolOwnerGetArchitecture(CSSymbolOwnerRef owner);
Boolean CSSymbolOwnerIsObject(CSSymbolOwnerRef owner);
long CSSymbolOwnerGetDataFlags(CSSymbolOwnerRef owner);
CSRegionRef CSSymbolOwnerGetRegionWithName(CSSymbolOwnerRef owner, const char* name);
CSSymbolRef CSSymbolOwnerGetSymbolWithName(CSSymbolOwnerRef owner, const char* name);
CSSymbolRef CSSymbolOwnerGetSymbolWithAddress(CSSymbolOwnerRef owner, mach_vm_address_t addr);

long CSSymbolOwnerForeachSymbol(CSSymbolOwnerRef owner, CSSymbolIterator each);

CFUUIDBytes *CSSymbolOwnerGetCFUUIDBytes(CSSymbolOwnerRef owner);

#ifdef __cplusplus
}
#endif

#endif
