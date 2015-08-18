#ifndef __sh_socket_h__
#define __sh_socket_h__

#include <stdint.h>
#include "socket_define.h"

int sh_socket_listen(const char *addr, int port, int moduleid);
int sh_socket_connect(const char *addr, int port, int moduleid);
int sh_socket_blockconnect(const char *addr, int port, int moduleid);
int sh_socket_close(int id, int force);
int sh_socket_subscribe(int id, int read);
int sh_socket_poll(int timeout);
int sh_socket_send(int id, void *data, int sz);
int sh_socket_write(int id, void *data, int sz);
int sh_socket_read(int id, void **data);
int sh_socket_address(int id, struct socket_addr *addr);
int sh_socket_limit(int id, int slimit, int rlimit);
int sh_socket_lasterrno();
const char *sh_socket_error(int err);
#define SH_SOCKETERR sh_socket_error(sh_socket_lasterrno())
int sh_socket_fd(int id);

#endif
