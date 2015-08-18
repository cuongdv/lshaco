#include "sh.h"
#include "args.h"
#include "socket_buffer.h"
#include "socket_platform.h"
#include <unistd.h>

#define NODE_MAX 256

#define MSG_MAX 63*1024

struct sub_ent {
    int handle;
    char *name;
    bool active;
};

struct pub_ent {
    int handle;
    char *name;
};

struct node {
    int id;
    int node_handle;
    struct sh_node_addr addr; 
    uint64_t last_heartbeat;
};

struct remote {
    int heartbeat_tick;
    int master_handle;
    int myid;
    struct node nodes[NODE_MAX];
    struct sh_array buffers;
    struct sh_array subs;
    struct sh_array pubs;
};

#define MASTERID(self) sh_nodeid_from_handle((self)->master_handle)
#define MYID(self) (self)->myid
#define NODE_ME(self) node_index(self, MYID(self))

// buffer
struct buffer {
    int id;
    struct socket_buffer sb;
};

static void 
buffer_initall(struct remote *self) {
    // todo: node_read 中buffer_find之后处理消息过程可能会realloc这个array，导致buffer地址变更
    // 所以这里暂时初始化为NODE_MAX*2, 防止realloc
    sh_array_init(&self->buffers, sizeof(struct buffer), NODE_MAX*2);
}

static void
buffer_finiall(struct remote *self) {
    int i;
    for (i=0; i<self->buffers.nelem; ++i) {
        struct buffer *b = sh_array_get(&self->buffers, i);
        sb_fini(&b->sb);
    }
    sh_array_fini(&self->buffers);
}

static struct socket_buffer *
buffer_find(struct remote *self, int id) {
    int i;
    for (i=0; i<self->buffers.nelem; ++i) {
        struct buffer *b = sh_array_get(&self->buffers, i);
        if (b->id == id) {
            return &b->sb;
        }
    }
    return NULL;
}

static void
buffer_enable(struct remote *self, int id) {
    sh_socket_subscribe(id, true);
    if (buffer_find(self, id)) {
        return;
    }
    struct buffer *b = sh_array_push(&self->buffers);
    b->id = id;
    sb_init(&b->sb);
}

static void
buffer_disable(struct remote *self, int id) {
    int i;
    for (i=0; i<self->buffers.nelem; ++i) {
        struct buffer *b = sh_array_get(&self->buffers, i);
        if (b->id == id) {
            sb_fini(&b->sb);
            sh_array_remove(&self->buffers, i);
            return;
        }
    }
}

static inline bool
is_master(struct remote *self) {
    return MASTERID(self) == 0;
}

#pragma pack(1)
struct header {
    uint16_t source;
    uint16_t dest;
    int session;
    int type;
};
#pragma pack()

#define HEADSZ 8

static void *
readhead(void *p, struct header *hd) {
    hd->source = sh_from_littleendian16((uint8_t*)p);
    hd->dest   = sh_from_littleendian16((uint8_t*)p+2);
    hd->session= sh_from_littleendian32((uint8_t*)p+4);
    hd->type   = (hd->dest>>8) & 0xff;
    hd->dest  &= 0xff;
    return p+HEADSZ;
}

static int
b_send(int fd, void *data, int sz) {
    int n;
    while (sz > 0) {
        n = _socket_write(fd, data, sz);
        if (n<0) {
            int err = _socket_geterror(fd);
            if (err != SEAGAIN &&
                err != SEINTR) {
                return err;
            }
        } else {
            data += n;
            sz -= n;
        }
    }
    return 0;
}

static int
b_read(int fd, void *data, int sz) {
    int n;
    while (sz>0) {
        n = _socket_read(fd, data, sz);
        if (n<0) {
            int err = _socket_geterror(fd);
            if (err != SEAGAIN &&
                err != SEINTR)
                return err;
        } else if (n==0) {
            return -1;
        } else {
            data += n;
            sz -= n;
        }
    } 
    return 0;
}

