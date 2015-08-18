.PHONY: linenoise.so clean 

CFLAGS=-Wall -Werror -fPIC
ifeq ($(PLAT),macosx)
	SHARED:=-dynamiclib -Wl,-undefined,dynamic_lookup
else
	SHARED:=-shared
endif

LUA_INC=../lua/src

linenoise.so: llinenoise.c ../linenoise/linenoise.c 
	gcc $(CFLAGS) $(SHARED) -o $@ $^ -I$(LUA_INC) -I../linenoise

clean:
	@rm -f linenoise.so
