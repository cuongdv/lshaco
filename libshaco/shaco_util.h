#ifndef __sh_util_h__
#define __sh_util_h__

#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>

static inline char *
sh_strncpy(char *dest, const char *src, size_t n) {
    strncpy(dest, src, n);
    if (n > 1) {
        dest[n-1] = '\0';
    }
    return dest;
}

// endian
static inline void
sh_to_bigendian16(uint16_t n, uint8_t *buffer) {
    buffer[0] = (n >> 8) & 0xff;
    buffer[1] = (n) & 0xff;
}

static inline void
sh_to_bigendian32(uint32_t n, uint8_t *buffer) {
    buffer[0] = (n >> 24) & 0xff;
    buffer[1] = (n >> 16) & 0xff;
    buffer[2] = (n >> 8)  & 0xff;
    buffer[3] = (n) & 0xff;
}

static inline void
sh_to_littleendian16(uint16_t n, uint8_t *buffer) {
    buffer[0] = (n) & 0xff;
    buffer[1] = (n >> 8) & 0xff;
}

static inline void
sh_to_littleendian32(uint32_t n, uint8_t *buffer) {
    buffer[0] = (n) & 0xff;
    buffer[1] = (n >> 8) & 0xff;
    buffer[2] = (n >> 16) & 0xff;
    buffer[3] = (n >> 24) & 0xff;
}

static inline uint16_t 
sh_from_bigendian16(const uint8_t *buffer) {
    return buffer[0] << 8 | buffer[1];
}

static inline uint32_t 
sh_from_bigendian32(const uint8_t *buffer) {
    return buffer[0] << 24 | buffer[1] << 16 | buffer[2] << 8 | buffer[3];
}

static inline uint16_t
sh_from_littleendian16(const uint8_t *buffer) {
    return buffer[0] | buffer[1] << 8;
}

static inline uint32_t
sh_from_littleendian32(const uint8_t *buffer) {
    return buffer[0] | buffer[1] << 8 | buffer[2] << 16 | buffer[3] << 24;
}

static int sh_vsnprintf(char *str, size_t size, const char *format, va_list ap);
static int sh_snprintf(char *str, size_t size, const char *format, ...)
#ifdef __GNUC__
__attribute__((format(printf, 3, 4)))
#endif
;

static inline int 
sh_vsnprintf(char *str, size_t size, const char *format, va_list ap) {
    int n = vsnprintf(str, size, format, ap);
    if (n <= 0)
        return 0;
    if (n < (int)size)
        return n;
    return (int)(size-1);
}

static inline int 
sh_snprintf(char *str, size_t size, const char *format, ...) {
    va_list ap;
    int n;
    va_start(ap, format);
    n = sh_vsnprintf(str, size, format, ap);
    va_end(ap);
    return n;
}

int sh_fork(char *const argv[], int n);

#endif