// cmd
static inline int
cmd_REG(struct node *o, int nodeid, char *cmd, int n) {
    return sh_snprintf(cmd, n, "%d %s %u %s %u %s %04x",
            nodeid,
            o->addr.naddr, o->addr.nport, 
            o->addr.gaddr, o->addr.gport, 
            o->addr.waddr, o->node_handle); 
}

static inline int
cmd_UNREG(int nodeid, char *cmd, int n) {
    return sh_snprintf(cmd, n, "UNREG %d", nodeid);
}


static inline int
cmd_ADDR(struct node *o, int nodeid, char *cmd, int n) {
    return sh_snprintf(cmd, n, "ADDR %d %s %u %s %u %s %04x",
            nodeid,
            o->addr.naddr, o->addr.nport,
            o->addr.gaddr, o->addr.gport,
            o->addr.waddr, o->node_handle);
}

static inline int
cmd_SUB(const char *name, char *cmd, int n) {
    return sh_snprintf(cmd, n, "SUB %s", name);
}

static inline int
cmd_PUB(const char *name, int handle, char *cmd, int n) {
    return sh_snprintf(cmd, n, "PUB %s:%04x", name, handle);
}

// node 
static inline void
node_bound_address(struct node *no, 
        const char *naddr, int nport, 
        const char *gaddr, int gport,
        const char *waddr) {
    sh_strncpy(no->addr.naddr, naddr, sizeof(no->addr.naddr));
    sh_strncpy(no->addr.gaddr, gaddr, sizeof(no->addr.gaddr));
    sh_strncpy(no->addr.waddr, waddr, sizeof(no->addr.waddr));
    no->addr.nport = nport;
    no->addr.gport = gport;
}

static inline void
node_bound_entry(struct node *no, int handle) {
    no->node_handle = handle;
}

static inline void
node_bound_connection(struct node *no, int id) {
    no->id = id;
    no->last_heartbeat = sh_timer_now();
}

static inline struct node *
node_index(struct remote *self, int id) {
    return (id>0 && id<NODE_MAX) ? &self->nodes[id] : NULL;
}

static struct node *
node_find(struct remote *self, int id) {
    int i;
    for (i=0; i<NODE_MAX; ++i)
        if (self->nodes[i].id == id) 
            return &self->nodes[i];
    return NULL;
}

static int
node_connect(struct module *s, struct node *o) {
    struct remote *self = MODULE_SELF;
    if (o->id != -1) return 0;
    int32_t nodeid = o-self->nodes;
    struct sh_node_addr *ad = &o->addr; 
    int id = sh_socket_blockconnect(ad->naddr, ad->nport, MODULE_ID);
    if (id < 0) {
        sh_error("Connect node(%d) %s:%u fail: %s", nodeid, ad->naddr, ad->nport, SH_SOCKETERR);
        return 1;
    }
    int32_t ok;
    int fd = sh_socket_fd(id);
    assert(fd != -1);
    b_send(fd, &self->myid, 4);
    b_read(fd, &ok, 4);
    assert(ok==1);
    buffer_enable(self, id);
    node_bound_connection(o, id); 
    sh_info("Connect node(%d:%d) %s:%u ok", id, id, ad->naddr, ad->nport);
    return 0;
}

static void
node_disconnect(struct module *s, int id) {
    struct remote *self = MODULE_SELF;
    struct node *o = node_find(self, id);
    if (o) {
        int nodeid = o-self->nodes;
        sh_info("Node(%d:%d) disconnect", nodeid, id);
        o->id = -1;
        o->node_handle = -1;
        buffer_disable(self, id);
        //sh_node_exit(nodeid);
        int i;
        struct sh_array *a = &self->subs;
        for (i=0;i<a->nelem;++i) {
            struct sub_ent *e = sh_array_get(a,i);
            if (e->handle !=-1 &&
                sh_nodeid_from_handle(e->handle) == nodeid) {
                sh_handle_exit(e->handle);
            }
        }
        if (is_master(self)) {
            char cmd[64];
            int sz = cmd_UNREG(nodeid, cmd, sizeof(cmd));
            sh_handle_send(MODULE_ID, self->master_handle, MT_TEXT, cmd, sz);
        }
    }
}

