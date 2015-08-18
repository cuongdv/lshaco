#include "sh.h"
#include "freeid.h"
#include "cmdctl.h"
#include "msg_client.h"
#include "msg_server.h"

/*
 * control the client connect, login, heartbeat, and logout, 
 * the handler module only focus on logined client
 */

#define S_FREE        0
#define S_CONNECTED   1
#define S_LOGINED     2
#define S_LOGOUTED    3

struct client {
    int connid;
    int status;
    uint64_t active_time;
};

struct gate {
    int load_handle;
    int load_size;
    int load_max_interval;
    int last_load;
    uint64_t last_load_time; 
    int handler;
    bool handler_down;
    int livetime;
    bool need_verify;

    int cmax;
    int used;
    struct freeid fi;
    struct client* p;
};

// gate
static inline void
update_load(struct module *s, bool force) {
    /*struct gate *self = MODULE_SELF;
    if (self->load_handle == -1) {
        return;
    }
    uint64_t now = sh_timer_now();
    int cur_load = self->handler_down ? INT_MAX : self->used;
    int diff_load = abs(cur_load - self->last_load);
    if (force ||
        (self->load_size <= diff_load) ||
        ((diff_load > 0) &&
         (self->load_max_interval <= now - self->last_load_time))) {

        UM_DEFFIX(UM_UPDATELOAD, load);
        load->value = cur_load;
        sh_handle_send(MODULE_ID, self->load_handle, MT_UM, load, sizeof(*load));

        self->last_load = cur_load;
        self->last_load_time = now;
    }*/
}

static void
init_clients(struct gate *self, int cmax, int hmax) {
    assert(cmax > 0);
    self->cmax = cmax;
    self->p = sh_malloc(sizeof(self->p[0]) * cmax);
    memset(self->p, 0, sizeof(self->p[0]) * cmax);
    freeid_init(&self->fi, cmax, hmax);
}

static void
free_clients(struct gate *self) {
    freeid_fini(&self->fi);
    sh_free(self->p);
    self->p = NULL;
}

static inline void
send_to_client(int connid, void *data, int sz) {
    uint8_t *tmp = sh_malloc(sz+2);
    sh_to_littleendian16(sz, tmp);
    memcpy(tmp+2, data, sz);
    sh_socket_send(connid, tmp, sz+2);
}

static inline void
notify_logout(int connid, int err) {
    UM_DEFFIX(UM_LOGOUT, lo);
    lo->err = err;
    send_to_client(connid, lo, sizeof(*lo));
}

static inline struct client*
accept_client(struct module *s, int connid) {
    struct gate *self = MODULE_SELF;
    assert(connid != -1);
    if (self->handler_down) {
        notify_logout(connid, SERR_GATEHANDLEEXIT);
        sh_socket_close(connid, true);
        return NULL;
    }
    int id = freeid_alloc(&self->fi, connid);
    if (id == -1) {
        notify_logout(connid, SERR_GATEFULL);
        sh_socket_close(connid, true);
        return NULL;
    }
    assert(id >= 0 && id < self->cmax);
    struct client* c = &self->p[id];
    assert(c->status == S_FREE);
    c->connid = connid;
    c->status = S_CONNECTED;
    c->active_time = sh_timer_now();
    sh_socket_subscribe(connid, true);
    self->used++;

    update_load(s, false);
    return c;
}

static inline void 
login_client(struct client* c) { 
    if (c->status == S_CONNECTED) {
        c->status = S_LOGINED; 
        c->active_time = sh_timer_now();
    }
}

static bool
disconnect_client(struct module *s, struct client* c, bool force) {
    struct gate *self = MODULE_SELF;
    if (c->status == S_FREE)
        return true;
    bool closed = sh_socket_close(c->connid, force);
    if (closed) {
        int id = freeid_free(&self->fi, c->connid);
        assert(id == (c-self->p));
        c->status = S_FREE;
        c->active_time = 0;
        self->used--;

        update_load(s, false);
    } else {
        if (c->status != S_LOGOUTED) {
            c->status = S_LOGOUTED;
            c->active_time = sh_timer_now();
        }
    }
    return closed;
}

