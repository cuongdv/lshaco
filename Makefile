.PHONY: all clean 3rd 3rduninstall package cleanall
 #-Wpointer-arith -Winline

#mod_src=$(wildcard src-mod/*.c)
#mod_so=$(patsubst %.c,%.so,$(notdir $(mod_src)))
ILUA=-I3rd/lua/src
ISHACO=-Isrc-shaco 

LIBSHACO_SRC=\
	src-shaco/shaco.c \
	src-shaco/shaco_env.c \
 	src-shaco/shaco_socket.c \
	src-shaco/socket.c \
 	src-shaco/shaco_module.c \
 	src-shaco/shaco_timer.c \
	src-shaco/shaco_context.c \
	src-shaco/shaco_handle.c \
	src-shaco/shaco_harbor.c \
	src-shaco/shaco_msg_dispatcher.c \
 	src-shaco/shaco_log.c \
	src-shaco/shaco_malloc.c

all_t=\
	shaco \
	tool/luapacker \
	lib-mod/mod_lua.so \
	lib-mod/mod_harbor.so \
	lib-l/shaco.so \
	lib-l/socket.so \
	lib-l/socketbuffer.so \
	lib-l/serialize.so \
	lib-l/linenoise.so \
	lib-l/crypt.so \
	lib-l/mysqlaux.so \
	lib-l/process.so \
	lib-l/signal.so \
	lib-l/md5.so \
	lib-l/ssl.so \
	lib-l/protobuf.so
#	lib-l/memory.so \
#	lib-l/util.so \

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

SHACO_MALLOC_FLAG=-DUSE_SHACO_MALLOC
CFLAGS=-g -Wall -Werror -DDHAVE_MALLOC $(SHACO_MALLOC_FLAG) $(CFLAG)

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

# pbc
PBC_A=3rd/pbc/build/libpbc.a
$(PBC_A):
	cd 3rd/pbc && make lib CFLAGS="$(SHACO_MALLOC_FLAG) -fPIC"

# jemalloc
IJEMALLOC=-I3rd/jemalloc/include/jemalloc
JEMALLOC_A=3rd/jemalloc/lib/libjemalloc_pic.a

$(JEMALLOC_A): 3rd/jemalloc/Makefile
	cd 3rd/jemalloc && make lib/libjemalloc_pic.a

3rd/jemalloc/Makefile:
	cd 3rd/jemalloc && ./autogen.sh --with-jemalloc-prefix=je_ --enable-cc-silence --disable-valgrind

#shaco: src-shaco/shaco_main.c $(LIBSHACO_SRC) $(LUA_A) $(JEMALLOC_A)
#	gcc $(CFLAGS) $(EXPORT) -o $@ $^ $(ISHACO) $(ILUA) $(IJEMALLOC) $(LDLIB) -lpthread
shaco: src-shaco/shaco_main.c $(LIBSHACO_SRC) $(LUA_A) 
	gcc $(CFLAGS) $(EXPORT) -o $@ $^ $(ISHACO) $(ILUA) $(LDLIB) -lpthread

# openssl
#CRYPTO_A=3rd/openssl/libcrypto.a
#$(CRYPTO_A): 3rd/openssl/Makefile
#	cd 3rd/openssl && make libcrypto.a

lib-mod:
	mkdir $@
lib-l:
	mkdir $@

lib-mod/mod_lua.so: src-mod/mod_lua.c | lib-mod
	gcc $(CFLAGS) $(SHARED) -o $@ $^ -Isrc-mod $(ISHACO) $(ILUA)

lib-mod/mod_harbor.so: src-mod/mod_harbor.c src-mod/socket_buffer.c 
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO)

lib-l/shaco.so: src-l/lshaco.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 

lib-l/socket.so: src-l/lsocket.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

lib-l/socketbuffer.so: src-l/lsocketbuffer.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

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

lib-l/ssl.so: src-l/lssl.c | lib-l
	gcc $(CFLAGS) $(SHARED) -lssl -o $@ $^ $(ISHACO) $(ILUA) 

lib-l/protobuf.so: 3rd/pbc/binding/lua53/pbc-lua53.c $(PBC_A)
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) -I3rd/pbc

tool/luapacker: tool/luapacker.c
	gcc $(CFLAGS) -o $@ $^ -Isrc-mod

3rd: 
	cd 3rd && make PLAT="$(PLAT)" && make install && make clean 

3rduninstall:
	cd 3rd && make uninstall

package:
	mkdir -pv lib-package
	python tool/luapacker.py ./lua-shaco lib-package
	python tool/luapacker.py ./lua-mod   lib-package
	python tool/luapacker.py ./examples  lib-package

server: package
	mkdir -pv ~/server && mkdir -pv ~/server/bin
	cp shaco ~/server/bin
	cp -r lib-3rd/* ~/server/bin
	cp -r lib-l/* ~/server/bin
	cp -r lib-mod/* ~/server/bin
	cp -r lib-package/* ~/server/bin

dist:
	rm -rf lshaco.tgz
	tar -zcf lshaco.tgz \
	Makefile \
	shaco-foot \
	tool \
	src-shaco \
	src-mod \
	src-l \
	lua-shaco \
	lua-mod \
	examples \
	3rd
	scp lshaco.tgz qzsource:
	ssh qzsource "mkdir -pv lshaco && tar -mzxf lshaco.tgz -C lshaco && cd lshaco && make cleanall && make && make 3rd && make server"
	mkdir -pv ~/server_linux
	mkdir -pv ~/server_linux/bin
	scp qzsource:server/bin/shaco ~/server_linux/bin
	scp qzsource:server/bin/*.so ~/server_linux/bin
	scp qzsource:server/bin/*.lso ~/server_linux/bin

distclean:
	ssh qzsource "rm -rf lshaco lshaco.tgz"

clean:	
	rm -f $(all_t) 
	rm -rf lib-mod
	rm -rf lib-l
	rm -rf *.dSYM

cleanall: clean
	cd 3rd/lua && make clean
	cd 3rd/jemalloc && make clean
	cd 3rd/pbc && make clean
	rm -rf lib-3rd
	rm -rf lib-package
