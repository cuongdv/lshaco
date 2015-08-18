#include "sh_socket.h"
#include "sh.h"
#include "sh_init.h"
#include "sh_env.h"
#include "sh_log.h"
#include "sh_module.h"
#include "socket.h"
#include <stdlib.h>
#include <arpa/inet.h>
#include <signal.h>

static struct net* N = NULL;

static inline void
_dispatch_one(struct socket_event* event) {
    int moduleid = event->udata;
    if (event->type == LS_ECONN_THEN_READ) {
        event->type = LS_ECONNECT;
        module_main(moduleid, 0, 0, MT_SOCKET, event, sizeof(*event));
        event->type = LS_EREAD; 
    }
    module_main(moduleid, 0, 0, MT_SOCKET, event, sizeof(*event));
}

int
sh_socket_poll(int timeout) {
    struct socket_event *events;
    int n = socket_poll(N, timeout, &events);
    int i;
    for (i=0; i<n; ++i)
        _dispatch_one(&events[i]);
    return n;
}

int 
sh_socket_send(int id, void* data, int sz) {
    struct socket_event event;
    int n = socket_send(N, id, data, sz, &event);
    if (n == 0) return 0;
    else if (n < 0) return 1;
    else {_dispatch_one(&event); return 1;}
}

int 
sh_socket_write(int id, void *data, int sz) {
    struct socket_event event;
    int n = socket_send(N, id, data, sz, &event);
    if (n<=0) return 0;
    else return event.err;
}

static void
sh_socket_init() {
    int max = sh_getint("connmax", 0);
    if (max <= 0)
        max = 1;
    signal(SIGHUP, SIG_IGN);
    signal(SIGPIPE, SIG_IGN);
    N = net_create(max);
    if (N == NULL) {
        sh_exit("net_create fail, max=%d", max);
    }
}

static void
sh_socket_fini() {
    net_free(N);
    N = NULL;
}

int sh_socket_listen(const char *addr, int port, int moduleid) { return socket_listen(N, addr, port, moduleid); }
int sh_socket_connect(const char* addr, int port, int moduleid) { return socket_connect(N, addr, port, 0, moduleid); }
int sh_socket_blockconnect(const char *addr, int port, int moduleid) { return socket_connect(N, addr, port, 1, moduleid); }
int sh_socket_close(int id, int force) { return socket_close(N, id, force); }
int sh_socket_subscribe(int id, int read) { return socket_subscribe(N, id, read); }
int sh_socket_read(int id, void **data) { return socket_read(N, id, data); }
int sh_socket_address(int id, struct socket_addr *addr) { return socket_address(N, id, addr); }
int sh_socket_limit(int id, int slimit, int rlimit) { return socket_limit(N, id, slimit, rlimit); }
int sh_socket_lasterrno() { return socket_lasterrno(N); }
const char *sh_socket_error(int err) { return socket_error(N, err); }
int sh_socket_fd(int id) { return socket_fd(N, id); }

SH_LIBRARY_INIT_PRIO(sh_socket_init, sh_socket_fini, 20);
