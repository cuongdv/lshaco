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
static bool REOPENING = false;

static void 
_sigtermhandler(int sig) {
    // do not call sh_warning, is no signal safe
    shaco_stop("received sigterm");
} 

static void
_sigreopen(int sig) {
    REOPENING = true;
}

static void
sig_handler_init() {
    struct sigaction act;
    sigemptyset(&act.sa_mask);
    act.sa_flags = 0;
    act.sa_handler = _sigtermhandler;
    sigaction(SIGINT, &act, NULL);
    sigaction(SIGTERM, &act, NULL);

    struct sigaction act2;
    sigemptyset(&act2.sa_mask);
    act2.sa_flags = 0;
    act2.sa_handler = _sigreopen;
    sigaction(SIGUSR1, &act2, NULL);
}

static void
rlimit_check() {
    struct rlimit l;
    int max = shaco_optint("maxsocket", 0) + 32;
    if (getrlimit(RLIMIT_NOFILE, &l) == -1) {
        shaco_exit(NULL, "getrlimit nofile fail: %s", strerror(errno));
    }
    if (l.rlim_cur < max) {
        l.rlim_cur = max;
        l.rlim_max = max;
        if (setrlimit(RLIMIT_NOFILE, &l) == -1) {
            shaco_exit(NULL, "setrlimit nofile fail: %s", strerror(errno));
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

static void
reopenlog() {
    int daemon = shaco_optint("daemon", 0);
    if (daemon) {
        shaco_log_close();
        shaco_log_open(shaco_optstr("logfile", "./shaco.log"));
    }
}

void 
shaco_init() {
    int daemon = shaco_optint("daemon", 0);
    if (daemon)
        daemonize(0);
    shaco_timer_init();
    if (daemon)
        shaco_log_open(shaco_optstr("logfile", "./shaco.log"));
    else
        shaco_log_open(NULL);
    shaco_log_setlevel(shaco_optstr("loglevel", ""));
    shaco_module_init(shaco_optstr("modpath", "./lib-mod"));
    shaco_handle_init();
    sig_handler_init();
    rlimit_check();
    shaco_socket_init(shaco_optint("maxsocket", 0));
    shaco_msg_dispatcher_init();

    RUN = true; 
    STOP_INFO[0] = '\0';

    const char *boot = shaco_optstr("bootstrap", "lua bootstrap");
    if (shaco_launch(NULL, boot) == 0) {
        shaco_exit(NULL, "bootstrap fail");
    }
}

void
shaco_fini() {
    shaco_msg_dispatcher_fini();
    shaco_handle_fini();
    shaco_module_fini();
    shaco_socket_fini();
    shaco_log_close();
    shaco_timer_fini();
    shaco_env_fini();
}

void
shaco_start() {
    shaco_info(NULL, "Shaco start");
    int timeout;
    while (RUN) {
        timeout = shaco_timer_max_timeout();
        if (!shaco_msg_empty()) 
            timeout = 0;
        shaco_socket_poll(timeout);
        shaco_timer_trigger();
        shaco_msg_dispatch();
        if (REOPENING) {
            reopenlog();
            REOPENING = false;
        }
    }
    shaco_info(NULL, "Shaco stop (%s)", STOP_INFO);
}

void
shaco_stop(const char *info) {
    RUN = false;
    strncpy(STOP_INFO, info, sizeof(STOP_INFO));
    STOP_INFO[sizeof(STOP_INFO)-1] = '\0';
}
