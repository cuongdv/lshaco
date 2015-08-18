.PHONY: liblinenoise.so clean 

CFLAGS=-g -Wall -Werror 
ifeq ($(PLAT),macosx)
	SHARED:=-fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
else
	SHARED:=-fPIC -shared
endif
liblinenoise.so: linenoise.c
	gcc $(CFLAGS) $(SHARED) -o $@ $^ 

clean:
	rm -f liblinenoise.so 
