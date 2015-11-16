#include "sh_node.h"
#include "sh_malloc.h"
#include "sh_util.h"
#include "sh.h"
#include "sh_module.h"
#include "sh_init.h"
#include "sh_log.h"
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>

#define SID_MASK 0xff
#define SUB_MAX  0xff
#define NODE_MASK 0xff00
#define VHANDLE_MASK (0x10000)
#define VHANDLE(i) (VHANDLE_MASK | (i))

struct rid {
    int id;
    int load;
};

struct rhandle {
    char *name; 
    int load_iter;
    int cap;
    int sz;
    struct rid *p;
    struct sh_array mor;
};

static struct {
    int handle;
    int cap;
    int sz;
    struct rhandle *p;
} *R = NULL;

// handle
static int
_add_handle(struct rhandle *s, int handle) {
    if (handle == -1) {
        return 1;
    }
    int n = s->sz;
    if (n >= s->cap) {
        s->cap *= 2;
        if (s->cap == 0)
            s->cap = 1;
        s->p = sh_realloc(s->p, sizeof(s->p[0]) * s->cap);
    }
    s->p[n].id = handle;
    s->p[n].load = 0;
    s->sz++;
    return 0;
}

static int
_rm_handle(struct rhandle *s, int handle) {
    if (handle == -1) {
        return 1;
    }
    int i;
    for (i=0; i<s->sz; ++i) {
        if (s->p[i].id == handle) {
            for (; i<s->sz-1; ++i) {
                s->p[i] = s->p[i+1];
            }
            s->sz--;
            return 0;
        }
    }
    return 1;
}

static inline int
_first_handle(struct rhandle *s) {
    if (s->sz > 0) {
        return s->p[0].id;
    }
    return -1;
}

static bool
_has_handle(struct rhandle *s, int handle) {
    int i;
    for (i=0; i<s->sz; ++i) {
        if (s->p[i].id == handle)
            return true;
    }
    return false;
}

static inline struct rhandle *
_get_module(int vhandle) {
    int id = vhandle & SID_MASK;
    if (id >= 0 && id < R->sz) {
        return &R->p[id];
    }
    return NULL;
}

static int
_vhandle(const char *name) {
    struct rhandle *s;
    int i;
    int n = R->sz;
    for (i=0; i<n; ++i) {
        s = &R->p[i];
        if (!strcmp(s->name, name)) {
            return VHANDLE(i);
        }
    }
    return -1;
}

static int
_subscribe(const char *name) {
    struct rhandle *s;
    int vhandle = _vhandle(name);
    if (vhandle != -1) {
        return vhandle;
    }
    int n = R->sz;
    if (n >= R->cap) {
        R->cap *= 2;
        if (R->cap == 0)
            R->cap = 1;
        R->p = sh_realloc(R->p, sizeof(R->p[0]) * R->cap);
    } 
    s = &R->p[n];
    memset(s, 0, sizeof(*s));
    s->name = sh_malloc(strlen(name)+1);
    strcpy(s->name, name);
    sh_array_init(&s->mor, sizeof(struct sh_monitor), 1);
    R->sz++;
    return VHANDLE(n);
}

static int
_register(const char *name, int handle) {
    struct rhandle *s;
    int i,j;
    for (i=0; i<R->sz; ++i) {
        s = &R->p[i];
        for (j=0; j<s->sz; ++j) {
            if (s->p[j].id == handle) {
                if (!strcmp(s->name, name))
                    return VHANDLE(i);
                else
                    return -1;
            }
        }
    }
    for (i=0; i<R->sz; ++i) {
        s = &R->p[i];
        if (!strcmp(s->name, name)) {
            if (!_add_handle(s, handle)) {
                return VHANDLE(i);
            } else
                return -1;
        }
    }
    return -1;
}

static int
_unregister(int handle) {
    struct rhandle *s;
    int i,j;
    for (i=0; i<R->sz; ++i) {
        s = &R->p[i];
        for (j=0; j<s->sz; ++j) {
            if (!_rm_handle(s, handle)) {
                sh_info("Handle(%s:%0x) exit", s->name, handle);
                return VHANDLE(i); 
            }
        }
    }
    return -1;
}