// handle
static int
conn_send(struct remote *self, int id, int session, int source, int dest, int type, const void *msg, size_t sz) { 
    if (sz > MSG_MAX) {
        sh_error("Too large msg from %04x to %04x", source, dest);
        return 1;
    }
    int len = sz+10;
    source &= 0x00ff;
    source |= (self->myid << 8);
    dest   &= 0x00ff;
    dest   |= (type << 8);
    uint8_t *tmp = sh_malloc(len);
    sh_to_littleendian16(len-2, tmp);
    sh_to_littleendian16(source, tmp+2);
    sh_to_littleendian16(dest, tmp+4);
    sh_to_littleendian32(session, tmp+6);
    memcpy(tmp+10, msg, sz);
    //sh_trace("send to socket %d", id);
    return sh_socket_send(id, tmp, len);
}

static int
handle_send(struct remote *self, int session, int source, int dest, int type, const void *msg, size_t sz) {
    char tmp[sz+1];
    memcpy(tmp, msg, sz);
    tmp[sz] = '\0';
    if (dest <= 0) {
        sh_error("Invalid dest %04x", dest);
        return 1;
    }
    int nodeid = sh_nodeid_from_handle(dest);
    struct node *o = node_index(self, nodeid);
    if (o == NULL) {
        sh_error("Invalid nodeid from dest %04x", dest);
        return 1;
    }
    if (o->id == -1) {
        sh_error("Node(%d) has not connect, by dest %04x", nodeid, dest);
        return 1;
    }
    return conn_send(self, o->id, session, source, dest, type, msg, sz);
}

static int
handle_connect(struct module *s, const char *name, int handle) {
    struct remote *self = MODULE_SELF;
    int id = sh_nodeid_from_handle(handle);
    if (id == 0) id = self->myid;
    struct node *o = node_index(self, id);
    if (o == NULL) {
        sh_error("Connect handle %s:%d fail: Invalid node(%d)", name, handle, id);
        return 1;
    }
    if (id != self->myid) {
        if (node_connect(s, o))
            return 1;
    } else
        handle = sh_moduleid_from_handle(handle);
    sh_handle_start(name, handle);
    return 0;
}

static int
handle_subscribe(struct module *s, const char *name) {
    struct remote *self = MODULE_SELF;
    int handle = module_query_id(name);
    if (handle != -1) {
        handle_connect(s, name, handle); // if local has mod also, connect it
    }
    char cmd[128];
    int sz = cmd_SUB(name, cmd, sizeof(cmd));
    return sh_handle_send(MODULE_ID, self->master_handle, MT_TEXT, cmd, sz);
}

static int
handle_publish(struct module *s, const char *name, int handle) {
    struct remote *self = MODULE_SELF;
    handle &= 0xff;
    handle |= (self->myid << 8) & 0xff00;
    char cmd[128];
    int sz = cmd_PUB(name, handle, cmd, sizeof(cmd));
    return sh_handle_send(MODULE_ID, self->master_handle, MT_TEXT, cmd, sz);
}

// cache sub pub
static void
cache_init(struct remote *self) {
    sh_array_init(&self->subs, sizeof(struct sub_ent), 1);
    sh_array_init(&self->pubs, sizeof(struct pub_ent), 1);
}

static void
cache_fini(struct remote *self) {
    int i;
    for (i=0; i<self->subs.nelem; ++i) {
        struct sub_ent *e = sh_array_get(&self->subs, i);
        sh_free(e->name);
    }
    for (i=0; i<self->pubs.nelem; ++i) {
        struct pub_ent *e = sh_array_get(&self->pubs, i);
        sh_free(e->name);
    }
    sh_array_fini(&self->subs);
    sh_array_fini(&self->pubs);
}

static struct sub_ent *
get_sub(struct remote *self, const char *name) {
    struct sh_array *a = &self->subs;
    int i;
    for (i=0; i<a->nelem; ++i) {
        struct sub_ent *e = sh_array_get(a, i);
        if (!strcmp(e->name, name)) {
            return e;
        }
    }
    return NULL;
}