static inline struct client* 
get_client(struct gate *self, int connid) {
   int id = freeid_find(&self->fi, connid);
   if (id == -1)
       return NULL;
   assert(id >= 0 && id < self->cmax);
   struct client* c = &self->p[id];
   assert(c->connid == connid);
   return c;
}

struct gate*
gate_create() {
    struct gate* self = sh_malloc(sizeof(*self));
    memset(self, 0, sizeof(*self));
    return self;
}

void
gate_free(struct gate* self) {
    if (self == NULL)
        return;
    free_clients(self);
    sh_free(self);
}

static int
listen_gate(struct module* s) { 
    const char* addr = sh_getstr("gate_ip", "");
    int port = sh_getint("gate_port", 0);
    int wbuffermax = sh_getint("gate_wbuffermax", 0);
    if (addr[0] == '\0')
        return 1;
    int err;
    int id = sh_socket_listen(addr, port, wbuffermax, MODULE_ID, 0, &err);
    if (id == -1) {
        sh_error("Gate listen on %s:%d err: %s", addr, port, sh_socket_error(err));
        return 1;
    }
    sh_info("Gate listen on %s:%u [%d]", addr, port, id);
    return 0;
}

int
gate_init(struct module* s) {
    MY_LOG("check %d", 1);
    struct gate* self = MODULE_SELF;
    self->handler_down = false; 
    if (sh_getint("gate_publish", 1)) {
        if (sh_handle_publish(MODULE_NAME, PUB_SER))
            return 1;
    }
    const char* hname = sh_getstr("gate_handler", "");
    self->handler = module_query_id(hname);
    if (self->handler == -1) {
        struct sh_monitor h = { MODULE_ID, MODULE_ID };
        if (sh_handle_monitor(hname, &h, &self->handler, 1)) {
            return 1;
        }
    }
    self->load_handle = -1;
    const char *lname = sh_getstr("gate_load", "");
    if (lname[0] != '\0') {
        struct sh_monitor h = { MODULE_ID, -1 };
        if (sh_handle_monitor(lname, &h, &self->load_handle, 1)) {
            return 1;
        }
    }
    self->load_size = sh_max(1, sh_getint("gate_load_size", 1));
    self->load_max_interval = sh_getint("gate_load_max_interval", 0);
    self->last_load_time = sh_timer_now();
    
    if (listen_gate(s)) {
        return 1;
    }
    int cmax = sh_getint("gate_clientmax", 0);
    int hmax = sh_getint("connmax", cmax);
    if (cmax <= 0)
        cmax = 1;
    init_clients(self, cmax, hmax);
    sh_info("gate_clientmax = %d", cmax);

    self->need_verify = false;//sh_getint("gate_need_verify", 1);
    
    int live = sh_getint("gate_clientlive", 3);
    self->livetime = live * 1000;
    sh_timer_register(MODULE_ID, 1000);
    return 0;
}

static inline int
handle(struct module *s, struct client* c, const void *msg, int sz) {
    if (sz < sizeof(struct UM_BASE) || sz > UM_CLI_MAXSZ) {
        return 1;
    }
    struct gate *self = MODULE_SELF;
    UM_CAST(UM_BASE, um, msg);
    if (um->msgid >= IDUM_GATEB && um->msgid < IDUM_GATEE) {
        if (c->status == S_LOGINED) {
            c->active_time = sh_timer_now();
        } 
        if (um->msgid != IDUM_HEARTBEAT) {
            UM_DEFWRAP2(UM_GATE, ga, UM_CLI_MAXSZ);
            ga->connid = c->connid;
            memcpy(ga->wrap, msg, sz);

            sh_trace("Client %d receive msg: %u", c->connid, um->msgid);
            sh_handle_send(MODULE_ID, self->handler, MT_UM, ga, sizeof(*ga)+sz);
        }
    }
    return 0;
}

