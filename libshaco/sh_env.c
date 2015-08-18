#include "sh_env.h"
#include "sh_malloc.h"
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include <stdlib.h>

struct sh_env {
    lua_State* L;
};

static struct sh_env* E = NULL;

void 
sh_env_init() {
    E = sh_malloc(sizeof(*E));
    E->L = lua_newstate(sh_lalloc, NULL);
}

void
sh_env_fini() {
    if (E == NULL)
        return;
    if (E->L) {
        lua_close(E->L);
        E->L = NULL;
    }
    sh_free(E);
    E = NULL;
}

const char* 
sh_getenv(const char* key) {
    const char* str;
    lua_State* L = E->L;
    lua_getglobal(L, key);
    str = lua_tostring(L, -1);
    lua_pop(L, 1);
    return str;
}

void 
sh_setenv(const char* key, const char* value) {
    lua_State* L = E->L;
    lua_pushstring(L, value);
    lua_setglobal(L, key);
}

float
sh_getnum(const char* key, float def) {
    float f;
    lua_State* L = E->L;
    lua_getglobal(L, key);
    if (lua_isnumber(L, -1)) {
        f = lua_tonumber(L, -1);
        lua_pop(L, 1);
        return f;
    } else {
        lua_pop(L, 1);
        return def;
    }
}

const char* 
sh_getstr(const char* key, const char* def) {
    const char* str;
    lua_State* L = E->L;
    lua_getglobal(L, key);
    if (lua_isstring(L, -1)) {
        str = lua_tostring(L, -1);
        lua_pop(L, 1);
        return str;
    } else {
        lua_pop(L, 1);
        return def;
    }
}

void 
sh_setnumenv(const char* key, float value) {
    lua_State* L = E->L;
    lua_pushnumber(L, value);
    lua_setglobal(L, key);
}
