#ifndef __sh_socket_h__
#define __sh_socket_h__

#include "socket.h"

struct shaco_context;

void shaco_socket_init(int max_socket);
void shaco_socket_fini();

int shaco_socket_bind(struct shaco_context *ctx, int fd, int protocol);
int shaco_socket_listen(struct shaco_context *ctx, const char *addr, int port);
int shaco_socket_connect(struct shaco_context *ctx, const char *addr, int port, int *conning);
int shaco_socket_blockconnect(struct shaco_context *ctx, const char *addr, int port);
int shaco_socket_start(struct shaco_context *ctx, int id);
int shaco_socket_psend(struct shaco_context *ctx, int id, void *data, int sz);
int shaco_socket_close(int id, int force);
int shaco_socket_enableread(int id, int read);
void shaco_socket_poll(int timeout);
int shaco_socket_send(int id, void *data, int sz);
int shaco_socket_sendfd(int id, void *data, int size, int fd);
int shaco_socket_fd(int id);

#endif
