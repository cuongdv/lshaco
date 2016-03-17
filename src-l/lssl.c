#include <lua.h>
#include <lauxlib.h>
#include <openssl/err.h>
#include <openssl/dh.h>
#include <openssl/ssl.h>
#include <openssl/conf.h>
#include <openssl/engine.h>

#define METANAME "LSSL*"

struct lssl {
    SSL *handle;
    BIO *rbio;
    BIO *wbio;
};

static SSL_CTX *CTX;

static int
lnew(struct lua_State *L) {
    struct lssl *self = lua_newuserdata(L, sizeof(*self));
    self->handle = SSL_new(CTX);
    self->rbio = BIO_new(BIO_s_mem());
    self->wbio = BIO_new(BIO_s_mem());
    SSL_set_bio(self->handle, self->rbio, self->wbio);
    luaL_setmetatable(L, METANAME);
    return 1;
}

static int
lfree(struct lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    struct lssl *self = lua_touserdata(L,1);
    if (self->handle) {
        SSL_free(self->handle);
        self->handle = NULL;
    }
    return 0;
}

static int
lconnect(struct lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    struct lssl *self = lua_touserdata(L, 1);
     
    SSL_set_connect_state(self->handle);
    return 0;
}

static int
lhandshake(struct lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    struct lssl *self = lua_touserdata(L, 1);
    if (!SSL_is_init_finished(self->handle)) {
        int ret = SSL_do_handshake(self->handle);
        if (ret != 1) {
            int err = SSL_get_error(self->handle, ret);
            if (err == SSL_ERROR_WANT_READ) {
                //fprintf(stderr, "want read\n");
                lua_pushboolean(L, 0);
                lua_pushliteral(L, "read");
                return 2;
                //size_t n = BIO_ctrl_pending(self->wbio);
                //fprintf(stderr, "pending size:%d\n", (int)n);
                //int i;
                //char buffer[255];
                //for (i=0; i<n; ++i) {
                //    int rsize = BIO_read(self->wbio, buffer, 10);
                //    size_t n = BIO_ctrl_pending(self->wbio);
                //fprintf(stderr, "read:%d, pending size:%d\n", 
                //        rsize, (int)n);
                //}
            } else if (err == SSL_ERROR_WANT_WRITE) {
                //fprintf(stderr, "want write\n");
                lua_pushboolean(L, 0);
                lua_pushliteral(L, "write");
                return 2;
            } else {
                lua_pushboolean(L, 0);
                return 1;
            }
        }
    }
    lua_pushboolean(L,1); // handshake ok
    return 1;
}

static int
lread(struct lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    struct lssl *self = lua_touserdata(L, 1);

    luaL_Buffer b;
    luaL_buffinit(L, &b);

    char tmp[1024];
    int n = BIO_read(self->wbio, tmp, sizeof(tmp));
    if (n > 0) {
        luaL_addlstring(&b, tmp, n);
        luaL_pushresult(&b);
        return 1;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int
lwrite(struct lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    struct lssl *self = lua_touserdata(L, 1);

    size_t l;
    const char *s = luaL_checklstring(L, 2, &l);

    BIO_write(self->rbio, s, l); // no need check
    return 0;
}

static int
lencode(struct lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    struct lssl *self = lua_touserdata(L, 1);

    size_t l;
    const char *s = luaL_checklstring(L, 2, &l);

    SSL_write(self->handle, s, l); // todo: check return
    return 0;
}

static int
ldecode(struct lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    struct lssl *self = lua_touserdata(L, 1);

    // just 1024 max, not all
    char tmp[1024];
    int ret  = SSL_read(self->handle, tmp, sizeof(tmp)); 
    if (ret > 0) {
        lua_pushlstring(L, tmp, ret);
        return 1;
    }
    int err = SSL_get_error(self->handle, ret);
    if (err == SSL_ERROR_WANT_READ) {
        lua_pushliteral(L, "");
        return 1;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static void
createmeta(struct lua_State *L) {
    luaL_Reg l[] = {
        {"connect", lconnect},
        {"handshake", lhandshake},
        {"read", lread},
        {"write", lwrite},
        {"encode", lencode},
        {"decode", ldecode},
        {"__gc", lfree},
        {NULL, NULL},
    };
    luaL_newmetatable(L, METANAME);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, l, 0);
    lua_pop(L, 1);
}

static int
_gc_ssl(lua_State *L) {
    if (CTX) {
        SSL_CTX_free (CTX);
        ERR_remove_state(0);
        ENGINE_cleanup();
        CONF_modules_unload(1);
        ERR_free_strings();
        EVP_cleanup();
        sk_SSL_COMP_free(SSL_COMP_get_compression_methods());
        CRYPTO_cleanup_all_ex_data();
        CTX = NULL;
    }
    return 0;
}

int
luaopen_ssl_c(lua_State *L) {
    if (CTX == NULL) {
        SSL_library_init();
        SSL_load_error_strings();
        ERR_load_BIO_strings();
        OpenSSL_add_all_algorithms();

        CTX = SSL_CTX_new (SSLv23_client_method ());
        if (CTX == NULL) {
            return luaL_error(L, "init ssl fail");
        }
    }

	luaL_Reg l[] = { 
        {"new", lnew},
        { NULL, NULL },
	}; 
	luaL_newlib(L, l);
    createmeta(L);

    // metatable
    lua_newtable(L);
    lua_pushcfunction(L, _gc_ssl);
    lua_setfield(L, -2, "__gc");
    lua_setmetatable(L, -2);
	return 1;
}