static void
read(struct module* s, struct client* c, struct net_event* nm) {
    int id = nm->connid;
    int err = 0; 
    struct mread_buffer buf;
    int nread = sh_socket_read(id, &buf, &err); 
    if (nread > 0) {
        for (;;) {
            if (buf.sz < 2) {
                break;
            }
            uint16_t sz = sh_from_littleendian16((uint8_t*)buf.ptr) + 2;
            if (buf.sz < sz) {
                break;
            }
            if (handle(s, c, buf.ptr+2, sz-2)) {
                err = NET_ERR_MSG;
                sh_socket_close(id, true);
                goto errout;
            }
            buf.ptr += sz;
            buf.sz  -= sz;
        }
        int drop = nread - buf.sz;
        if (drop) {
            sh_socket_dropread(id, drop);
        }
    } else if (nread < 0) {
        goto errout;
    }
    return;
errout:
    nm->type = LS_ESOCKERR;
    nm->error = err;
    module_net(nm->ud, nm);
}

static inline void
forward_connect(struct module *s, struct client *c) {
    struct gate *self = MODULE_SELF; 
    UM_DEFWRAP(UM_GATE, ga, UM_NETCONNECT, nc);
    ga->connid = c->connid;
    //nc->ip[0] = '\0'; // valgrind uninitialised byte
    memset(nc->ip, 0, sizeof(nc->ip));
    uint16_t port = 0;
    sh_socket_address(c->connid, nc->ip, &port);
    sh_handle_send(MODULE_ID, self->handler, MT_UM, ga, sizeof(*ga)+sizeof(*nc));
}

static inline void
forward_disconnect(struct module *s, struct client *c, int type, int err) {
    struct gate *self = MODULE_SELF;
    UM_DEFWRAP(UM_GATE, ga, UM_NETDISCONN, nd);
    ga->connid = c->connid;
    nd->type = type;
    nd->err  = err;
    sh_handle_send(MODULE_ID, self->handler, MT_UM, ga, sizeof(*ga) + sizeof(*nd));
}

