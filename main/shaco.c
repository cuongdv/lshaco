#include "sh.h"
#include "sh_env.h"
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
            sh_setnumenv(key, lua_tonumber(L, -1));
            break;
        case LUA_TSTRING:
            sh_setenv(key, lua_tostring(L, -1));
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
    lua_State* L = lua_newstate(sh_lalloc, NULL);
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
    sh_env_init();

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
                sh_setenv(&(argv[i][2]), argv[i+1]);
                i++;
            } else {
                usage(argv[0]);
                return 1;
            }
        }
    }
    int len = argc-1;
    for (i=0; i<argc; ++i) {
        len += strlen(argv[i]);
    }
    char *args = sh_malloc(len+1);
    char *p = args;
    int n;
    for (i=0; i<argc; ++i) {
        strcpy(p, argv[i]);
        n = strlen(argv[i]);
        p += n;
        *p = ' ';
        p += 1;
    }
    *(p-1) = '\0';

    sh_setenv("startup_args", args);
    sh_free(args);

    if (sh_getint("daemon", 0)) {
        daemon(1, 1);
    }

    //for (;;) {
    //fprintf(stderr, "mem ago:%f\n", sh_memory_used()/1024.f);
    //int action=0;
    //fprintf(stderr, "action 1 to continue:");
    //scanf("%d", &action);
    //if (action == 0) 
        //break;
    //int count, size;
    //scanf("%d %d", &size, &count);
    //fprintf(stderr, "alloc begin: size=%d, count=%d\n", size, count);
    //char **pp = sh_malloc(sizeof(char*)*count);
    //for (i=0;i<count;++i) {
        //pp[i] = sh_malloc(size);
    //}

    //fprintf(stderr, "alloc ok\n");
    //fprintf(stderr, "mem alloc:%f", sh_memory_used()/1024.f);

    //scanf("%d", &i);
    //fprintf(stderr, "free begin\n");
    //for (i=0; i<count;++i) {
        //sh_free(pp[i]);
    //}
    //fprintf(stderr, "free ok %d\n",count);
    //sh_free(pp);
    
    //fprintf(stderr, "mem free:%f", sh_memory_used()/1024.f);
    //}

    sh_init();
    sh_start();
    sh_env_fini();
    return 0;
}
