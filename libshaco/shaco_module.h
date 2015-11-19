#ifndef __shaco_module_h__
#define __shaco_module_h__

#include <stdint.h>
#include <stdbool.h>

typedef void *(*shaco_dl_create)();
typedef void  (*shaco_dl_free)(void *instance);
typedef void  (*shaco_dl_init)(struct shaco_context *context, const char *args);

struct shaco_module {
    int  moduleid; // >= 0, will not change since loaded
    char *name;
    void *handle;
    shaco_dl_create create;
    shaco_dl_free free;
    shaco_dl_init init;
};

void shaco_module_init();
void shaco_module_fini();
struct shaco_module *shaco_module_create(const char *name);
void shaco_module_free(struct shaco_module *dl);
struct shaco_module *shaco_module_index(int moduleid);
struct shaco_module *shaco_module_find(const char *name);

void *shaco_module_instance_create(struct shaco_module *dl);
void  shaco_module_instance_free(void *instance);
void  shaco_module_instance_init(struct shaco_module *dl);

#endif
