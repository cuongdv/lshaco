#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <lstate.h>
#include "shaco.h"
static int _TRACE=0;
static int                                        
_traceback(lua_State *L) {                        
    //const char *msg = lua_tostring(L, 1);
    const char *msg = luaL_tolstring(L, 1, NULL);
    if (msg)
        luaL_traceback(L, L, msg, 1);
    else 
        lua_pushliteral(L, "(no error message)"); 
    return 1;
}

static int
lcommand(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    const char *name = luaL_checkstring(L, 1);
    const char *param = lua_tostring(L, 2);
    if (param == NULL) 
        param = "";
    const char *result = shaco_command(ctx, name, param);
    lua_pushstring(L, result);
    return 1; 
}

static int
llog(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    int level = luaL_checkinteger(L, 1);
    const char *log = luaL_checkstring(L, 2);
    shaco_log(ctx, level, "%s", log);
	return 0;
}

static int 
lnow(lua_State *L) {
    lua_pushnumber(L, shaco_timer_now());
    return 1;
}

static int
lsend(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    int session = luaL_checkinteger(L, 2);
    int type = luaL_checkinteger(L, 3);
    int isptr = lua_type(L,4)==LUA_TLIGHTUSERDATA;
    void *msg;
    size_t sz;
    if (isptr) { 
        msg = lua_touserdata(L, 4);
        sz = luaL_checkinteger(L, 5);
        type |= SHACO_DONT_COPY;
    } else {
        msg = (void*)luaL_checklstring(L, 4, &sz);
    }
    int dest = lua_tointeger(L,1);
    if (dest == 0) {
        const char *name = luaL_checkstring(L,1);
        if (name[0]=='.') name++;
        // todo: remote query
        dest = shaco_handle_query(name);
        if (dest == 0) {
            if (isptr) shaco_free(msg);
            return luaL_error(L, "Not dest `%s`", name);
        }
    }
    int ret = shaco_send(ctx, dest, session, type, msg, sz);
    if (ret != 0) {
        lua_pushboolean(L, 0);
    } else {
        lua_pushboolean(L, 1);
    }
    return 1;
}

static int
ltimer(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    uint32_t handle = shaco_context_handle(ctx);
    int session = luaL_checkinteger(L, 1);
    int interval = luaL_checkinteger(L, 2);
    shaco_timer_register(handle, session, interval);
    return 0;
}

static int
_cb(struct shaco_context *ctx, void *ud, int source, int session, int type, const void *msg, int sz) {
    lua_State *L = ud;
    _TRACE = lua_gettop(L);
    lua_pushcfunction(L, _traceback);
    int trace = lua_gettop(L);
    lua_rawgetp(L, LUA_REGISTRYINDEX, _cb);
    lua_pushinteger(L, source);
    lua_pushinteger(L, session);
    lua_pushinteger(L, type);
    lua_pushlightuserdata(L, (void*)msg);
    lua_pushinteger(L, sz);

    int r = lua_pcall(L, 5, 0, trace);
    if (r==LUA_OK) {
        lua_pop(L,1);
        return 0;
    }
    shaco_error(ctx, "cb error: %s", lua_tostring(L, -1));
    lua_pop(L, 2);
    return 1;
}

static int
lcallback(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_rawsetp(L, LUA_REGISTRYINDEX, _cb);

    lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD);
    struct lua_State *gL = lua_tothread(L,-1);
    assert(gL);

    shaco_callback(ctx, _cb, gL);
    return 0;
}

static int
lhandle(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    lua_pushinteger(L, shaco_context_handle(ctx));
    return 1;
}

static int
ltostring(lua_State *L) {
    luaL_checktype(L,1, LUA_TLIGHTUSERDATA);
    void *p = lua_touserdata(L,1);
    size_t sz = luaL_checkinteger(L,2);
    lua_pushlstring(L, p, sz);
    return 1;
}

static int
ltopointstring(lua_State *L) {
    if (lua_type(L,1) == LUA_TNIL) {
        lua_pushliteral(L, "0");
    } else {
        luaL_checktype(L,1, LUA_TLIGHTUSERDATA);
        void *p = lua_touserdata(L,1);
        char tmp[24];
        snprintf(tmp, sizeof(tmp), "%p", p);
        lua_pushstring(L, tmp);
    }
    return 1;
}

int
luaopen_shaco_c(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
        { "command",        lcommand },
        { "log",            llog },
        { "send",           lsend },
        { "timer",          ltimer },
        { "callback",       lcallback },
        { "handle",         lhandle },
        { NULL, NULL},
	}; 
    luaL_Reg l2[] = {
        { "now",            lnow },
        { "tostring",       ltostring },
        { "topointstring",  ltopointstring },
        { NULL, NULL},
    };
	luaL_newlibtable(L, l);
	lua_getfield(L, LUA_REGISTRYINDEX, "shaco_context");
	struct shaco_context *ctx = lua_touserdata(L,-1);
	if (ctx == NULL)
		return luaL_error(L, "init shaco context first");
	luaL_setfuncs(L,l,1);
	luaL_setfuncs(L,l2,0);
	return 1;
}
