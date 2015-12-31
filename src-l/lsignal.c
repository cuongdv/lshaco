#include "shaco.h"
#include <lua.h>
#include <lauxlib.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#include <sys/wait.h>

static lua_State *_signalL;
static const char *_sigstr[] = {"SIG_DFL", "SIG_IGN", NULL};
static void (*_sighandler[])(int) = {SIG_DFL, SIG_IGN};
static volatile sig_atomic_t *_sig_tag;
static int _sig_max;

static void
sig_chld(lua_State *L, int sig) {
    pid_t pid;
    int one = 0;
    int status, code;
    const char *reason, *extra;
    for (;;) {
        pid = waitpid(-1, &status, WNOHANG);
        if (pid == 0) {
            break;
        }
        if (pid == -1) {
            int err = errno;
            if (err == EINTR) 
                continue;
            if (!(err == ECHILD && one)) {
                shaco_error(NULL, "SIGCHLD waitpid fail: %s", strerror(err));
            }
            break;
        }
        one = 1;
        if (WTERMSIG(status)) {
            reason = "signal";
            code = WTERMSIG(status);
#ifdef WCOREDUMP
            extra = WCOREDUMP(status) ? "core dumped" : "";
#else
            extra = "";
#endif
        } else {
            reason = "exit";
            code = WEXITSTATUS(status);
            extra = "";
        }
        lua_pushinteger(L, sig);
        lua_rawget(L, -2);
        lua_pushinteger(L, sig);
        lua_pushinteger(L, pid);
        lua_pushstring(L, reason);
        lua_pushinteger(L, code);
        lua_pushstring(L, extra);
        if (lua_pcall(L, 5, 0, 0) != 0) {
            shaco_error(NULL, "sig_hook error: %s", lua_tostring(L, -1));
            lua_pop(L,1);
        }
    }
}

static void 
sig_hook(lua_State *L, lua_Debug *ar) {
    sigset_t set, oldset;
    sigfillset(&set);
    sigprocmask(SIG_SETMASK, &set, &oldset);
    
    lua_sethook(L, NULL, 0, 0);

    lua_pushlightuserdata(L, &_signalL);
    lua_rawget(L, LUA_REGISTRYINDEX);
 
    int sig;
    for (sig=0; sig<_sig_max; ++sig) {
        if (sig == SIGCHLD) {
            if (_sig_tag[sig+_sig_max] != _sig_tag[sig]) {
                sig_chld(L, sig);
                _sig_tag[sig+_sig_max] = _sig_tag[sig];
            }
        } else {
            while (_sig_tag[sig+_sig_max] != _sig_tag[sig]) {
                lua_pushinteger(L, sig);
                lua_rawget(L, -2);
                lua_pushinteger(L, sig);

                if (lua_pcall(L, 1, 0, 0) != 0) {
                    shaco_error(NULL, "sig_hook error: %s", lua_tostring(L, -1));
                    lua_pop(L,1);
                }
                _sig_tag[sig+_sig_max]++;
            }
        }
    }
    lua_pop(L,1);
    sigprocmask(SIG_SETMASK, &oldset, NULL);
}

