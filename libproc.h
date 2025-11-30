#ifndef _LIBPROC_H_
#define _LIBPROC_H_

#include <sys/cdefs.h>
#include <sys/param.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/resource.h>
#include <stdint.h>
#include <stdbool.h>
#include <mach/message.h>

#include <sys/proc.h>

#include <Availability.h>
#include <os/availability.h>

#define PROC_LISTPIDSPATH_PATH_IS_VOLUME        1

#define PROC_LISTPIDSPATH_EXCLUDE_EVTONLY       2

__BEGIN_DECLS

int     proc_listpidspath(uint32_t      type,
    uint32_t      typeinfo,
    const char    *path,
    uint32_t      pathflags,
    void          *buffer,
    int           buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);

int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_listallpids(void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_1);
int proc_listpgrppids(pid_t pgrpid, void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_1);
int proc_listchildpids(pid_t ppid, void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_1);
int proc_pidinfo(int pid, int flavor, uint64_t arg, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_pidfdinfo(int pid, int fd, int flavor, void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_pidfileportinfo(int pid, uint32_t fileport, int flavor, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
int proc_name(int pid, void * buffer, uint32_t buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_regionfilename(int pid, uint64_t address, void * buffer, uint32_t buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_kmsgbuf(void * buffer, uint32_t buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_pidpath(int pid, void * buffer, uint32_t  buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int proc_pidpath_audittoken(audit_token_t *audittoken, void * buffer, uint32_t  buffersize) API_AVAILABLE(macos(10.16), ios(14.0), watchos(7.0), tvos(14.0));
int proc_libversion(int *major, int * minor) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);

int proc_pid_rusage(int pid, int flavor, rusage_info_t *buffer) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);

#define PROC_SETPC_NONE         0
#define PROC_SETPC_THROTTLEMEM  1
#define PROC_SETPC_SUSPEND      2
#define PROC_SETPC_TERMINATE    3

int proc_setpcontrol(const int control) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
int proc_setpcontrol(const int control);

int proc_track_dirty(pid_t pid, uint32_t flags);
int proc_set_dirty(pid_t pid, bool dirty);
int proc_get_dirty(pid_t pid, uint32_t *flags);
int proc_clear_dirty(pid_t pid, uint32_t flags);

int proc_terminate(pid_t pid, int *sig);

int proc_set_no_smt(void) __API_AVAILABLE(macos(10.16));

int proc_setthread_no_smt(void) __API_AVAILABLE(macos(10.16));

int proc_set_csm(uint32_t flags) __API_AVAILABLE(macos(10.16));

int proc_setthread_csm(uint32_t flags) __API_AVAILABLE(macos(10.16));

#define PROC_CSM_ALL         0x0001
#define PROC_CSM_NOSMT       0x0002
#define PROC_CSM_TECS        0x0004

#ifdef PRIVATE
#include <sys/event.h>
int proc_list_uptrs(pid_t pid, uint64_t *buffer, uint32_t buffersize);

int proc_list_dynkqueueids(int pid, kqueue_id_t *buf, uint32_t bufsz);
int proc_piddynkqueueinfo(int pid, int flavor, kqueue_id_t kq_id, void *buffer,
    int buffersize);
#endif

int proc_udata_info(int pid, int flavor, void *buffer, int buffersize);

__END_DECLS

#endif
