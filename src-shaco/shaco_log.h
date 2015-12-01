#ifndef __shaco_log_h__
#define __shaco_log_h__

#define LOG_DEBUG   0
#define LOG_TRACE   1
#define LOG_INFO    2
#define LOG_WARNING 3
#define LOG_ERROR   4
#define LOG_EXIT    5
#define LOG_PANIC   6
#define LOG_MAX     7

struct shaco_context;

void shaco_log_open(const char *filename);
void shaco_log_close();

const char* shaco_log_level();
int shaco_log_setlevel(const char* level);
void shaco_log(struct shaco_context *ctx, int level, const char *fmt, ...)
#ifdef __GNUC__
__attribute__((format(printf, 3, 4)))
#endif
;

#define shaco_error(ctx, fmt, args...) \
    shaco_log(ctx, LOG_ERROR, fmt, ##args)
#define shaco_warning(ctx, fmt, args...) \
    shaco_log(ctx, LOG_WARNING, fmt, ##args)
#define shaco_info(ctx, fmt, args...) \
    shaco_log(ctx, LOG_INFO, fmt, ##args)
#define shaco_trace(ctx, fmt, args...) \
    shaco_log(ctx, LOG_TRACE, fmt, ##args)
#define shaco_debug(ctx, fmt, args...) \
    shaco_log(ctx, LOG_DEBUG, fmt, ##args)

#endif