static void
sig_handler(int sig) {
    if (sig >= _sig_max) {
        return; // should be no here
    }
    _sig_tag[sig]++;
    lua_sethook(_signalL, sig_hook, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

static int
sig_handler_wrap(lua_State *L) {
    int sig = luaL_checkinteger(L, lua_upvalueindex(1));
    void (*handler)(int) = lua_touserdata(L, lua_upvalueindex(2));
    handler(sig);
    return 0;
}

static int
lsignal(lua_State *L) {
    void (*handler)(int);
    int sig = luaL_checkinteger(L, 1);
    int flag;
    switch (lua_type(L, 2)) {
    case LUA_TNIL:
    case LUA_TSTRING: {
        int index = luaL_checkoption(L, 2, "SIG_DFL", _sigstr);
        handler = _sighandler[index];
        } break;
    case LUA_TFUNCTION:
        if (lua_tocfunction(L, 2) == sig_handler_wrap) {
            lua_getupvalue(L, 2, 2);
            handler = lua_touserdata(L, -1);
            lua_pop(L,1);
        } else {
            handler = sig_handler;
        }
        break;
    default:
        return luaL_argerror(L, 2, "Invalid handler type");
    }
    if (lua_gettop(L) >=3)
        flag = luaL_checkinteger(L,3);
    else flag = 0;

    struct sigaction sa, sa_old; 
    sigfillset(&sa.sa_mask);
    sa.sa_flags = flag;
    sa.sa_handler = handler;
    int ret = sigaction(sig, &sa, &sa_old);
    if (ret != 0) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    
    if (sa_old.sa_handler == sig_handler) {
        lua_pushlightuserdata(L, &_signalL);
        lua_rawget(L, LUA_REGISTRYINDEX);
        lua_pushvalue(L, 1);
        lua_rawget(L, -2);
        lua_replace(L, -2);
    } else if (sa_old.sa_handler == SIG_DFL) {
        lua_pushliteral(L, "SIG_DFL");
    } else if (sa_old.sa_handler == SIG_IGN) {
        lua_pushliteral(L, "SIG_IGN");
    } else {
        lua_pushinteger(L, sig);
        lua_pushlightuserdata(L, sa_old.sa_handler);
        lua_pushcclosure(L, sig_handler_wrap, 2); 
    }

    if (sa.sa_handler == sig_handler) {
        lua_pushlightuserdata(L, &_signalL);
        lua_rawget(L, LUA_REGISTRYINDEX);
        lua_pushvalue(L,1);
        lua_pushvalue(L,2);
        lua_rawset(L, -3);
        lua_pop(L,1);
    }
    return 1;
} 

static int
pusherror(lua_State *L, int err) {
    if (err == 0) {
        lua_pushboolean(L,1);
        return 1;
    } else {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
}

static int
lraise(lua_State *L) {
    int sig = luaL_checkinteger(L, 1);
    return pusherror(L, raise(sig));
}

static int
lkill(lua_State *L) {
    int pid = luaL_checkinteger(L,1);
    int sig = luaL_checkinteger(L,2);
    return pusherror(L, kill(pid, sig));
}

int
luaopen_signal_c(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = { 
        {"signal", lsignal},
        {"raise", lraise},
        {"kill", lkill},
        { NULL, NULL },
	}; 
	luaL_newlib(L, l);
    lua_pushlightuserdata(L, &_signalL);
    lua_newtable(L);
    lua_rawset(L, LUA_REGISTRYINDEX);
    _signalL = L;

    _sig_max = 0;
#define ASSIGN_SIG(f)  \
    lua_pushinteger(L, f); \
    lua_setfield(L, -2, #f); \
    if (_sig_max <= f) { \
        _sig_max = f+1; \
    }

#ifdef SIGABRT
	ASSIGN_SIG( SIGABRT		);
#endif
#ifdef SIGALRM
	ASSIGN_SIG( SIGALRM		);
#endif
#ifdef SIGBUS
	ASSIGN_SIG( SIGBUS		);
#endif
#ifdef SIGCHLD
	ASSIGN_SIG( SIGCHLD		);
#endif
#ifdef SIGCONT
	ASSIGN_SIG( SIGCONT		);
#endif
#ifdef SIGFPE
	ASSIGN_SIG( SIGFPE		);
#endif
#ifdef SIGHUP
	ASSIGN_SIG( SIGHUP		);
#endif
#ifdef SIGILL
	ASSIGN_SIG( SIGILL		);
#endif
#ifdef SIGINT
	ASSIGN_SIG( SIGINT		);
#endif
#ifdef SIGKILL
	ASSIGN_SIG( SIGKILL		);
#endif
#ifdef SIGPIPE
	ASSIGN_SIG( SIGPIPE		);
#endif
#ifdef SIGQUIT
	ASSIGN_SIG( SIGQUIT		);
#endif
#ifdef SIGSEGV
	ASSIGN_SIG( SIGSEGV		);
#endif
#ifdef SIGSTOP
	ASSIGN_SIG( SIGSTOP		);
#endif
#ifdef SIGTERM
	ASSIGN_SIG( SIGTERM		);
#endif
#ifdef SIGTSTP
	ASSIGN_SIG( SIGTSTP		);
#endif
#ifdef SIGTTIN
	ASSIGN_SIG( SIGTTIN		);
#endif
#ifdef SIGTTOU
	ASSIGN_SIG( SIGTTOU		);
#endif
#ifdef SIGUSR1
	ASSIGN_SIG( SIGUSR1		);
#endif
#ifdef SIGUSR2
	ASSIGN_SIG( SIGUSR2		);
#endif
#ifdef SIGSYS
	ASSIGN_SIG( SIGSYS		);
#endif
#ifdef SIGTRAP
	ASSIGN_SIG( SIGTRAP		);
#endif
#ifdef SIGURG
	ASSIGN_SIG( SIGURG		);
#endif
#ifdef SIGVTALRM
	ASSIGN_SIG( SIGVTALRM	);
#endif
#ifdef SIGXCPU
	ASSIGN_SIG( SIGXCPU		);
#endif
#ifdef SIGXFSZ
	ASSIGN_SIG( SIGXFSZ		);
#endif


#define ASSIGN_FLAG(f) \
    lua_pushinteger(L, f); \
    lua_setfield(L, -2, #f);

#ifdef SA_NOCLDSTOP
	ASSIGN_FLAG( SA_NOCLDSTOP	);
#endif
#ifdef SA_NOCLDWAIT
	ASSIGN_FLAG( SA_NOCLDWAIT	);
#endif
#ifdef SA_RESETHAND
	ASSIGN_FLAG( SA_RESETHAND	);
#endif
#ifdef SA_NODEFER
	ASSIGN_FLAG( SA_NODEFER	);
#endif
    // to cache all sig
    int size = sizeof(_sig_tag[0])*_sig_max*2;
    _sig_tag = lua_newuserdata(L, size);
    memset((void*)_sig_tag, 0, size);
    lua_pushboolean(L, 1);
    lua_rawset(L, LUA_REGISTRYINDEX); // refrence, or free by gc
	return 1;
}
