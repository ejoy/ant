include ../common.mk

MOBILE_DEVICE_PATH = $(ANT3RD)/libimobiledevice
PLIST_PATH = $(ANT3RD)/libplist
USBMUXD_PATH = $(ANT3RD)/libusbmuxd

IMOBILEDEVICE_INC = -I$(MOBILE_DEVICE_PATH)/include -I$(PLIST_PATH)/include -I$(USBMUXD_PATH)/include
IMOBILEDEVICE_LIB = -L$(MOBILE_DEVICE_PATH)/src/.libs -limobiledevice -L$(USBMUXD_PATH)/src/.libs -lusbmuxd -L$(PLIST_PATH)/src/.libs -lplist

CFLAGS = -O2 -Wall
CXX = g++

mingw : libimobiledevicelua.dll

libimobiledevicelua.o : libimobiledevicelua.cpp  
	$(CXX) $(CFLAGS) -c -o $@ $^ -L. $(LUAINC) $(IMOBILEDEVICE_INC)
	
libimobiledevicelua.dll : libimobiledevicelua.o
	$(CXX) $(CFLAGS) $(LD_SHARED) -o $@ $^ -L. $(LUALIB) $(IMOBILEDEVICE_LIB) -lws2_32 -lssl -lcrypto -lz -lOle32

clean :
	rm -f libimobiledevicelua.dll
