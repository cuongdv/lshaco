#ifndef __sh_socket_h__
#define __sh_socket_h__

#include <stdint.h>
#include "socket_define.h"

struct shaco_context;

void shaco_socket_init(int max_socket);
void shaco_socket_fini();

int shaco_socket_bind(struct shaco_context *ctx, int fd, int protocol);
int shaco_socket_listen(struct shaco_context *ctx, const char *addr, int port);
int shaco_socket_connect(struct shaco_context *ctx, const char *addr, int port);
int shaco_socket_blockconnect(struct shaco_context *ctx, const char *addr, int port);
int shaco_socket_start(struct shaco_context *ctx, int id);
int shaco_socket_close(int id, int force);
int shaco_socket_enableread(int id, int read);
int shaco_socket_poll(int timeout);
int shaco_socket_send(int id, void *data, int sz);
int shaco_socket_send_nodispatcherror(int id, void *data, int sz);
int shaco_socket_read(int id, void **data);
int shaco_socket_sendmsg(int id, void *data, int size, int fd);
int shaco_socket_address(int id, struct socket_addr *addr);
int shaco_socket_limit(int id, int slimit, int rlimit);
int shaco_socket_lasterrno();
const char *shaco_socket_error(int err);
#define SHACO_SOCKETERR shaco_socket_error(shaco_socket_lasterrno())
int shaco_socket_fd(int id);

#endif
