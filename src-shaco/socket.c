#include "socket_alloc.h"
#include "socket_platform.h"
#include "socket.h"
#include "np.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>

#define STATUS_INVALID    -1
#define STATUS_LISTENING   1 
#define STATUS_CONNECTING  2
#define STATUS_CONNECTED   3
#define STATUS_HALFCLOSE   4
#define STATUS_SUSPEND     5
#define STATUS_OPENED      STATUS_LISTENING
#define STATUS_BIND        6

#define LISTEN_BACKLOG 511
#define RBUFFER_SZ 64
#define RECVMSG_MAXSIZE 64

#define sockid(s) ((s)-self->sockets)

struct sbuffer {
    struct sbuffer *next;
    int sz;
    int fd; // for ipc
    char *begin;
    char *ptr;
};

struct socket {
    socket_t fd;
    int protocol;
    int status;
    int mask;
    int ud;
    struct sbuffer *head;
    struct sbuffer *tail; 
    int sbuffersz;
    int rbuffersz;
};

struct net {
    struct np_state np;
    int max;
    struct np_event *events;
    int event_count;
    int event_index;
    struct socket *sockets;
    struct socket *free_socket;
    struct socket *tail_socket;
    char recvmsg_buffer[RECVMSG_MAXSIZE];
    char buffer[128];
};

static inline struct socket *
_socket(struct net *self, int id) {
    assert(id>=0 && id<self->max);
    struct socket *s = &self->sockets[id];
    if (s->status != STATUS_INVALID) 
        return s;
    else return NULL;
}

static int
_subscribe(struct net *self, struct socket *s, int mask) {
    int result;
    if (mask == s->mask)
        return 0;
    if (mask == 0)
        result = np_del(&self->np, s->fd);
    else if (s->mask == 0)
        result = np_add(&self->np, s->fd, mask, s);
    else
        result = np_mod(&self->np, s->fd, mask, s);
    if (result == 0)
        s->mask = mask;
    return result;
}

static struct socket*
_alloc_sockets(int max) {
    assert(max > 0);
    int i;
    struct socket *s = malloc(max*sizeof(struct socket)); 
    for (i=0; i<max; ++i) { 
        s[i].fd = i+1;
        s[i].status = STATUS_INVALID;
        s[i].mask = 0;
        s[i].ud = -1;
        s[i].head = NULL;
        s[i].tail = NULL;
        s[i].sbuffersz = 0;
    }
    s[max-1].fd = -1;
    return s;
}

static struct socket*
_create_socket(struct net *self, socket_t fd, int ud, int protocol) {
    assert(fd >= 0);
    if (protocol < SOCKET_PROTOCOL_TCP || protocol > SOCKET_PROTOCOL_IPC) {
        protocol = SOCKET_PROTOCOL_TCP;
    } 
    if (self->free_socket == NULL)
        return NULL;
    struct socket *s = self->free_socket;
    if (s->fd >= 0)
        self->free_socket = &self->sockets[s->fd];
    else
        self->free_socket = NULL;
    s->fd = fd;
    s->protocol = protocol;
    s->status = STATUS_SUSPEND;
    s->mask = 0; 
    s->ud = ud;
    s->head = NULL;
    s->tail = NULL;
    s->sbuffersz = 0;
    s->rbuffersz = RBUFFER_SZ;
    return s;
}

static void
_close_socket(struct net *self, struct socket *s) {
    if (s->fd < 0) return;

    // don't do this, or in the issue, fork
    // child close listen socket, then will
    // delete read event from epoll_fd (
    // parent and children has the same epoll_fd now)
    // note: epoll_create fd will inherited by a child created with fork, 
    // but kqueue is not.
    //_subscribe(self, s, 0);

    // eg bind stdin for async read data
    if (s->fd > STDERR_FILENO) {
        _socket_close(s->fd);
    }
    s->fd = -1;
    s->status = STATUS_INVALID;
    s->ud = 0; 
    while (s->head) {
        struct sbuffer *p = s->head;
        s->head = s->head->next;
        free(p->begin);
        free(p);
    }
    s->tail = NULL;
    s->sbuffersz = 0;
    if (self->free_socket == NULL) {
        self->free_socket = s;
    } else {
        assert(self->tail_socket);
        assert(self->tail_socket->fd == -1);
        self->tail_socket->fd = sockid(s);
    }
    self->tail_socket = s;
}

