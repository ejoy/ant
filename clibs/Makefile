BIN = .
LIBS = math3d lsocket redirectfd winfile bgfx remotedebug \
		memoryfile lanes crypt assimplua hierarchy cppfs debugger bullet
PLAT = mingw

IUPLIBS = luaiup scintilla iupluaimglib iupluacontrols
IUPTARS = $(foreach v, $(IUPLIBS), $(BIN)/$(v).dll)

TARS = $(foreach v, $(LIBS), $(BIN)/$(v).dll)

all : $(TARS) $(BIN)/lua53.dll $(BIN)/lua.exe $(IUPTARS) $(BIN)/iup.exe

build_lua :
	cd lua && $(MAKE) $(PLAT)

clean_lua :
	cd lua && $(MAKE) clean

build_iup :
	cd iup && $(MAKE) -j8

clean_iup :
	cd iup && $(MAKE) clean

$(BIN)/iup.exe : build_iup
	cp iup/iup.exe $@

build_lsocket : build_lua

define COPY_iup
$(BIN)/$(1).dll : build_iup
	cp iup/$(1).dll $$@

endef

$(foreach v, $(IUPLIBS), $(eval $(call COPY_iup,$(v))))

lua/lua53.dll : build_lua

$(BIN)/lua53.dll : lua/lua53.dll
	cp $< $@

lua/lua.exe : build_lua

$(BIN)/lua.exe : lua/lua.exe
	cp $< $@

define COPY_temp
$(BIN)/$(1).dll : build_$(1)
	cp $(1)/$(1).dll $$@

build_$(1) : build_lua
	cd $(1) && $(MAKE) $(PLAT)

clean_$(1) :
	cd $(1) && $(MAKE) clean
endef

$(foreach v, $(LIBS), $(eval $(call COPY_temp,$(v))))

clean : $(addprefix clean_,$(LIBS) iup lua)
	rm -f *.dll && rm -f *.exe