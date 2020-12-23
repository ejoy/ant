#===================================
# Build script for RmlUi ===========
#===================================

cmake_minimum_required(VERSION 3.1)

if(APPLE)
	# This has to be before most other options so CMake properly handles the 
	# compiler variables, it MUST bebefore the project() definition
	if(IOS_PLATFORM)
		set(CMAKE_TOOLCHAIN_FILE CMake/Platform/iOS.cmake)
	endif(IOS_PLATFORM)

	option(BUILD_UNIVERSAL_BINARIES "Build universal binaries for all architectures supported" ON)
	if (NOT CMAKE_OSX_ARCHITECTURES AND BUILD_UNIVERSAL_BINARIES)
		if(IOS)
			# set the architecture for iOS 
			if (${IOS_PLATFORM} STREQUAL "OS")
				set (IOS_ARCH armv6 armv7 armv7s arm64)
				set (CMAKE_OSX_ARCHITECTURES ${IOS_ARCH} CACHE STRING  "Build architecture for iOS")
			else (${IOS_PLATFORM} STREQUAL "OS")
				set (IOS_ARCH x86_64)
				set (CMAKE_OSX_ARCHITECTURES ${IOS_ARCH} CACHE STRING  "Build architecture for iOS Simulator")
			endif (${IOS_PLATFORM} STREQUAL "OS")

		else(IOS)
			# set the architectures for OS X
			set (OSXI_ARCH x86_64)
			set (CMAKE_OSX_ARCHITECTURES ${OSXI_ARCH} CACHE STRING  "Build architecture for OS X universal binaries")
		endif(IOS)
	endif (NOT CMAKE_OSX_ARCHITECTURES AND BUILD_UNIVERSAL_BINARIES)
endif(APPLE)

if(COMMAND cmake_policy)
	cmake_policy(SET CMP0015 NEW)
endif(COMMAND cmake_policy)

# Enable the use of MACOSX_RPATH by default for CMake v3.0+; this effectively 
# allows plug 'n' play functionality, so to speak -- the resulting shared 
# library files can simply be copied over into the end-user's application 
# bundle or framework bundle. No mucking around with install_name_tool.
#
# 	See also: 
# cmake --help-policy cmp0042
# http://www.kitware.com/blog/home/post/510
if(POLICY CMP0042)
	cmake_policy(SET CMP0042 NEW)
endif(POLICY CMP0042)
if (POLICY CMP0072)
	cmake_policy (SET CMP0072 NEW)
endif(POLICY CMP0072)
if(POLICY CMP0074)
	cmake_policy(SET CMP0074 NEW)
endif(POLICY CMP0074)

project(RmlUi LANGUAGES C CXX VERSION 4.0)

set(RMLUI_VERSION_RELEASE false)

if(RMLUI_VERSION_RELEASE)
	set(RMLUI_VERSION_SUFFIX "")
else()
	set(RMLUI_VERSION_SUFFIX "-dev")
endif()

set(RMLUI_VERSION_SHORT ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}${RMLUI_VERSION_SUFFIX})

# paths
include(GNUInstallDirs)

# Search in the 'cmake' directory for additional CMake modules.
list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/CMake;${PROJECT_SOURCE_DIR}/CMake/Modules)

#===================================
# Provide hints as to where depends=
# might be found                   =
#===================================

if(NOT DEFINED ENV{FREETYPE_DIR})
	set(ENV{FREETYPE_DIR} "${PROJECT_SOURCE_DIR}/Dependencies")
endif()

if(NOT DEFINED ENV{SDL2DIR})
	set(ENV{SDL2DIR} "${PROJECT_SOURCE_DIR}/Dependencies")
endif()

if(NOT DEFINED ENV{SDL2_IMAGE_DIR})
	set(ENV{SDL2_IMAGE_DIR} "${PROJECT_SOURCE_DIR}/Dependencies")
endif()

if(NOT DEFINED ENV{SFML_ROOT})
	set(ENV{SFML_ROOT} "${PROJECT_SOURCE_DIR}/Dependencies")
endif()

if(NOT DEFINED ENV{TRACY_DIR})
	set(ENV{TRACY_DIR} "${PROJECT_SOURCE_DIR}/Dependencies")
endif()