int
socket_close(struct net *self, int id, int force) {
    struct socket *s = _socket(self, id);
    if (s == NULL) return 0;
    if (s->status == STATUS_INVALID)
        return 0;
    if (force || !s->head) {
        _close_socket(self, s);
        return 0;
    } else {
        s->status = STATUS_HALFCLOSE;
        return 1;
    }
}

int
socket_enableread(struct net *self, int id, int read) {
    struct socket *s = _socket(self, id);
    if (s == NULL) return 1;
    int mask = 0;
    if (read)
        mask |= NP_RABLE;
    if (s->mask & NP_WABLE)
        mask |= NP_WABLE;
    return _subscribe(self, s, mask);
}

int 
socket_udata(struct net *self, int id, int ud) {
    struct socket *s = _socket(self, id);
    if (s==NULL)
        return 1;
    s->ud = ud;
    return 0;
}

struct net*
net_create(int max) {
    if (max <= 0)
        max = 1;
    struct net *self = malloc(sizeof(struct net));
    if (np_init(&self->np, max)) {
        free(self);
        return NULL;
    }
    self->max = max;
    self->events = malloc(max*sizeof(struct np_event));
    self->event_count = 0;
    self->event_index = 0;
    self->sockets = _alloc_sockets(max);
    self->free_socket = &self->sockets[0];
    self->tail_socket = &self->sockets[max-1];
    return self;
}

void
net_free(struct net *self) {
    if (self == NULL)
        return;

    int i;
    for (i=0; i<self->max; ++i) {
        struct socket *s = &self->sockets[i];
        if (s->status >= STATUS_OPENED) {
            _close_socket(self, s);
        }
    }
    free(self->sockets);
    self->free_socket = NULL;
    self->tail_socket = NULL;
    free(self->events);
    np_fini(&self->np);
    free(self);
}

static int
_read_close(struct socket *s) {
    char buf[1024];
    for (;;) {
        int n = _socket_read(s->fd, buf, sizeof(buf));
        if (n < 0) {
            int err = _socket_geterror(s->fd);
            if (err == SEAGAIN) return 0;
            else if (err == SEINTR) continue;
            else return -1;
        } else if (n == 0) {
            return -1;
        } else return 0; // we not care data
    }
}

// return read size, or -1 for error
static int
_read_tcp(struct net *self, struct socket *s, void **data) {
    if (s->status == STATUS_HALFCLOSE) {
        if (_read_close(s)) {
            _close_socket(self, s);
            return -1;
        } else return 0;
    }
    int size = s->rbuffersz;
    void *p = malloc(size);
    for (;;) {
        int n = _socket_read(s->fd, p, size);
        if (n < 0) {
            int err = _socket_geterror(s->fd);
            switch (err) {
            case SEAGAIN:
                free(p);
                return 0;
            case SEINTR:
                continue;
            default:
                free(p);
                _close_socket(self, s);
                return -1;
            }
        } else if (n == 0) {
            // zero indicates end of file
            free(p);
            _close_socket(self, s);
            return -1;
        } else {
            if (n == s->rbuffersz)
                s->rbuffersz <<= 1;
            else if (s->rbuffersz > RBUFFER_SZ && n < (s->rbuffersz<<1))
                s->rbuffersz >>= 1;
            *data = p;
            return n;
        } 
    }
}

static inline int
_send_fd(int fd, void *data, int sz, int cfd) {
    char tmp[1] = {0};
    if (data == NULL) {
        data = tmp;
    }
    struct msghdr msg;
    if (cfd < 0) {
        msg.msg_control = NULL;
        msg.msg_controllen = 0;
    } else {
        union {
            struct cmsghdr  cm;
            char space[CMSG_SPACE(sizeof(int))];
        } cmsg;

        msg.msg_control = (caddr_t)&cmsg;
        msg.msg_controllen = sizeof(cmsg);
        memset(&cmsg, 0, sizeof(cmsg));
        cmsg.cm.cmsg_len = CMSG_LEN(sizeof(int));
        cmsg.cm.cmsg_level = SOL_SOCKET;
        cmsg.cm.cmsg_type = SCM_RIGHTS;
        *(int*)CMSG_DATA(&cmsg.cm) = cfd;
    }
    struct iovec iov[1];
    iov[0].iov_base = data;
    iov[0].iov_len = sz;
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;

    msg.msg_name = NULL;
    msg.msg_namelen = 0;

    msg.msg_flags = 0;
    return sendmsg(fd, &msg, 0);
}

