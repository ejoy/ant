include ../common.mk

ANT3RD = ../../3rd
include ant_define.mk

ifeq "$(PLAT)" "mingw"
default : ant.exe
else
default : libant.a
endif

LIBS= bgfx bullet hierarchy math3d thread terrain crypt debugger lsocket protocol remotedebug firmware platform #window

define MakeLibs
lib$(1).a :	
	@cd ./../$(1)/ && $(MAKE) --no-print-directory lib$(1).a && cp lib$(1).a ../ant/tmp/lib$(1).a
endef
$(foreach v, $(LIBS), $(eval $(call MakeLibs,$(v))))

ALLLIBS= $(LIBS) lua cjson
define UnpackLibs
unpack_lib$(1).a : lib$(1).a
	@cd tmp && ar x lib$(1).a
endef
$(foreach v, $(ALLLIBS), $(eval $(call UnpackLibs,$(v))))
UNPACKLIBS= $(foreach v, $(ALLLIBS), unpack_lib$(v).a)

ifeq "$(PLAT)" "mingw"
liblua.a :
	@cd ../lua && $(MAKE) --no-print-directory "MYOBJS=utf8_unicode.o utf8_crt.o" $@ && mv $@ ../ant/tmp
else ifeq "$(PLAT)" "osx"
liblua.a :
	@cd ../lua && $(MAKE) --no-print-directory $@ && mv $@ ../ant/tmp
else ifeq "$(PLAT)" "ios"
liblua.a :
	@cd ../lua && $(MAKE) --no-print-directory "SYSCFLAGS=$(CFLAGS)" $@ && mv $@ ../ant/tmp
endif

libcjson.a :
	@cd ../../3rd/lua-cjson/ && $(MAKE) --no-print-directory "LUA_INCLUDE_DIR=../../clibs/lua" "CJSON_LDFLAGS=" "TARGET=libcjson.a" "AR=ar rsv" "CFLAGS=$(CFLAGS)" && mv libcjson.a ../../clibs/ant/tmp

tmp/ant_searcher.o : ant_searcher.cpp ant.h ant_module_define.h ant_module_declar.h
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

main.o : main.c
	$(CC) -c $(CFLAGS) $(LUAINC) -o $@ $<

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
