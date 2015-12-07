#ifndef __shaco_module_h__
#define __shaco_module_h__

#include <stdint.h>
#include <stdbool.h>

struct shaco_context;

typedef void *(*shaco_dl_create)();
typedef void  (*shaco_dl_free)(void *instance);
typedef int   (*shaco_dl_init)(struct shaco_context *context, void *instance, const char *args);

struct shaco_module {
    const char *name;
    void *handle;
    shaco_dl_create create;
    shaco_dl_free free;
    shaco_dl_init init;
};

void shaco_module_init(const char *path);
void shaco_module_fini();

struct shaco_module *shaco_module_query(const char *name);
void *shaco_module_instance_create(struct shaco_module *dl);
void  shaco_module_instance_free(struct shaco_module *dl, void *instance);

#endif
