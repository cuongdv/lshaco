#include "shaco_module.h"
#include "shaco_malloc.h"
#include "shaco_log.h"
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>

static struct {
    const char *path;
    int cap;
    int sz;
    struct shaco_module **p;
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
_dlopen(struct shaco_module* dl, const char *name) {
    assert(dl->handle == NULL);
    int lenpath = strlen(M->path);
    int len = strlen(name);
    char path[lenpath+len+8+1];
    snprintf(path, sizeof(path), "%s/mod_%s.so", M->path, name);
    void* handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        shaco_error("DL `%s` open error: %s", path, dlerror());
        return 1;
    }
    char sym[len+7+1];
    strcpy(sym, name);
    strcpy(sym+len, "_create");
    dl->create = dlsym(handle, sym);
    strcpy(sym+len, "_free");
    dl->free = dlsym(handle, sym);
    strcpy(sym+len, "_init");
    dl->init = dlsym(handle, sym);

    dl->handle = handle;

    if (dl->create == NULL &&
        dl->free == NULL &&
        dl->init == NULL) {
        shaco_error("DL `%s` no interface", path);
        _dlclose(dl);
        return 1;
    }
    if (dl->create && 
        dl->free == NULL) {
        shaco_error("DL `%s` has `create` with no `free`, probably memory leak", name);
        _dlclose(dl);
        return 1;
    }
    return 0;
}

static struct shaco_module *
shaco_module_create(const char *name) {
    struct shaco_module *dl = shaco_malloc(sizeof(*dl));
    memset(dl, 0, sizeof(*dl));
    if (_dlopen(dl, name)) {
        shaco_free(dl);
        return NULL;
    }
    dl->name = shaco_strdup(name);
    if (M->sz == M->cap) {
        M->cap *= 2;
        M->p = shaco_realloc(M->p, sizeof(M->p[0]) * M->cap);
    }
    M->p[M->sz++] = dl;
    return dl;

}

static void 
shaco_module_free(struct shaco_module *dl) {
    _dlclose(dl);
    shaco_free((void*)dl->name);
    dl->name = NULL;
}

struct shaco_module *
shaco_module_query(const char *name) {
    int i;
    for (i=0; i<M->sz; ++i) {
        struct shaco_module* dl = M->p[i];
        if (!strcmp(dl->name, name))
            return dl;
    }
    return shaco_module_create(name);
}

void *
shaco_module_instance_create(struct shaco_module *dl) {
    if (dl->create) {
        return dl->create();
    } else
        return NULL;
}

void  
shaco_module_instance_free(struct shaco_module *dl, void *instance) {
    if (dl->free) {
        assert(instance);
        dl->free(instance);
    }
}

void
shaco_module_init(const char *path) {
    M = shaco_malloc(sizeof(*M));
    M->path = shaco_strdup(path);
    M->cap = 1;
    M->sz = 0;
    M->p = shaco_malloc(sizeof(M->p[0]) * M->cap);
}

void
shaco_module_fini() {
    if (M) {
        int i;
        for (i=0; i<M->sz; ++i) {
            struct shaco_module *dl = M->p[i];
            shaco_module_free(dl);
            shaco_free(dl);
        }
        shaco_free(M->p);
        M->p = NULL;
        shaco_free((void*)M->path);
        M->path = NULL;
        shaco_free(M);
        M = NULL;
    }
}
