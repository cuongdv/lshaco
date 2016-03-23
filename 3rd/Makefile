SUBDIRS := \
	pbc \
	lpeg \
	luafilesystem \
	lua-snapshot \
	lua-cjson

.PHONY : all $(SUBDIRS) dist clean

all : $(SUBDIRS)

$(SUBDIRS) :
	$(MAKE) -C $@ PLAT="$(PLAT)" || exit 1;

install :
	@mkdir -p ../lib-3rd && \
	 cp pbc/libpbc.so \
		pbc/protobuf.so \
		lpeg/lpeg.so \
		luafilesystem/src/lfs.so \
		lua-snapshot/snapshot.so \
		lua-cjson/cjson.so \
		../lib-3rd

uninstall:
	rm -rf ../lib-3rd

clean :
	@for dir in $(SUBDIRS); do $(MAKE) -C $$dir clean; done