static inline int
send(int session, int source, int dest, int type, const void *msg, int sz) {
    if (dest & NODE_MASK) {
        return module_send(R->handle, session, source, dest, type, msg, sz);
    } else {
        return module_main(dest, session, source, type, msg, sz);
    }
}

int 
sh_handle_call(int session, int source, int dest, int type, const void *msg, int sz) {
    if (dest & VHANDLE_MASK) {
        struct rhandle *s = _get_module(dest);
        if (s == NULL) {
            sh_error("No subscribe remote handle %04x", dest);
            return 1;
        }
        int h = _first_handle(s);
        if (h == -1) {
            sh_error("No connect remote handle %s:%04x", s->name, dest);
            return 1;
        }
        dest = h;
    }
    return send(session, source, dest, type, msg, sz);
}

int 
sh_handle_send(int source, int dest, int type, const void *msg, int sz) {
    return sh_handle_call(0, source, dest, type, msg, sz);
}

int 
sh_handle_broadcast(int source, int dest, int type, const void *msg, int sz) {
    struct rhandle *s;
    int i, n=0;
    if (dest & VHANDLE_MASK) {
        s = _get_module(dest);
        if (s) {
            for (i=0; i<s->sz; ++i)
                if (!send(0, source, s->p[i].id, type, msg, sz))
                    n++;
        }
    } else {
        if (!send(0, source, dest, type, msg, sz))
            n++;
    }
    return n;
}

int 
sh_handle_vsend(int source, int dest, const char *fmt, ...) {
    char msg[2048];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(msg, sizeof(msg), fmt, ap);
    va_end(ap);
    if (n >= sizeof(msg)) {
        sh_error("Too large msg %s from %0x to %0x", fmt, source, dest);
        return 1;
    }
    sh_handle_send(source, dest, MT_TEXT, msg, n);
    return 0;
}

int 
sh_handle_minload(int vhandle) {
    struct rhandle *s = _get_module(vhandle);
    if (s == NULL) {
        return -1;
    }
    if (s->sz <= 0) {
        return -1;
    }
    if (s->load_iter >= s->sz) {
        s->load_iter = 0;
    }
    return s->p[s->load_iter++].id;
}

int 
sh_handle_nextload(int vhandle) {
    struct rhandle *s = _get_module(vhandle);
    if (s == NULL) {
        return -1;
    }
    int minload = INT_MAX;
    int idx=-1;
    int n = s->sz;
    int i;
    for (i=0; i<n; ++i) {
        idx = (s->load_iter+i) % n;
        if (minload > s->p[idx].load) {
            minload = s->p[idx].load;
            break;
        }
    }
    if (idx != -1) {
        s->load_iter = idx+1;
        return s->p[idx].id;
    } else {
        return -1;
    }
}

bool 
sh_handle_exist(int vhandle, int handle) {
    struct rhandle *s = _get_module(vhandle);
    if (s) {
        return _has_handle(s, handle);
    }
    return false;
}

int 
sh_handle_subscribe(const char *name, int active) {
    int handle = -1;
    if (name[0] == '\0') {
        sh_error("Handle subscribe none");
        return handle;
    }
    if (R->handle == -1) {
        handle = module_query_id(name);
    } else {
        handle = _subscribe(name);
        if (handle != -1) {
            char msg[128];
            int n = snprintf(msg, sizeof(msg), "SUB %s %d", name, active); 
            if (module_main(R->handle, 0, 0, MT_TEXT, msg, n)) {
                return -1;
            } 
        }
    }
    return handle;
}

int 
sh_handle_publish(const char *name, int flag) {
    int handle = module_query_id(name);
    if (handle == -1) {
        return 1;
    }
    if (R->handle == -1) {
        _subscribe(name);
        sh_handle_start(name, handle);
        return 0;
    }
    if (flag & PUB_SER) {
        char msg[128];
        int n = snprintf(msg, sizeof(msg), "PUB %s:%04x", name, handle);
        return module_main(R->handle, 0, 0, MT_TEXT, msg, n);
    }
    if (flag & PUB_MOD) {
        const char *module_name = module_query_module_name(handle);
        if (!(flag & PUB_SER) || strcmp(module_name, name)) {
            char msg[128];
            int n = snprintf(msg, sizeof(msg), "PUB %s:%04x", module_name, handle);
            return module_main(R->handle, 0, 0, MT_TEXT, msg, n);
        }
    }
    return 0;
}

