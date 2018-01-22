BIN = .
LIBS = lua53 math3d

TARGETS = $(foreach v, $(LIBS), $(BIN)/$(v).dll)

all : $(TARGETS)

lua/lua53.dll :
	cd lua && $(MAKE) mingw

$(BIN)/lua53.dll : lua/lua53.dll
	cp $< $@

math3d/math3d.dll :
	cd math3d && $(MAKE)

$(BIN)/math3d.dll : math3d/math3d.dll
	cp $< $@
