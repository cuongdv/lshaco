#include "shaco.h"
#include "shaco_socket.h"
#include "socket_platform.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <sys/socket.h>
#include <errno.h>

static int
lbind(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    int fd = luaL_checkinteger(L,1);  
    int protocol;
    if (lua_type(L,2)==LUA_TNUMBER) {
        protocol = luaL_checkinteger(L,2);
    } else {
        protocol = SOCKET_PROTOCOL_TCP;
    }
    int id = shaco_socket_bind(ctx, fd, protocol);
    if (id >=0 ) {
        lua_pushinteger(L, id);
        return 1;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int
llisten(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    int id;
    if (lua_gettop(L) == 1) {
        size_t sz;
        const char *ip = luaL_checklstring(L, 1, &sz);
        char tmp[sz+1];
        memcpy(tmp, ip, sz);
        tmp[sz] = '\0';
        char *p = strchr(tmp, ':');
        if (p == NULL) {
            return luaL_error(L, "Invalid address %s", ip);
        }
        *p = '\0';
        int port = strtol(p+1, NULL, 10);
        id = shaco_socket_listen(ctx, tmp, port);
    } else {
        const char *ip = luaL_checkstring(L, 1);
        int port = luaL_checkinteger(L, 2);
        id = shaco_socket_listen(ctx, ip, port);
    }
    if (id >= 0) { 
        lua_pushinteger(L, id); 
        return 1;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int
lconnect(lua_State *L) {
    struct shaco_context *ctx = lua_touserdata(L, lua_upvalueindex(1));
    int id, conning = 0;
    if (lua_gettop(L) == 1) {
        size_t sz;
        const char *ip = luaL_checklstring(L, 1, &sz);
        char tmp[sz+1];
        memcpy(tmp, ip, sz);
        tmp[sz] = '\0';
        char *p = strchr(tmp, ':');
        if (p == NULL) {
            return luaL_error(L, "Invalid address %s", ip);
        }
        *p = '\0';
        int port = strtol(p+1, NULL, 10);
        id = shaco_socket_connect(ctx, tmp, port, &conning);
    } else {
        const char *ip = luaL_checkstring(L, 1);
        int port = luaL_checkinteger(L, 2);
        id = shaco_socket_connect(ctx, ip, port, &conning);
    }
    if (id >= 0) {
        if (conning) {
            lua_pushinteger(L, id);
            lua_pushboolean(L, 1);
            return 2;
        } else {
            lua_pushinteger(L, id);
            return 1;
        }
    } else {
        lua_pushnil(L);
        return 1;
    }
}

// return fd[2]
static int
lpair(lua_State *L) {
    int fildes[2];
    if (!socketpair(AF_UNIX, SOCK_STREAM, 0, fildes)) {
        lua_pushinteger(L, fildes[0]);
        lua_pushinteger(L, fildes[1]);
        return 2;
    } else {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
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
            return luaL_error(L, "send range error");
        }
        sz = end-start+1;
        msg = shaco_malloc(sz);
        memcpy(msg, s+start-1, sz);
        break; }
    default:
        return luaL_argerror(L, 2, "invalid type");
    }
    int n = shaco_socket_send(id,msg,sz);
    if (n < 0) {
        lua_pushnil(L);
        return 1;
    } else {
        lua_pushinteger(L,n);
        return 1;
    }
}

static int
lsendfd(lua_State *L) {
    int id = luaL_checkinteger(L,1);
    int fd;
    if (lua_isinteger(L, 2)) {
        fd = lua_tointeger(L,2);
   } else {
        fd = -1;
    }
    void *msg;
    int   sz;
    if (lua_gettop(L) > 2) {
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
    } else {
        if (fd == -1) {
            return luaL_error(L, "sendfd nothing");
        }
        msg = NULL;
        sz  = 1;
    }
    int n = shaco_socket_sendfd(id, msg, sz, fd);
    if (n < 0) {
        lua_pushnil(L);
        return 1;
    } else {
        lua_pushinteger(L,n);
        return 1;
    }
}

static int
lreinit(lua_State *L) {
    shaco_socket_fini();
    shaco_socket_init(shaco_optint("maxsocket", 0));
    return 0;
}

static int
lclosefd(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    _socket_close(fd);
    return 0;
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
    struct socket_message *msg = lua_touserdata(L,1);
    int sz = luaL_checkinteger(L,2);
    assert(sz == sizeof(*msg));

    int type = msg->type;
    int id   = msg->id;
    switch (type) {
    case SOCKET_TYPE_DATA:
        lua_pushinteger(L, type);
        lua_pushinteger(L, id);
        lua_pushlightuserdata(L, msg->data);
        lua_pushinteger(L, msg->size);
        return 4;
    case SOCKET_TYPE_CONNECT:
        lua_pushinteger(L, type);
        lua_pushinteger(L, id);
        return 2;
    case SOCKET_TYPE_ACCEPT:
        lua_pushinteger(L, type);
        lua_pushinteger(L, id);
        lua_pushinteger(L, msg->listenid);
        lua_pushlstring(L, msg->data, msg->size);
        return 4;
    case SOCKET_TYPE_CONNERR:
    case SOCKET_TYPE_SOCKERR:
        lua_pushinteger(L, type);
        lua_pushinteger(L, id);
        return 2;
    default:
        return 2;
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
        {"reinit", lreinit},
        {"closefd", lclosefd},
        {"close", lclose},
        {"send", lsend},
        {"sendfd", lsendfd},
        {"readon", lreadon},
        {"readoff", lreadoff},
        {"getfd", lgetfd},
        {"pair", lpair},
        {"drop", ldrop},
        {"unpack", lunpack},
        {NULL, NULL},
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
