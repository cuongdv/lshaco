#include "shaco.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// socket

static int
llisten(lua_State *L) {
    struct shaco_module *mod = lua_touserdata(L, lua_upvalueindex(1));
    const char *ip = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    int id = sh_socket_listen(ip, port, mod->moduleid);
    if (id >= 0) { 
        lua_pushinteger(L, id); 
        return 1;
    } else {
        lua_pushnil(L);
        lua_pushstring(L, SHACO_SOCKETERR);
        return 2;
    }
}

static int
lconnect(lua_State *L) {
    struct shaco_module *mod = lua_touserdata(L, lua_upvalueindex(1));
    const char *ip = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    int id = shaco_socket_connect(ip, port, mod->moduleid);
    if (id >= 0) {
        if (shaco_socket_lasterrno() == LS_CONNECTING) {
            lua_pushinteger(L, id);
            lua_pushnil(L);
            lua_pushboolean(L, 1);
            return 3;
        } else {
            lua_pushinteger(L, id);
            return 1;
        }
    } else {
        lua_pushnil(L);
        lua_pushinteger(L, shaco_socket_lasterrno());
        return 2;
    }
}

static int
lread(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    void *data;
    int n = shaco_socket_read(id, &data);
    if (n > 0) {
        lua_pushlightuserdata(L, data);
        lua_pushinteger(L, n);
        return 2;
    } else if (n == 0) {
        lua_pushnil(L);
        return 1;
    } else {
        lua_pushnil(L);
        lua_pushinteger(L, shaco_socket_lasterrno());
        return 2;
    }
}

static int
lsend(lua_State *L) {
    int id = luaL_checkinteger(L,1);
    void *msg;
    int sz;
    int type = lua_type(L,2);
    switch (type) {
    case LUA_TLIGHTUSERDATA:
        msg = lua_touserdata(L,2);
        sz = luaL_checkinteger(L,3);
        break;
    case LUA_TSTRING: {
        size_t l;
        const char *s = luaL_checklstring(L,2,&l);
        int start = luaL_optinteger(L, 3, 1);
        int end = luaL_optinteger(L, 4, l);
        if (start < 1) start = 1;
        if (end > l) end = l;
        if (start > end) {
            lua_pushboolean(L, 0);
            return 1;
        }
        sz = end-start+1;
        msg = shaco_malloc(sz);
        memcpy(msg, s+start-1, sz);
        break; }
    default:
        return luaL_argerror(L, 2, "invalid type");
    }
    int err = shaco_socket_send_nodispatcherror(id,msg,sz);
    if (err != 0) lua_pushinteger(L,err);
    else lua_pushnil(L);
    return 1;
}

static int
lclose(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    int force = lua_toboolean(L, 2);
    int ok = shaco_socket_close(id, force) == 0;
    lua_pushboolean(L, ok);
    return 1;
}

static int
lreadenable(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    int enable = lua_toboolean(L, 2);
    shaco_socket_enableread(id, enable);
    return 0;
}

