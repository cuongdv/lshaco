#include "shaco.h"
#include "shaco_env.h"
#include "shaco_malloc.h"
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

static void
_init_env(lua_State *L) {
	lua_pushglobaltable(L);
	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		if (lua_type(L, -2) != LUA_TSTRING) {
			fprintf(stderr, "Invalid config key type\n");
			exit(1);
		}
        const char* key = lua_tostring(L, -2);
        if (key[0] == '_') {
            lua_pop(L,1);
            continue; // no read
        }
        switch (lua_type(L, -1)) {
        case LUA_TBOOLEAN:
        case LUA_TNUMBER:
            if (lua_isinteger(L,-1))
                shaco_setinteger(key, lua_tointeger(L,-1));
            else
                shaco_setfloat(key, lua_tonumber(L,-1));
            break;
        case LUA_TSTRING:
            shaco_setenv(key, lua_tostring(L, -1));
            break;
        default:
            //fprintf(stderr, "Invalid config table key %s\n", key);
            //exit(1);
            break;
        }
		lua_pop(L,1);
	}
	lua_pop(L,1);
}

static void
sh_env_load(const char* file) {
    lua_State* L = lua_newstate(shaco_lalloc, NULL);
    luaL_openlibs(L);
    if (luaL_dofile(L, file) != LUA_OK) {
        fprintf(stderr, "Error load config file, %s\n", lua_tostring(L, -1));
        exit(1);
    }
    _init_env(L); 
    lua_close(L);
}

static void
usage(const char* app) {
    fprintf(stderr, "usage: %s config [--key value]\n", app);
}

int 
main(int argc, char* argv[]) {
    shaco_env_init();

    int i;
    if (argc > 1) {
        int start;
        if (strncmp(argv[1], "--", 2)) {
            sh_env_load(argv[1]);
            start = 2;
        } else {
            start = 1;
        }
        int lastarg;
        for (i=start; i<argc; ++i) {
            lastarg = i==argc-1;
            if (!strncmp(argv[i], "--", 2) && 
                 argv[i][2] != '\0' &&
                !lastarg) {
                shaco_setenv(&(argv[i][2]), argv[i+1]);
                i++;
            } else {
                usage(argv[0]);
                return 1;
            }
        }
    }
    //int len = argc-1;
    //for (i=0; i<argc; ++i) {
    //    len += strlen(argv[i]);
    //}
    //char *args = shaco_malloc(len+1);
    //char *p = args;
    //int n;
    //for (i=0; i<argc; ++i) {
    //    strcpy(p, argv[i]);
    //    n = strlen(argv[i]);
    //    p += n;
    //    *p = ' ';
    //    p += 1;
    //}
    //*(p-1) = '\0';

    //shaco_setenv("startup_args", args);
    //shaco_free(args);

    shaco_init();
    shaco_start();
    shaco_fini();
    return 0;
}
