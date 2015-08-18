#include "sh.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct keepalivec {
    bool alive_always;
    int nodeid;
    int serverid;
    int hb_tick;
    int tick;
    bool connecting;
};

struct keepalivec *
keepalivec_create() {
    struct keepalivec *self = sh_malloc(sizeof(*self));
    memset(self, 0, sizeof(*self));
    return self;
}

void
keepalivec_free(struct keepalivec *self) {
    sh_free(self);
}

static int
connect(struct module *s) {
    struct keepalivec *self = MODULE_SELF;
    self->alive_always = sh_getint("keepalive_always", 0);
    self->nodeid = sh_getint("id", 0);
    const char *ip = sh_getstr("keepalive_ip", "");
    int port = sh_getint("keepalive_port", 0);
    if (ip[0] == '\0' || port == 0) {
        return 1;
    }
    // todo
    //if (!sh_socket_connect(ip, port, false, MODULE_ID, 0)) {
        //self->connecting = true;
        //return 0;
    //} else
        //return 1;
}

int
keepalivec_init(struct module *s) {
    struct keepalivec *self = MODULE_SELF;
    self->serverid = -1;
    if (connect(s))
        return 1;

    self->hb_tick = sh_getint("keepalive_tick", 3);
    if (self->hb_tick <= 0)
        self->hb_tick = 1;
    sh_timer_register(MODULE_ID, 1000);
    return 0;
}

void
notify_startup(struct keepalivec *self) {
    const char *args = sh_getstr("sh_startup_args", "");
    if (args[0] == '\0')
        return;
    pid_t pid = getpid();
    char cmd[1024];
    int n = sh_snprintf(cmd, sizeof(cmd), "START %d %d %d %s", 
            self->alive_always, self->nodeid, (int)pid, args);
    uint8_t *msg = sh_malloc(n+2);
    sh_to_littleendian16(n, msg);
    memcpy(msg+2, cmd, n);
    sh_socket_send(self->serverid, msg, n+2);
}

void
keepalivec_socket(struct module* s, struct net_event* nm) {
    struct keepalivec *self = MODULE_SELF;
    switch (nm->type) {
    case LS_ECONNECT:
        self->serverid = nm->connid;
        self->connecting = false;
        sh_socket_subscribe(nm->connid, true);
        sh_info("Connect keepalived(%d) ok", nm->connid);
        notify_startup(self);
        break;
    case LS_ECONNERR:
        self->connecting = false;
        sh_error("Connect keepalived fail, %s", sh_socket_error(nm->error));
        break;
    case LS_ESOCKERR:
        assert(nm->connid == self->serverid); 
        self->serverid = -1;
        sh_error("Disonnect keepalived(%d), %s", nm->connid, sh_socket_error(nm->error));
        break;
    }
}
/*
void
keepalivec_time(struct module *s) {
    struct keepalivec *self = MODULE_SELF;

    self->tick++;
    if (self->serverid != -1) {
        if (self->tick % self->hb_tick == 0) {
            uint8_t *msg = sh_malloc(4);
            sh_to_littleendian16(2, msg);
            msg[2] = 'H';
            msg[3] = 'B';
            sh_socket_send(self->serverid, msg, 4);
        }
    } else {
        if (!self->connecting)
            connect(s);
    }
}
*/
