.PHONY: all clean 3rd 3rduninstall package
 #-Wpointer-arith -Winline

#mod_src=$(wildcard src-mod/*.c)
#mod_so=$(patsubst %.c,%.so,$(notdir $(mod_src)))
ILUA=-I3rd/lua/src
ISHACO=-Isrc-shaco -I3rd/lsocket/src

LIBSHACO_SRC=\
	src-shaco/shaco.c \
	src-shaco/shaco_env.c \
 	src-shaco/shaco_socket.c \
 	src-shaco/shaco_module.c \
 	src-shaco/shaco_timer.c \
	src-shaco/shaco_context.c \
	src-shaco/shaco_handle.c \
	src-shaco/shaco_harbor.c \
	src-shaco/shaco_msg_dispatcher.c \
 	src-shaco/shaco_log.c \
	src-shaco/shaco_malloc.c \
	3rd/lsocket/src/socket.c

all_t=\
	shaco \
	tool/luapacker \
	lib-cmod/mod_lua.so \
	lib-cmod/mod_harbor.so \
	lib-l/shaco.so \
	lib-l/socket.so \
	lib-l/socketbuffer.so \
	lib-l/serialize.so \
	lib-l/linenoise.so \
	lib-l/crypt.so \
	lib-l/mysqlaux.so \
	lib-l/process.so \
	lib-l/signal.so #\
#	lib-l/memory.so \
#	lib-l/util.so \
#	lib-l/md5.so

PLATS=linux macosx
UNAME=$(shell uname)
PLAT=$(if $(filter Linux%,$(UNAME)), linux,\
		$(if $(filter Darwin%,$(UNAME)), macosx,\
			undefined\
))

default: $(PLAT)

undefined:
	@echo "Please do 'make PLATFORM' where PLATFORM is one of this:"
	@echo "    $(PLATS)"

CFLAGS=-g -Wall -Werror -DHAVE_MALLOC -DUSE_SHACO_MALLOC $(CFLAG)

linux: SHARED:=-fPIC -shared
linux: EXPORT:=-Wl,-E
linux: LDLIB:=-ldl -lrt -lm

macosx: CFLAG:=-Wno-deprecated
macosx: SHARED:=-fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
macosx: EXPORT:=
macosx: LDLIB:=

linux macosx:
	$(MAKE) all CFLAG="$(CFLAG)" SHARED="$(SHARED)" EXPORT="$(EXPORT)" LDLIB="$(LDLIB)"

all: $(all_t) 

# lua
LUA_A=3rd/lua/src/liblua.a

$(LUA_A):
	cd 3rd/lua && make $(PLAT)

# jemalloc
IJEMALLOC=-I3rd/jemalloc/include/jemalloc
JEMALLOC_A=3rd/jemalloc/lib/libjemalloc_pic.a

$(JEMALLOC_A): 3rd/jemalloc/Makefile
	cd 3rd/jemalloc && make lib/libjemalloc_pic.a

3rd/jemalloc/Makefile:
	cd 3rd/jemalloc && ./autogen.sh --with-jemalloc-prefix=je_ --enable-cc-silence --disable-valgrind

shaco: src-shaco/shaco_main.c $(LIBSHACO_SRC) $(LUA_A) $(JEMALLOC_A)
	gcc $(CFLAGS) $(EXPORT) -o $@ $^ $(ISHACO) $(ILUA) $(IJEMALLOC) $(LDLIB) -lpthread

# openssl
#CRYPTO_A=3rd/openssl/libcrypto.a
#$(CRYPTO_A): 3rd/openssl/Makefile
#	cd 3rd/openssl && make libcrypto.a

lib-cmod:
	mkdir $@
lib-l:
	mkdir $@

lib-cmod/mod_lua.so: src-mod/mod_lua.c src-mod/luapacker.c | lib-cmod
	gcc $(CFLAGS) $(SHARED) -o $@ $^ -Isrc-mod $(ISHACO) $(ILUA)

lib-cmod/mod_harbor.so: src-mod/mod_harbor.c src-mod/socket_buffer.c 
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO)

lib-l/shaco.so: src-l/lshaco.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 

lib-l/socket.so: src-l/lsocket.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

lib-l/socketbuffer.so: 3rd/lsocket/src/lsocketbuffer.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ILUA)

lib-l/memory.so: src-l/lmemory.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

lib-l/serialize.so: src-l/lserialize.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

lib-l/linenoise.so: src-l/llinenoise.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

lib-l/util.so: src-l/lutil.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

lib-l/crypt.so: src-l/lcrypt.c src-l/lsha1.c  | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) -lcrypto

lib-l/mysqlaux.so: src-l/lmysqlaux.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 

lib-l/md5.so: 3rd/lua-md5/md5lib.c 3rd/lua-md5/md5.c 3rd/lua-md5/compat-5.2.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ILUA) -I3rd/lua-md5

lib-l/process.so: src-l/lprocess.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 

lib-l/signal.so: src-l/lsignal.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 

tool/luapacker: tool/luapacker.c \
	src-mod/luapacker.c
	gcc $(CFLAGS) -o $@ $^ -Isrc-mod

3rd: 
	cd 3rd && make PLAT="$(PLAT)" && make install && make clean 

3rduninstall:
	cd 3rd && make uninstall

package:
	python tool/luapacker.py ./lua-shaco lib-package
	python tool/luapacker.py ./lua-mod   lib-package
	python tool/luapacker.py ./examples  lib-package

clean:	
	rm -f $(all_t) 
	rm -rf lib-cmod
	rm -rf lib-l
	rm -rf *.dSYM
