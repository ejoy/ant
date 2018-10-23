include ../common.mk

MOBILE_DEVICE_PATH = $(ANT3RD)/libimobiledevice
PLIST_PATH = $(ANT3RD)/libplist
USBMUXD_PATH = $(ANT3RD)/libusbmuxd

IMOBILEDEVICE_INC = -I $(MOBILE_DEVICE_PATH)/include -I $(PLIST_PATH)/include -I $(USBMUXD_PATH)/include
IMOBILEDEVICE_LIB = -L $(MOBILE_DEVICE_PATH)/src/.libs -limobiledevice -L $(PLIST_PATH)/src/.libs -lplist -L $(USBMUXD_PATH)/src/.libs -lusbmuxd

CFLAGS = -O2 -Wall
CXX = g++

mingw : libimobiledevicelua.dll

libimobiledevicelua.o : libimobiledevicelua.cpp  
	$(CXX) $(CFLAGS) -c -o $@ $^ -L. $(LUAINC) $(IMOBILEDEVICE_INC)
	
libimobiledevicelua.dll : libimobiledevicelua.o
	$(CXX) $(CFLAGS) --shared -o $@ $^ -L. $(LUALIB) $(IMOBILEDEVICE_LIB)
	cp -R libimobiledevicelua.dll ../../bin
clean :
	rm -f libimobiledevicelua.dll