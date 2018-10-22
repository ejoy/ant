LUAINC= -I./../lua
LUALIB= -L./../lua -llua53
CFLAGS= -O2 -Wall -fPIC

PLAT= win
TARGET= subprocess.dll

CC= g++ -std=c++17 -c
AR= g++ --shared
RANLIB=strip --strip-unneeded

default : $(TARGET)

mingw :
	$(MAKE) PLAT=win TARGET=subprocess.dll

linux :
	$(MAKE) PLAT=posix TARGET=subprocess.so

subprocess.h : subprocess_$(PLAT).h

subprocess.cpp : subprocess_$(PLAT).cpp

binding.o : binding.cpp subprocess.h
	$(CC) $(CFLAGS) $(LUAINC) -o $@ $<

subprocess.o : subprocess.cpp subprocess.h
	$(CC) $(CFLAGS) $(LUAINC) -o $@ $<

$(TARGET) : binding.o subprocess.o
	$(AR) $(LUALIB) -o $@ $^
	$(RANLIB) $@

clean :
	rm -f binding.o subprocess.o subprocess.so subprocess.dll