static void
cache_sub(struct sh_array *a, const char *name, bool active) {
    int i;
    for (i=0; i<a->nelem; ++i) {
        struct sub_ent *e = sh_array_get(a, i);
        if (!strcmp(e->name, name)) return;
    }
    struct sub_ent *e = sh_array_push(a);
    e->handle = -1;
    e->name = sh_strdup(name);
    e->active = active;
}

static void
cache_pub(struct sh_array *pubs, const char *name, int handle) {
    int i;
    for (i=0; i<pubs->nelem; ++i) {
        struct pub_ent *e = sh_array_get(pubs, i);
        if (!strcmp(e->name, name)) return;
    }
    struct pub_ent *e = sh_array_push(pubs);
    e->handle = handle;
    e->name = sh_strdup(name);
}

static void
cache_redo(struct module *s) {
    struct remote *self = MODULE_SELF;
    int i;
    for (i=0; i<self->subs.nelem; ++i) {
        struct sub_ent *e = sh_array_get(&self->subs, i);
        handle_subscribe(s, e->name);
    }
    for (i=0; i<self->pubs.nelem; ++i) {
        struct pub_ent *e = sh_array_get(&self->pubs, i);
        handle_publish(s, e->name, e->handle);
    }
}

static void
getaddr(const char *addr, char ip[40], int *port) {
    char *p = strchr(addr, ':');
    if (p) {
        int sz = p-addr;
        if (sz>39) sz=39;
        memcpy(ip, addr, sz);
        ip[sz]='\0';
        *port = strtol(p+1, NULL, 10);
    } else {
        sh_strncpy(ip, addr, 40);
        *port = 0;
    }
}

// initialize
static int
node_me_init(struct module *s) {
    struct remote *self = MODULE_SELF; 
    int nodeid = sh_getint("id", 0);
    struct node *o = node_index(self, nodeid);
    if (o == NULL) {
        sh_error("Invalid node id %d", nodeid);
        return 1;
    }
    const char *nodeaddr = sh_getstr("address", "0");
    char nodeip[40];
    int  nodeport;
    getaddr(nodeaddr, nodeip, &nodeport);

    const char *gateaddr = sh_getstr("gateaddress", "0");
    char gateip[40];
    int  gateport;
    getaddr(gateaddr, gateip, &gateport);
    node_bound_address(o, nodeip, nodeport, gateip, gateport, "0");
    node_bound_entry(o, sh_handleid(nodeid, MODULE_ID));
    self->myid = nodeid;
    return 0;
}

static int
node_listen(struct module *s) {
    struct remote *self = MODULE_SELF;
    struct node *my = NODE_ME(self);
    assert(my);
    int id = sh_socket_listen(my->addr.naddr, my->addr.nport, s->moduleid);
    if (id == -1) {
        sh_error("Node listen on %s:%d err: %s", my->addr.naddr, my->addr.nport, SH_SOCKETERR);
        return 1;
    }
    sh_info("Node listen on %s:%u [%d]", my->addr.naddr, my->addr.nport, id);
    sh_info("Node[%d:%02x] start", id, self->myid);
    return 0;
}

static int
connect_to_master(struct module* s) {
    struct remote *self = MODULE_SELF;
    const char *addr = sh_getstr("master", "0");
    char ip[40];
    int  port;
    getaddr(addr, ip, &port);
    int id = sh_socket_blockconnect(ip, port, MODULE_ID);
    if (id < 0) {
        sh_error("Connect master fail: %s", SH_SOCKETERR);
        return 1;
    }
    struct node nc;
    memset(&nc, 0, sizeof(nc));
    node_bound_address(&nc, ip, port, "", 0, "");
    buffer_enable(self, id);
    node_bound_connection(&nc, id);

    int fd = sh_socket_fd(id);
    char entry[8];
    b_read(fd, entry, 8);

    self->master_handle = *(int32_t*)&entry[0];
    int node_handle   = *(int32_t*)&entry[4];
    node_bound_entry(&nc, node_handle);

    int masterid = MASTERID(self);
    struct node *o = node_index(self, masterid);
    if (o == NULL) {
        sh_error("Reg master node fail");
        return 1;
    }
    *o = nc;

    struct node *me = NODE_ME(self);
    char reg[256];
    int32_t sz = cmd_REG(me, self->myid, reg, sizeof(reg));
    b_send(fd, &sz, 4);
    b_send(fd, reg, sz);
  
    int32_t ok;
    b_read(fd, &ok, 4);
    
    sh_info("Connect master(%d) %s:%u ok", masterid, ip, port); 
    return 0;
}

