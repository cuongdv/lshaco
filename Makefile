.PHONY: all clean cleanall 3rd 3rdclean 3rduninstall pack deploy patch
 #-Wpointer-arith -Winline

BIN_DIR=bin
MOD_DIR=mod
#mod_src=$(wildcard $(MOD_DIR)/*.c)
#mod_so=$(patsubst %.c,%.so,$(notdir $(mod_src)))
ILUA=-I3rd/lua/src
ISHACO=-Ilibshaco -I3rd/lsocket/src

LIBSHACO_SRC=\
	libshaco/sh_init.c \
	libshaco/sh_start.c \
	libshaco/sh_prepare.c \
	libshaco/sh_sig.c \
	libshaco/sh_check.c \
	libshaco/sh_env.c \
 	libshaco/sh_socket.c \
 	libshaco/sh_module.c \
 	libshaco/sh_timer.c \
 	libshaco/sh_log.c \
	libshaco/sh_reload.c \
	libshaco/sh_node.c \
	libshaco/sh_util.c \
	libshaco/sh_array.c \
	libshaco/sh_malloc.c \
	3rd/lsocket/src/socket.c

mod_so=\
	$(BIN_DIR)/mod_master.so
	#$(BIN_DIR)/mod_keepalivec.so \
	#$(BIN_DIR)/mod_keepalived.so \
	#$(BIN_DIR)/mod_gate.so

all_t=\
	$(BIN_DIR)/shaco \
	$(BIN_DIR)/shaco-cli \
	$(BIN_DIR)/test \
	tool/srcpack \
	$(BIN_DIR)/mod_node.so \
	$(BIN_DIR)/mod_log.so \
	$(BIN_DIR)/mod_lua.so \
	$(BIN_DIR)/shaco.so \
	$(BIN_DIR)/socket.so \
	$(BIN_DIR)/socketbuffer.so \
	$(BIN_DIR)/memory.so \
	$(BIN_DIR)/serialize.so \
	$(BIN_DIR)/util.so \
	$(BIN_DIR)/crypt.so \
	$(BIN_DIR)/mysqlaux.so \
	$(BIN_DIR)/md5.so \
	$(mod_so)

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

# openssl
#CRYPTO_A=3rd/openssl/libcrypto.a
#$(CRYPTO_A): 3rd/openssl/Makefile
#	cd 3rd/openssl && make libcrypto.a

# shaco
$(mod_so): $(BIN_DIR)/%.so: $(MOD_DIR)/%.c
	@rm -f $@
	gcc $(CFLAGS) $(SHARED) -o $@ $< $(ISHACO)

$(BIN_DIR)/mod_node.so: $(MOD_DIR)/mod_node.c $(MOD_DIR)/socket_buffer.c 
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO)

$(BIN_DIR)/mod_log.so: $(MOD_DIR)/mod_log.c \
	3rd/elog/elog.c \
	3rd/elog/elog_appender_file.c \
	3rd/elog/elog_appender_rollfile.c
	@rm -f $@
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) -I3rd/elog 

$(BIN_DIR)/mod_lua.so: $(MOD_DIR)/mod_lua.c
	@rm -f $@
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 


$(BIN_DIR)/shaco.so: lshaco/lshaco.c
	@rm -f $@
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 

$(BIN_DIR)/socket.so: lshaco/lsocket.c
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

$(BIN_DIR)/socketbuffer.so: 3rd/lsocket/src/lsocketbuffer.c
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ILUA)

$(BIN_DIR)/memory.so: lshaco/lmemory.c
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

$(BIN_DIR)/serialize.so: lshaco/lserialize.c
	@rm -f $@
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

$(BIN_DIR)/util.so: lshaco/lutil.c
	@rm -f $@
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA)

$(BIN_DIR)/crypt.so: lshaco/lcrypt.c lshaco/lsha1.c 
	@rm -f $@
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) -lcrypto

$(BIN_DIR)/mysqlaux.so: lshaco/lmysqlaux.c 
	@rm -f $@
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ISHACO) $(ILUA) 

$(BIN_DIR)/md5.so: 3rd/lua-md5/md5lib.c 3rd/lua-md5/md5.c 3rd/lua-md5/compat-5.2.c
	@rm -f $@
	gcc $(CFLAGS) $(SHARED) -o $@ $^ $(ILUA) -I3rd/lua-md5

$(BIN_DIR)/shaco: main/shaco.c $(LIBSHACO_SRC) $(LUA_A) $(JEMALLOC_A)
	gcc $(CFLAGS) $(EXPORT) -o $@ $^ $(ISHACO) $(ILUA) $(IJEMALLOC) $(LDLIB) -lpthread

$(BIN_DIR)/test: main/test.c
	gcc $(CFLAGS) -o $@ $^ $(LDLIB)

$(BIN_DIR)/shaco-cli: tool/shaco-cli.c
	gcc $(CFLAGS) -o $@ $^ -lpthread

tool/srcpack: main/srcpack.c \
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
	cp -r bin/*.so bin/base.lso bin/shaco bin/shaco-cli $(DEPLOY_PATH)/bin
	cp -r 3rdlib $(DEPLOY_PATH)

patch:
	scp bin/base.lso lvxiaojun@192.168.1.220:~/server/trunk/bin

clean:	
	rm -f $(all_t) 
	rm -rf ./bin/*.dSYM ./tool/*.dSYM

cleanall: clean
	cd 3rd/lua && make clean
	cd 3rd/jemalloc && make clean
	rm -rf cscope.* tags
	rm -rf bin/*.lso
	rm -rf tool/*.sl
