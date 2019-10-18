LUAINC= -I./../../lua
LUALIB= -L./../../lua -llua54
CFLAGS= -O2 -Wall -fPIC

CLIBSCC= g++ -std=c++17 -c
CLIBSAR= g++ --shared
RANLIB=strip --strip-unneeded

default : clibs.dll

mingw : default

foreach_clibs.o : foreach_clibs.cpp foreach_clibs.h foreach_eat.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

foreach_eat.o : foreach_eat.cpp foreach_eat.h memory_file.h array_view.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

memory_file.o : memory_file.cpp memory_file.h scoped_handle.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

clibs.o : clibs.cpp foreach_clibs.h
	$(CLIBSCC) $(CFLAGS) $(LUAINC) -o $@ $<

clibs.dll : clibs.o memory_file.o foreach_eat.o foreach_clibs.o
	$(CLIBSAR) $(LUALIB) -o $@ $^ -lstdc++fs
	$(RANLIB) $@

clean :
	rm -f *.o clibs.dll
