#Windows
编译器 mingw-gcc-8.2

1. 环境准备

```
pacman -S libtool
pacman -S automake
pacman -S autoconf
pacman -S pkg-config
pacman -S openssl
pacman -S libopenssl
pacman -S openssl-devel
```

2. 编译libplist
```
./autogen.sh
make
make intasll
```

3. 编译libusbmuxd
```
./autogen.sh
make SUBDIRS="common src include" INCLUDES=-I../../libplist/include
make intasll SUBDIRS="common src include"
```

4. 编译libimobiledevice/
```
./autogen.sh
make SUBDIRS="common src include docs" INCLUDES="-I../../libplist/include -I../../libusbmuxd/include"
```



