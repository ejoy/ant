BIN = .
LIBS = lua53

TARGETS = $(foreach v, $(LIBS), $(BIN)/$(v).dll)

all : $(TARGETS)

lua/lua53.dll :
	cd lua && $(MAKE) mingw

$(BIN)/lua53.dll : lua/lua53.dll
	cp $< $@
	