// return -1 for error, or read size (0 no read)
int
_read_fd(struct net *self, struct socket *s, void **data) {
    if (s->protocol != SOCKET_PROTOCOL_IPC) {
        fprintf(stderr, "Socket error: can't read fd with protocol %d\n", s->protocol);
        return -1;
    }
    union {
        struct cmsghdr  cm;
        char space[CMSG_SPACE(sizeof(int))];
    } cmsg;

    struct iovec iov[1];
    iov[0].iov_base = self->recvmsg_buffer;
    iov[0].iov_len = RECVMSG_MAXSIZE;

    struct msghdr msg;
    msg.msg_name = NULL;
    msg.msg_namelen = 0;
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;

    memset(&cmsg, 0, sizeof(cmsg));
    msg.msg_control = (caddr_t)&cmsg;
    msg.msg_controllen = sizeof(cmsg);

    for (;;) {
        int n = recvmsg(s->fd, &msg, 0);
        if (n < 0) {
            int err = _socket_geterror(s->fd);
            switch (err) {
            case SEAGAIN: return 0;
            case SEINTR: continue;
            default:
                _close_socket(self, s);
                return -1;
            }
        } else if (n==0) {
            _close_socket(self, s);
            return -1;
        } 
        if (msg.msg_flags & (MSG_TRUNC|MSG_CTRUNC)) {
            fprintf(stderr, "Socket error: read fd msg is truncated\n");
            _close_socket(self, s);
            return -1;
        }
        if (cmsg.cm.cmsg_len == CMSG_LEN(sizeof(int))) {
            if (cmsg.cm.cmsg_level != SOL_SOCKET || cmsg.cm.cmsg_type != SCM_RIGHTS) {
                fprintf(stderr, "Socket error: read fd msg type dismatch\n");
                _close_socket(self, s);
                return -1;
            }
            char *p = malloc(n+sizeof(int));
            *(int *)p = *(int*)CMSG_DATA(&cmsg.cm);
            memcpy(p+sizeof(int), self->recvmsg_buffer, n);
            *data = p;
            return n+sizeof(int);
        } else {
            char *p = malloc(n+1);
            memcpy(p, self->recvmsg_buffer, n);
            *data = p;
            return n;
        }
    }
}

static int
_read(struct net *self, struct socket *s, struct socket_message *msg) {
    void *data;
    int size;
    msg->id = sockid(s);
    msg->ud = s->ud;
    switch (s->protocol) {
    case SOCKET_PROTOCOL_TCP: 
        size = _read_tcp(self, s, &data); 
        break;
    case SOCKET_PROTOCOL_IPC: 
        size = _read_fd(self, s, &data); 
        break;
    default: 
        assert(false); 
    }
    if (size > 0) {
        msg->type = SOCKET_TYPE_DATA; 
        msg->data = data;
        msg->size = size;
        return 1;
    } else if (size < 0) {
        msg->type = SOCKET_TYPE_SOCKERR;
        return 1;
    } else return 0;
}

int
_send_buffer_tcp(struct net *self, struct socket *s) {
    while (s->head) {
        struct sbuffer *b = s->head;
        for (;;) {
            int n = _socket_write(s->fd, b->ptr, b->sz);
            if (n < 0) {
                int err = _socket_geterror(s->fd);
                switch (err) {
                case SEAGAIN: return 0;
                case SEINTR: continue;
                default: return err;
                }
            } else if (n < b->sz) {
                b->ptr += n;
                b->sz -= n;
                s->sbuffersz -= n;
                return 0;
            } else {
                s->sbuffersz -= n;
                break;
            }
        } 
        s->head = b->next;
        free(b->begin);
        free(b);
    }
    return 0;
}

