LUAINC= -I./../lua
LUALIB= -L./../lua -llua53
CFLAGS= -O2 -Wall -fPIC

CLIBSCC= g++ -std=c++17 -c
CLIBSAR= g++ --shared
RANLIB=strip --strip-unneeded

default : mini

mingw : default

foreach_clibs.o : foreach_clibs.cpp foreach_clibs.h foreach_eat.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

foreach_eat.o : foreach_eat.cpp foreach_eat.h memory_file.h array_view.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

memory_file.o : memory_file.cpp memory_file.h scoped_handle.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

preload_module.o : preload_module.cpp preload_module.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

preload_module_mini.o : preload_module_mini.cpp preload_module.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

clibs.o : clibs.cpp foreach_clibs.h preload_module.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

mini : clibs.o memory_file.o foreach_eat.o foreach_clibs.o preload_module_mini.o
	$(CLIBSAR) $(LUALIB) -o clibs.dll $^ -lstdc++fs
	$(RANLIB) clibs.dll

include ../common.mk
include ../bgfx/bgfx_define.mk

LIBS= bgfx bullet math3d thread terrain hierarchy crypt debugger lsocket memoryfile protocol remotedebug

define MakeLibs
lib$(1).a :	
	cd ./../$(1)/ && $(MAKE) lib$(1).a
endef
$(foreach v, $(LIBS), $(eval $(call MakeLibs,$(v))))

ALLLIBS= $(foreach v, $(LIBS), lib$(v).a)
LINKLIBS= $(foreach v, $(LIBS), ./../$(v)/lib$(v).a)

ALLOBJ= clibs.o memory_file.o foreach_eat.o foreach_clibs.o preload_module.o

LIBBGFX= $(BGFXUTILLIB) $(BIMGLIB) $(BGFXLIB)
LIBBULLET= -L$(ANT3RD)/build/bullet3/lib -lBulletDynamics -lBulletCollision -lLinearMath -lstdc++ -lHACD

ifeq ("$(BUILD_CONFIG)","Release")
LIB_SUFFIX := _r
else
LIB_SUFFIX := _d
endif
OZZLIBDIR = $(ANT3RD)/build/ozz-animation
OZZLIBSRC_DIR = $(OZZLIBDIR)/src
OZZBASE = -L $(OZZLIBSRC_DIR)/base -lozz_base$(LIB_SUFFIX)
OZZRUNTIME = -L $(OZZLIBSRC_DIR)/animation/runtime -lozz_animation$(LIB_SUFFIX)
OZZOFFLINE = -L $(OZZLIBSRC_DIR)/animation/offline -lozz_animation_offline$(LIB_SUFFIX)
OZZGEOMERTY = -L $(OZZLIBSRC_DIR)/geometry/runtime -lozz_geometry$(LIB_SUFFIX)
OZZSAMPLE = -L $(OZZLIBDIR)/samples/framework -lsample_framework$(LIB_SUFFIX)
LIBOZZ= $(OZZSAMPLE) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

full : $(ALLOBJ) $(ALLLIBS)
	$(CLIBSAR) $(LUALIB) -o clibs.dll $(ALLOBJ) -lstdc++fs $(LINKLIBS) $(LIBBGFX) $(LIBBULLET) $(LIBOZZ) -lws2_32
	$(RANLIB) clibs.dll

clean :
	rm -f *.o clibs.dll
