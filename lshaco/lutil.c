#include "shaco_malloc.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <iconv.h>
#include <assert.h>

static int 
lgetenv(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);
    lua_pushstring(L, getenv(name));
    return 1;
}

static int 
lsetenv(lua_State* L) {
    const char *name  = luaL_checkstring(L, 1); 
    const char *value = lua_tostring(L, 2); 
#ifndef _WIN32
    if (!(value ? setenv(name,value,1) : unsetenv(name)))
#else
    if (SetEnvironmentVariableA(name,value))
#endif
        lua_pushboolean(L,1);
    else
        lua_pushboolean(L,0);
    return 1;
}

static int 
ldaemon(lua_State* L) {
#ifndef _WIN32
    int nochdir = luaL_checkinteger(L,1);
    int noclose = luaL_checkinteger(L,2);
    if (!daemon(nochdir, noclose)) {
        lua_pushboolean(L,1);
        return 1;
    } else {
        lua_pushnil(L);
        lua_pushstring(L,strerror(errno));
        return 2;
    }
#endif
    lua_pushnil(L);
    lua_pushstring(L,"Unsupport windows");
    return 2;
}

static int 
liconv(lua_State* L) {
#ifdef __linux__
    size_t l;
    const char* str = luaL_checklstring(L, 1, &l);
    if (l==0) {
        lua_pushliteral(L,"");
        return 1;
    }
    size_t unuse_l;
    const char* to = luaL_checklstring(L,2,&unuse_l);
    const char* from = luaL_checklstring(L,3,&unuse_l);
    
    iconv_t h = iconv_open(to, from);
    if (h == (iconv_t)-1) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    size_t outsz = l*4;
    size_t avail = outsz;
    char *out = shaco_malloc(outsz);
    memset(out, 0, outsz);
   
    char *p = out;
    char *in = (char*)str;
    if (iconv(h, &in, &l, &p, &avail) == -1) {
        lua_pushnil(L);
        lua_pushstring(L,strerror(errno));
        iconv_close(h);
        shaco_free(out);
        return 2;
    } else { 
        lua_pushlstring(L, out, outsz-avail); 
        iconv_close(h);
        shaco_free(out);
        return 1;
    }
#else
    return 0;
#endif
}

static int
lsleep(lua_State *L) {
    int ms = luaL_checkinteger(L,1);
    usleep(ms*1000);
    return 0;
}

static int
lstr2bytes(lua_State *L) {
    size_t l;
    const char *s = luaL_checklstring(L,1,&l);
    char *p = lua_newuserdata(L, l);
    memcpy(p,s,l);
    lua_pushlightuserdata(L,p);
    lua_pushinteger(L,l);
    return 2;
}

static int
lbytes2str(lua_State *L) {
    const void *p = lua_touserdata(L,1);
    assert(p != NULL);
    size_t sz = (size_t)luaL_checkinteger(L,2);
    lua_pushlstring(L, p, sz);
    return 1;
}

static int
lfreebytes(lua_State *L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    void *p = lua_touserdata(L,1);
    shaco_free(p);
    return 0;
}

static int
lprintr(lua_State *L) {
    size_t l;
    const char *s = luaL_checklstring(L,1, &l);
    fwrite(s, sizeof(char), l, stdout);
    fwrite("\r", sizeof(char), 1, stdout);
    fflush(stdout);
    return 0;
}

int
luaopen_util_c(lua_State *L) {
	luaL_checkversion(L);

	luaL_Reg l[] = { 
        {"getenv", lgetenv},
        {"setenv", lsetenv},
        {"daemon", ldaemon},
        {"iconv", liconv},
        {"sleep", lsleep},
        {"printr", lprintr},
        {"str2bytes", lstr2bytes},
        {"bytes2str", lbytes2str},
        {"freebytes", lfreebytes},
        { NULL, NULL },
	}; 
	luaL_newlib(L, l);
	return 1;
}
