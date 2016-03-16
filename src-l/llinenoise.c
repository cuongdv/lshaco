#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>

static int _atexit_registered = 0;
static int _rawmode = 0;
static struct termios _orig_termios;

static void 
_rawmod_off(int fd) {
    if (_rawmode && tcsetattr(fd,TCSAFLUSH,&_orig_termios) != -1)
        _rawmode = 0;
}

static void 
_atexit_restore(void) {
    _rawmod_off(STDIN_FILENO);
}

static int 
_rawmod_on(int fd) {
    if (!isatty(STDIN_FILENO)) 
        return 1;

    struct termios raw;
    if (tcgetattr(fd,&_orig_termios) == -1)
        return 1;

    raw = _orig_termios;
    /* input modes: no break, no CR to NL, no parity check, no strip char,
     * no start/stop output control. */
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    /* output modes - disable post processing */
    //raw.c_oflag &= ~(OPOST);
    /* control modes - set 8 bit chars */
    raw.c_cflag |= (CS8);
    /* local modes - choing off, canonical off, no extended functions,
     * no signal chars (^Z,^C) */
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    /* control chars - set return condition: min number of bytes and timer.
     * We want read to return every single byte, without timeout. */
    raw.c_cc[VMIN] = 1; raw.c_cc[VTIME] = 0; /* 1 byte, no timer */

    /* put terminal in raw mode after flushing */
    if (tcsetattr(fd,TCSAFLUSH,&raw) < 0)
        return 1;
    
    _rawmode = 1;

    if (!_atexit_registered) {
        atexit(_atexit_restore);
        _atexit_registered = 1;
    }
    return 0;
}

static int 
lrawmode_on(lua_State* L) {
    int fd = luaL_checkinteger(L,1);
    if (_rawmod_on(fd) == 0)
        lua_pushboolean(L, 1);
    else
        lua_pushboolean(L, 0);
    return 1;
}

static int 
lrawmode_off(lua_State* L) {
    int fd = luaL_checkinteger(L,1);
    _rawmod_off(fd);
    return 0;
}

int
luaopen_linenoise_c(lua_State *L) {
	luaL_Reg l[] = { 
        { "rawmode_on", lrawmode_on},
        { "rawmode_off", lrawmode_off},
        { NULL, NULL },
	}; 
	luaL_newlib(L, l);
	return 1;
}
