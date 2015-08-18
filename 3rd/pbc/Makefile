CC = gcc
CFLAGS = -O2 -fPIC -DUSE_SHACO_MALLOC
#SHARED=-fPIC -shared
ifeq ($(PLAT),macosx)
	SHARED:=-fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
else
	SHARED:=-fPIC -shared
endif

AR = ar rc

BUILD = build

.PHONY : all lib clean tool

LIBSRCS = context.c varint.c array.c pattern.c register.c proto.c map.c alloc.c rmessage.c wmessage.c bootstrap.c stringpool.c decode.c
LIBNAME = libpbc.a
SONAME = libpbc.so
LSONAME = protobuf.so

TESTSRCS = addressbook.c pattern.c pbc.c float.c map.c test.c decode.c
PROTOSRCS = addressbook.proto descriptor.proto float.proto test.proto

BUILD_O = $(BUILD)/o

all : lib 

lib : $(SONAME) $(LSONAME) $(LIBNAME)

clean :
	rm -rf $(BUILD) $(SONAME) $(LSONAME)

$(BUILD) : $(BUILD_O)

$(BUILD_O) :
	mkdir -p $@

TOOL := $(BUILD)/dump

tool : $(TOOL)

$(TOOL) : | $(BUILD)
$(TOOL) : $(LIBNAME)
$(TOOL) : tool/dump.c
	cd $(BUILD) && $(CC) $(CFLAGS) -I.. -L. -o dump ../$< -lpbc

LIB_O :=

define BUILD_temp
  TAR :=  $(BUILD_O)/$(notdir $(basename $(1)))
  LIB_O := $(LIB_O) $$(TAR).o
  $$(TAR).o : | $(BUILD_O)
  -include $$(TAR).d
  $$(TAR).o : src/$(1)
	$(CC) $(CFLAGS) -c -Isrc -I. -o $$@ -MMD $$<
endef

$(foreach s,$(LIBSRCS),$(eval $(call BUILD_temp,$(s))))

$(LIBNAME) : $(LIB_O)
	cd $(BUILD) && $(AR) $(LIBNAME) $(addprefix ../,$^)

$(SONAME) : $(LIB_O)
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^ -I.

LUA_INC=../lua/src
LUA_LIB=../lua/src 
$(LSONAME) : binding/lua53/pbc-lua53.c
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^ -I. $(LDFLAGS) -lpbc -L. -I$(LUA_INC) -L$(LUA_LIB)

TEST :=

define TEST_temp
  TAR :=  $(BUILD)/$(notdir $(basename $(1)))
  TEST := $(TEST) $$(TAR)
  $$(TAR) : | $(BUILD)
  $$(TAR) : $(LIBNAME)
  $$(TAR) : test/$(1) 
	cd $(BUILD) && $(CC) $(CFLAGS) -I.. -L. -o $$(notdir $$@) ../$$< -lpbc
endef

$(foreach s,$(TESTSRCS),$(eval $(call TEST_temp,$(s))))

test : $(TEST) proto

PROTO :=

define PROTO_temp
  TAR :=  $(BUILD)/$(notdir $(basename $(1)))
  PROTO := $(PROTO) $$(TAR).pb
  $$(TAR).pb : | $(BUILD)
  $$(TAR).pb : test/$(1)
	protoc -o$$@ $$<
endef

$(foreach s,$(PROTOSRCS),$(eval $(call PROTO_temp,$(s))))

proto : $(PROTO)

.PHONY : all lib test proto clean

