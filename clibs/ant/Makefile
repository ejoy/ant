include ../common.mk

ANT3RD = ../../3rd
include ant_define.mk

default : ant.exe

mingw : default

LIBS= bgfx bullet math3d thread terrain hierarchy crypt debugger lsocket protocol remotedebug window firmware platform

define MakeLibs
lib$(1).a :	
	cd ./../$(1)/ && $(MAKE) lib$(1).a && cp lib$(1).a ../ant/tmp/lib$(1).a
endef
$(foreach v, $(LIBS), $(eval $(call MakeLibs,$(v))))

ALLLIBS= $(LIBS) lua cjson
define UnpackLibs
unpack_lib$(1).a : lib$(1).a
	cd tmp && ar x lib$(1).a
endef
$(foreach v, $(ALLLIBS), $(eval $(call UnpackLibs,$(v))))
UNPACKLIBS= $(foreach v, $(ALLLIBS), unpack_lib$(v).a)

ifeq "$(PLAT)" "mingw"
liblua.a :
	cd ../lua && $(MAKE) "MYOBJS=utf8_unicode.o utf8_crt.o" $@ && mv $@ ../ant/tmp
else
liblua.a :
	cd ../lua && $(MAKE) $@ && mv $@ ../ant/tmp
endif

libcjson.a :
	cd ../../3rd/lua-cjson/ && $(MAKE) "LUA_INCLUDE_DIR=../../clibs/lua" "CJSON_LDFLAGS=" "TARGET=libcjson.a" "AR=ar rsv" && mv libcjson.a ../../clibs/ant/tmp

LUAINC= -I./../lua
CFLAGS= -O2 -Wall -fPIC

tmp/ant_searcher.o : ant_searcher.cpp ant.h ant_module_define.h ant_module_declar.h
	g++ -std=c++17 -c $(CFLAGS) $(LUAINC) -o $@ $<

main.o : main.c
	gcc -std=gnu99 -c $(CFLAGS) $(LUAINC) -o $@ $<

libant.a : tmp/ant_searcher.o $(UNPACKLIBS)
	rm -f "tmp/__.SYMDEF"
	rm -f "tmp/__.SYMDEF SORTED"
	cd tmp && ar rs $@ *.o
	mv tmp/$@ $@

ant.exe : main.o libant.a
	gcc -o $@ $^ $(LINKLIBANT)
	$(STRIP) $@ 

clean :
	rm -f tmp/*.a && rm -f tmp/*.o && rm -f ant.exe libant.a
