#include "shaco.h"

#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <lstate.h>

static int                                        
_traceback(lua_State *L) {                        
    const char *msg = lua_tostring(L, 1);
    if (msg) {
        luaL_traceback(L, L, msg, 1);
    } else {
        lua_pushliteral(L, "(no error message)"); 
    }                                     
    return 1;
}

//
static int
llog(lua_State *L) {
    struct shaco_module *s = lua_touserdata(L, lua_upvalueindex(1));
    sh_log(luaL_checkinteger(L, 1), "[%s] %s", MODULE_NAME, luaL_checkstring(L, 2));
	return 0;
}

static int
lgetloglevel(lua_State *L) {
    lua_pushstring(L, sh_log_level());
    return 1;
}

static int
lsetloglevel(lua_State *L) {
    sh_log_setlevel(luaL_checkstring(L, 1));
    lua_pushstring(L, sh_log_level());
    return 1;
}

static int 
lgetenv(lua_State *L) {
    shaco_pushenv(luaL_checkstring(L,1), L);
    return 1;
}

static int 
lnow(lua_State *L) {
    lua_pushnumber(L, shaco_timer_now());
    return 1;
}

static int
lstarttime(lua_State *L) {
    lua_pushnumber(L, shaco_timer_start_time());
    return 1;
}

static int 
ltime(lua_State *L) {
    lua_pushnumber(L, shaco_timer_time());
    return 1;
}

//
static int
lpublish(lua_State *L) {
    const char *name = luaL_checkstring(L, 1);
    if (sh_handle_publish(name, PUB_SER)) {
        return luaL_error(L, "publish handle:%s error", name);
    }
    return 0;
}

static int
lsubscribe(lua_State *L) {
    const char *name = luaL_checkstring(L, 1);
    int active = lua_toboolean(L, 2);
    int handle = sh_handle_subscribe(name, active);
    if (handle == -1) {
        return luaL_error(L, "subscribe handle:%s error", name);
    } else {
        lua_pushinteger(L, handle);
        return 1;
    }
}

static int
lqueryid(lua_State *L) {
    int handle = module_query_id(luaL_checkstring(L, 1));
    if (handle != -1) {
        lua_pushinteger(L, handle);
        return 1;
    } else
        return 0;
}

static int
luniquemodule(lua_State *L) {
    struct shaco_module *s = lua_touserdata(L, lua_upvalueindex(1));
    assert(s);
    const char *name = luaL_checkstring(L,1);
    int active = lua_toboolean(L,2);
    int vhandle;
    struct sh_monitor h = {s->moduleid, s->moduleid};
    int r = sh_handle_monitor(name, &h, &vhandle, active);
    if (r==1) {
        return luaL_error(L, "uniquemodule handle:%s error", name);
    } else if (r==0) {
        lua_pushinteger(L, vhandle);
        lua_pushboolean(L, false); // no published
        return 2;
    } else {
        assert(r==2);
        lua_pushinteger(L, vhandle);
        lua_pushboolean(L, true); // published
        return 2;
    }
}

static int
lbroadcast(lua_State *L) {
    struct shaco_module *ctx = lua_touserdata(L, lua_upvalueindex(1));
    assert(ctx);
    int dest = luaL_checkinteger(L, 1);
    int type = luaL_checkinteger(L, 2);
    luaL_checktype(L, 3, LUA_TLIGHTUSERDATA);
    void *msg = lua_touserdata(L, 3);
    int sz = luaL_checkinteger(L, 4);
    int n = sh_handle_broadcast(ctx->moduleid, dest, type, msg, sz);
    lua_pushinteger(L, n);
    shaco_free(msg);
    return 1;
}

static int
lsend(lua_State *L) {
    int session = luaL_checkinteger(L, 1);
    int source;
    if (lua_type(L, 2) == LUA_TNIL) {
        struct shaco_module *ctx = lua_touserdata(L, lua_upvalueindex(1));
        assert(ctx);
        source = ctx->moduleid;
    } else {
        source = luaL_checkinteger(L, 2);
    }
    int dest = luaL_checkinteger(L, 3);
    int type = luaL_checkinteger(L, 4);
    luaL_checktype(L, 5, LUA_TLIGHTUSERDATA);
    void *msg = lua_touserdata(L, 5);
    int sz = luaL_checkinteger(L, 6);
    if (sh_handle_call(session, source, dest, type, msg, sz)) {
        shaco_free(msg);
        return luaL_error(L, "send %d ~ %d, session:%d, type:%d", source, dest, session, type);
    } else {
        shaco_free(msg);
        return 0;
    }
}

static int
ltimer(lua_State *L) {
    struct shaco_module *s = lua_touserdata(L, lua_upvalueindex(1));
    int session = luaL_checkinteger(L, 1);
    int interval = luaL_checkinteger(L, 2);
    shaco_timer_register(s->moduleid, session, interval);
    return 0;
}

static void
_maincb(struct shaco_module *s, int session, int source, int type, const void *msg, int sz) {
    lua_State *L = s->dl.udata;
    lua_pushcfunction(L, _traceback);
    int trace = lua_gettop(L);
    lua_rawgetp(L, LUA_REGISTRYINDEX, _maincb);
    lua_pushinteger(L, session);
    lua_pushinteger(L, source);
    lua_pushinteger(L, type);
    lua_pushlightuserdata(L, (void*)msg);
    lua_pushinteger(L, sz);
//if (L->nCcalls > 200-10) {
//fprintf(stderr, "[%p][_maincb] %d [%s][source %0x, type %d, sz %d]\n", L, L->nCcalls, MODULE_NAME, source, type, sz);
  //}


    int r = lua_pcall(L, 5, 0, trace);
    if (r != LUA_OK) {
        sh_error("[%s] main error: %s", MODULE_NAME, lua_tostring(L, -1));
        lua_pop(L, 2);
    } else {
        lua_pop(L, 1);
    } 
//if (L->nCcalls > 200-10) {
//fprintf(stderr, "[%p][_maincb ok] %d [%s][source %0x, type %d, sz %d]\n", L, L->nCcalls, MODULE_NAME, source, type, sz);
  //}


}

static int
lmain(lua_State *L) {
    struct shaco_module *s = lua_touserdata(L, lua_upvalueindex(1));
    assert(s); 
    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_rawsetp(L, LUA_REGISTRYINDEX, _maincb);

    lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD);
    struct lua_State *gL = lua_tothread(L,-1);
    assert(gL);

    s->dl.main = _maincb;
    s->dl.udata= gL;
    return 0;
}

int
luaopen_shaco_c(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
        { "log",            llog },
        { "setloglevel",    lsetloglevel },
        { "getloglevel",    lgetloglevel },
        { "getenv",         lgetenv },
        { "now",            lnow},
        { "starttime",      lstarttime},
        { "time",           ltime },
        { "publish",        lpublish },
        { "subscribe",      lsubscribe },
        { "queryid",        lqueryid },
        { "uniquemodule",   luniquemodule},
        { "broadcast",      lbroadcast },
        { "send",           lsend },
        { "timer",          ltimer },

	}; 
	luaL_newlibtable(L, l);
	lua_getfield(L, LUA_REGISTRYINDEX, "shaco_context");
	struct shaco_module *m = lua_touserdata(L,-1);
	if (m == NULL)
		return luaL_error(L, "init shaco context first");
	luaL_setfuncs(L,l,1);
	return 1;
}
