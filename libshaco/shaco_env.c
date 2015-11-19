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

void 
shaco_setinteger(const char *key, int value) {
    lua_pushinteger(L, value);
    lua_setglobal(L, key);
}

void 
shaco_setfloat(const char *key, float value) {
    lua_pushnumber(L, value);
    lua_setglobal(L, key);
}

int
shaco_pushenv(const char *key, lua_State *T) {
    lua_getglobal(L, key);
    switch (lua_type(L,-1)) {
    case LUA_TNUMBER:
        if (lua_isinteger(L,-1))
            lua_pushinteger(T,lua_tointeger(L,-1));
        else
            lua_pushnumber(T, lua_tonumber(L,-1));
        break;
    case LUA_TBOOLEAN:
        lua_pushboolean(T, lua_toboolean(L,-1));
        break;
    case LUA_TSTRING:
        lua_pushstring(T, lua_tostring(L,-1));
        break;
    default:
        lua_pushnil(T);
        break;
    }
    lua_pop(L,1);
    return 1;
}

int 
shaco_optint(const char *key, int def) {
    int i;
    lua_getglobal(L,key);
    if (lua_isinteger(L, -1)) {
        i = lua_tointeger(L, -1);
    } else {
        lua_pushinteger(L, def);
        lua_setglobal(L, key);
        i = def;
    }
    lua_pop(L,1);
    return i;
}

float 
shaco_optfloat(const char *key, float def) {
    float f;
    lua_getglobal(L,key);
    if (lua_isnumber(L, -1)) {
        f = lua_tonumber(L, -1);
    } else {
        lua_pushnumber(L, def);
        lua_setglobal(L, key);
        f = def;
    }
    lua_pop(L,1);
    return f;
}

const char *
shaco_optstr(const char *key, const char *def) {
    const char *s;
    lua_getglobal(L,key);
    if (lua_isstring(L, -1)) {
        s = lua_tostring(L, -1);
    } else {
        lua_pushstring(L, def);
        lua_setglobal(L, key);
        s = def;
    }
    lua_pop(L,1);
    return s;
}
