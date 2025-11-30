#import <Foundation/Foundation.h>
static inline void opainject_task_log(const char *fmt, ...) {
    if (!fmt) return;
    va_list ap;
    va_start(ap, fmt);
    NSString *format = [NSString stringWithUTF8String:fmt];
    if (!format) {
        va_end(ap);
        return;
    }
    NSString *message = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    NSLog(@"%@", message);
}

#define printf opainject_task_log

#import <mach/mach.h>
#import <stdlib.h>

kern_return_t task_read(task_t task, vm_address_t address, void *outBuf, vm_size_t size)
{
	size_t maxSize = size;
	kern_return_t kr = vm_read_overwrite(task, address, size, (vm_address_t)outBuf, &maxSize);
	if (kr == KERN_SUCCESS) {
		if (maxSize < size) {
			uint8_t *outBufU = outBuf;
			memset(&outBufU[maxSize-1], 0, size - maxSize);
		}
	}
	return kr;
}

char *task_copy_string(task_t task, vm_address_t address)
{
	size_t len = 0;
	char buf = 0;
	do {
		if (task_read(task, address + (len++), &buf, sizeof(buf)) != KERN_SUCCESS) return NULL;
	} while (buf != '\0');

	char *strBuf = malloc(len);
	if (task_read(task, address, &strBuf[0], len) != KERN_SUCCESS) return NULL;
	return strBuf;
}

kern_return_t task_write(task_t task, vm_address_t address, void* inBuf, vm_size_t size)
{
	return vm_write(task, address, (vm_offset_t)inBuf, size);
}