static int
broadcast_node(struct module *s, int nodeid) {
    struct remote *self = MODULE_SELF;
    struct node *me = node_index(self, nodeid);
    if (me == NULL) return 1;
    if (me->id == -1) return 1;
    
    char cmd[256];
    int sz, i;
    // boradcast me
    for (i=0; i<NODE_MAX; ++i) {
        struct node *ot = &self->nodes[i];
        if (i == nodeid || i == self->myid) 
            continue;
        if (ot->id == -1) 
            continue;
        sz = cmd_ADDR(me, nodeid, cmd, sizeof(cmd));
        handle_send(self, 0, MODULE_ID, ot->node_handle, MT_TEXT, cmd, sz);
    }

    // get other
    for (i=0; i<NODE_MAX; ++i) {
        struct node *ot = &self->nodes[i];
        if (i == nodeid)
            continue;
        if (ot->id == -1 ||
            me->id == -1)
            continue;
        sz = cmd_ADDR(ot, i, cmd, sizeof(cmd));
        handle_send(self, 0, MODULE_ID, me->node_handle, MT_TEXT, cmd, sz);
    }
    return 0;
}

// node
struct remote *
node_create() {
    struct remote* self = sh_malloc(sizeof(*self));
    memset(self, 0, sizeof(*self));
    self->master_handle = -1;
    int i;
    for (i=0; i<NODE_MAX; ++i) {
        self->nodes[i].id = -1;
        self->nodes[i].node_handle = -1;
    }
    return self;
}

void
node_free(struct remote* self) {
    if (self == NULL)
        return;

    buffer_finiall(self);
    cache_fini(self); 
    sh_free(self);
}

int
node_init(struct module* s) {
    struct remote *self = MODULE_SELF;
    if (node_me_init(s)) {
        return 1;
    }
    if (node_listen(s)) {
        return 1;
    }
    buffer_initall(self);
    cache_init(self); 
    self->master_handle = module_query_id("master");
    if (self->master_handle == -1) {
        if (connect_to_master(s))
            return 1;
    }
    int heartbeat_tick = sh_getint("node_heartbeat", 3);
    if (heartbeat_tick < 3)
        heartbeat_tick = 3;
    else if (heartbeat_tick > 30)
        heartbeat_tick = 30;

    self->heartbeat_tick = heartbeat_tick * 1000;
    sh_timer_register(MODULE_ID, 0, self->heartbeat_tick);
    return 0;
}
static int COUNT=0;
static uint64_t LAST_TIME=0;
static void
node_read(struct module *s, struct socket_event *event) {
    struct remote *self = MODULE_SELF;
  
    struct socket_buffer *sb = buffer_find(self, event->id);
    if (sb == NULL) return;
    int err;
    void *data;
    int n = sh_socket_read(event->id, &data);
    if (n < 0) {
        err = sh_socket_lasterrno();
        goto errout;
    } else if (n == 0) {
        return;
    } 
    sb_push(sb, data, n);
    uint64_t now = sh_timer_now();
    if (COUNT==0) {
        LAST_TIME = now;
    }
    
    int c = 0;
    for (;;) {
        struct socket_pack pk;
        if (sb_pop(sb, &pk)) 
            break;
        if (pk.sz <= HEADSZ) {
            sh_free(pk.p);
            err = LS_ERR_MSG;
            goto errout;
        }
        struct header hd;
        void *p = readhead(pk.p, &hd);
        sh_handle_call(hd.session, hd.source, 
                hd.dest, hd.type, 
                p, pk.sz-HEADSZ);
        sh_free(pk.p);
        c++;
    } 
    COUNT += c;
    if (now - LAST_TIME > 1000) {
        //sh_error("------ unit stat:%.02f\n", COUNT/((now-LAST_TIME)/1000.f));
        COUNT = 0;
    }
    return;
errout:
    event->type = LS_ESOCKERR;
    event->err = err;
    module_main(event->udata, 0, 0, MT_SOCKET, event, sizeof(*event));
}