int
_send_buffer_ipc(struct net *self, struct socket *s) {
    while (s->head) {
        struct sbuffer *b = s->head;
        for (;;) {
            int n = _send_fd(s->fd, b->ptr, b->sz, b->fd);
            if (n < 0) {
                int err = _socket_geterror(s->fd);
                switch (err) {
                case SEAGAIN: return 0;
                case SEINTR: continue;
                default: return err;
                }
            } else if (n==0) {
                return 0;
            } else if (n<b->sz) {
                b->fd   = -1; // the fd should be send
                b->ptr += n;
                b->sz  -= n;
                s->sbuffersz -= n;
                return 0;
            } else {
                s->sbuffersz -= n;
                break;
            }
        }
        s->head = b->next;
        free(b->begin);
        free(b);
    }
    return 0;
}

static int
_send_buffer(struct net *self, struct socket *s, struct socket_message *msg) {
    int err;
    if (s->head == NULL) return 0;
    switch (s->protocol) {
    case SOCKET_PROTOCOL_TCP:
        err = _send_buffer_tcp(self, s);
        break;
    case SOCKET_PROTOCOL_IPC:
        err = _send_buffer_ipc(self, s);
        break;
    default:
        assert(false);
    }
    if (err == 0) {
        if (s->head == NULL) {
            _subscribe(self, s, s->mask & (~NP_WABLE));
            if (s->status == STATUS_HALFCLOSE) {
                msg->id = sockid(s);
                msg->ud = s->ud;
                msg->type = SOCKET_TYPE_WRIDONECLOSE;
                _close_socket(self, s);
                return 1;
            }
        }
    } else {
        msg->id = sockid(s);
        msg->ud = s->ud;
        msg->type = SOCKET_TYPE_SOCKERR;
        _close_socket(self, s);
        return 1;
    }
    return 0;
}

// return send buffer size, or -1 for error
int 
socket_send(struct net* self, int id, void* data, int sz) {
    assert(sz > 0);
    struct socket* s = _socket(self, id);
    if (s == NULL) {
        free(data);
        return -1;
    }
    if (s->protocol != SOCKET_PROTOCOL_TCP || s->status == STATUS_HALFCLOSE) {
        fprintf(stderr, "Socket error: use send with invalid protocol %d\n", s->protocol);
        free(data);
        return -1; 
    }
    int err;
    if (s->head == NULL) {
        char *ptr;
        int n = _socket_write(s->fd, data, sz);
        if (n >= sz) {
            free(data);
            return 0;
        } else if (n >= 0) {
            ptr = (char*)data + n;
            sz -= n;
        } else {
            ptr = data;
            err = _socket_geterror(s->fd);
            switch (err) {
            case SEAGAIN: break;
            case SEINTR: break;
            default: goto errout;
            }
        }
        s->sbuffersz += sz;
        struct sbuffer* p = malloc(sizeof(*p));
        p->next = NULL;
        p->sz = sz;
        p->fd = -1;
        p->begin = data;
        p->ptr = ptr;
        
        s->head = s->tail = p;
        _subscribe(self, s, s->mask|NP_WABLE);
    } else {
        s->sbuffersz += sz;
        struct sbuffer* p = malloc(sizeof(*p));
        p->next = NULL;
        p->sz = sz;
        p->fd = -1;
        p->begin = data;
        p->ptr = data;
        
        assert(s->tail != NULL);
        assert(s->tail->next == NULL);
        s->tail->next = p;
        s->tail = p;
    }
    return s->sbuffersz;
errout:
    free(data);
    _close_socket(self, s);
    return -1;
}

