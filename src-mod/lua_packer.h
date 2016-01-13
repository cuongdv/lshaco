#ifndef __lua_packer_h__
#define __lua_packer_h__

#include <stdio.h>

#define LP_MALLOC   shaco_malloc
#define LP_FREE     shaco_free
#include "luapacker.h"

#if !defined (LUA_PATH_SEP)
#define LUA_PATH_SEP        ";" 
#endif

#if !defined (LUA_PATH_MARK)
#define LUA_PATH_MARK		"?"
#endif

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
    struct sp_entry *entry;
    const char *filename;
    while ((path = pushnexttemplate(L, path)) != NULL) {
        filename = luaL_gsub(L, lua_tostring(L, -1), LUA_PATH_MARK, name);
        entry = ispacked(v, filename); 
        lua_pop(L, 2);
        if (entry) return entry;
    }
    return NULL;  
}

#define unpack_error(err) { \
    lua_pushfstring(L, "\n\t" err LUA_QS, package); \
    LP_FREE(p); \
    sp_entryv_fini(&v); \
    if (fp) fclose(fp); \
    return NULL; \
}

static  void * unpack_package(lua_State *L, 
        const char *name, 
        const char *package,
        const char *lua_path, 
        void **body,
        size_t *size) {
    void *p  = NULL;
    struct sp_entry *entry;
    struct sp_entryv v;
    sp_entryv_init(&v);
    FILE *fp;
    if ((fp = fopen(package, "r")) == NULL)
        unpack_error("no package");
    if (sp_lentryv(fp, &v)) 
        unpack_error("illegal package");
    if ((entry = search_package(L, &v, name, lua_path)) == NULL) 
        unpack_error("no in package");
    if (fseek(fp, entry->offset, SEEK_SET)) 
        unpack_error("seek error from package");
    p = LP_MALLOC(entry->bodysz);
    if (fread(p, entry->bodysz, 1, fp) != 1) 
        unpack_error("read error from package");
    if ((*body = sp_decrypt(p, entry->bodysz, size)) == NULL) 
        unpack_error("decrypt error from package");
    lua_pushstring(L, entry->name);
    sp_entryv_fini(&v);
    fclose(fp);
    return p;
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
        if (p) {
            lua_replace(L, -2); // filename -> name
            return p;  // filename
        } else luaL_addvalue(&msg);
    }
    lua_pop(L, 1); // pop name
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
        luaL_error(L, "'package.path' must be a string");
    void *p, *buff;
    size_t size;
    p = search_packagepath(L, name, package_path, lua_path, &buff, &size);
    lua_remove(L, -2);
    lua_remove(L, -2);
    if (p == NULL) return 1;
    const char *filename = lua_tostring(L, -1);
    int status = luaL_loadbuffer(L, buff, size, filename);
    if (status == LUA_OK) {
        lua_insert(L, -2); // buffer, filename
        LP_FREE(p);
        return 2;  /* return open function and file name */
    } else {
        LP_FREE(p);
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
            LP_FREE(p);
            return load_aux(L, status, env);
        }
        status = LUA_ERRERR;
        lua_pushfstring(L, "cannot open %s: no found in package %s", 
            fname, lua_tostring(L, lua_upvalueindex(1)));
        return load_aux(L, status, env);
    }
}

static int _error(struct shaco_context *ctx, lua_State *L, int n, const char *err) {
    lua_pop(L, n);
    shaco_error(ctx, "%s", err);
    return 1;
}

static int lua_packer(struct shaco_context *ctx, lua_State *L, const char *path) {
    lua_getfield(L, LUA_REGISTRYINDEX, "_LOADED");
    if (lua_getfield(L, -1, "package") != LUA_TTABLE)
        return _error(ctx, L, 2, "package must be a table"); 
    if (lua_getfield(L, -1, "searchers") != LUA_TTABLE)
        return _error(ctx, L, 3, "package.searchers must be a table"); 
    lua_pushstring(L, path);
    lua_setfield(L, -3, "packagepath");
    size_t len = lua_rawlen(L, -1);
    len = 1; // todo
    lua_pushvalue(L, -2);
    lua_pushcclosure(L, searcher_luapackage, 1);
    lua_rawseti(L, -2, len+1);
    lua_pop(L, 3); // pop all

    lua_pushglobaltable(L);
    lua_pushstring(L, path);
    lua_pushcclosure(L, loadfile, 1);
    lua_setfield(L, -2, "loadfile");
    lua_pop(L, 1);
    return 0;
}

#endif
