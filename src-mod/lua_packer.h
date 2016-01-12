#ifndef __lua_packer_h__
#define __lua_packer_h__

#include <stdio.h>

#include "luapacker.h"

#if !defined (LUA_PATH_SEP)
#define LUA_PATH_SEP        ";" 
#endif

#if !defined (LUA_PATH_MARK)
#define LUA_PATH_MARK		"?"
#endif

static int _error(lua_State *L, int top, const char *str) {
    lua_settop(L, top);
    shaco_error(NULL, "%s", str);
    return 1;
}

static const char *pushnexttemplate (lua_State *L, const char *path) {
    const char *l;
    while (*path == *LUA_PATH_SEP) path++;  /* skip separators */
    if (*path == '\0') return NULL;  /* no more templates */
    l = strchr(path, *LUA_PATH_SEP);  /* find next separator */
    if (l == NULL) l = path + strlen(path);
    lua_pushlstring(L, path, l - path);  /* template */
    return l;
}

static struct sp_entry *ispacked(struct sp_entryv *v, const char *filename) {
    size_t sz = strlen(filename);
    int i;
    for (i=0; i<v->c; ++i) {
        struct sp_entry *entry = &v->v[i];
        if (entry->nsz==sz && 
            !memcmp(filename, entry->name, sz))
            return entry;
    }
    return NULL;
}

static struct sp_entry *search_package(lua_State *L, 
        struct sp_entryv *v,
        const char *name,
        const char *path) {
    while ((path = pushnexttemplate(L, path)) != NULL) {
        const char *filename = luaL_gsub(L, lua_tostring(L, -1),
                                     LUA_PATH_MARK, name);
        lua_remove(L, -2); // remove path
        struct sp_entry *entry = ispacked(v, filename); 
        if (entry) return entry;
    }
    return NULL;  
}

static void * unpack_package(lua_State *L, 
        const char *name, 
        const char *package,
        const char *lua_path, 
        void **body,
        size_t *size) {
    FILE *fp = fopen(package, "r");
    if (fp == NULL) {
        lua_pushfstring(L, "\n\tno package" LUA_QS, package);
        return NULL;
    }
    struct sp_entryv v;
    sp_entryv_init(&v);
    if (sp_lentryv(fp, &v)) {
        fclose(fp);
        lua_pushfstring(L, "\n\tillegal package" LUA_QS, package);
        return NULL;
    }
    struct sp_entry *entry;
    entry = search_package(L, &v, name, lua_path);
    if (entry == NULL) {
        sp_entryv_fini(&v);
        fclose(fp);
        lua_pushfstring(L, "\n\tno in package" LUA_QS, package);
        return NULL;
    }
    void *p = shaco_malloc(entry->bodysz);
    fseek(fp, entry->offset, SEEK_SET);
    fread(p, entry->bodysz, 1, fp);
    *body = sp_decrypt(p, entry->bodysz, size);
    if (*body == NULL) {
        shaco_free(p);
        sp_entryv_fini(&v);
        fclose(fp);
        lua_pushfstring(L, "\n\tdecrypt fail package" LUA_QS, package);
        return NULL;
    } else { 
        lua_pushstring(L, entry->name);
        sp_entryv_fini(&v);
        fclose(fp);
        return p;
    }
}

static char *
search_packagepath(lua_State *L, 
        const char *name,
        const char *package_path, 
        const char *lua_path, 
        void **body, size_t *size) {
    luaL_Buffer msg;  /* to build error message */
    luaL_buffinit(L, &msg);

    name = luaL_gsub(L, name, ".", LUA_DIRSEP);  /* replace it by 'dirsep' */

    while ((package_path = pushnexttemplate(L, package_path)) != NULL) {
        const char *package = lua_tostring(L,-1);
        char *p = unpack_package(L, name, package, lua_path, body, size);
        lua_remove(L, -2); // remove  path template
        if (p) return p;  // filename
        else luaL_addvalue(&msg);
    }
    luaL_pushresult(&msg); // error string
    return NULL;
}


