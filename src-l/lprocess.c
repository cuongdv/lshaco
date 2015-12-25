#include "shaco.h"
#include "shaco_socket.h"
#include <sys/socket.h>
#include <lua.h>
#include <lauxlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>

static char *arg_end;

extern char **environ;
extern char **shaco_os_argv;
extern char *shaco_arg;

static void
init() {
    int i;
    size_t len = 0;
    for (i=0; environ[i]; ++i) {
        len += strlen(environ[i])+1;
    }
    arg_end = shaco_os_argv[0];
    for (i=0; shaco_os_argv[i]; ++i) {
        if (arg_end == shaco_os_argv[i]) {
            arg_end = arg_end + strlen(arg_end) + 1;
        }
    }
    size_t size;
    char *p = malloc(len); // it is free by os, don't use shaco_malloc
    for (i=0; environ[i]; ++i) {
        if (arg_end == environ[i]) {
            size = strlen(environ[i]) + 1;
            arg_end = arg_end + size;
            strcpy(p, environ[i]);
            environ[i] = p;
            p += size;
        } 
    }
    --arg_end;
}

static inline char *
_safe_memcpy(char *dst, const char *src, int n, char *end) {
    int size = end-dst;
    if (size > n)
        size = n;
    if (size > 0)
        memcpy(dst, src, size);
    return dst + size;
}

static int
lsettitle(lua_State *L) {
    size_t l;
    const char *title = luaL_checklstring(L, 1, &l);

    shaco_os_argv[1] = NULL;
   
    char *p = shaco_os_argv[0];
    char *end = arg_end;

    p = _safe_memcpy(p, "shaco: ", 7, end);
    p = _safe_memcpy(p, title, l, end);
    p = _safe_memcpy(p, " ", 1, end);
    p = _safe_memcpy(p, shaco_arg, strlen(shaco_arg), end);
    *p = '\0';
    if (end - p > 0) {
        memset(p+1, '\0', end-p); // pad use '\0', or is would still show in ps 
    }
    return 0;
}

static int
lfork(lua_State *L) {
    int fildes[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, fildes)) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    pid_t pid = fork();
    if (pid < 0) {
        close(fildes[0]);
        close(fildes[1]);
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    } else if (pid > 0) {
        close(fildes[0]);
        lua_pushinteger(L, pid);
        lua_pushinteger(L, fildes[1]);
        return 2;
    } else {
        close(fildes[1]);
        // close  stdin, stout, stderr
        // close  log
        // close  net socket
        int fd;
        if ((fd = open("/dev/null", O_RDWR, 0)) != -1) {
            dup2(fd, STDIN_FILENO);
            //dup2(fd, STDOUT_FILENO);
            //dup2(fd, STDERR_FILENO);
            if (fd > STDERR_FILENO) close(fd);
        }
        shaco_socket_fini();
        shaco_socket_init(shaco_optint("maxsocket", 0));
        lua_pushinteger(L, 0);
        lua_pushinteger(L, fildes[0]);
        return 2;
    }
}

static int
lgetpid(lua_State *L) {
    lua_pushinteger(L, getpid());
    return 1;
}

int
luaopen_process_c(lua_State *L) {
	luaL_checkversion(L);
    init();
	luaL_Reg l[] = { 
        {"fork", lfork },
        {"getpid", lgetpid },
        {"settitle", lsettitle },
        { NULL, NULL },
	}; 
	luaL_newlib(L, l);
	return 1;
}