// return send buffer size, -1 for error
int
socket_sendfd(struct net *self, int id, void *data, int sz, int cfd) {
    assert(sz > 0 || (data == NULL && sz == 1)); // if data == NULL, then sz set 1
    struct socket *s = _socket(self, id);
    if (s == NULL) {
        free(data);
        return -1;
    }
    if (s->protocol != SOCKET_PROTOCOL_IPC || s->status == STATUS_HALFCLOSE) {
        fprintf(stderr, "Socket error: use send fd with protocol %d\n", s->protocol);
        free(data);
        return -1;
    }
    if (s->head == NULL) {
        char *ptr;
        int n = _send_fd(s->fd, data, sz, cfd);
        if (n >= sz) {
            free(data);
            return 0;
        } else if (n>0) {
            ptr = (char *)data + n;
            sz -= n;
            cfd = -1;
        } else if (n==0) {
            ptr = data;
        } else {
            ptr = data;
            int err = _socket_geterror(s->fd);
            switch (err) {
            case SEAGAIN: break;
            case SEINTR: break;
            default:
                goto errout;
            }
        }
        s->sbuffersz += sz;
        struct sbuffer* p = malloc(sizeof(*p));
        p->next = NULL;
        p->sz = sz;
        p->fd = cfd;
        p->begin = data;
        p->ptr = ptr;
        
        s->head = s->tail = p;
        _subscribe(self, s, s->mask|NP_WABLE);
    } else {
        s->sbuffersz += sz;
        struct sbuffer* p = malloc(sizeof(*p));
        p->next = NULL;
        p->sz = sz;
        p->fd = cfd;
        p->begin = data;
        p->ptr = data;
        
        assert(s->tail != NULL);
        assert(s->tail->next == NULL);
        s->tail->next = p;
        s->tail = p;
    }
    return s->sbuffersz;
errout:
    free(data);
    _close_socket(self, s);
    return -1;
}

int
socket_bind(struct net *self, int fd, int ud, int protocol) {
    struct socket *s;
    s = _create_socket(self, fd, ud, protocol);
    if (s == NULL) {
        return -1;
    }
    if (_socket_nonblocking(fd) == -1) {
        _close_socket(self, s);
        return -1;
    }
    s->status = STATUS_BIND;
    return sockid(s);
}

static int
_accept(struct net *self, struct socket *lis, struct socket_message *msg) {
    struct sockaddr_storage sa;
    socklen_t l = sizeof(sa);
    socket_t fd = accept(lis->fd, (struct sockaddr*)&sa, &l);
    if (fd < 0) {
        return 0;
    }
    _socket_keepalive(fd);
    struct socket *s = _create_socket(self, fd, lis->ud, SOCKET_PROTOCOL_TCP);
    if (s == NULL) {
        _socket_close(fd);
        return 0;
    }
    if (_socket_nonblocking(fd) == -1 /*||
        _socket_closeonexec(fd) == -1*/) {
        _close_socket(self, s);
        return 0;
    }
    s->status = STATUS_CONNECTED;

    msg->id = sockid(s); 
    msg->ud = s->ud;
    msg->type = SOCKET_TYPE_ACCEPT;
    msg->listenid = sockid(lis);

    char tmp[INET6_ADDRSTRLEN];
    const void *addr;
    uint16_t port;
    if (sa.ss_family == AF_INET) {
        struct sockaddr_in *s = (struct sockaddr_in *)&sa;
        addr = &s->sin_addr;
        port = s->sin_port;
    } else {
        struct sockaddr_in6 *s = (struct sockaddr_in6 *)&sa;
        addr = &s->sin6_addr;
        port = s->sin6_port;
    }
    if (inet_ntop(sa.ss_family, addr, tmp, sizeof(tmp))) {
        int n = sprintf(self->buffer, "%s:%d", tmp, ntohs(port));
        msg->data = self->buffer;
        msg->size = n;
    } else {
        msg->data = "";
        msg->size = 0;
    }
    return 1;
}

int
socket_listen(struct net *self, const char *addr, int port, int ud) {    
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC; // allow IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM; 
    hints.ai_protocol = IPPROTO_TCP;

    char sport[16];
    snprintf(sport, sizeof(sport), "%u", port);
    if (getaddrinfo(addr, sport, &hints, &result)) {
        return -1;
    }
    int fd = -1;
    for (rp = result; rp; rp = rp->ai_next) {
        fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (fd == -1)
            continue;
        if (_socket_nonblocking(fd) == -1 ||
            _socket_closeonexec(fd) == -1 ||
            _socket_reuseaddr(fd)   == -1) {
            _socket_close(fd);
            return -1;
        }
        if (bind(fd, rp->ai_addr, rp->ai_addrlen) == -1) {
            _socket_close(fd);
            fd = -1;
            continue;
        }
        break;
    }
    freeaddrinfo(result);
    if (fd == -1) 
        return -1;

    if (listen(fd, LISTEN_BACKLOG) == -1) {
        _socket_close(fd);
        return -1;
    }
    struct socket *s;
    s = _create_socket(self, fd, ud, SOCKET_PROTOCOL_TCP);
    if (s == NULL) {
        _socket_close(fd);
        return -1;
    }
    if (_subscribe(self, s, NP_RABLE)) {
        _close_socket(self, s);
        return -1;
    }
    s->status = STATUS_LISTENING;
    return sockid(s);
}

