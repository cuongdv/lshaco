#include "shaco_socket.h"
#include "socket.h"
#include "shaco.h"
#include <stdlib.h>
#include <arpa/inet.h>
#include <signal.h>

static struct net* N = NULL;

static inline void
_dispatch_one(struct socket_event* event) {
    int moduleid = event->udata;
    if (event->type == LS_ECONN_THEN_READ) {
        event->type = LS_ECONNECT;
        shaco_handle_send(moduleid, 0, 0, SHACO_TSOCKET, event, sizeof(*event));
        event->type = LS_EREAD; 
    }
    shaco_handle_send(moduleid, 0, 0, SHACO_TSOCKET, event, sizeof(*event));
}

int
shaco_socket_poll(int timeout) {
    struct socket_event *events;
    int n = socket_poll(N, timeout, &events);
    int i;
    for (i=0; i<n; ++i)
        _dispatch_one(&events[i]);
    return n;
}

int 
shaco_socket_psend(struct shaco_context *ctx, int id, void *data, int sz) {
    int n = socket_send(N, id, data, sz);
    if (n < 0) {
        struct socket_event event;
        event.id = id;
        event.type = LS_ESOCKERR;
        event.udata = shaco_context_handle(ctx);
        event.err = socket_lasterrno(N);
        _dispatch_one(&event);
    }
    return n;
}

void 
shaco_socket_init(int max_socket) {
    signal(SIGHUP, SIG_IGN);
    signal(SIGPIPE, SIG_IGN);
    int max = max_socket;
    if (max ==0) 
        max = 1;
    N = net_create(max);
    if (N == NULL) {
        shaco_exit(NULL, "net_create fail, max=%d", max);
    }
}

void
shaco_socket_fini() {
    if (N==NULL) 
        return;
    net_free(N);
    N = NULL;
}

int 
shaco_socket_bind(struct shaco_context *ctx, int fd, int protocol) {
    return socket_bind(N, fd, shaco_context_handle(ctx), protocol);
}
int 
shaco_socket_listen(struct shaco_context *ctx, const char *addr, int port) { 
    return socket_listen(N, addr, port, shaco_context_handle(ctx)); 
}
int 
shaco_socket_connect(struct shaco_context *ctx, const char* addr, int port) { 
    return socket_connect(N, addr, port, 0, shaco_context_handle(ctx));
}

int 
shaco_socket_blockconnect(struct shaco_context *ctx, const char *addr, int port) { 
    return socket_connect(N, addr, port, 1, shaco_context_handle(ctx)); 
}

int
shaco_socket_start(struct shaco_context *ctx, int id) {
    return socket_udata(N, id, shaco_context_handle(ctx));
}

int shaco_socket_close(int id, int force) { return socket_close(N, id, force); }
int shaco_socket_enableread(int id, int read) { return socket_enableread(N, id, read); }
int shaco_socket_read(int id, void **data) { return socket_read(N, id, data); }
int shaco_socket_send(int id, void *data, int sz) { return socket_send(N, id, data, sz); }
int shaco_socket_sendfd(int id, void *data, int sz, int fd) { return socket_sendfd(N, id, data, sz, fd); }
int shaco_socket_address(int id, struct socket_addr *addr) { return socket_address(N, id, addr); }
int shaco_socket_limit(int id, int slimit, int rlimit) { return socket_limit(N, id, slimit, rlimit); }
int shaco_socket_lasterrno() { return socket_lasterrno(N); }
const char *shaco_socket_error(int err) { return socket_error(N, err); }
int shaco_socket_fd(int id) { return socket_fd(N, id); }
