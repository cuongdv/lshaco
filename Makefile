.PHONY: all clean cleanall 3rd 3rdclean 3rduninstall pack deploy patch
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
	src-shaco/shaco_clusternode.c \
	src-shaco/shaco_msg_dispatcher.c \
 	src-shaco/shaco_log.c \
	src-shaco/shaco_malloc.c \
	3rd/lsocket/src/socket.c

all_t=\
	shaco \
	tool/srcpack \
	lib-cmod/mod_lua.so \
	lib-l/shaco.so \
	lib-l/socket.so \
	lib-l/socketbuffer.so #\
#	lib-l/memory.so \
#	lib-l/serialize.so \
#	lib-l/util.so \
#	lib-l/crypt.so \
#	lib-l/mysqlaux.so \
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

CFLAGS=-g -Wall -Werror -DUSE_SHACO_MALLOC -DHAVE_MALLOC $(CFLAG)

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

lib-cmod/mod_node.so: src-mod/mod_node.c src-mod/socket_buffer.c 
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO)

lib-cmod/mod_lua.so: src-mod/mod_lua.c | lib-cmod
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 

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

lib-l/util.so: src-l/lutil.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

lib-l/crypt.so: src-l/lcrypt.c src-l/lsha1.c  | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) -lcrypto

lib-l/mysqlaux.so: src-l/lmysqlaux.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 

lib-l/md5.so: 3rd/lua-md5/md5lib.c 3rd/lua-md5/md5.c 3rd/lua-md5/compat-5.2.c | lib-l
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ILUA) -I3rd/lua-md5


tool/srcpack: tool/srcpack.c \
	3rd/lua/src/srcpack.c
	gcc $(CFLAGS) -o $@ $^ $(ILUA) 

3rd: 
	cd 3rd && make PLAT="$(PLAT)" && make install && make clean 

3rduninstall:
	cd 3rd && make uninstall

pack:
	cd tool && \
	for one in base node game db test; do \
	python srcpack.py ../lua/$$one ../bin ../lua/$$one ; \
	done
	cd ..

DEPLOY_PATH=~/server/trunk
deploy:
	cp -r bin/*.so bin/base.lso bin/shaco $(DEPLOY_PATH)/bin
	cp -r 3rdlib $(DEPLOY_PATH)

patch:
	scp bin/base.lso lvxiaojun@192.168.1.220:~/server/trunk/bin

clean:	
	rm -f $(all_t) 
	rm -rf lib-cmod
	rm -rf lib-l
	rm -f shaco
	rm -rf *.dSYM

cleanall: clean
	cd 3rd/lua && make clean
	cd 3rd/jemalloc && make clean
	rm -rf cscope.* tags
	rm -rf bin/*.lso
	rm -rf tool/*.sl