static inline int
_onconnect(struct net *self, struct socket *s, struct socket_message *msg) {
    int err;
    socklen_t errlen = sizeof(err);
    if (getsockopt(s->fd, SOL_SOCKET, SO_ERROR, (void*)&err, &errlen) == -1) {
        if (err == 0)
            err = _socket_error != 0 ? _socket_error : -1;
    }
    msg->id = sockid(s); 
    msg->ud = s->ud;
    if (err == 0) {
        s->status = STATUS_CONNECTED;
        _subscribe(self, s, 0);
        msg->type = SOCKET_TYPE_CONNECT;
    } else {
        _close_socket(self, s);
        msg->type = SOCKET_TYPE_CONNERR;
    }
    return 1;
}

int
socket_connect(struct net *self, const char *addr, int port, int block, int ud, int *conning) {
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC; // allow IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM; 
    hints.ai_protocol = IPPROTO_TCP;

    char sport[16];
    snprintf(sport, sizeof(sport), "%u", port);
    if (getaddrinfo(addr, sport, &hints, &result)) {
        return -1;
    }
    int fd = -1, status;
    for (rp = result; rp != NULL; rp = rp->ai_next) {
        fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (fd == -1)
            continue;
        if (_socket_keepalive(fd) != 0) {
            _socket_close(fd);
            return -1;
        }
        if (!block)
            if (_socket_nonblocking(fd) == -1) {
                _socket_close(fd);
                return -1;
            }
        if (connect(fd, rp->ai_addr, rp->ai_addrlen) == -1) {
            if (block) {
                _socket_close(fd);
                fd = -1;
                continue;
            } else {
                int err = _socket_geterror(fd);
                if (!SECONNECTING(err)) {
                    _socket_close(fd);
                    fd = -1;
                    continue;
                }
            }
            status = STATUS_CONNECTING;
        } else {
            status = STATUS_CONNECTED;
        }
        if (block)
            if (_socket_nonblocking(fd) == -1) { // 仅connect阻塞
                return -1;
            }
        break;
    }
    freeaddrinfo(result);
    if (fd == -1)  {
        return -1;
    }
    struct socket *s;
    s = _create_socket(self, fd, ud, SOCKET_PROTOCOL_TCP);
    if (s == NULL) {
        _socket_close(fd);
        return -1;
    }
    s->status = status;
    if (s->status == STATUS_CONNECTING) {
        if (_subscribe(self, s, NP_RABLE|NP_WABLE)) {
            _close_socket(self, s);
            return -1;
        }
        if (conning) *conning = 1;
    }
    return sockid(s);
}

int
socket_poll(struct net *self, int timeout, struct socket_message *msg, int *more) {
    if (self->event_index == self->event_count) {
        int n = np_poll(&self->np, self->events, self->max, timeout);
        if (n > 0) {
            self->event_count = n;
            self->event_index = 0;
        } else return 0;
    }
    struct np_event *event = &self->events[self->event_index++];
    if (more &&
        self->event_index == self->event_count)
        *more = 0;
    struct socket *s = (struct socket *)event->ud;
    switch (s->status) {
    case STATUS_LISTENING: {
        struct socket *lis = s;
        return _accept(self, lis, msg);
        }
    case STATUS_CONNECTING:
        return _onconnect(self, s, msg);
    case STATUS_INVALID:
        return 0;
    default: 
        if (event->write) {
            if (_send_buffer(self, s, msg))
                return 1;
        }
        if (event->read) {
            if (_read(self, s, msg)) 
                return 1;
        }
        return 0;
    }
}

int 
socket_fd(struct net *self, int id) {
    struct socket *s = _socket(self, id);
    return s ? s->fd : -1;
}
