#include "shaco.h"
#include "shaco_malloc.h"
#include "shaco_module.h"
#include "shaco_handle.h"
#include "shaco_log.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct shaco_context {
    struct shaco_module *module;
    const char *name;
    uint32_t handle;
    void *instance;
    shaco_cb cb;
    void *ud;
    char result[32];
};

uint32_t
shaco_context_create(const char *name, const char *args) {
    struct shaco_module *dl = shaco_module_query(name);
    if (dl == NULL) {
        shaco_error("Context `%s %s` create fail: no module `%s`", name, args, name);
        return 0;
    }
    struct shaco_context *ctx = shaco_malloc(sizeof(*ctx));
    ctx->module = dl;
    ctx->name = shaco_strdup(name);
    ctx->cb = NULL;
    ctx->ud = NULL;
    ctx->instance = shaco_module_instance_create(dl);
    ctx->handle = shaco_handle_register(ctx);
    if (ctx->module->init) {
        ctx->module->init(ctx, ctx->instance, args); 
    }
    shaco_info("LAUNCH [%02x] %s %s", ctx->handle, name, args?args:" ");
    return ctx->handle;
}

void 
shaco_context_free(struct shaco_context *ctx) {
    if (ctx) {
        shaco_module_instance_free(ctx->module, ctx->instance);
        ctx->module = NULL;
        ctx->instance = NULL;
        shaco_free((void*)ctx->name);
        ctx->name = NULL;
        ctx->handle = 0;
        shaco_handle_unregister(ctx);
        shaco_free(ctx);
    }
}

uint32_t 
shaco_context_handle(struct shaco_context *ctx) {
    return ctx->handle;
}

void 
shaco_context_send(struct shaco_context *ctx, int source, int session, int type, const void *msg, int sz) {
    int result = ctx->cb(ctx, ctx->ud, source, session, type, msg, sz);
    if (result !=0 ) {
        shaco_error(
        "Context `%s` cb fail:%d : %0x->%0x session:%d type:%d sz:%d", 
        ctx->name, result, source, ctx->handle, session, type, sz);
    }
}

void 
shaco_context_log(struct shaco_context *ctx, int level, const char *log) {
    shaco_log(level, "[%02x] %s", ctx->handle, log);
}

void 
shaco_callback(struct shaco_context *ctx, shaco_cb cb, void *ud) {
    ctx->cb = cb;
    ctx->ud = ud;
}

struct command {
    const char *name;
    const char * (*func)(struct shaco_context *ctx, const char *param);
};

static const char*
cmd_launch(struct shaco_context *ctx, const char *param) {
    int len = strlen(param);
    char name[len+1];
    const char *args;
    strcpy(name, param);
    char *p = strchr(name, ' ');
    if (p) {
        *p = '\0';
        args = p+1;
    } else {
        args = NULL;
    }
    uint32_t handle = shaco_context_create(name, args);
    if (handle == 0) {
        return NULL;
    } else {
        sprintf(ctx->result, "0x%0x", handle);
        return ctx->result;
    }
}

static const char *
cmd_query(struct shaco_context *ctx, const char *param) {
    uint32_t handle = shaco_handle_query(param);
    if (handle == 0) {
        return NULL;
    } else {
        sprintf(ctx->result, "%0x", handle);
        return ctx->result;
    }
}

static const char *
cmd_reg(struct shaco_context *ctx, const char *param) {
    int len = strlen(param);
    char tmp[len+1];
    strcpy(tmp, param);
    char *p = strchr(tmp, ' ');
    if (p == NULL) {
        return "reg no handle";
    }
    *p = '\0';
    uint32_t handle = strtol(p+1, NULL, 10);
    shaco_handle_bindname(handle, tmp);
    return NULL;
}

static const char *
cmd_qname(struct shaco_context *ctx, const char *param) {
    return ctx->name;
}

static const char *
cmd_time(struct shaco_context *ctx, const char *param) {
    uint64_t time = shaco_timer_time();
    sprintf(ctx->result, "%llu", (long long unsigned int)time);
    return ctx->result;
}

static const char *
cmd_starttime(struct shaco_context *ctx, const char *param) {
    uint64_t time = shaco_timer_start_time();
    sprintf(ctx->result, "%llu", (long long unsigned int)time);
    return ctx->result;
}

static const char *
cmd_getenv(struct shaco_context *ctx, const char *param) {
    return shaco_getenv(param);
}

static const char *
cmd_setenv(struct shaco_context *ctx, const char *param) {
    char tmp[strlen(param)+1];
    strcpy(tmp, param);
    const char *value;
    char *p = strchr(tmp, ' ');
    if (p) {
        *p = '\0';
        value = p+1;
    } else {
        value = "";
    }
    shaco_setenv(tmp, value);
    return NULL;
}

static const char *
cmd_getloglevel(struct shaco_context *ctx, const char *param) {
    return shaco_log_level();
}

static const char *
cmd_setloglevel(struct shaco_context *ctx, const char *param) {
    shaco_log_setlevel(param);
    return NULL;
}

struct command C[] = {
    { "LAUNCH", cmd_launch },
    { "QUERY", cmd_query },
    { "REG", cmd_reg },
    { "QNAME", cmd_qname },
    { "TIME", cmd_time },
    { "STARTTIME", cmd_starttime },
    { "GETENV", cmd_getenv },
    { "SETENV", cmd_setenv },
    { "GETLOGLEVEL", cmd_getloglevel },
    { "SETLOGLEVEL", cmd_setloglevel },
    { NULL, NULL },
};

const char *
shaco_command(struct shaco_context *ctx, const char *name, const char *param) {
    const struct command *c;
    for (c=C; c->name; c++) {
        if (strcmp(c->name, name)==0)
            return c->func(ctx, param);
    }
    return NULL;
}
