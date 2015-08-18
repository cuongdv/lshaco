SUBDIRS := \
	pbc \
	lpeg \
	luafilesystem \
	lua-snapshot \
	lua-cjson \
	lua-linenoise

.PHONY : all $(SUBDIRS) dist clean

all : $(SUBDIRS)

$(SUBDIRS) :
	$(MAKE) -C $@ PLAT="$(PLAT)" || exit 1;

install :
	@mkdir -p ../3rdlib && \
	 cp pbc/libpbc.so \
		pbc/protobuf.so \
		pbc/binding/lua53/protobuf.lua \
		lpeg/lpeg.so \
		luafilesystem/src/lfs.so \
		lua-snapshot/snapshot.so \
		lua-linenoise/linenoise.so \
		lua-cjson/cjson.so \
		../3rdlib && \
	 cd ../3rdlib && \
	 cp libpbc.so \
		protobuf.so \
		snapshot.so \
		linenoise.so \
		cjson.so \
	 	../bin

uninstall:
	rm -rf ../3rdlib && \
	rm -rf \
	   ../bin/libpbc.so \
	   ../bin/protobuf.so \
	   ../bin/snapshot.so \
	   ../bin/linenoise.so \
	   ../bin/cjson.so
clean :
	@for dir in $(SUBDIRS); do $(MAKE) -C $$dir clean; done
