include ../common.mk
include ../bgfx/bgfx_define.mk

default : ant.exe

mingw : default

LIBS= bgfx bullet math3d thread terrain hierarchy crypt debugger lsocket memoryfile protocol remotedebug lfs

define MakeLibs
lib$(1).a :	
	cd ./../$(1)/ && $(MAKE) lib$(1).a
endef
$(foreach v, $(LIBS), $(eval $(call MakeLibs,$(v))))

ALLLIBS= $(foreach v, $(LIBS), lib$(v).a)
LINKLIBS= $(foreach v, $(LIBS), ./../$(v)/lib$(v).a)

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

lua.o :
	cd ../lua && $(MAKE) $@ && mv $@ ../ant/

liblua.a :
	cd ../lua && $(MAKE) $@ && mv $@ ../ant/

LUAINC= -I./../lua
CFLAGS= -O2 -Wall -fPIC

ALLOBJ= preload_module.o searcher_C.o main.o

preload_module.o : preload_module.cpp preload_module.h
	g++ -std=c++17 -c $(CFLAGS) $(LUAINC) -o $@ $<

searcher_C.o : searcher_C.cpp  preload_module.h
	g++ -std=c++17 -c $(CFLAGS) $(LUAINC) -o $@ $<

main.o : main.c
	gcc -std=gnu99 -c $(CFLAGS) $(LUAINC) -o $@ $<

libcjson.a :
	cd ../../3rd/lua-cjson/ && $(MAKE) "LUA_INCLUDE_DIR=../../clibs/lua" "CJSON_LDFLAGS=" "TARGET=libcjson.a" "AR=ar rsv" && mv libcjson.a ../../clibs/ant/

ant.exe : $(ALLOBJ) $(ALLLIBS) libcjson.a
	gcc -o $@ $(ALLOBJ) liblua.a libcjson.a $(LINKLIBS) $(LIBBGFX) $(LIBBULLET) $(LIBOZZ) -lws2_32 -lstdc++
	strip --strip-unneeded $@ 
