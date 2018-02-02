PLAT= none

LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -g -Wall

all:  $(PLAT)

PLATS= linux mingw

none:
	@echo "Please do 'make PLATFORM' where PLATFORM is one of these:"
	@echo "   $(PLATS)"

linux: remotedebug.so

mingw: remotedebug.dll

remotedebug.so: remotedebug.c debugvar.h
	gcc $(CFLAGS) --shared -o $@ $< $(LUAINC) -fPIC

remotedebug.dll : remotedebug.c debugvar.h
	gcc $(CFLAGS) --shared -o $@ $< $(LUAINC) $(LUALIB)

clean :
	rm -f remotedebug.so remotedebug.dll