void
node_send(struct module *s, int session, int source, int dest, int type, const void *msg, int sz) {
    handle_send(MODULE_SELF, session, source, dest, type, msg, sz);
}

void
_socket(struct module* s, struct socket_event* event) {
    struct remote *self = MODULE_SELF;
    switch (event->type) {
    case LS_EREAD:
        node_read(s, event);
        break;
    case LS_EACCEPT: {
        int id = event->id;
        int fd = sh_socket_fd(id);
        int nodeid;
        struct node *o;
        if (is_master(self)) {
            struct node *me = NODE_ME(self);
            char entry[8];
            *(int32_t*)&entry[0] = sh_handleid(self->myid, self->master_handle);
            *(int32_t*)&entry[4] = me->node_handle;
            b_send(fd, entry, sizeof(entry));

            int32_t sz;
            b_read(fd, &sz, 4);
            char reg[sz];
            b_read(fd, reg, sz);
            struct args A;
            assert(args_parsestrl(&A, 0, reg, sz, ' ') == 7);
          
            nodeid = strtol(A.argv[0], NULL, 10);
            const char *naddr = A.argv[1];
            int nport = strtol(A.argv[2], NULL, 10);
            const char *gaddr = A.argv[3];
            int gport = strtol(A.argv[4], NULL, 10);
            const char *waddr = A.argv[5];
            int node_handle = strtol(A.argv[6], NULL, 16);

            o = node_index(self, nodeid);
            node_bound_address(o, naddr, nport, gaddr, gport, waddr);
            node_bound_entry(o, node_handle);
            buffer_enable(self, id);
            node_bound_connection(o, id); 

            int32_t ok=1;
            b_send(fd, &ok, 4);
            
            sh_info("Accept node[%d:%02x]", id, nodeid);

            broadcast_node(s, nodeid);
        } else {
            b_read(fd, &nodeid, 4);
            o = node_index(self, nodeid);
            if (o== NULL) {
                sh_socket_close(id, true);
                break;
            }
            int32_t ok=1;
            b_send(fd, &ok, 4);

            sh_info("Accept node[%d:%02x]", id, nodeid);
            int i;
            struct sh_array *a = &self->subs;
            for (i=0;i<a->nelem;++i) {
                struct sub_ent *e = sh_array_get(a,i);
                //sh_trace("+++++++ %s:%d", e->name, e->handle);
                if (!e->active) {
                    if (nodeid == sh_nodeid_from_handle(e->handle)) {
                        sh_handle_start(e->name, e->handle);
                    }
                }
            }
            buffer_enable(self, id);
            node_bound_connection(o, id); 
        }} break;
    //case LS_ECONNECT:
        //sh_info("connect to node ok, %d", event->id);
        //break;
    //case LS_ECONNERR:
        //sh_error("connect to node fail: %s", sh_socket_error(event->error));
        //break;
    case LS_ESOCKERR:
        sh_error("node disconnect: %s, %d", sh_socket_error(event->err), event->id);
        node_disconnect(s, event->id);
        break;
    default:
        sh_error("node unknown net event %d, %d", event->type, event->id);
        break;
    }
}

