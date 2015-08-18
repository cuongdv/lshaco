.PHONY : snapshot.so clean

LUA_INC=../lua/src
ifeq ($(PLAT),macosx)
	SHARED:=-fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
else
	SHARED:=-fPIC -shared
endif

snapshot.so: snapshot.c
	gcc -Wall $(SHARED) -o $@ $^ -I$(LUA_INC) 

clean:
	@rm -f snapshot.so
