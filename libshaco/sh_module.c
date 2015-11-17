#include "sh_module.h"
#include "sh_malloc.h"
#include "sh_node.h"
#include "sh.h"
#include "sh_util.h"
#include "sh_init.h"
#include "sh_env.h"
#include "sh_log.h"
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>
#include <assert.h>

#define MOD_LEN 32

// dl
static void
_dlclose(struct dlmodule* dl) {
    assert(dl->handle);
    dlclose(dl->handle);
    dl->handle = NULL;
    dl->create = NULL;
    dl->free = NULL;
    dl->init = NULL;
    dl->send = NULL;
    dl->main = NULL;
}

static int
_dlopen(struct dlmodule* dl) {
    assert(dl->handle == NULL);

    int len = strlen(dl->name);
    char name[len+7+1];
    int n = snprintf(name, sizeof(name), "mod_%s.so", dl->name);

    char soname[n+2+1];
    snprintf(soname, sizeof(soname), "./%s", name);
    void* handle = dlopen(soname, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        sh_error("Module %s open error: %s", soname, dlerror());
        return 1;
    }
    
    dl->handle = handle;

    char sym[len+10+1];
    strcpy(sym, dl->name);
    strcpy(sym+len, "_create");
    dl->create = dlsym(handle, sym);
    strcpy(sym+len, "_free");
    dl->free = dlsym(handle, sym);
    strcpy(sym+len, "_init");
    dl->init = dlsym(handle, sym);
    strcpy(sym+len, "_send");
    dl->send = dlsym(handle, sym);
    strcpy(sym+len, "_main");
    dl->main = dlsym(handle, sym);

    if (dl->create && 
        dl->free == NULL) {
        sh_error("Module %s probably memory leak", soname);
        _dlclose(dl);
        return 1;
    }
    return 0;
}

void
_dlunload(struct dlmodule* dl) {
    if (dl == NULL)
        return;
   
    if (dl->free) {
        // sometimes need free, even if no dl->content
        dl->free(dl->content);
        dl->content = NULL;
    }
    if (dl->handle) {
        //_dlclose(dl); notice: don't do this, just for valgrind Discard the module sym
    }
    if (dl->name) {
        sh_free(dl->name);
        dl->name = NULL;
    }
}

int
_dlload(struct dlmodule* dl, const char* name) {
    memset(dl, 0, sizeof(*dl));
    int len = strlen(name);
    if (len > MOD_LEN) {
        sh_error("Module `%s` name too long", name);
        return 1;
    }
    dl->name = sh_malloc(len+1);
    strcpy(dl->name, name);
    if (_dlopen(dl)) {
        sh_free(dl->name);
        dl->name = NULL;
        return 1;
    }
    if (dl->create) {
        dl->content = dl->create();
    }
    return 0;
}

#define INIT_COUNT 8

// module
static struct {
    int cap;
    int sz;
    struct module **p;
} *M = NULL;

static struct module *
_index(int idx) {
    if (idx >= 0 && idx < M->sz) {
        return M->p[idx];
    } else { 
        sh_error("Invalid moudle index %d", idx);
        return NULL;
    }
}

static struct module *
_find(const char* rname) {
    int i;
    for (i=0; i<M->sz; ++i) {
        struct module* s = M->p[i];
        if (s && strcmp(s->rname, rname) == 0) {
            return s;
        }
    }
    return NULL;
}

static inline void
_insert(struct module* s) {
    if (M->sz == M->cap) {
        M->cap *= 2;
        M->p = sh_realloc(M->p, sizeof(M->p[0]) * M->cap);
    }
    s->moduleid = M->sz;
    M->p[M->sz++] = s;
}

static struct module *
_create(const char *soname, const char* mname, const char *rname) {
    struct module *s = _find(rname);
    if (s) {
        sh_error("Module `%s` already exist", rname);
        return NULL;
    }
    s = sh_malloc(sizeof(*s));
    memset(s, 0, sizeof(*s));
    if (_dlload(&s->dl, soname)) {
        sh_free(s);
        return NULL;
    }
    s->mname = sh_strdup(mname);
    s->rname = sh_strdup(rname);
    _insert(s); 
    sh_info("Moulde `%s:%s[%02X]` load ok", mname, rname, s->moduleid);
    return s;
}

static int
_init(struct module* s, const char *args) {
    const char *p = "";
    if (!strcmp(s->dl.name, "lua")) {
        p = s->mname;
    } else {
        p = args;
    }
    if (s->dl.init && !s->inited) {
        if (s->dl.init(s, p)) { 
            return 1;
        }
        s->inited = true;
        sh_info("Module `%s:%s[%02X]` init ok", s->mname, s->rname, s->moduleid);
    }
    return 0;
}