void
_time(struct module* s) {
    struct remote *self = MODULE_SELF;
    uint64_t now = sh_timer_now();
    int i;
    for (i=0; i<NODE_MAX; ++i) {
        struct node *o = &self->nodes[i];
        if (o->id != -1 && o->node_handle != -1) {
            if (now - o->last_heartbeat >= self->heartbeat_tick) {
                //handle_send(self, 0, MODULE_ID, o->node_handle, MT_TEXT, "HB", 2);
            }
        }
    }
    int id = MASTERID(self);
    if (id > 0) {
        struct node *o = node_index(self, id);
        if (o && o->id == -1) {
            if (!connect_to_master(s))
                cache_redo(s);
        }
    }
    sh_timer_register(MODULE_ID, 0, self->heartbeat_tick);
}

void
node_main(struct module *s, int session, int source, int type, const void *msg, int sz) {
    //sh_trace("command in");
  
    if (type == MT_SOCKET) {
        struct socket_event *event = (struct socket_event *)msg;
        assert(sizeof(*event) == sz);
        _socket(s, event);
    } else if (type == MT_TIME) {
        _time(s);
    } else if (type == MT_TEXT) {
    struct remote *self = MODULE_SELF;
    struct args A;
    if (args_parsestrl(&A, 0, msg, sz, ' ') < 1)
        return;

    const char *cmd = A.argv[0];
    
    if (!strcmp(cmd, "ADDR")) {
        //sh_trace("----- addr come");
        if (A.argc != 8)
            return;
        int id = strtol(A.argv[1], NULL, 10);
        const char *naddr = A.argv[2];
        int nport = strtol(A.argv[3], NULL, 10);
        const char *gaddr = A.argv[4];
        int gport = strtol(A.argv[5], NULL, 10);
        const char *waddr = A.argv[6];
        int node_handle = strtol(A.argv[7], NULL, 16);
//sh_trace("----- addr come 2");

        if (id > 0) {
            struct node *no = node_index(self, id);
            if (no) {
//sh_trace("----- addr come 3");

                node_bound_address(no, naddr, nport, gaddr, gport, waddr);
                node_bound_entry(no, node_handle);
                // no need connect each other
                //node_connect(s, no); 
            }
        }
    } else if (!strcmp(cmd, "BROADCAST")) {
        if (A.argc != 2)
            return;
        int id = strtol(A.argv[1], NULL, 10);
        broadcast_node(s, id);
    } else if (!strcmp(cmd, "SUB")) {
        if (A.argc != 3)
            return;
        const char *name = A.argv[1];
        int active = strtol(A.argv[2], NULL, 10);
        //sh_trace("sub %s", name);
        cache_sub(&self->subs, name, active!=0);
        handle_subscribe(s, name); 
    } else if (!strcmp(cmd, "PUB")) {
        if (A.argc != 2)
            return;
        const char *name = A.argv[1];
        char *p = strchr(name, ':');
        if (p) {
            p[0] = '\0';
            int handle = strtol(p+1, NULL, 16); 
            //sh_trace("pub %s:%d", name, handle);
            cache_pub(&self->pubs, name, handle);
            handle_publish(s, name, handle);
        }
    } else if (!strcmp(cmd, "HANDLE")) { // after subscribe
        //sh_trace("handle come");
        if (A.argc != 2)
            return;
        const char *name = A.argv[1];
        char *p = strchr(name, ':');
        if (p==NULL)
            return;
        p[0] = '\0';
        struct sub_ent *sub = get_sub(self, name);
        if (sub == NULL) {
            return;
        }
        int handle = strtol(p+1, NULL, 16); 
        //sh_trace("%d, %s", handle, name);
        if (sub->active ||
            is_master(self) ||
            MASTERID(self) == sh_nodeid_from_handle(handle)) {
            handle_connect(s, name, handle);
        } else {
            int nodeid = sh_nodeid_from_handle(handle);
            //sh_trace("------------------------- handle %d, nodeid %d", handle, nodeid);
            struct node *o = node_index(self, nodeid);
            //sh_trace("----------------------%p %d", o, o ? o->id:123456);
            if (o && o->id !=-1) {
                sh_handle_start(name, handle);
            }
        }
        sub->handle=handle;
    } 
    }
}
