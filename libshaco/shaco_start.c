#include "shaco.h"
#include "shaco_env.h"
#include "shaco_log.h"
#include "shaco_timer.h"
#include "shaco_module.h"
#include "shaco_handle.h"
#include "shaco_context.h"
#include "shaco_socket.h"
#include "shaco_msg_dispatcher.h"
#include <stdbool.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

static bool RUN = false;
static char STOP_INFO[32];

static void 
_sigtermhandler(int sig) {
    // do not call sh_warning, is no signal safe
    shaco_stop("received sigterm");
} 

static void
sig_handler_init() {
    struct sigaction act;
    sigemptyset(&act.sa_mask);
    act.sa_flags = 0;
    act.sa_handler = _sigtermhandler;
    sigaction(SIGINT, &act, NULL);
    sigaction(SIGTERM, &act, NULL);
}

static void
rlimit_check() {
    struct rlimit l;
    if (getrlimit(RLIMIT_CORE, &l) == -1) {
        shaco_exit("getrlimit core fail: %s", strerror(errno));
    }
    if (l.rlim_cur !=-1 && 
        l.rlim_cur < 1024*1024) {
        shaco_exit("ulimit -c %d, too small", (int)l.rlim_cur);
    }
    int max = shaco_optint("max_socket", 0) + 1000;
    if (getrlimit(RLIMIT_NOFILE, &l) == -1) {
        shaco_exit("getrlimit nofile fail: %s", strerror(errno));
    }
    if (l.rlim_cur < max) {
        shaco_exit("ulimit -n %d, too small", (int)l.rlim_cur);
    }
}

static void
daemonize() {
    int fd;
    if (fork() != 0) exit(0); // parent exit
    setsid(); // create a new session

    if ((fd = open("/dev/null", O_RDWR, 0)) != -1) {
        dup2(fd, STDIN_FILENO);
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        if (fd > STDERR_FILENO) close(fd);
    }
}

void 
shaco_init() {
    if (shaco_optint("daemon", 0)) {
        daemonize();
    }
    shaco_log_setlevel(shaco_optstr("loglevel", ""));
    shaco_timer_init();
    shaco_module_init();
    shaco_handle_init();
    const char *name = shaco_getenv("log");
    if (name) {
        struct shaco_context *log = shaco_context_create(name);
        if (log)
            shaco_log_attach(log);
        else
            return;
    }
    sig_handler_init();
    rlimit_check();
    struct shaco_socket_config cfg;
    cfg.max_socket = shaco_optint("max_socket", 0);
    shaco_socket_init(&cfg);
    shaco_msg_dispatcher_init();
}

void
shaco_fini() {
    shaco_msg_dispatcher_fini();
    shaco_socket_fini();
    shaco_log_attach(NULL);
    shaco_handle_fini();
    shaco_module_fini();
    shaco_timer_fini();
    shaco_env_fini();
}

void
shaco_start() {
    sh_info("Shaco start");
    int timeout;
    STOP_INFO[0] = '\0';
    RUN = true; 
    while (RUN) {
        timeout = shaco_timer_max_timeout();
        if (!shaco_msg_empty()) 
            timeout = 0;
        shaco_socket_poll(timeout);
        shaco_timer_trigger();
        shaco_msg_dispatch();
    }
    sh_info("Shaco stop(%s)", STOP_INFO);
}

void
shaco_stop(const char *info) {
    RUN = false;
    strncpy(STOP_INFO, info, sizeof(STOP_INFO));
    STOP_INFO[sizeof(STOP_INFO)-1] = '\0';
}
