#指定版本
CMAKE_MINIMUM_REQUIRED(VERSION 3.0)
#指定工程名称
PROJECT("ant-nuklear" )

#设置 lib 或dll 名
set(LUA_LIBRARIES "lua53.dll")     			   #链接库名称 
#设置include path 变量
set(LUA_INCLUDE_DIR "../../ant/clibs/lua")     #这个可以正常替换

set(BGFX_LIBRARIES "bgfx-shared-libRelease.dll")

#set(LUA_INCLUDE_DIR "d:/work/ant/clibs/lua")  #mingw 
#set(LUA_INCLUDE_DIR "/d/work/ant/clibs/lua")  #unix 

#INCLUDE_DIRECTORIES("../../ant/clibs/lua")    #common
#INCLUDE_DIRECTORIES("d:/work/ant/clibs/lua")  #mingw  
#INCLUDE_DIRECTORIES("/d/work/ant/clibs/lua")  #unix 

#设置dll,lib的链接库目录
link_directories("../../ant/clibs/lua")       #common 
#link_directories("d:/work/ant/clibs/lua")     #mingw  
#link_directories("/d/work/ant/clibs/lua")     #unix 
include_directories("../../../gits/bgfx/include")
include_directories("../../../gits/bx/include")

link_directories("../../../gits/bgfx")

include_directories("/usr/include")
link_directories("/usr/lib")

#设置链接库名称
LINK_LIBRARIES(OpenGL32 Glew32 Glfw3 stdc++ bgfx-shared-libRelease  )                       #其他链接库

SET(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

#查找包，功能和上面的设置一样，会产生覆盖
#FIND_PACKAGE(lua REQUIRED)


SET(LIB_NAME "nuklearlua")

#添加生成的库 和 源文件 
ADD_LIBRARY(
	"${LIB_NAME}"
	MODULE
	nuklear/nuklear.h
	src/nuklearlua.cpp
	src/platform_gl.cpp 
	src/platform_bgfx.cpp
	src/imageutl.cpp 
)


#include path 另一种指定
TARGET_INCLUDE_DIRECTORIES(
	"${LIB_NAME}"
	PUBLIC
	"${LUA_INCLUDE_DIR}"
)
#link lib 次序，被需求的放在后面
TARGET_LINK_LIBRARIES(
	"${LIB_NAME}"
	${LUA_LIBRARIES}
	${BGFX_LIBRARIES}
)

SET_TARGET_PROPERTIES("${LIB_NAME}" PROPERTIES PREFIX "")

#add_executable(%{PROJECT_NAME}_node src/svo_node src/system.cpp )

