#ifndef __socket_h__
#define __socket_h__

#include <stdint.h>

#define SOCKET_PROTOCOL_TCP 0
#define SOCKET_PROTOCOL_UDP 1
#define SOCKET_PROTOCOL_IPC 2

#define SOCKET_TYPE_DATA    0
#define SOCKET_TYPE_ACCEPT  1 
#define SOCKET_TYPE_CONNECT 2 
#define SOCKET_TYPE_CONNERR 3 
#define SOCKET_TYPE_SOCKERR 4
#define SOCKET_TYPE_WRIDONECLOSE 5

struct socket_message {
    int id;         // socket id
    int ud;         // socket userdata
    int type;       // socket msg type, see SOCKET_TYPE
    int listenid;   // for SOCKET_TYPE_ACCEPT
    void *data;     // data
    int size;       // data size
};

struct net;
struct net *net_create(int max);
void net_free(struct net *self);

int socket_bind(struct net *self, int fd, int ud, int protocol);
int socket_listen(struct net *self, const char *addr, int port, int ud);
int socket_connect(struct net *self, const char *addr, int port, int block, int ud, int *conning);
int socket_udata(struct net *self, int id, int ud);
int socket_close(struct net *self, int id, int force);
int socket_enableread(struct net *self, int id, int read);
int socket_poll(struct net *self, int timeout, struct socket_message *msg, int *more);
int socket_send(struct net *self, int id, void *data, int sz);
int socket_sendfd(struct net *self, int id, void *data, int sz, int fd);
int socket_fd(struct net *self, int id);

#endif