if(NOT DEFINED ENV{RLOTTIE_DIR})
	set(ENV{RLOTTIE_DIR} "${PROJECT_SOURCE_DIR}/Dependencies/rlottie")
endif()

#===================================
# Build options ====================
#===================================

if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Release CACHE STRING
		"Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel."
		FORCE)
endif()

if(NOT IOS)
	option(BUILD_SHARED_LIBS "Build shared (dynamic) libraries" ON)
endif(NOT IOS)

if(APPLE)
	option(BUILD_FRAMEWORK "Build Framework bundle for OSX" OFF)
endif()

option(MATRIX_ROW_MAJOR "Use row-major matrices. Column-major matrices are used by default." OFF)

if(APPLE)
	if(IOS)
		if(BUILD_SHARED_LIBS)
			message(FATAL_ERROR "BUILD_SHARED_LIBS must be OFF for iOS builds.  iOS does not support shared libraries.")
		endif(BUILD_SHARED_LIBS)
	endif(IOS)

	if(BUILD_FRAMEWORK)
		if(NOT "${CMAKE_GENERATOR}" STREQUAL "Xcode")
			message(FATAL_ERROR "You should use Xcode generator with BUILD_FRAMEWORK enabled")
		endif()
		if(NOT BUILD_SHARED_LIBS)
			message(FATAL_ERROR "BUILD_SHARED_LIBS must be ON with BUILD_FRAMEWORK enabled")
		endif()
	endif()
else(APPLE)
	if(BUILD_FRAMEWORK)
		message(FATAL_ERROR "BUILD_FRAMEWORK is only supported on Mac OS X with the Xcode generator")
	endif()
endif(APPLE)

option(NO_FONT_INTERFACE_DEFAULT "Do not include the default font engine in the build. Allows building without the FreeType dependency, but a custom font engine must be created and set." OFF)
if(NO_FONT_INTERFACE_DEFAULT)
	add_definitions(-DRMLUI_NO_FONT_INTERFACE_DEFAULT)
endif()

if(NOT BUILD_SHARED_LIBS)
	add_definitions(-DRMLUI_STATIC_LIB)
	message("-- Building static libraries. Make sure to #define RMLUI_STATIC_LIB before including RmlUi in your project.")
endif()

option(NO_THIRDPARTY_CONTAINERS "Only use standard library containers." OFF)
if( NO_THIRDPARTY_CONTAINERS )
	add_definitions(-DRMLUI_NO_THIRDPARTY_CONTAINERS)
	message("-- No third-party containers will be used: Make sure to #define RMLUI_NO_THIRDPARTY_CONTAINERS before including RmlUi in your project.")
endif()

option(CUSTOM_CONFIGURATION "Customize RmlUi configuration files for overriding the default configuration and types." OFF)

set(CUSTOM_CONFIGURATION_FILE "" CACHE STRING "Custom configuration file to be included in place of <RmlUi/Config/Config.h>.")
if( CUSTOM_CONFIGURATION AND CUSTOM_CONFIGURATION_FILE )
	add_definitions(-DRMLUI_CUSTOM_CONFIGURATION_FILE="${CUSTOM_CONFIGURATION_FILE}")
	message("-- Including ${CUSTOM_CONFIGURATION_FILE} instead of <RmlUi/Config/Config.h>")
endif ()

set(CUSTOM_INCLUDE_DIRS "" CACHE STRING "Extra include directories (use with CUSTOM_CONFIGURATION_FILE).")
if( CUSTOM_CONFIGURATION AND CUSTOM_INCLUDE_DIRS )
	include_directories(${CUSTOM_INCLUDE_DIRS})
endif ()

set(CUSTOM_LINK_LIBRARIES "" CACHE STRING "Extra link libraries (use with CUSTOM_CONFIGURATION_FILE).")

if( CUSTOM_CONFIGURATION )
	mark_as_advanced( CLEAR CUSTOM_CONFIGURATION_FILE CUSTOM_INCLUDE_DIRS CUSTOM_LINK_LIBRARIES )
else()
	mark_as_advanced( FORCE CUSTOM_CONFIGURATION_FILE CUSTOM_INCLUDE_DIRS CUSTOM_LINK_LIBRARIES )
	
	if( CUSTOM_CONFIGURATION_FILE OR CUSTOM_INCLUDE_DIRS OR CUSTOM_LINK_LIBRARIES )
		message("-- CUSTOM_CONFIGURATION disabled, but custom configuration variables are set. They will have no effect.")
	endif()