static int
_reload(struct module* s) {
    //assert(s->dl.handle); donot do this
    // foreach all same so 
    struct module *m;
    int i;
    for (i=0; i<M->sz; ++i) {
        m = M->p[i];
        if (m->dl.handle) {
            if (!strcmp(m->dl.name, s->dl.name)) {
                _dlclose(&m->dl);
                sh_info("Moudle `%s:%s[%02X]` unload ok", m->mname, m->rname, m->moduleid);
            }
        }
    }
    for (i=0; i<M->sz; ++i) {
        m = M->p[i];
        if (m->dl.handle == NULL) {
            if (_dlopen(&m->dl)) {
                sh_error("Module `%s:%s[%02X]` reload fail", m->mname, m->rname, m->moduleid);
            } else {
                sh_info ("Module `%s:%s[%02X]` reload ok", m->mname, m->rname, m->moduleid);
            }
        }
    }
    return 0;
}

int 
module_load(const char* name, const char *mod) {
    assert(name);
    size_t len = strlen(name);
    char tmp[len+1];
    strcpy(tmp, name);
    
    char *save = NULL, *one;
    one = strtok_r(tmp, ",", &save);
    while (one) {
        int len = strlen(one);
        char tmp[len+1];
        strcpy(tmp, one);
        const char *rname, *mname;
        char *p = strchr(tmp, ':');
        if (p) {
            p[0] = '\0';
            rname = p+1;
        } else {
            rname = one;
        }
        mname = tmp;
        if (mod[0]) {
            if (_create(mod, mname, rname) == NULL)
                return 1;
        } else {
            if (_create(mname, mname, rname) == NULL)
                return 1;
        }
        one = strtok_r(NULL, ",", &save);
    }
    return 0;
}

int 
module_init(const char* rname) {
    struct module* s;
    if (rname) {
        s = _find(rname);
        if (s) {
            return _init(s, "");
        }
        return 1;
    } else {
        int i;
        for (i=0; i<M->sz; ++i) {
            s = M->p[i];
            if (_init(s, "")) {
                return 1;
            }
        }
    }
    return 0;
}

int 
module_new(const char *soname, const char *mname, const char *rname, const char *args) {
    struct module *s = _create(soname, mname, rname);
    if (s && !_init(s, args)) {
        return s->moduleid;
    } else
        return -1;
}

int
module_reload(const char* rname) {
    struct module* s = _find(rname);
    if (s) {
        return _reload(s);
    } else {
        return 1;
    }
}

int 
module_reload_byid(int moduleid) {
    struct module* s = _index(moduleid);
    if (s) return _reload(s);
    return 1;
}

int
module_query_id(const char* rname) {
    struct module* s = _find(rname);
    return s ? s->moduleid : MODULE_INVALID;
}

const char* 
module_query_module_name(int moduleid) {
    struct module* s = _index(moduleid);
    return s ? s->dl.name : "";
}

int 
module_main(int moduleid, int session, int source, int type, const void *msg, int sz) {
    struct module *s = _index(moduleid);
    if (s && s->dl.main) {
        s->dl.main(s, session, source, type, msg, sz);
        return 0;
    }
    return 1;
}

int 
module_send(int moduleid, int session, int source, int dest, int type, const void *msg, int sz) {
    struct module *s = _index(moduleid);
    if (s && s->dl.send) {
        s->dl.send(s, session, source, dest, type, msg, sz);
        return 0;
    }
    return 1;
}

static void
module_mgr_init() {
    M = sh_malloc(sizeof(*M));
    M->cap = INIT_COUNT;
    M->p = sh_malloc(sizeof(M->p[0]) * M->cap);
    M->sz = 0;
    const char* modules = sh_getstr("cmod", "");
    const char *luamods = sh_getstr("luamod", "");
    if ((modules[0] &&
         module_load(modules, "")) ||
        (luamods[0] &&
         module_load(luamods, "lua"))) {
        sh_exit("module_mgr_init `%s` fail", modules);
    }
}

static void
module_mgr_fini() {
    if (M == NULL) 
        return;
    struct module *s;
    int i;
    for (i=0; i<M->sz; ++i) {
        s = M->p[i];
        _dlunload(&s->dl);
        sh_free(s->mname);
        sh_free(s->rname);
        sh_free(s);
    }
    sh_free(M->p);
    M->p = NULL;
    M->cap = 0;
    M->sz = 0;
    sh_free(M);
}

static void
module_mgr_prepare() {
    if (module_init(NULL)) {
        sh_exit("module_mgr_prepare fail");
    }
}

SH_LIBRARY_INIT_PRIO(module_mgr_init, module_mgr_fini, 10)
SH_LIBRARY_INIT_PRIO(module_mgr_prepare, NULL, 50)