// monitor
int 
sh_handle_monitor(const char *name, const struct sh_monitor *h, int *vhandle, int active) {
    *vhandle = sh_handle_subscribe(name, active);
    if (*vhandle == -1) {
        return 1;
    }
    if (R->handle == -1) {
        *vhandle = _subscribe(name);
        struct rhandle *s = _get_module(*vhandle);
        assert(s);
        struct sh_monitor *sm = sh_array_push(&s->mor);
        sm->start_handle = h->start_handle;
        sm->exit_handle = h->exit_handle;
        // return 2 if has published
        return s->sz >0 ? 2 : 0;
    } else {
        struct rhandle *s = _get_module(*vhandle);
        assert(s);
        struct sh_monitor *sm = sh_array_push(&s->mor);
        sm->start_handle = h->start_handle;
        sm->exit_handle = h->exit_handle;
        return 0;
    }
}

int
sh_handle_start(const char *name, int handle) {
    int vhandle = _register(name, handle);
    if (vhandle == -1)
        return 1;
    struct rhandle *s = _get_module(vhandle);
    assert(s);
    sh_info("Handle(%s:%0x) start", name, handle);
   
    int i;
    for (i=0; i<s->mor.nelem; ++i) {
        struct sh_monitor *sm = sh_array_get(&s->mor, i);
        int start_handle = sm->start_handle;
        if (start_handle != -1) {
            int nlen = strlen(name);
            uint8_t msg[5+nlen+1];
            uint8_t *p = msg;
            *p++ = MONITOR_START;
            memcpy(p, name, nlen); p+=nlen;
            *p++ = '\0';
            sh_to_littleendian32(vhandle, p); p+=4;
            sh_handle_send(handle, sm->start_handle, MT_MONITOR, msg, sizeof(msg));
        }
    }
    return 0;
}

int 
sh_handle_exit(int handle) {
    int vhandle = _unregister(handle);
    if (vhandle == -1)
        return 1;
    struct rhandle *s = _get_module(vhandle);
    assert(s);

    int i;
    for (i=0; i<s->mor.nelem; ++i) {
        struct sh_monitor *sm = sh_array_get(&s->mor, i);
        int exit_handle = sm->exit_handle;
        if (exit_handle != -1) {
            int nlen = strlen(s->name);
            uint8_t msg[5+nlen+1];
            uint8_t *p = msg;
            *p++ = MONITOR_EXIT;
            memcpy(p, s->name, nlen); p+=nlen;
            *p++ = '\0';
            sh_to_littleendian32(vhandle, p); p+=4;
            sh_handle_send(handle, exit_handle, MT_MONITOR, msg, sizeof(msg));
        }
    }
    return 0;
}

int 
sh_node_exit(int nodeid) {
    return 0;
}

// init
static void
sh_handle_init() {
    int node_handle = -1;
    int cluster = sh_getint("cluster", 0);
    if (cluster) {
        if (module_load("node", "")) {
            sh_exit("lost node module");
        }
        bool master = !sh_getenv("master");
        if (master) {
            if (module_load("master", "")) {
                sh_exit("lost master module");
            }
        }
        int handle;
        handle = module_query_id("node");
        if (handle != -1) {
            if (module_init("node")) {
                sh_exit("node init fail");
            }
        }
        node_handle = handle;
        handle = module_query_id("master");
        if (handle != -1) {
            if (module_init("master")) {
                sh_exit("master init fail");
            }
        }
    }
    R = sh_malloc(sizeof(*R));
    memset(R, 0, sizeof(*R));
    R->handle = node_handle;
}

static void
sh_handle_fini() {
    if (R == NULL) {
        return;
    }
    if (R->p) {
        int i;
        for (i=0; i<R->sz; ++i) {
            sh_free(R->p[i].name);
            sh_free(R->p[i].p);
            sh_array_fini(&R->p[i].mor);
        }
        sh_free(R->p);
        R->p = NULL;
        R->sz = 0;
        R->cap = 0;
    }
    sh_free(R);
    R = NULL;
}

SH_LIBRARY_INIT_PRIO(sh_handle_init, sh_handle_fini, 30)
