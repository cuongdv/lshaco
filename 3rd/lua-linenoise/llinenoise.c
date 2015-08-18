#include <lauxlib.h>
#include "linenoise.h"

static int 
llinenoise(lua_State *L) {
    const char *prompt = luaL_checkstring(L, 1);
    lua_pushstring(L, linenoise(prompt));
    return 1;
}

static int 
laddhistory(lua_State *L) {
    linenoiseHistoryAdd(luaL_checkstring(L, 1));
    return 0;
}

static int 
lsavehistory(lua_State *L) {
    linenoiseHistorySave(luaL_checkstring(L, 1));
    return 0;
}

static int 
lloadhistory(lua_State *L) {
    linenoiseHistoryLoad(luaL_checkstring(L, 1));
    return 0;
}

int luaopen_linenoise(lua_State *L) {
    luaL_checkversion(L);

    luaL_Reg l[] = {
        { "linenoise", llinenoise },
        { "addhistory", laddhistory },
        { "savehistory", lsavehistory },
        { "loadhistory", lloadhistory },
        { NULL, NULL}
    };
    luaL_newlib(L, l);
    return 1;
}