void
gate_socket(struct module* s, struct net_event* nm) {
    struct gate* self = MODULE_SELF;
    struct client* c;
    int id = nm->connid;
    switch (nm->type) {
    case LS_EREAD:
        c = get_client(self, id); 
        if (c) {
            // net.c all event will first cache, then deal together, 
            // so now this client may be free, due to the event of other connection,
            // eg: gate_main send_to_client, then c occur LS_ESOCKERR, then c free,
            // bug, c has the LS_EREAD event in net.c:ne
            read(s, c, nm);
        }
        break;
    case LS_EACCEPT:
        sh_trace("Client %d accepted", id);
        // do not forward to handler
        c = accept_client(s, id); 
        if (c) {
            if (!self->need_verify) {
                login_client(c);
            }
            forward_connect(s, c);
        }
        break;
    case LS_ESOCKERR:
        sh_trace("Client %d sockerr disconnect %d", id, nm->error);
        c = get_client(self, id);
        if (c) {
            if (c->status == S_LOGINED) { 
                forward_disconnect(s, c, LS_ESOCKERR, nm->error);
            }
            disconnect_client(s, c, true);
        }
        break;
    case LS_EWRIDONECLOSE:
        // donot forward to handler
        c = get_client(self, id);
        if (c) {
            sh_trace("Client %d writedone close", id);
            disconnect_client(s, c, true); 
        }
        break;
    }
}
/*
void
gate_time(struct module* s) {
    struct gate* self = MODULE_SELF; 
    uint64_t now = sh_timer_now();
    
    int i;
    for (i=0; i<self->cmax; ++i) {
        struct client *c = &self->p[i];
        switch (c->status) {
        case S_CONNECTED:
            if (now - c->active_time > 10*1000) {
                sh_trace("Client %d login timeout", c->connid);
                disconnect_client(s, c, true);
            }
            break;
        case S_LOGINED:
            if (self->livetime > 0 &&
                self->livetime < now - c->active_time) {
                sh_trace("Client %d heartbeat timeout", c->connid);
               
                forward_disconnect(s, c, LS_ETIMEOUT, 0);
                disconnect_client(s, c, true);
            }
            break;
        case S_LOGOUTED:
            if (now - c->active_time > 5*1000) {
                sh_trace("Client %d logout timeout", c->connid);
                disconnect_client(s, c, true);
            }
            break;
        default:
            break;
        }
    }
    update_load(s, false);
}
*/
static void
umsg(struct module *s, int source, const void *msg, int sz) {
    struct gate *self = MODULE_SELF;
    UM_CAST(UM_BASE, base, msg);
    switch (base->msgid) {
    case IDUM_GATE: {
        UM_CAST(UM_GATE, ga, msg); 
        UM_CAST(UM_BASE, sub, ga->wrap);
        int connid = ga->connid; 
        struct client *cl = get_client(self, connid);
        if (cl == NULL) {
            sh_trace("Client %d send %d sz %d, but closed", 
                    connid, sub->msgid, sz-(int)sizeof(*ga));
            return;
        }
        sh_trace("Client %d send %d sz %d", 
                    connid, sub->msgid, sz-(int)sizeof(*ga));
        switch (sub->msgid) {
        case IDUM_LOGOUT: {
            UM_CAST(UM_LOGOUT, lo, sub);
            switch (lo->err) {
            case SERR_OKUNFORCE:
                disconnect_client(s, cl, false);
                break;
            case SERR_OK:
                disconnect_client(s, cl, true);
                break;
            default:
                send_to_client(connid, lo, sizeof(*lo));
                disconnect_client(s, cl, false);
                break;
            }
            }
            break;
        default:
            send_to_client(connid, ga->wrap, sz-sizeof(*ga));
            break;
        }
        break;
        } 
    }
}

static void
disconnect_all(struct module *s) {
    struct gate *self = MODULE_SELF;
    int i;
    for (i=0; i<self->cmax; ++i) {
        struct client *c = &self->p[i];
        if (c->status != S_FREE) {
            disconnect_client(s, c, true);
        }
    }
}

static void
monitor(struct module *s, int source, const void *msg, int sz) {
    struct gate *self = MODULE_SELF;
    assert(sz >= 5);
    int type = sh_monitor_type(msg);
    int vhandle = sh_monitor_vhandle(msg);
    switch (type) {
    case MONITOR_START:
        if (vhandle == self->load_handle) {
            update_load(s, true);
        } else if (vhandle == self->handler) {
            //self->handler_down = false;
            update_load(s, false);
        }
        break;
    case MONITOR_EXIT:
        if (vhandle == self->handler) {
            disconnect_all(s);
            //self->handler_down = true;
            update_load(s, false); // set max load for down
        }
        break;
    }
}

static int
command(struct module *s, int source, int connid, const char *msg, int len, struct memrw *rw) {
    struct gate *self = MODULE_SELF;
    struct args A;
    args_parsestrl(&A, 0, msg, len, ' ');
    if (A.argc == 0) {
        return CTL_ARGLESS;
    }
    const char *cmd = A.argv[0];
    if (!strcmp(cmd, "nuser")) {
        int n = snprintf(rw->ptr, RW_SPACE(rw), "%d(nclient)", self->used);
        memrw_pos(rw, n); 
    } else {
        return CTL_NOCMD;
    }
    return CTL_OK;
}

void
gate_main(struct module* s, int session, int source, int type, const void *msg, int sz) {
    switch (type) {
    case MT_UM:
        umsg(s, source, msg, sz);
        break;
    case MT_MONITOR:
        monitor(s, source, msg, sz);
        break;
    case MT_CMD:
        cmdctl(s, source, msg, sz, command);
        break;
    }
}
