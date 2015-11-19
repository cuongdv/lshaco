#include "shaco_module.h"
#include "shaco_malloc.h"
#include "shaco.h"
#include "shaco_log.h"
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>
#include <assert.h>

static struct {
    int cap;
    int sz;
    struct shaco_module *p;
} *M = NULL;

// dl
static void
_dlclose(struct shaco_module* dl) {
    assert(dl->handle);
    dlclose(dl->handle);
    dl->handle = NULL;
    dl->create = NULL;
    dl->free = NULL;
    dl->init = NULL;
}

static int
_dlopen(struct shaco_module* dl) {
    assert(dl->handle == NULL);
    const char *name = dl->name;
    int len = strlen(name);
    char path[len+9+1];
    snprintf(path, sizeof(path), "./mod_%s.so", name);
    void* handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        sh_error("Module %s open error: %s", path, dlerror());
        return 1;
    }
    
    dl->handle = handle;

    char sym[len+7+1];
    strcpy(sym, name);
    strcpy(sym+len, "_create");
    dl->create = dlsym(handle, sym);
    strcpy(sym+len, "_free");
    dl->free = dlsym(handle, sym);
    strcpy(sym+len, "_init");
    dl->init = dlsym(handle, sym);

    if (dl->create == NULL &&
        dl->free == NULL &&
        dl->init == NULL) {
        sh_error("Module %s no interface");
        return 1;
    }
    if (dl->create && 
        dl->free == NULL) {
        sh_error("Module %s has `create` with no `free`, probably memory leak", name);
        _dlclose(dl);
        return 1;
    }
    return 0;
}

static struct shaco_module *
_alloc() {
    if (M->sz == M->cap) {
        M->cap *= 2;
        M->p = shaco_realloc(M->p, sizeof(M->p[0]) * M->cap);
    }
    return &M->p[M->sz];
}

struct shaco_module *
shaco_module_create(const char *name) {
    struct shaco_module *dl;
    dl = shaco_module_query(name);
    if (dl) {
        return NULL;
    }
    dl = _alloc();
    dl->name = shaco_strdup(name);
    if (_dlopen(dl)) {
        shaco_free(dl->name);
        dl->name = NULL;
        return NULL;
    }
    dl->moduleid = M->sz;
    M->sz++;
    sh_info("Moulde `%s` load ok", name);
    return dl;

}

void 
shaco_module_free(struct shaco_module *dl) {
    _dlclose(dl);
    shaco_free(dl->name);
    dl->name = NULL;
}

struct shaco_module *
shaco_module_index(int moduleid) {
    if (moduleid >= 0 && moduleid < M->sz) {
        return M->p[moduleid];
    } else { 
        sh_error("Invalid moudleid %d", moduleid);
        return NULL;
    }
}

struct shaco_module *
shaco_module_query(const char *name) {
    int i;
    for (i=0; i<M->sz; ++i) {
        struct shaco_module* dl = &M->p[i];
        if (!strcmp(dl->name, name))
            return dl;
    }
    return NULL;
}

void *
shaco_module_instance_create(struct shaco_module *dl) {
    if (dl->create) {
        return dl->create();
    } else
        return NULL;
}

void  
shaco_module_instance_free(void *instance) {
    if (dl->free) {
        assert(instance);
        dl->free(instance);
    }
}

void
shaco_module_init() {
    M = shaco_malloc(sizeof(*M));
    memset(M, 0, sizeof(*M));
}

void
shaco_module_fini() {
    if (M) {
        free(M);
        M = NULL;
    }
}
