#include "sh_malloc.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>

static int 
lquote_string(lua_State* L) {
    size_t l;
    const char* sql = luaL_checklstring(L, 1, &l);
    if (l==0) {
        lua_pushlstring(L, "''", 2);
        return 1;
    }   
    char *tmp = sh_malloc(l*2+2);
    const char *src = sql;
    char *dst = tmp;
    
    *dst++ = '\'';
    size_t i;
    for (i=0; i<l; ++i) {
        if ((*src & 0x80) == 0) {
            switch (*src) {
            case '\0': *dst++ = '\\'; *dst++ = '0'; break;
            case '\'': *dst++ = '\\'; *dst++ = '\''; break;
            case '\"': *dst++ = '\\'; *dst++ = '"'; break;
            case '\b': *dst++ = '\\'; *dst++ = 'b'; break;
            case '\n': *dst++ = '\\'; *dst++ = 'n'; break;
            case '\r': *dst++ = '\\'; *dst++ = 'r'; break;
            case '\t': *dst++ = '\\'; *dst++ = 't'; break;
            case 0x1a: *dst++ = '\\'; *dst++ = 'Z'; break;
            case '\\': *dst++ = '\\'; *dst++ = '\\'; break;
            default:   *dst++ = *src;
            }
        } else {
            *dst++ = *src;
        }
        src++;
    }
    *dst++ = '\'';
   
    lua_pushlstring(L, tmp, dst-tmp);
    sh_free(tmp);
    return 1;
}

int
luaopen_mysqlaux_c(lua_State *L) {
	luaL_checkversion(L);

	luaL_Reg l[] = { 
        { "quote_string", lquote_string },
        { NULL, NULL },
	}; 
	luaL_newlib(L, l);
	return 1;
}
