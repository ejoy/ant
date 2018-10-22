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

binding_$(PLAT).o : binding.cpp subprocess.h
	$(CC) $(CFLAGS) $(LUAINC) -o $@ $<

subprocess_$(PLAT).o : subprocess_$(PLAT).cpp subprocess.h
	$(CC) $(CFLAGS) $(LUAINC) -o $@ $<

$(TARGET) : binding_$(PLAT).o subprocess_$(PLAT).o
	$(AR) $(LUALIB) -o $@ $^
	$(RANLIB) $@

clean :
	rm -f *.o subprocess.so subprocess.dll