static int
laddress(lua_State *L) {
    struct socket_addr addr;
    int id = luaL_checkinteger(L, 1); 
    if (!shaco_socket_address(id, &addr)) {
        lua_pushstring(L, addr.ip);
        lua_pushinteger(L, addr.port);
        return 2;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int
llimit(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    int slimit = luaL_checkinteger(L, 2);
    int rlimit = luaL_checkinteger(L, 3);
    shaco_socket_limit(id, slimit, rlimit);
    return 0;
}

static int
lerror(lua_State *L) {
    if (lua_gettop(L) == 0)
        lua_pushstring(L, SHACO_SOCKETERR);
    else {
        int err = luaL_checkinteger(L, 1);
        lua_pushstring(L, shaco_socket_error(err));
    }
    return 1;
}

// extra
static int
lunpack(lua_State *L) {
    luaL_checktype(L,1,LUA_TLIGHTUSERDATA);
    struct socket_event *event = lua_touserdata(L,1);
    int sz = luaL_checkinteger(L,2);
    assert(sz == sizeof(*event));

    lua_pushinteger(L, event->type);
    lua_pushinteger(L, event->id);
    switch (event->type) {
    case LS_EREAD:
    case LS_ECONNECT:
        return 2;
    case LS_EACCEPT:
        lua_pushinteger(L, event->listenid);
        return 3;
    case LS_ECONNERR:
    case LS_ESOCKERR:
        lua_pushinteger(L, event->err);
        return 3;
    default:
        return 2;
    }
}

static int
lsendpack(lua_State *L) {
    int id = luaL_checkinteger(L,1);
    int type = lua_type(L, 2);
    void *p;
    int sz;
    if (type == LUA_TLIGHTUSERDATA) {
        p = lua_touserdata(L, 2);
        sz = luaL_checkinteger(L, 3);
    } else if (type == LUA_TSTRING) {
        size_t l;
        p = (void*)lua_tolstring(L, 2, &l);
        sz = (int)l;
    } else {
        return luaL_argerror(L, 2, "invalid type");
    }
    if (!p || sz<=0)
        return 0;
    uint8_t *msg = shaco_malloc(sz+2);
    sh_to_littleendian16(sz, msg);
    memcpy(msg+2, p, sz);
    int ok = shaco_socket_send(id,msg,sz+2) == 0;
    lua_pushboolean(L,ok);
    return 1;
}

static int
lsendpack_um(lua_State *L) {
    int id = luaL_checkinteger(L,1);
    int msgid = luaL_checkinteger(L,2);

    int type = lua_type(L, 3);
    void *p;
    int sz;
    if (type == LUA_TLIGHTUSERDATA) {
        p = lua_touserdata(L, 3);
        sz = luaL_checkinteger(L, 4);
    } else if (type == LUA_TSTRING) {
        size_t l;
        p = (void*)lua_tolstring(L, 3, &l);
        sz = (int)l;
    } else {
        return luaL_argerror(L, 2, "invalid type");
    }
    uint8_t *msg = shaco_malloc(sz+4);
    sh_to_littleendian16(sz+2, msg);
    sh_to_littleendian16(msgid, msg+2);
    if (p && sz > 0)
        memcpy(msg+4, p, sz);
    int ok = shaco_socket_send(id,msg,sz+4) == 0;
    lua_pushboolean(L,ok);
    return 1;
}

static int
lunpack_msgid(lua_State *L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    uint8_t *p = lua_touserdata(L, 1);
    int sz = luaL_checkinteger(L, 2);
    if (sz >= 2) {
        lua_pushinteger(L, sh_from_littleendian16(p));
        lua_pushlightuserdata(L, p+2);
        lua_pushinteger(L, sz-2);
        return 3;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

int
luaopen_socket_c(lua_State *L) {
	luaL_checkversion(L);
    luaL_Reg l[] = {
        {"listen", llisten},
        {"connect", lconnect},
        {NULL, NULL},
	}; 
    luaL_Reg l2[] = {
        {"close", lclose},
        {"read", lread},
        {"send", lsend},
        {"readenable", lreadenable},
        {"address", laddress},
        {"limit", llimit}, 
        {"error", lerror},
        {NULL, NULL},
    };
    luaL_Reg l3[] = {
        {"unpack", lunpack},
        {"sendpack", lsendpack},
        {"sendpack_um", lsendpack_um},
        {"unpack_msgid", lunpack_msgid},
        {NULL, NULL},
    };
    luaL_newlibtable(L, l);
	lua_getfield(L, LUA_REGISTRYINDEX, "shaco_context");
	struct shaco_module *mod = lua_touserdata(L,-1);
	if (mod == NULL)
		return luaL_error(L, "init shaco context first");
	luaL_setfuncs(L,l,1);
    luaL_setfuncs(L,l2,0);
    luaL_setfuncs(L,l3,0);
	return 1;
}
