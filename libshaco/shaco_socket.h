#ifndef __sh_socket_h__
#define __sh_socket_h__

#include <stdint.h>
#include "socket_define.h"

struct shaco_socket_config {
    int max_socket;
};

void shaco_socket_init(struct shaco_socket_config *cfg);
void shaco_socket_fini();

int shaco_socket_listen(const char *addr, int port, int moduleid);
int shaco_socket_connect(const char *addr, int port, int moduleid);
int shaco_socket_blockconnect(const char *addr, int port, int moduleid);
int shaco_socket_close(int id, int force);
int shaco_socket_enableread(int id, int read);
int shaco_socket_poll(int timeout);
int shaco_socket_send(int id, void *data, int sz);
int shaco_socket_send_nodispatcherror(int id, void *data, int sz);
int shaco_socket_read(int id, void **data);
int shaco_socket_address(int id, struct socket_addr *addr);
int shaco_socket_limit(int id, int slimit, int rlimit);
int shaco_socket_lasterrno();
const char *shaco_socket_error(int err);
#define SHACO_SOCKETERR shaco_socket_error(shaco_socket_lasterrno())
int shaco_socket_fd(int id);

#endif