static int searcher_luapackage(lua_State *L) {
    const char *name = luaL_checkstring(L,1); 
    lua_getfield(L, lua_upvalueindex(1), "packagepath");
    const char *package_path = lua_tostring(L, -1);
    if (package_path == NULL)
        luaL_error(L, "'package.packagepath' must be a string");
    lua_getfield(L, lua_upvalueindex(1), "path");
    const char *lua_path = lua_tostring(L, -1);
    if (lua_path == NULL)
        luaL_error(L, "'pcakge.path' must be a string");
    void *p, *buff;
    size_t size;
    p = search_packagepath(L, name, package_path, lua_path, &buff, &size);
    lua_replace(L, -3); // filename | error string -> packagepath
    lua_pop(L, 1); // pop path
    if (p == NULL) {
        return 1;
    }
    const char *filename = lua_tostring(L, -1);
    int status = luaL_loadbuffer(L, buff, size, filename);
    if (status == LUA_OK) {
        lua_insert(L, -2); // buffer, filename
        shaco_free(p);
        return 2;  /* return open function and file name */
    } else {
        shaco_free(p);
        return luaL_error(L, "error loading module '%s' from file '%s':\n\t%s",
                name, filename, lua_tostring(L, -1));
    }
}

static int load_aux (lua_State *L, int status, int envidx) {
  if (status == LUA_OK) {
    if (envidx != 0) {  /* 'env' parameter? */
      lua_pushvalue(L, envidx);  /* environment for loaded function */
      if (!lua_setupvalue(L, -2, 1))  /* set it as 1st upvalue */
        lua_pop(L, 1);  /* remove 'env' if not used by previous call */
    }
    return 1;
  }
  else {  /* error (message is on top of the stack) */
    lua_pushnil(L);
    lua_insert(L, -2);  /* put before error message */
    return 2;  /* return nil plus error message */
  }
}

static int readable (const char *filename) {
    FILE *f = fopen(filename, "r");  /* try to open file */
    if (f == NULL) return 0;  /* open failed */
    fclose(f);
    return 1;
}

static int loadfile(lua_State *L) {
    int status;
    const char *fname = luaL_optstring(L, 1, NULL);
    const char *mode = luaL_optstring(L, 2, NULL);
    int env = (!lua_isnone(L, 3) ? 3 : 0);  /* 'env' index or 0 if no 'env' */
    if (readable(fname)) {
        status = luaL_loadfilex(L, fname, mode);
        return load_aux(L, status, env);
    } else {
        const char *path, *package; 
        char *p, *body;
        size_t size;
        path = lua_tostring(L, lua_upvalueindex(1));
        while ((path = pushnexttemplate(L, path)) != NULL) {
            package = lua_tostring(L,-1);
            p = sp_unpack(package, fname, &body, &size);
            lua_pop(L,1);
            if (p == NULL) continue;
            status = luaL_loadbuffer(L, body, size, fname);
            sp_free(p);
            return load_aux(L, status, env);
        }
        status = LUA_ERRERR;
        lua_pushfstring(L, "cannot open %s: no found in package %s", 
            fname, lua_tostring(L, lua_upvalueindex(1)));
        return load_aux(L, status, env);
    }
}

static int lua_packer(lua_State *L, const char *path) {
    int top = lua_gettop(L);
    lua_getfield(L, LUA_REGISTRYINDEX, "_LOADED");
    if (lua_getfield(L, -1, "package") != LUA_TTABLE)
        return _error(L, top, "package must be a table"); 
    if (lua_getfield(L, -1, "searchers") != LUA_TTABLE)
        return _error(L, top, "package.searchers must be a table"); 
    lua_pushstring(L, path);
    lua_setfield(L, -3, "packagepath");
    size_t len = lua_rawlen(L, -1);
    len = 1; // todo
    lua_pushvalue(L, -2);
    lua_pushcclosure(L, searcher_luapackage, 1);
    lua_rawseti(L, -2, len+1);
    lua_pop(L, 3); // pop package.searchers, package

    lua_pushglobaltable(L);
    lua_pushstring(L, path);
    lua_pushcclosure(L, loadfile, 1);
    lua_setfield(L, -2, "loadfile");

    lua_settop(L, top);
    return 0;
}

#endif
