#include "shaco.h"
#include "shaco_socket.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// socket

static inline void
_to_littleendian16(uint16_t n, uint8_t *buffer) {
    buffer[0] = (n) & 0xff;
    buffer[1] = (n >> 8) & 0xff;
}

static inline uint16_t
_from_littleendian16(const uint8_t *buffer) {
    return buffer[0] | buffer[1] << 8;
}

static int
lbind(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    int fd = luaL_checkinteger(L,1);  
    int protocol;
    if (lua_type(L,2)==LUA_TNUMBER) {
        protocol = luaL_checkinteger(L,2);
    } else {
        protocol = LS_PROTOCOL_TCP;
    }
    int id = shaco_socket_bind(ctx, fd, protocol);
    if (id >=0 ) {
        lua_pushinteger(L, id);
        return 1;
    } else {
        lua_pushnil(L);
        lua_pushstring(L, SHACO_SOCKETERR);
        return 2;
    }
}

static int
llisten(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    const char *ip = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    int id = shaco_socket_listen(ctx, ip, port);
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
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    const char *ip = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    int id = shaco_socket_connect(ctx, ip, port);
    if (id >= 0) {
        if (shaco_socket_lasterrno() == LS_CONNECTING) {
            lua_pushinteger(L, id);
            lua_pushboolean(L, 1);
            return 2;
        } else {
            lua_pushinteger(L, id);
            return 1;
        }
    } else {
        lua_pushnil(L);
        lua_pushstring(L, SHACO_SOCKETERR);
        return 2;
    }
}

//static int
//lread(lua_State *L) {
//    int id = luaL_checkinteger(L, 1);
//    void *data;
//    int n = shaco_socket_read(id, &data);
//    if (n > 0) {
//        lua_pushlightuserdata(L, data);
//        lua_pushinteger(L, n);
//        return 2;
//    } else if (n == 0) {
//        lua_pushnil(L);
//        return 1;
//    } else {
//        lua_pushnil(L);
//        lua_pushstring(L, SHACO_SOCKETERR);
//        return 2;
//    }
//}

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
            return luaL_error(L, "send range error");
        }
        sz = end-start+1;
        msg = shaco_malloc(sz);
        memcpy(msg, s+start-1, sz);
        break; }
    default:
        return luaL_argerror(L, 2, "invalid type");
    }
    int err = shaco_socket_send_nodispatcherror(id,msg,sz);
    if (err != 0) 
        lua_pushstring(L, shaco_socket_error(err));
    else lua_pushnil(L);
    return 1;
}

static int
lsendmsg(lua_State *L) {
    int id = luaL_checkinteger(L,1);
    int fd;
    if (lua_isinteger(L, 2)) {
        fd = lua_tointeger(L,2);
    } else {
        fd = -1;
    }
    void *msg;
    int sz;
    int type = lua_type(L,3);
    switch (type) {
    case LUA_TLIGHTUSERDATA:
        msg = lua_touserdata(L,3);
        sz = luaL_checkinteger(L,4);
        break;
    case LUA_TSTRING: {
        size_t l;
        const char *s = luaL_checklstring(L,3,&l);
        int start = luaL_optinteger(L, 4, 1);
        int end = luaL_optinteger(L, 5, l);
        if (start < 1) start = 1;
        if (end > l) end = l;
        if (start > end) {
            return luaL_error(L, "send range error");
        }
        sz = end-start+1;
        msg = shaco_malloc(sz);
        memcpy(msg, s+start-1, sz);
        break; }
    default:
        return luaL_argerror(L, 2, "invalid type");
    }
    int err = shaco_socket_sendmsg(id, msg, sz, fd);
    if (err != 0)
        lua_pushstring(L, shaco_socket_error(err));
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
lreadon(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    shaco_socket_enableread(id, 1);
    return 0;
}

static int
lreadoff(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    shaco_socket_enableread(id, 0);
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
lgetfd(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    lua_pushinteger(L, shaco_socket_fd(id));
    return 1;
}

static int
ldrop(lua_State *L) {
    void *msg = lua_touserdata(L,1);
    luaL_checkinteger(L,2);
    shaco_free(msg);
    return 0;
}

// extra
static int
lunpack(lua_State *L) {
    luaL_checktype(L,1,LUA_TLIGHTUSERDATA);
    struct socket_event *event = lua_touserdata(L,1);
    int sz = luaL_checkinteger(L,2);
    assert(sz == sizeof(*event));

    int type = event->type;
    int id   = event->id;
    switch (type) {
    case LS_EREAD: {
        void *data;
        int size = shaco_socket_read(id, &data);
        if (size > 0) {
            lua_pushinteger(L, type);
            lua_pushinteger(L, id);
            lua_pushlightuserdata(L, data);
            lua_pushinteger(L, size);
            return 4;
        } else if (size == 0) {
            lua_pushinteger(L, LS_EREAD0);
            lua_pushinteger(L, id);
            return 2;
        } else {
            lua_pushinteger(L, LS_ESOCKERR);
            lua_pushinteger(L, id);
            lua_pushstring(L, SHACO_SOCKETERR);
            return 3;
        }}break;
    case LS_EREADMSG: {
        void *data;
        int size = shaco_socket_read(id, &data);
        if (size > 0) {
            lua_pushinteger(L, type);
            lua_pushinteger(L, id);
            lua_pushlightuserdata(L, data);
            lua_pushinteger(L, size);
            return 4;
        } else if (size == 0) {
            lua_pushinteger(L, LS_EREAD0);
            lua_pushinteger(L, id);
            return 2;
        } else {
            lua_pushinteger(L, LS_ESOCKERR);
            lua_pushinteger(L, id);
            lua_pushstring(L, SHACO_SOCKETERR);
            return 3;
        }}break;
    case LS_ECONNECT:
        lua_pushinteger(L, type);
        lua_pushinteger(L, id);
        return 2;
    case LS_EACCEPT:
        lua_pushinteger(L, type);
        lua_pushinteger(L, id);
        lua_pushinteger(L, event->listenid);
        return 3;
    case LS_ECONNERR:
    case LS_ESOCKERR:
        lua_pushinteger(L, type);
        lua_pushinteger(L, id);
        lua_pushstring(L, shaco_socket_error(event->err));
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
    _to_littleendian16(sz, msg);
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
    _to_littleendian16(sz+2, msg);
    _to_littleendian16(msgid, msg+2);
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
        lua_pushinteger(L, _from_littleendian16(p));
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
        {"bind", lbind },
        {"listen", llisten},
        {"connect", lconnect},
        {NULL, NULL},
	}; 
    luaL_Reg l2[] = {
        {"close", lclose},
        //{"read", lread},
        {"send", lsend},
        {"sendmsg", lsendmsg},
        {"readon", lreadon},
        {"readoff", lreadoff},
        {"address", laddress},
        {"limit", llimit}, 
        {"getfd", lgetfd},
        {"drop", ldrop},
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
	struct shaco_context *ctx = lua_touserdata(L,-1);
	if (ctx == NULL)
		return luaL_error(L, "init shaco context first");
	luaL_setfuncs(L,l,1);
    luaL_setfuncs(L,l2,0);
    luaL_setfuncs(L,l3,0);
	return 1;
}
