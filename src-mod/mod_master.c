#include "shaco.h"

struct handle_slot {
    char *name;
    struct sh_array pubs;
    struct sh_array subs;
};

struct master { 
    int node_handle;
    struct sh_array ps;
};

// cmd
static inline int
cmd_HANDLE(const char *name, int handle, char *cmd, int n) {
    return sh_snprintf(cmd, n, "HANDLE %s:%04x", name, handle);
}

static inline int
cmd_BROADCAST(int nodeid, char *cmd, int n) {
    return sh_snprintf(cmd, n, "BROADCAST %d", nodeid);
}

// master
struct master*
master_create() {
    struct master* self = shaco_malloc(sizeof(*self));
    memset(self, 0, sizeof(*self));
    return self;
}

void
master_free(struct master* self) {
    if (self == NULL) return;
    int i;
    for (i=0; i<self->ps.nelem; ++i) {
        struct handle_slot *slot = sh_array_get(&self->ps, i);
        sh_array_fini(&slot->pubs);
        sh_array_fini(&slot->subs);
        shaco_free(slot->name);
    }
    sh_array_fini(&self->ps);
    shaco_free(self);
}

int
master_init(struct shaco_module* s) {
    struct master *self = MODULE_SELF;
    self->node_handle = module_query_id("node");
    if (self->node_handle == -1) return 1;
    sh_array_init(&self->ps, sizeof(struct handle_slot), 1);
    return 0;
}

static struct handle_slot *
handle_name_insert(struct sh_array *ps, const char *name) {
    struct handle_slot *slot;
    int i;
    for (i=0; i<ps->nelem; ++i) {
        slot = sh_array_get(ps, i);
        if (!strcmp(slot->name, name)) 
            return slot;
    }
    slot = sh_array_push(ps);
    slot->name = shaco_strdup(name);
    sh_array_init(&slot->pubs, sizeof(int), 1);
    sh_array_init(&slot->subs, sizeof(int), 1);
    return slot;
}

static int 
handle_existed(struct sh_array *a, int handle) {
    int i;
    for (i=0; i<a->nelem; ++i) {
        int *v = sh_array_get(a, i);
        if (*v == handle) return 1;
    }
    return 0;
}

static int
handle_insert(struct sh_array *a, int handle) {
    if (handle < 0) return 1;
    if (handle_existed(a, handle)) return 1;
    *(int*)sh_array_push(a) = handle;
    return 0;
}

static void
handle_remove(struct sh_array *a, int nodeid) {
    int i;
    for (i=0; i<a->nelem; ) {
        int *handle = sh_array_get(a, i);
        if (sh_nodeid_from_handle(*handle) == nodeid)
            sh_array_remove(a, i);
        else i++;
    }
}

static void
node_reg(struct shaco_module *s, int nodeid) {
    struct master *self = MODULE_SELF;
    char cmd[64];
    int sz = cmd_BROADCAST(nodeid, cmd, sizeof(cmd));
    sh_handle_send(MODULE_ID, self->node_handle, SHACO_TTEXT, cmd, sz);
}

static void
node_unreg(struct shaco_module *s, int nodeid) {
    struct master *self = MODULE_SELF;
    struct sh_array* a = &self->ps;
    int i;
    for (i=0; i<a->nelem; ++i) {
        struct handle_slot *slot = sh_array_get(a, i);
        handle_remove(&slot->pubs, nodeid);
        handle_remove(&slot->subs, nodeid);
    }
}

static void
handle_sub(struct shaco_module *s, int source, const char *name) {
    struct master *self = MODULE_SELF;
    struct handle_slot *slot = handle_name_insert(&self->ps, name);
    assert(slot);
    if (handle_insert(&slot->subs, source))
        return; 
    char cmd[128];
    struct sh_array *a = &slot->pubs;
    int i;
    for (i=0; i<a->nelem; ++i) {
        int *pub = sh_array_get(a, i);
        if (sh_nodeid_from_handle(*pub) != sh_nodeid_from_handle(source)) {
            int sz = cmd_HANDLE(name, *pub, cmd, sizeof(cmd));
            sh_handle_send(MODULE_ID, source, SHACO_TTEXT, cmd, sz);
        }
    }
}

static void
handle_pub(struct shaco_module *s, int source, const char *name, int handle) {
    struct master *self = MODULE_SELF;
    struct handle_slot *slot = handle_name_insert(&self->ps, name);
    assert(slot);
    if (handle_insert(&slot->pubs, handle))
        return;
    char cmd[128];
    struct sh_array *a = &slot->subs;
    int i;
    for (i=0; i<a->nelem; ++i) {
        int *sub = sh_array_get(a, i);
        if (sh_nodeid_from_handle(*sub) != sh_nodeid_from_handle(source)) {
            int sz = cmd_HANDLE(name, handle, cmd, sizeof(cmd));
            sh_handle_send(MODULE_ID, *sub, SHACO_TTEXT, cmd, sz);
        }
    }
}

static void
redirect_to_node(struct shaco_module *s, const void *msg, int sz) {
    struct master *self = MODULE_SELF;
    sh_handle_send(MODULE_ID, self->node_handle, SHACO_TTEXT, msg, sz);
}

void
master_main(struct shaco_module *s, int session, int source, int type, const void *msg, int sz) {
    if (type != SHACO_TTEXT) return;
    
    char cmd[sz+1];
    memcpy(cmd, msg, sz);
    cmd[sz] = '\0';

    char *arg = strchr(cmd, ' ');
    if (arg) {
        *arg = '\0';
        arg+=1; 
    }
    if (!strcmp(cmd, "REG")) {
        if (arg == NULL) return;
        redirect_to_node(s, msg, sz);
        char *p = strchr(arg, ' ');
        if (p) *p = '\0';
        int nodeid = strtol(arg, NULL, 10);
        node_reg(s, nodeid); 
    } else if (!strcmp(cmd, "UNREG")) {
        if (arg == NULL) return;
        int nodeid = strtol(arg, NULL, 10);
        node_unreg(s, nodeid);
    } else if (!strcmp(cmd, "SUB")) {
        if (arg == NULL) return;
        const char *name = arg;
        handle_sub(s, source, name);
    } else if (!strcmp(cmd, "PUB")) {
        if (arg == NULL) return;
        char *p = strchr(arg, ':');
        if (p == NULL) return;
        *p = '\0';
        const char *name = arg;
        int handle = strtol(p+1, NULL, 16);
        handle_pub(s, source, name, handle);
    }
}
