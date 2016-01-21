#include "shaco_socket.h"
#include "socket.h"
#include "shaco.h"
#include <stdlib.h>
#include <arpa/inet.h>
#include <signal.h>

static struct net* N = NULL;

void
shaco_socket_poll(int timeout) {
    int more = 1;
    struct socket_message msg;
    while (socket_poll(N, timeout, &msg, &more)) {
        int handle = msg.ud;
        shaco_handle_send(handle, 0, 0, SHACO_TSOCKET, &msg, sizeof(msg));
        if (!more) break;
    }
}

int 
shaco_socket_psend(struct shaco_context *ctx, int id, void *data, int sz) {
    int n = socket_send(N, id, data, sz);
    if (n < 0) {
        int handle = shaco_context_handle(ctx);
        struct socket_message msg;
        msg.id = id;
        msg.ud = handle;
        msg.type = SOCKET_TYPE_SOCKERR;
        shaco_handle_send(handle, 0, 0, SHACO_TSOCKET, &msg, sizeof(msg));
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
shaco_socket_connect(struct shaco_context *ctx, const char* addr, int port, int *conning) { 
    return socket_connect(N, addr, port, 0, shaco_context_handle(ctx), conning);
}

int 
shaco_socket_blockconnect(struct shaco_context *ctx, const char *addr, int port) { 
    return socket_connect(N, addr, port, 1, shaco_context_handle(ctx), NULL); 
}

int
shaco_socket_start(struct shaco_context *ctx, int id) {
    return socket_udata(N, id, shaco_context_handle(ctx));
}

int shaco_socket_close(int id, int force) { return socket_close(N, id, force); }
int shaco_socket_enableread(int id, int read) { return socket_enableread(N, id, read); }
int shaco_socket_send(int id, void *data, int sz) { return socket_send(N, id, data, sz); }
int shaco_socket_sendfd(int id, void *data, int sz, int fd) { return socket_sendfd(N, id, data, sz, fd); }
int shaco_socket_fd(int id) { return socket_fd(N, id); }
