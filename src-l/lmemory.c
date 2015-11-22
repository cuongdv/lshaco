#include "shaco_malloc.h"
#include <lua.h>
#include <lauxlib.h>

static int
lused(lua_State *L) {
    size_t used = shaco_memory_used();
    lua_pushinteger(L, used);
    return 1;
}

static int
lstat(lua_State *L) {
    shaco_memory_stat();
    return 0;
}

int
luaopen_memory_c(lua_State *L) {
	luaL_checkversion(L);

	luaL_Reg l[] = { 
        {"used", lused},
        {"stat", lstat},
        { NULL, NULL },
	}; 
	luaL_newlib(L, l);
	return 1;
}
