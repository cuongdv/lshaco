#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "shaco.h"

static const char *LOADER_SCRIPT =
"local mod, _ = ...\n"
"assert(mod, \"lua mod is nil\")\n"
"package.path = package.path .. ';' .. LUA_PATH\n"
"package.cpath = package.cpath .. ';' .. LUA_CPATH\n"
"package.packpath = LUA_PACKPATH\n"
"local main\n"
"local msg = {}\n"
"for pat in string.gmatch(LUA_MODPATH, '([^;]+);*') do\n"
"    local filename = string.gsub(pat, '?', mod)\n"
"    local f, err = loadfile(filename)\n"
"    if not f then\n"
"        table.insert(msg, err)\n"
"    else\n"
"        main = f\n"
"        break\n"
"    end\n"
"end\n"
"if not main then\n"
"    if #msg > 0 then error(table.concat(msg, [[\n]]))\n"
"    else error(\"no found lua file\")\n"
"    end\n"
"end\n"
"setmetatable(_ENV, {\n"
"__index = function(_, k)\n" 
"    error('attempt to read undeclared var `'..k..'`', 2)\n"
"end,"
"__newindex = function(_, k)\n"
"    error('attempt to write undeclared var `'..k..'`', 2)\n"
"end,"
"})"
"main()\n"
;

struct lua {
    lua_State *L;
    struct shaco_module *context;
};

struct lua *
lua_create() {
    struct lua *l = shaco_malloc(sizeof(*l));
    memset(l, 0, sizeof(*l));
    return l;
}

void
lua_free(struct lua *self) {
    if (self->L) {
        lua_close(self->L);
        self->L = NULL;
    }
    shaco_free(self);
}

static int                                        
_traceback(lua_State *L) {                        
    const char *msg = lua_tostring(L, 1);
    if (msg) {
        luaL_traceback(L, L, msg, 1);
    } else {
        lua_pushliteral(L, "(no error message)"); 
    }                                     
    return 1;
}

int
lua_init(struct shaco_module *s, const char *args) {
    struct lua *self = MODULE_SELF;
    self->context = s;
    lua_State *L = lua_newstate(shaco_lalloc, NULL);
    luaL_openlibs(L);
    lua_pushlightuserdata(L, s);
    lua_setfield(L, LUA_REGISTRYINDEX, "shaco_context");
    self->L = L;
    lua_pushcfunction(L, _traceback);

    const char *path = sh_getstr("luapath", ""); 
    lua_pushstring(L, path);
    lua_setglobal(L, "LUA_PATH");
    const char *cpath = sh_getstr("luacpath", "");
    lua_pushstring(L, cpath);
    lua_setglobal(L, "LUA_CPATH");
    const char *modpath = sh_getstr("luamodpath", "");
    lua_pushstring(L, modpath);
    lua_setglobal(L, "LUA_MODPATH");
    const char *packpath = sh_getstr("luapackpath", "");
    lua_pushstring(L, packpath);
    lua_setglobal(L, "LUA_PACKPATH");

    int r = luaL_loadstring(L, LOADER_SCRIPT);
    if (r != LUA_OK) {
        sh_error("%s", lua_tostring(L, -1));
        lua_pop(L, 2);
        return 1;
    }
    lua_pushstring(L, args);
    r = lua_pcall(L, 1, 0, 1);
    if (r != LUA_OK) {
        sh_error("%s", lua_tostring(L, -1));
        lua_pop(L, 2);
        return 1;
    } else {
        lua_pop(L, 1);
        return 0;
    }
}
