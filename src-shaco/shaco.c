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
#include <stdio.h>

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
        l.rlim_cur < 128*1024*1024) {
        l.rlim_cur = -1;
        l.rlim_max = -1;
        if (setrlimit(RLIMIT_CORE, &l) == -1) {
            shaco_exit("setrlimit core fail: %s", strerror(errno));
        }
    }
    int max = shaco_optint("max_socket", 0) + 1024;
    if (getrlimit(RLIMIT_NOFILE, &l) == -1) {
        shaco_exit("getrlimit nofile fail: %s", strerror(errno));
    }
    if (l.rlim_cur < max) {
        l.rlim_cur = max;
        l.rlim_max = max;
        if (setrlimit(RLIMIT_NOFILE, &l) == -1) {
            shaco_exit("setrlimit nofile fail: %s", strerror(errno));
        }
    }
}

static void
daemonize(int noclose) {
    int fd;
    if (fork() != 0) exit(0); // parent exit
    setsid(); // create a new session

    if (noclose == 0) {
        if ((fd = open("/dev/null", O_RDWR, 0)) != -1) {
            dup2(fd, STDIN_FILENO);
            dup2(fd, STDOUT_FILENO);
            dup2(fd, STDERR_FILENO);
            if (fd > STDERR_FILENO) close(fd);
        }
    }
}

void 
shaco_init() {
    int daemon = shaco_optint("daemon", 0);
    if (daemon)
        daemonize(1);
    shaco_timer_init();
    if (daemon)
        shaco_log_open(shaco_optstr("logfile", "./shaco.log"));
    else
        shaco_log_open(NULL);
    shaco_log_setlevel(shaco_optstr("loglevel", ""));
    shaco_module_init();
    shaco_handle_init();
    sig_handler_init();
    rlimit_check();
    shaco_socket_init(shaco_optint("max_socket", 0));
    shaco_msg_dispatcher_init();
}

void
shaco_fini() {
    shaco_msg_dispatcher_fini();
    shaco_socket_fini();
    shaco_handle_fini();
    shaco_module_fini();
    shaco_log_close();
    shaco_timer_fini();
    shaco_env_fini();
}

void
shaco_start() {
    shaco_info("Shaco start");
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
    shaco_info("Shaco stop(%s)", STOP_INFO);
}

void
shaco_stop(const char *info) {
    RUN = false;
    strncpy(STOP_INFO, info, sizeof(STOP_INFO));
    STOP_INFO[sizeof(STOP_INFO)-1] = '\0';
}