endif()

option(ENABLE_TRACY_PROFILING "Enable profiling with Tracy. Source files can be placed in Dependencies/tracy." OFF)
if( ENABLE_TRACY_PROFILING )
	find_package(Tracy REQUIRED)

	include_directories(${TRACY_INCLUDE_DIR})

	if( CMAKE_CONFIGURATION_TYPES )
		list(APPEND CMAKE_CONFIGURATION_TYPES Tracy)
		list(REMOVE_DUPLICATES CMAKE_CONFIGURATION_TYPES)
		set(CMAKE_CONFIGURATION_TYPES "${CMAKE_CONFIGURATION_TYPES}" CACHE STRING
			"Add the configurations that we need"
			FORCE)
		set(CMAKE_C_FLAGS_TRACY "${CMAKE_CXX_FLAGS_RELEASE} -DRMLUI_ENABLE_PROFILING")
		set(CMAKE_CXX_FLAGS_TRACY "${CMAKE_CXX_FLAGS_RELEASE} -DRMLUI_ENABLE_PROFILING")
		set(CMAKE_EXE_LINKER_FLAGS_TRACY "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
		set(CMAKE_SHARED_LINKER_FLAGS_TRACY "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
		message("-- Tracy profiling enabled in configuration 'Tracy'.")
	else()
		message("-- Tracy profiling enabled.")
		add_definitions(-DRMLUI_ENABLE_PROFILING)
	endif()
elseif( CMAKE_CONFIGURATION_TYPES )
	list(REMOVE_ITEM CMAKE_CONFIGURATION_TYPES Tracy)
endif()

option(DISABLE_RTTI_AND_EXCEPTIONS "Build with rtti and exceptions disabled." OFF)
if(DISABLE_RTTI_AND_EXCEPTIONS)
	add_definitions(-DRMLUI_USE_CUSTOM_RTTI)
	message("-- C++ RTTI and exceptions will be disabled: Make sure to #define RMLUI_USE_CUSTOM_RTTI before including RmlUi in your project.")
endif()

option(ENABLE_PRECOMPILED_HEADERS "Enable precompiled headers" ON)
set(PRECOMPILED_HEADERS_ENABLED OFF)
if (ENABLE_PRECOMPILED_HEADERS AND (CMAKE_VERSION VERSION_LESS 3.16.0))
	message("-- Could not enable precompiled headers. Need CMake version 3.16.0 or greater.")
elseif (ENABLE_PRECOMPILED_HEADERS)
	set(PRECOMPILED_HEADERS_ENABLED ON)
endif()

option(WARNINGS_AS_ERRORS "Treat compiler warnings as errors." OFF)
mark_as_advanced(WARNINGS_AS_ERRORS)

macro(add_common_target_options NAME)
	# C++ language version
	if(CMAKE_VERSION VERSION_LESS 3.8.0)
		set_target_properties(${NAME} PROPERTIES 
			CXX_STANDARD 14
			CXX_STANDARD_REQUIRED YES
		)
	else()
		target_compile_features(${NAME} PUBLIC cxx_std_14)
	endif()
	set_target_properties(${NAME} PROPERTIES CXX_EXTENSIONS OFF)
	
	# Compiler warnings
	if(CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID MATCHES "GNU")
		target_compile_options(${NAME} PRIVATE -Wall -pedantic -Wextra)
		
		if(WARNINGS_AS_ERRORS)
			target_compile_options(${NAME} PRIVATE -Werror)
		endif()
	elseif(MSVC)
		target_compile_options(${NAME} PRIVATE /MP /W4 /w44062 /permissive-)
		
		if(WARNINGS_AS_ERRORS)
			target_compile_options(${NAME} PRIVATE /WX)
		endif()
	endif()
endmacro()

#===================================
# Find dependencies ================
#===================================

# FreeType
if(NOT NO_FONT_INTERFACE_DEFAULT)
	find_package(Freetype REQUIRED)	

	if(FREETYPE_FOUND)
		include_directories(${FREETYPE_INCLUDE_DIRS})
		link_directories(${FREETYPE_LINK_DIRS})
		list(APPEND CORE_LINK_LIBS ${FREETYPE_LIBRARY})
	endif()
endif()

#===================================
# Setup paths ======================
#===================================

include_directories(
	${PROJECT_SOURCE_DIR}/Include
)

# Include list of source files
include(FileList)

if(NOT BUILD_FRAMEWORK)
#===================================
# Build libraries ==================
#===================================

set(LIBRARIES Core Debugger)

foreach(library ${LIBRARIES})
	set(NAME Rml${library})

	add_library(${NAME}
		${${library}_HDR_FILES}
		${${library}_PUB_HDR_FILES}
		${MASTER_${library}_PUB_HDR_FILES}
		${${library}_SRC_FILES}
	)

	set_target_properties(${NAME} PROPERTIES
	   VERSION ${PROJECT_VERSION}
	   SOVERSION ${PROJECT_VERSION_MAJOR}
	)
	
	add_common_target_options(${NAME})

	install(TARGETS ${NAME}
		EXPORT RmlUiTargets
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
	)

	set(RMLUI_EXPORTED_TARGETS ${RMLUI_EXPORTED_TARGETS} ${NAME})
endforeach(library)

if( CUSTOM_CONFIGURATION )
	foreach(library ${CUSTOM_LINK_LIBRARIES})
		install(TARGETS ${library}
			EXPORT RmlUiTargets
			LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
			ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
			RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
		)
		set(RMLUI_EXPORTED_TARGETS ${RMLUI_EXPORTED_TARGETS} ${library})
	endforeach(library ${CUSTOM_LINK_LIBRARIES})
endif()

target_compile_definitions(RmlCore PRIVATE RMLUI_VERSION="${RMLUI_VERSION_SHORT}")

if( MATRIX_ROW_MAJOR )
	target_compile_definitions(RmlCore PUBLIC -DRMLUI_MATRIX_ROW_MAJOR)
endif ()
if( CUSTOM_CONFIGURATION AND CUSTOM_LINK_LIBRARIES )
	target_link_libraries(RmlCore PUBLIC ${CUSTOM_LINK_LIBRARIES})
endif ()

if (PRECOMPILED_HEADERS_ENABLED)
	target_precompile_headers(RmlCore PRIVATE ${PROJECT_SOURCE_DIR}/Source/Core/precompiled.h)
endif()


else(NOT BUILD_FRAMEWORK)
	#===================================
	# Build combined Framework =========
	#===================================

	set(NAME RmlUi)

	set(MASTER_PUB_HDR_FILES
		${MASTER_Core_PUB_HDR_FILES}
		${MASTER_Debugger_PUB_HDR_FILES}
	)

	add_library(${NAME}
		${Core_HDR_FILES}
		${MASTER_Core_PUB_HDR_FILES}
		${Core_PUB_HDR_FILES}
		${Core_SRC_FILES}
		${Debugger_HDR_FILES}
		${MASTER_Debugger_PUB_HDR_FILES}
		${Debugger_PUB_HDR_FILES}
		${Debugger_SRC_FILES}
	)

	set_target_properties(${NAME} PROPERTIES
		VERSION ${PROJECT_VERSION}
		SOVERSION ${PROJECT_VERSION_MAJOR}
	)

	set_property(SOURCE ${MASTER_PUB_HDR_FILES}
		PROPERTY MACOSX_PACKAGE_LOCATION Headers
	)
	set_property(SOURCE ${Core_PUB_HDR_FILES}
		PROPERTY MACOSX_PACKAGE_LOCATION Headers/Core
	)
	set_property(SOURCE ${Debugger_PUB_HDR_FILES}
		PROPERTY MACOSX_PACKAGE_LOCATION Headers/Debugger
	)
	set_target_properties(${NAME} PROPERTIES
		FRAMEWORK TRUE
		FRAMEWORK_VERSION ${PROJECT_VERSION}
		MACOSX_FRAMEWORK_IDENTIFIER com.rmlui.${NAME}
		MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${RMLUI_VERSION_SHORT}
		MACOSX_FRAMEWORK_BUNDLE_VERSION ${PROJECT_VERSION}
		XCODE_ATTRIBUTE_INSTALL_PATH "@rpath"
		PUBLIC_HEADER ${MASTER_PUB_HDR_FILES}
	)

	install(TARGETS ${NAME}
		EXPORT RmlUiTargets
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
		FRAMEWORK DESTINATION Library/Frameworks
	)

	set(RMLUI_EXPORTED_TARGETS ${RMLUI_EXPORTED_TARGETS} ${NAME})
endif(NOT BUILD_FRAMEWORK)

if(DISABLE_RTTI_AND_EXCEPTIONS)
    if( CMAKE_COMPILER_IS_GNUCXX )
		add_definitions( -fno-rtti -fno-exceptions )
    elseif( MSVC )
		add_definitions( -D_HAS_EXCEPTIONS=0 /GR- )
		if(CMAKE_CXX_FLAGS MATCHES "/EHsc ")
			string(REPLACE "/EHsc" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
			message(STATUS "CMAKE_CXX_FLAGS matches /EHsc before end of string replaced...")
		endif()

		if(CMAKE_CXX_FLAGS MATCHES "/EHsc$")
			string(REPLACE "/EHsc" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
			message(STATUS "CMAKE_CXX_FLAGS matches /EHsc at end of string replaced...")
		endif()
	else()
		message(STATUS "Could not create build configuration without rtti and exceptions...")
    endif()
endif()


#===================================
# Link libraries ===================
#===================================

if(NOT BUILD_FRAMEWORK)
	target_link_libraries(RmlCore ${CORE_LINK_LIBS})
	target_link_libraries(RmlDebugger RmlCore)
else()
	target_link_libraries(RmlUi ${CORE_LINK_LIBS})
endif()

#===================================
# Generate Config.cmake files ======
#===================================

# Try to include helper module
include(CMakePackageConfigHelpers OPTIONAL RESULT_VARIABLE PkgHelpers_AVAILABLE)

# guard against older versions of cmake which do not provide it
if(PkgHelpers_AVAILABLE)
	set (INCLUDE_INSTALL_DIR "include")
	set (LIB_INSTALL_DIR "lib")
	set (INCLUDE_DIR "${PROJECT_SOURCE_DIR}/Include")

	# generate configuration for install tree
	configure_package_config_file(${PROJECT_SOURCE_DIR}/CMake/RmlUiConfig.cmake.install.in
		${CMAKE_CURRENT_BINARY_DIR}/install/RmlUiConfig.cmake
		INSTALL_DESTINATION ${LIB_INSTALL_DIR}/RmlUi/cmake
		PATH_VARS INCLUDE_INSTALL_DIR LIB_INSTALL_DIR)
	write_basic_package_version_file(
		${CMAKE_CURRENT_BINARY_DIR}/install/RmlUiConfigVersion.cmake
		VERSION ${PROJECT_VERSION}
		COMPATIBILITY SameMajorVersion )
	install(FILES ${CMAKE_CURRENT_BINARY_DIR}/install/RmlUiConfig.cmake
		${CMAKE_CURRENT_BINARY_DIR}/install/RmlUiConfigVersion.cmake
		DESTINATION ${LIB_INSTALL_DIR}/RmlUi/cmake )
	install(EXPORT RmlUiTargets
		DESTINATION ${LIB_INSTALL_DIR}/RmlUi/cmake)

	# generate configuration for build tree
	configure_package_config_file(${PROJECT_SOURCE_DIR}/CMake/RmlUiConfig.cmake.build.in
		${CMAKE_CURRENT_BINARY_DIR}/RmlUiConfig.cmake
		INSTALL_DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
		PATH_VARS INCLUDE_DIR CMAKE_CURRENT_BINARY_DIR)
	export(TARGETS ${RMLUI_EXPORTED_TARGETS}
		FILE "${CMAKE_CURRENT_BINARY_DIR}/RmlUiTargets.cmake")
	write_basic_package_version_file(
		${CMAKE_CURRENT_BINARY_DIR}/RmlUiConfigVersion.cmake
		VERSION ${PROJECT_VERSION}
		COMPATIBILITY SameMajorVersion )
	set(RmlUi_DIR "${CMAKE_CURRENT_BINARY_DIR}" CACHE PATH "The directory containing a CMake configuration file for RmlUi.")
else()
	message("If you wish to use find_package(RmlUi) in your own project to find RmlUi library"
		" please update cmake to version which provides CMakePackageConfighelpers module"
		" or write generators for RmlUiConfig.cmake by yourself.")
endif()
