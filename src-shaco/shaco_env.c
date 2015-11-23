#include "shaco_malloc.h"
#include "lua.h"
#include "lauxlib.h" 

static lua_State *L;

void 
shaco_env_init() {
    L = lua_newstate(shaco_lalloc, NULL);
}

void
shaco_env_fini() {
    if (L) {
        lua_close(L);
        L = NULL;
    }
}

const char* 
shaco_getenv(const char* key) {
    lua_getglobal(L, key);
    const char *s = lua_tostring(L, -1);
    lua_pop(L, 1);
    return s;
}

void 
shaco_setenv(const char* key, const char* value) {
    lua_pushstring(L, value);
    lua_setglobal(L, key);
}

int 
shaco_optint(const char *key, int def) {
    const char *s = shaco_getenv(key);
    if (s==NULL) {
        char tmp[16];
        sprintf(tmp, "%d", def);
        shaco_setenv(key, tmp);
        return def;
    }
    return strtol(s, NULL, 10);
}

float 
shaco_optfloat(const char *key, float def) {
    const char *s = shaco_getenv(key);
    if (s==NULL) {
        char tmp[32];
        snprintf(tmp, sizeof(tmp), "%f", def);
        shaco_setenv(key, tmp);
        return def;
    }
    return strtof(s, NULL);
}

const char *
shaco_optstr(const char *key, const char *def) {
    const char *s = shaco_getenv(key);
    if (s==NULL) {
        shaco_setenv(key, def);
        return def;
    } else
        return s;
}
