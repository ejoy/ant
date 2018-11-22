include ../common.mk

CFLAGS = -O2 -Wall

mingw: remotedebug.dll

linux: remotedebug.so

remotedebug.o : remotedebug.c debugvar.h
	gcc $(CFLAGS) -c -o $@ $< $(LUAINC)

remotedebug.so: remotedebug.o
	gcc $(CFLAGS) --shared -o $@ $^ $(LUAINC) -fPIC

remotedebug.dll : remotedebug.o
	gcc $(CFLAGS) --shared -o $@ $^ $(LUAINC) $(LUALIB)

libremotedebug.a : remotedebug.o
	ar rsv $@ $^

clean :
	rm -f remotedebug.so remotedebug.dll
