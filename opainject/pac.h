#ifndef PTRAUTH_HELPERS_H
#define PTRAUTH_HELPERS_H
#if __arm64e__
#include <ptrauth.h>
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"

static void *make_sym_callable(void *ptr) {
#if __arm64e__
    ptr = ptrauth_sign_unauthenticated(ptrauth_strip(ptr, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0);
#endif
    return ptr;
}

static void *make_sym_callable_data(void *ptr) {
#if __arm64e__
    ptr = ptrauth_sign_unauthenticated(ptrauth_strip(ptr, ptrauth_key_process_independent_data), ptrauth_key_process_independent_data, 0);
#endif
    return ptr;
}

static void *make_sym_readable(void *ptr) {
#if __arm64e__
    ptr = ptrauth_strip(ptr, ptrauth_key_function_pointer);
#endif
    return ptr;
}

static void *make_sym_readable_data(void *ptr) {
#if __arm64e__
    ptr = ptrauth_strip(ptr, ptrauth_key_process_independent_data);
#endif
    return ptr;
}

#pragma clang diagnostic pop
#endif
