#ifndef __sh_log_h__
#define __sh_log_h__

#define LOG_DEBUG   0
#define LOG_TRACE   1
#define LOG_INFO    2
#define LOG_WARNING 3
#define LOG_ERROR   4
#define LOG_EXIT    5
#define LOG_PANIC   6
#define LOG_MAX     7

const char* sh_log_level();
int sh_log_setlevel(const char* level);

void sh_log(int level, const char *fmt, ...)
#ifdef __GNUC__
__attribute__((format(printf, 2, 3)))
#endif
;

#define sh_error(fmt, args...) sh_log(LOG_ERROR, fmt, ##args)
#define sh_warning(fmt, args...) sh_log(LOG_WARNING, fmt, ##args)
#define sh_info(fmt, args...) sh_log(LOG_INFO, fmt, ##args)
#define sh_trace(fmt, args...) sh_log(LOG_TRACE, fmt, ##args)
#define sh_debug(fmt, args...) sh_log(LOG_DEBUG, fmt, ##args)

void sh_log_backtrace();

#endif
