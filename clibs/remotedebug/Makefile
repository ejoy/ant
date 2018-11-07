PLAT= none

LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

all:  $(PLAT)

PLATS= linux mingw

none:
	@echo "Please do 'make PLATFORM' where PLATFORM is one of these:"
	@echo "   $(PLATS)"

linux: remotedebug.so

mingw: remotedebug.dll

remotedebug.o : remotedebug.c debugvar.h
	gcc $(CFLAGS) -c -o $@ $< $(LUAINC) $(LUALIB)

remotedebug.so: remotedebug.o
	gcc $(CFLAGS) --shared -o $@ $^ $(LUAINC) -fPIC

remotedebug.dll : remotedebug.o
	gcc $(CFLAGS) --shared -o $@ $^ $(LUAINC) $(LUALIB)

libremotedebug.a : remotedebug.o
	ar rsv $@ $^

clean :
	rm -f remotedebug.so remotedebug.dll
