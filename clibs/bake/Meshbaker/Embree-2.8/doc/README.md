% Embree: High Performance Ray Tracing Kernels 2.8.0
% Intel Corporation

Embree Overview
===============

Embree is a collection of high-performance ray tracing kernels,
developed at Intel. The target user of Embree are graphics application
engineers that want to improve the performance of their application by
leveraging the optimized ray tracing kernels of Embree. The kernels are
optimized for photo-realistic rendering on the latest Intel® processors
with support for SSE, AVX, AVX2, AVX512, and the 16-wide Intel® Xeon Phi™
coprocessor vector instructions. Embree supports runtime code selection
to choose the traversal and build algorithms that best matches the
instruction set of your CPU. We recommend using Embree through its API
to get the highest benefit from future improvements. Embree is released
as Open Source under the [Apache 2.0
license](http://www.apache.org/licenses/LICENSE-2.0).

Embree supports applications written with the Intel SPMD Programm
Compiler (ISPC, <https://ispc.github.io/>) by also providing an ISPC
interface to the core ray tracing algorithms. This makes it possible to
write a renderer in ISPC that leverages SSE, AVX, AVX2, AVX512, and Xeon Phi
instructions without any code change. ISPC also supports runtime code
selection, thus ISPC will select the best code path for your
application, while Embree selects the optimal code path for the ray
tracing algorithms.

Embree contains algorithms optimized for incoherent workloads (e.g.
Monte Carlo ray tracing algorithms) and coherent workloads (e.g. primary
visibility and hard shadow rays). For standard CPUs, the single-ray
traversal kernels in Embree provide the best performance for incoherent
workloads and are very easy to integrate into existing rendering
applications. For Xeon Phi, a renderer written in ISPC using the
default hybrid ray/packet traversal algorithms have shown to perform
best, but requires writing the renderer in ISPC. In general for coherent
workloads, ISPC outperforms the single ray mode on each platform. Embree
also supports dynamic scenes by implementing high performance two-level
spatial index structure construction algorithms.

In addition to the ray tracing kernels, Embree provides some tutorials
to demonstrate how to use the [Embree API]. The example photorealistic
renderer that was originally included in the Embree kernel package is
now available in a separate GIT repository (see [Embree Example
Renderer]).

Supported Platforms
-------------------

Embree supports Windows (32\ bit and 64\ bit), Linux (64\ bit) and Mac
OS\ X (64\ bit). The code compiles with the Intel Compiler, GCC, Clang
and the Microsoft Compiler. Embree is tested with Intel
Compiler 15.0.2, Clang 3.4.2, GCC 4.8.2, and Visual Studio
12 2013. Using the Intel Compiler improves performance by
approximately 10%.

Performance also varies across different operating systems. Embree is
optimized for Intel CPUs supporting SSE, AVX, and AVX2 instructions,
and requires at least a CPU with support for SSE2.

The Xeon Phi version of Embree only works under Linux in 64\ bit mode.
For compilation of the the Xeon Phi code the Intel Compiler is required.
The host side code compiles with GCC, Clang, and the Intel Compiler.

Contributing to Embree
----------------------

To contribute code to the Embree repository you need to sign a
Contributor License Agreement (CLA). Individuals need to fill out the
[Individual Contributor License Agreement (ICLA)]. Corporations need to
fill out the [Corporate Contributor License Agreement (CCLA)] and each
employee that wants to contribute has to fill out an [Individual
Contributor License Agreement (ICLA)]. Please follow the instructions of
the CLA forms to send them.

Embree Support and Contact
--------------------------

If you encounter bugs please report them via [Embree's GitHub Issue
Tracker](https://github.com/embree/embree/issues).

For questions please write us at <embree_support@intel.com>.

To receive notifications of updates and new features of Embree please
subscribe to the [Embree mailing
list](https://groups.google.com/d/forum/embree/).
Installation of Embree
======================

Windows Installer
-----------------

You can install the 64\ bit version of the Embree library using the
Windows installer application
[embree-2.8.0-x64.exe](https://github.com/embree/embree/releases/download/v2.8.0/embree-2.8.0.x64.exe). This
will install the 64 bit Embree version by default in `Program
Files\Intel\Embree v2.8.0 x64`. To install the 32\ bit
Embree library use the
[embree-2.8.0-win32.exe](https://github.com/embree/embree/releases/download/v2.8.0/embree-2.8.0.win32.exe)
installer. This will install the 32\ bit Embree version by default in
`Program Files\Intel\Embree v2.8.0 win32` on 32\ bit
systems and `Program Files (x86)\Intel\Embree v2.8.0 win32`
on 64\ bit systems.

You have to set the path to the `lib` folder manually to your `PATH`
environment variable for applications to find Embree. To compile
applications with Embree you also have to set the `Include
Directories` path in Visual Studio to the `include` folder of the
Embree installation.

To uninstall Embree again open `Programs and Features` by clicking the
`Start button`, clicking `Control Panel`, clicking `Programs`, and
then clicking `Programs and Features`. Select `Embree
2.8.0` and uninstall it.

Windows ZIP File
-----------------

Embree is also delivered as a ZIP file for 64 bit
[embree-2.8.0.x64.windows.zip](https://github.com/embree/embree/releases/download/v2.8.0/embree-2.8.0.x64.windows.zip)
and 32 bit
[embree-2.8.0.win32.windows.zip](https://github.com/embree/embree/releases/download/v2.8.0/embree-2.8.0.win32.windows.zip). After
unpacking this ZIP file you should set the path to the `lib` folder
manually to your `PATH` environment variable for applications to find
Embree. To compile applications with Embree you also have to set the
`Include Directories` path in Visual Studio to the `include` folder of
the Embree installation.

If you plan to ship Embree with your application, best use the Embree
version from this ZIP file.

Linux RPMs
----------

Uncompress the 'tar.gz' file
[embree-2.8.0.x86_64.rpm.tar.gz](https://github.com/embree/embree/releases/download/v2.8.0/embree-2.8.0.x86_64.rpm.tar.gz)
to
obtain the individual RPM files:

    tar xzf embree-2.8.0.x86_64.rpm.tar.gz

To install the Embree using the RPM packages on your Linux system type
the following:

    sudo rpm --install embree-lib-2.8.0-1.x86_64.rpm
    sudo rpm --install embree-devel-2.8.0-1.x86_64.rpm
    sudo rpm --install embree-examples-2.8.0-1.x86_64.rpm

To also install the Intel® Xeon Phi™ version of Embree additionally
install the following Xeon Phi™ RPMs:

    sudo rpm --install --nodeps embree-lib_xeonphi-2.8.0-1.x86_64.rpm
    sudo rpm --install --nodeps embree-examples_xeonphi-2.8.0-1.x86_64.rpm

To use the Xeon Phi™ version of Embree you additionally have configure your
`SINK_LD_LIBRARY_PATH` to point to `/usr/lib`:

    export SINK_LD_LIBRARY_PATH=/usr/local:${SINK_LD_LIBRARY_PATH}

You also have to install the Intel® Threading Building Blocks (TBB)
using `yum`:

    sudo yum install tbb.x86_64 tbb-devel.x86_64

or via `apt-get`:

    sudo apt-get install libtbb-dev

Alternatively you can download the latest TBB version from
[https://www.threadingbuildingblocks.org/download](https://www.threadingbuildingblocks.org/download)
and set the `LD_LIBRARY_PATH` environment variable to point
to the TBB library.

Note that the Embree RPMs are linked against the TBB version coming
with CentOS. This older TBB version is missing some features required
to get optimal build performance and does not support building of
scenes lazily during rendering. To get a full featured Embree please
install using the tar.gz files, which always ship with the latest TBB version.

Under Linux Embree is installed by default in the `/usr/lib` and
`/usr/include` directories. This way applications will find Embree
automatically. The Embree tutorials are installed into the
`/usr/bin/embree2` folder. Specify the full path to
the tutorials to start them.

To uninstall Embree again just execute the following:

    sudo rpm --erase embree-lib-2.8.0-1.x86_64
    sudo rpm --erase embree-devel-2.8.0-1.x86_64
    sudo rpm --erase embree-examples-2.8.0-1.x86_64

If you also installed the Xeon Phi™ RPMs you have to uninstall them
too:

    sudo rpm --erase embree-lib_xeonphi-2.8.0-1.x86_64
    sudo rpm --erase embree-examples_xeonphi-2.8.0-1.x86_64

Linux tar.gz files
------------------

The Linux version of Embree is also delivered as a tar.gz file
[embree-2.8.0.x86_64.linux.tar.gz](https://github.com/embree/embree/releases/download/v2.8.0/embree-2.8.0.x86_64.linux.tar.gz). Unpack
this file using `tar` and source the provided `embree-vars.sh` (if you
are using the bash shell) or `embree-vars.csh` (if you are using the
C shell) to setup the environment properly:

    tar xzf embree-2.8.0.x64.linux.tar.gz
    source embree-2.8.0.x64.linux/embree-vars.sh

If you want to ship Embree with your application best use the Embree
version provided through the tar.gz file.

Mac OS X PKG Installer
-----------------------

To install the Embree library on your Mac\ OS\ X system use the
provided package installer inside
[embree-2.8.0.x86_64.dmg](https://github.com/embree/embree/releases/download/v2.8.0/embree-2.8.0.x86_64.dmg). This
will install Embree by default into `/opt/local/lib` and
`/opt/local/include` directories. The Embree tutorials are installed
into the `/Applications/Embree2` folder.

You also have to install the Intel® Threading Building Blocks (TBB)
using [MacPorts](http://www.macports.org/):

    sudo port install tbb

Alternatively you can download the latest TBB version from
[https://www.threadingbuildingblocks.org/download](https://www.threadingbuildingblocks.org/download)
and set the `DYLD_LIBRARY_PATH` environment variable to point
to the TBB library.

To uninstall Embree again execute the uninstaller script
`/Applications/Embree2/uninstall.command`.

Mac OS X tar.gz file
---------------------

The Mac\ OS\ X version of Embree is also delivered as a tar.gz file
[embree-2.8.0.x86_64.macosx.tar.gz](https://github.com/embree/embree/releases/download/v2.8.0/embree-2.8.0.x86_64.macosx.tar.gz). Unpack
this file using `tar` and and source the provided `embree-vars.sh` (if you
are using the bash shell) or `embree-vars.csh` (if you are using the
C shell) to setup the environment properly:

    tar xzf embree-2.8.0.x64.macosx.tar.gz
    source embree-2.8.0.x64.macosx/embree-vars.sh

If you want to ship Embree with your application please use the Embree
library of the provided tar.gz file. The library name of that Embree
library does not contain any global path and also links against TBB
without global path. This ensures that the Embree (and TBB) library
that you put next to your application executable is used.

Linking ISPC applications with Embree
-------------------------------------

The precompiled Embree library uses the multi-target mode of ISPC. For
your ISPC application to properly link against Embree you also have to
enable this mode. You can do this by specifying multiple targets when
compiling your application with ISPC, e.g.:

    ispc --target sse2,sse4,avx,avx2 -o code.o code.ispc

Compiling Embree
================

Linux and Mac OS\ X
-------------------

To compile Embree you need a modern C++ compiler that supports C++11.
Embree is tested with Intel® Compiler 15.0.2, Clang 3.4.2, and GCC
4.8.2. If the GCC that comes with your Fedora/Red Hat/CentOS
distribution is too old then you can run the provided script
`scripts/install_linux_gcc.sh` to locally install a recent GCC into
`$HOME/devtools-2`.

Embree supports to use the Intel® Threading Building Blocks (TBB) as
tasking system. For performance and flexibility reasons we recommend
to use Embree with the Intel® Threading Building Blocks (TBB) and best
also use TBB inside your application. Optionally you can disable TBB
in Embree through the `RTCORE_TASKING_SYSTEM` CMake variable.

Embree supported the Intel® SPMD Program Compiler (ISPC), which allows
straight forward parallelization of an entire renderer. If you do not
want to use ISPC then you can disable `ENABLE_ISPC_SUPPORT` in
CMake. Otherwise, download and install the ISPC binaries (we have
tested ISPC version 1.8.2) from
[ispc.github.io](https://ispc.github.io/downloads.html). After
installation, put the path to `ispc` permanently into your `PATH`
environment variable or you need to correctly set the
`ISPC_EXECUTABLE` variable during CMake configuration.

You additionally have to install CMake 2.8.11 or higher and the developer
version of GLUT.

Under Mac OS\ X, all these dependencies can be installed
using [MacPorts](http://www.macports.org/):

    sudo port install cmake tbb freeglut

Depending on you Linux distribution you can install these dependencies
using `yum` or `apt-get`.  Some of these packages might already be
installed or might have slightly different names.

Type the following to install the dependencies using `yum`:

    sudo yum install cmake.x86_64
    sudo yum install tbb.x86_64 tbb-devel.x86_64
    sudo yum install freeglut.x86_64 freeglut-devel.x86_64
    sudo yum install libXmu.x86_64 libXi.x86_64
    sudo yum install libXmu-devel.x86_64 libXi-devel.x86_64

Type the following to install the dependencies using `apt-get`:

    sudo apt-get install cmake-curses-gui
    sudo apt-get install libtbb-dev
    sudo apt-get install freeglut3-dev
    sudo apt-get install libxmu-dev libxi-dev

Finally you can compile Embree using CMake. Create a build directory
inside the Embree root directory and execute `ccmake ..` inside this
build directory.

    mkdir build
    cd build
    ccmake ..

Per default CMake will use the compilers specified with the `CC` and
`CXX` environment variables. Should you want to use a different
compiler, run `cmake` first and set the `CMAKE_CXX_COMPILER` and
`CMAKE_C_COMPILER` variables to the desired compiler. For example, to
use the Intel Compiler instead of the default GCC on most Linux machines
(`g++` and `gcc`) execute

    cmake -DCMAKE_CXX_COMPILER=icpc -DCMAKE_C_COMPILER=icc ..

Similarly, to use Clang set the variables to `clang++` and `clang`,
respectively. Note that the compiler variables cannot be changed anymore
after the first run of `cmake` or `ccmake`.

Running `ccmake` will open a dialog where you can perform various
configurations as described below. After having configured Embree, press
c (for configure) and g (for generate) to generate a Makefile and leave
the configuration. The code can be compiled by executing make.

    make

The executables will be generated inside the build folder. We recommend
to finally install the Embree library and header files on your
system. Therefore set the `CMAKE_INSTALL_PREFIX` to `/usr` in cmake
and type:

    sudo make install

If you keep the default `CMAKE_INSTALL_PREFIX` of `/usr/local` then
you have to make sure the path `/usr/local/lib` is in your
`LD_LIBRARY_PATH`.

You can also uninstall Embree again by executing:

    sudo make uninstall

If you cannot install Embree on your system (e.g. when you don't have
administrator rights) you need to add embree_root_directory/build to
your `LD_LIBRARY_PATH` (and `SINK_LD_LIBRARY_PATH` in case you want to
use Embree on Intel® Xeon Phi™ coprocessors).

### Intel® Xeon Phi™ coprocessor

Embree supports the Intel® Xeon Phi™ coprocessor under Linux. To compile
Embree for Xeon Phi you need to enable the `XEON_PHI_ISA` option in
CMake and have the Intel Compiler and the Intel® [Manycore Platform Software
Stack](https://software.intel.com/en-us/articles/intel-manycore-platform-software-stack-mpss)
(Intel® MPSS) installed.

Enabling the buffer stride feature reduces performance for building
spatial hierarchies on Xeon Phi. Under Xeon Phi the Intel® Threading
Building Blocks (TBB) tasking system is not supported, and the
implementation will always use some internal tasking system.

Windows
-------

To compile Embree under Windows you need Visual Studio 2013 or Visual
Studio 2012. Under Visual Studio 2013 you can enable AVX2 in CMake,
however, Visual Studio 2012 supports at most AVX.

Embree supports to use the Intel® Threading Building Blocks (TBB) as
tasking system. For performance and flexibility reasons we recommend
to use Embree with the Intel® Threading Building Blocks (TBB) and best
also use TBB inside your application. Optionally you can disable TBB
in Embree through the `RTCORE_TASKING_SYSTEM` CMake variable.

Embree will either find the Intel® Threading Building Blocks (TBB)
installation that comes with the Intel® Compiler, or you can install the
binary distribution of TBB directly from
[www.threadingbuildingblocks.org](https://www.threadingbuildingblocks.org/download)
into a folder named tbb into your Embree root directory. You also have
to make sure that the libraries tbb.dll and tbb_malloc.dll can be found when
executing your Embree applications, e.g. by putting the path to these
libraries into your `PATH` environment variable.

Embree supported the Intel® SPMD Program Compiler (ISPC), which allows
straight forward parallelization of an entire renderer. If you do not
want to use ISPC then you can disable `ENABLE_ISPC_SUPPORT` in
CMake. Otherwise, download and install the ISPC binaries (we have
tested ISPC version 1.8.2) from
[ispc.github.io](https://ispc.github.io/downloads.html). After
installation, put the path to `ispc.exe` permanently into your `PATH`
environment variable or you need to correctly set the
`ISPC_EXECUTABLE` variable during CMake configuration.

You additionally have to install [CMake](http://www.cmake.org/download/)
(version 2.8.11 or higher). Note that you need a native Windows CMake
installation, because CMake under Cygwin cannot generate solution files
for Visual Studio.

### Using the IDE

Run `cmake-gui`, browse to the Embree sources, set the build directory
and click Configure. Now you can select the Generator, e.g. "Visual
Studio 12 2013" for a 32\ bit build or "Visual Studio 12 2013 Win64" for
a 64\ bit build. Most configuration parameters described for the [Linux
build](#linux-and-mac-osx) can be set under Windows as well. Finally,
click "Generate" to create the Visual Studio solution files.

  ------------------------- ------------------ ----------------------------
  Option                    Description        Default
  ------------------------- ------------------ ----------------------------
  CMAKE_CONFIGURATION_TYPE  List of generated  Debug;Release;RelWithDebInfo
                            configurations.

  USE_STATIC_RUNTIME        Use the static     OFF
                            version of the
                            C/C++ runtime
                            library.
  ------------------------- ------------------ ----------------------------
  : Windows-specific CMake build options for Embree.

For compilation of Embree under Windows use the generated Visual Studio
solution file `embree2.sln`. The solution is by default setup to use the
Microsoft Compiler. You can switch to the Intel Compiler by right
clicking onto the solution in the Solution Explorer and then selecting
the Intel Compiler. We recommend using 64\ bit mode and the Intel
Compiler for best performance.

To build Embree with support for the AVX2 instruction set you need at
least Visual Studio 2013 Update\ 4. When switching to the Intel Compiler
to build with AVX2 you currently need to manually *remove* the switch
`/arch:AVX2` from the `embree_avx2` project, which can be found under
Properties ⇒ C/C++ ⇒ All Options ⇒ Additional Options.

To build all projects of the solution it is recommend to build the CMake
utility project `ALL_BUILD`, which depends on all projects. Using "Build
Solution" would also build all other CMake utility projects (such as
`INSTALL`), which is usually not wanted.

We recommend enabling syntax highlighting for the `.ispc` source and
`.isph` header files. To do so open Visual Studio, go to Tools ⇒
Options ⇒ Text Editor ⇒ File Extension and add the isph and ispc
extension for the "Microsoft Visual C++" editor.

### Using the Command Line

Embree can also be configured and built without the IDE using the Visual
Studio command prompt:

    cd path\to\embree
    mkdir build
    cd build
    cmake -G "Visual Studio 12 2013 Win64" ..
    cmake --build . --config Release

To switch to the Intel Compiler use

    ICProjConvert150 embree2.sln /IC /s /f

You can also build only some projects with the `--target` switch.
Additional parameters after "`--`" will be passed to `msbuild`. For
example, to build the Embree library in parallel use

    cmake --build . --config Release --target embree -- /m


CMake configuration
-------------------

The default CMake configuration in the configuration dialog should be
appropriate for most usages. The following table describes all
parameters that can be configured in CMake:

  ---------------------------- -------------------------------- --------
  Option                       Description                      Default
  ---------------------------- -------------------------------- --------
  CMAKE_BUILD_TYPE             Can be used to switch between    Release
                               Debug mode (Debug), Release
                               mode (Release), and Release
                               mode with enabled assertions
                               and debug symbols
                               (RelWithDebInfo).

  ENABLE_ISPC_SUPPORT          Enables ISPC support of Embree.  ON

  ENABLE_STATIC_LIB            Builds Embree as a static        OFF
                               library. When using the
                               statically compiled Embree
                               library, you have to define
                               ENABLE_STATIC_LIB before
                               including rtcore.h in your
                               application.

  ENABLE_TUTORIALS             Enables build of Embree          ON
                               tutorials.

  ENABLE_XEON_PHI_SUPPORT      Enables generation of the        OFF
                               Xeon Phi version of Embree.

  RTCORE_BACKFACE_CULLING      Enables backface culling, i.e.   OFF
                               only surfaces facing a ray can
                               be hit.

  RTCORE_BUFFER_STRIDE         Enables the buffer stride        ON
                               feature.

  RTCORE_INTERSECTION_FILTER   Enables the intersection filter  ON
                               feature.

  RTCORE_INTERSECTION_FILTER   Restore previous hit when        ON
  _RESTORE                     ignoring hits.

  RTCORE_RAY_MASK              Enables the ray masking feature. OFF

  RTCORE_RAY_PACKETS           Enables ray packet support.      ON

  RTCORE_IGNORE_INVALID_RAYS   Makes code robust against the    OFF
                               risk of full-tree traversals
                               caused by invalid rays (e.g.
                               rays containing INF/NaN as
                               origins).

  RTCORE_TASKING_SYSTEM        Chooses between Intel® Threading TBB
                               Building Blocks (TBB) or an
                               internal tasking system
                               (INTERNAL).

  XEON_ISA                     Select highest supported ISA on  AVX2
                               Intel® Xeon® CPUs (SSE2, SSE3,
                               SSSE3, SSE4.1, SSE4.2, AVX,
                               AVX-I, AVX2, or AVX512KNL).
  ---------------------------- -------------------------------- --------
  : CMake build options for Embree.

Embree API
==========

The Embree API is a low level ray tracing API that supports defining and
committing of geometry and performing ray queries of different types.
Static and dynamic scenes are supported, that may contain triangular
geometry (including linear motions for motion blur), instanced geometry,
and user defined geometry. Supported ray queries are, finding the
closest scene intersection along a ray, and testing a ray segment for
any intersection with the scene. Single rays, as well as packets of rays
in a struct of array layout can be used for packet sizes of 1, 4, 8, and
16 rays. Filter callback functions are supported, that get invoked for every
intersection encountered during traversal.

The Embree API exists in a C++ and ISPC version. This document describes
the C++ version of the API, the ISPC version is almost identical. The
only differences are that the ISPC version needs some ISPC specific
uniform type modifiers, and limits the ray packets to the native SIMD
size the ISPC code is compiled for.

The user is supposed to include the `embree2/rtcore.h`, and the
`embree2/rtcore_ray.h` file, but none of the other header files. If
using the ISPC version of the API, the user should include
`embree2/rtcore.isph` and `embree2/rtcore_ray.isph`.

    #include <embree2/rtcore.h>
    #include <embree2/rtcore_ray.h>

All API calls carry the prefix `rtc` which stands for **r**ay
**t**racing **c**ore. Embree supports a device concept, which allows
different components of the application to use the API without
interfering with each other. You have to create at least one Embree
device through the `rtcNewDevice` call. Before the application exits
it should delete all devices by invoking
`rtcDeleteDevice`. An application typically creates a single device
only, and should create only a small number of devices.

    RTCDevice device = rtcNewDevice(NULL);
    ...
    rtcDeleteDevice(device);

It is strongly recommended to have the `Flush to Zero` and `Denormals
are Zero` mode of the MXCSR control and status register enabled for
each thread before calling the `rtcIntersect` and `rtcOccluded`
functions. Otherwise, under some circumstances special handling of
denormalized floating point numbers can significantly reduce
application and Embree performance. When using Embree together with
the Intel® Threading Building Blocks, it is sufficient to execute the
following code at the beginning of the application main thread (before
the creation of the tbb::task_scheduler_init object):

    #include <xmmintrin.h>
    #include <pmmintrin.h>
    ...
    _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);
    _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_ON);

Embree processes some implementation specific configuration from the
following locations in the specified order:

1) configuration string passed to the `rtcNewDevice` function
2) `.embree2` file in the application folder
3) `.embree2` file in the home folder

This way the configuration for the application can be changed globally
(either through the `rtcNewDevice` call or through the `.embree2` file in
the application folder) and each user has the option to modify the
configuration to fit its needs.

API calls that access geometries are only thread safe as long as
different geometries are accessed. Accesses to one geometry have to
get sequenced by the application. All other API calls are thread
safe. The API calls are re-entrant, it is thus safe to trace new rays
and create new geometry when intersecting a user defined object.

Each user thread has its own error flag per device. If an error occurs
when invoking some API function, this flag is set to an error code if it
stores no previous error. The `rtcDeviceGetError` function reads and returns
the currently stored error and clears the error flag again.

Possible error codes returned by `rtcDeviceGetError` are:

  ----------------------- ---------------------------------------------
  Error Code              Description
  ----------------------- ---------------------------------------------
  RTC_NO_ERROR            No error occurred.

  RTC_UNKNOWN_ERROR       An unknown error has occurred.

  RTC_INVALID_ARGUMENT    An invalid argument was specified.

  RTC_INVALID_OPERATION   The operation is not allowed for the
                          specified object.

  RTC_OUT_OF_MEMORY       There is not enough memory left to complete
                          the operation.

  RTC_UNSUPPORTED_CPU     The CPU is not supported as it does not
                          support SSE2.

  RTC_CANCELLED           The operation got cancelled
                          by an Memory Monitor Callback or
                          Progress Monitor Callback function.
  ----------------------- ---------------------------------------------
  : Return values of `rtcDeviceGetError`.

When the device construction fails `rtcNewDevice` returns NULL as
device. To detect the error code of a such a failed device
construction pass NULL as device to the `rtcDeviceGetError`
function. For all other invokations of `rtcDeviceGetError` a proper
device pointer has to get specified.

Using the `rtcDeviceSetErrorFunction` call, it is also possible to set
a callback function that is called whenever an error occurs for a
device. The callback function gets passed the error code, as well as
some string that describes the error further. Passing `NULL` to
`rtcDeviceSetErrorFunction` disables the set callback function again. The
previously described error flags are also set if an error callback
function is present.

Scene
-----

A scene is a container for a set of geometries of potentially different
types. A scene is created using the `rtcDeviceNewScene` function call, and
destroyed using the `rtcDeleteScene` function call. Two types of scenes
are supported, dynamic and static scenes. Different flags specify the
type of scene to create and the type of ray query operations that can
later be performed on the scene. The following example creates a scene
that supports dynamic updates and the single ray `rtcIntersect` and
`rtcOccluded` calls.

    RTCScene scene = rtcDeviceNewScene(device, RTC_SCENE_DYNAMIC, RTC_INTERSECT1);
    ...
    rtcDeleteScene(scene);

Using the following scene flags the user can select between creating a
static or dynamic scene.

  Scene Flag          Description
  ------------------- ------------------------------------------
  RTC_SCENE_STATIC    Scene is optimized for static geometry.
  RTC_SCENE_DYNAMIC   Scene is optimized for dynamic geometry.
  ------------------- ------------------------------------------
  : Dynamic type flags for `rtcDeviceNewScene`.

A dynamic scene is created by invoking `rtcDeviceNewScene` with the
`RTC_SCENE_DYNAMIC` flag. Different geometries can now be created
inside that scene. Geometries are enabled by default. Once the scene
geometry is specified, an `rtcCommit` call will finish the scene
description and trigger building of internal data structures. After
the `rtcCommit` call it is safe to perform ray queries of the type
specified at scene construction time. Geometries can get disabled
(`rtcDisable` call), enabled again (`rtcEnable` call), and deleted
(`rtcDeleteGeometry` call). Geometries can also get modified,
including their vertex and index arrays. After the modification of
some geometry, `rtcUpdate` or `rtcUpdateBuffer` has to get called for
that geometry to specify which buffers got modified. Each modified
buffer can specified separately using the `rtcUpdateBuffer`
function. In contrast the `rtcUpdate` function simply tags each buffer
of some geometry as modified. If geometries got enabled, disabled,
deleted, or modified an `rtcCommit` call has to get invoked before
performing any ray queries for the scene, otherwise the effect of the
ray query is undefined. During in `rtcCommit` call modifications to
the scene are not allowed.

A static scene is created by the `rtcDeviceNewScene` call with the
`RTC_SCENE_STATIC` flag. Geometries can only get created, enabled,
disabled and modified until the first `rtcCommit` call. After the
`rtcCommit` call, each access to any geometry of that static scene is
invalid. Geometries that got created inside a static scene can only
get deleted by deleting the entire scene.

The modification of geometry, building of hierarchies using
`rtcCommit`, and tracing of rays have always to happen separately,
never at the same time.

Embree silently ignores primitives that would cause numerical issues,
e.g. primitives containing NaNs, INFs, or values greater
than 1.844E18f.

The following flags can be used to tune the used acceleration structure.
These flags are only hints and may be ignored by the implementation.

  ------------------------ ---------------------------------------------
  Scene Flag               Description
  ------------------------ ---------------------------------------------
  RTC_SCENE_COMPACT        Creates a compact data structure and avoids
                           algorithms that consume much memory.

  RTC_SCENE_COHERENT       Optimize for coherent rays (e.g. primary
                           rays).

  RTC_SCENE_INCOHERENT     Optimize for in-coherent rays (e.g. diffuse
                           reflection rays).

  RTC_SCENE_HIGH_QUALITY   Build higher quality spatial data structures.
  ------------------------ ---------------------------------------------
  : Acceleration structure flags for `rtcDeviceNewScene`.

The following flags can be used to tune the traversal algorithm that is
used by Embree. These flags are only hints and may be ignored by the
implementation.

  Scene Flag         Description
  ------------------ ----------------------------------------------------
  RTC_SCENE_ROBUST   Avoid optimizations that reduce arithmetic accuracy.
  ------------------ ----------------------------------------------------
  : Traversal algorithm flags for `rtcDeviceNewScene`.

The second argument of the `rtcDeviceNewScene` function are algorithm flags,
that allow to specify which ray queries are required by the application.
Calling for a scene a ray query API function that is different to the
ones specified at scene creation time is not allowed. Further, the
application should only pass ray query requirements that are really
needed, to give Embree most freedom in choosing the best algorithm. E.g.
in case Embree implements no packet traversers for some highly optimized
data structure for single rays, then this data structure cannot be used
if the user enables any ray packet query.

  ----------------- ----------------------------------------------------
  Algorithm Flag    Description
  ----------------- ----------------------------------------------------
  RTC_INTERSECT1    Enables the `rtcIntersect` and `rtcOccluded`
                    functions (single ray interface) for this scene.

  RTC_INTERSECT4    Enables the `rtcIntersect4` and `rtcOccluded4`
                    functions (4-wide packet interface) for this scene.

  RTC_INTERSECT8    Enables the `rtcIntersect8` and `rtcOccluded8`
                    functions (8-wide packet interface) for this scene.

  RTC_INTERSECT16   Enables the `rtcIntersect16` and `rtcOccluded16`
                    functions (16-wide packet interface) for this
                    scene.

  RTC_INTERPOLATE   Enables the `rtcInterpolate` and `rtcInterpolateN`
                    interpolation functions.

  ----------------- ----------------------------------------------------
  : Enabled algorithm flags for `rtcDeviceNewScene`.

Geometries
----------

Geometries are always contained in the scene they are created in. Each
geometry is assigned an integer ID at creation time, which is unique
for that scene. The current version of the API supports triangle
meshes (`rtcNewTriangleMesh`), Catmull-Clark subdivision surfaces
(`rtcNewSubdivisionMesh`), hair geometries (`rtcNewHairGeometry`),
single level instances of other scenes (`rtcNewInstance`), and user
defined geometries (`rtcNewUserGeometry`). The API is designed in a
way that easily allows adding new geometry types in later releases.

For dynamic scenes, the assigned geometry IDs fulfill the following
properties. As long as no geometry got deleted, all IDs are assigned
sequentially, starting from 0. If geometries got deleted, the
implementation will reuse IDs later on in an implementation dependent
way. Consequently sequential assignment is no longer guaranteed, but a
compact range of IDs. These rules allow the application to manage a
dynamic array to efficiently map from geometry IDs to its own geometry
representation.

For static scenes, geometry IDs are assigned sequentially starting at 0.
This allows the application to use a fixed size array to map from
geometry IDs to its own geometry representation.

Alternatively the application can also use the `void rtcSetUserData
(RTCScene scene, unsigned geomID, void* ptr)` function to set a
pointer `ptr` to its own geometry representation, and later read out
this pointer again using the `void* rtcGetUserData (RTCScene scene,
unsigned geomID)` function.

The following geometry flags can be specified at construction time of
most geometries:

  ------------------------ ---------------------------------------------
  Geometry Flag            Description
  ------------------------ ---------------------------------------------
  RTC_GEOMETRY_STATIC      The geometry is considered static and should get
                           modified rarely by the application. This
                           flag has to get used in static scenes.

  RTC_GEOMETRY_DEFORMABLE  The geometry is considered to deform in a
                           coherent way, e.g. a skinned character. The
                           connectivity of the geometry has to stay
                           constant, thus modifying the index array is
                           not allowed. The implementation is free to
                           choose a BVH refitting approach for handling
                           meshes tagged with that flag.

  RTC_GEOMETRY_DYNAMIC     The geometry is considered highly dynamic and
                           changes frequently, possibly in an
                           unstructured way. Embree will rebuild data
                           structures from scratch for this type of
                           mesh.
  ------------------------ ---------------------------------------------
  : Flags for the creation of new geometries.


### Triangle Meshes

Triangle meshes are created using the `rtcNewTriangleMesh` function
call, and potentially deleted using the `rtcDeleteGeometry` function
call.

The number of triangles, number of vertices, and optionally the
number of time steps (1 for normal meshes, and 2 for linear motion
blur) have to get specified at construction time of the mesh. The user
can also specify additional flags that choose the strategy to handle
that mesh in dynamic scenes. The following example demonstrates how to
create a triangle mesh without motion blur:

    unsigned geomID = rtcNewTriangleMesh(scene, geomFlags,
       numTriangles, numVertices, 1);

The triangle indices can be set by mapping and writing to the index
buffer (`RTC_INDEX_BUFFER`) and the triangle vertices can be set by
mapping and writing into the vertex buffer (`RTC_VERTEX_BUFFER`). The
index buffer contains an array of three 32\ bit indices, while the
vertex buffer contains an array of three float values aligned to 16
bytes. The 4th component of the aligned vertices can be arbitrary. All
buffers have to get unmapped before an `rtcCommit` call to the scene.

    struct Vertex   { float x, y, z, a; };
    struct Triangle { int v0, v1, v2; };

    Vertex* vertices = (Vertex*) rtcMapBuffer(scene, geomID, RTC_VERTEX_BUFFER);
    // fill vertices here
    rtcUnmapBuffer(scene, geomID, RTC_VERTEX_BUFFER);

    Triangle* triangles = (Triangle*) rtcMapBuffer(scene, geomID, RTC_INDEX_BUFFER);
    // fill triangle indices here
    rtcUnmapBuffer(scene, geomID, RTC_INDEX_BUFFER);

Also see tutorial [Triangle Geometry] for an example of how to create
triangle meshes.

The parametrization of a triangle uses the first vertex `p0` as base
point, and the vector `p1 - p0` as u-direction and `p2 - p0` as
v-direction. The following picture additionally illustrates the
direction the geometry normal is pointing into.

![][imgTriangleUV]

Some texture coordinates `t0,t1,t2` can be linearly interpolated over
the triangle the following way:

    t_uv = (1-u-v)*t0 + u*(t1-t0) + v*(t2-t0)

### Quad Meshes

Quad meshes are created using the `rtcNewQuadMesh` function
call, and potentially deleted using the `rtcDeleteGeometry` function
call.

The number of quads, number of vertices, and optionally the
number of time steps (1 for normal meshes, and 2 for linear motion
blur) have to get specified at construction time of the mesh. The user
can also specify additional flags that choose the strategy to handle
that mesh in dynamic scenes. The following example demonstrates how to
create a quad mesh without motion blur:

    unsigned geomID = rtcNewQuadMesh(scene, geomFlags,
       numTriangles, numVertices, 1);

The quad indices can be set by mapping and writing to the index
buffer (`RTC_INDEX_BUFFER`) and the quad vertices can be set by
mapping and writing into the vertex buffer (`RTC_VERTEX_BUFFER`). The
index buffer contains an array of four 32\ bit indices, while the
vertex buffer contains an array of three float values aligned to 16
bytes. The 4th component of the aligned vertices can be arbitrary. All
buffers have to get unmapped before an `rtcCommit` call to the scene.

    struct Vertex { float x, y, z, a; };
    struct Quad   { int v0, v1, v2, v3; };

    Vertex* vertices = (Vertex*) rtcMapBuffer(scene, geomID, RTC_VERTEX_BUFFER);
    // fill vertices here
    rtcUnmapBuffer(scene, geomID, RTC_VERTEX_BUFFER);

    Quad* quads = (Quad*) rtcMapBuffer(scene, geomID, RTC_INDEX_BUFFER);
    // fill quad indices here
    rtcUnmapBuffer(scene, geomID, RTC_INDEX_BUFFER);

The quad is internally handled as a pair of two triangles `v0,v1,v3`
and `v2,v3,v1`, with the u'/v' coordinates of the second triangle
corrected by `u = 1-u'` and `v = 1-v'` to make a parametrization where
u and v go from 0 to 1.

Te encode a triangle as quad just replicate the last triangle
vertex (`v0,v1,v2` -> `v0,v1,v2,v2`). This way the quad mesh can be
used to represent a mesh with triangles and quads.

### Subdivision Surfaces

Catmull-Clark subdivision surfaces for meshes consisting of triangle
and quad primitives (even mixed inside one mesh) are supported,
including support for edge creases, vertex creases, holes, and
non-manifold geometry.

A subdivision surface is created using the `rtcNewSubdivisionMesh`
function call, and deleted again using the `rtcDeleteGeometry`
function call.

     unsigned rtcNewSubdivisionMesh(RTCScene scene, 
                                    RTCGeometryFlags flags,
                                    size_t numFaces,
                                    size_t numEdges,
                                    size_t numVertices,
                                    size_t numEdgeCreases,
                                    size_t numVertexCreases,
                                    size_t numCorners,
                                    size_t numHoles,
                                    size_t numTimeSteps);

The number of faces (`numFaces`), edges/indices (`numEdges`), vertices
(`numVertices`), edge creases (`numEdgeCreases`), vertex creases
(`numVertexCreases`), holes (`numHoles`), and time steps
(`numTimeSteps`) have to get specified at construction time.

The following buffers have to get setup by the application: the face
buffer (`RTC_FACE_BUFFER`) contains the number edges/indices (3 or 4) of
each of the `numFaces` faces, the index buffer (`RTC_INDEX_BUFFER`)
contains multiple (3 or 4) 32\ bit vertex indices for each face and
`numEdges` indices in total, the vertex buffer (`RTC_VERTEX_BUFFER`)
stores `numVertices` vertices as single precision `x`, `y`, `z` floating
point coordinates aligned to 16 bytes. The value of the 4th float used
for alignment can be arbitrary.

Optionally, the application can setup the hole buffer (`RTC_HOLE_BUFFER`)
with `numHoles` many 32\ bit indices of faces that should be considered
non-existing.

Optionally, the application can fill the level buffer
(`RTC_LEVEL_BUFFER`) with a tessellation level for each or the edges of
each face, making a total of `numEdges` values. The tessellation level
is a positive floating point value, that specifies how many quads
along the edge should get generated during tessellation. The
tessellation level is a lower bound, thus the implementation is free
to choose a larger level. If no level buffer is specified a level of 1
is used. Note that some edge may be shared between (typically 2)
faces. To guarantee a watertight tessellation, the level of these
shared edges has to be exactly identical.

Optionally, the application can fill the sparse edge crease buffers to
make some edges appear sharper. The edge crease index buffer
(`RTC_EDGE_CREASE_INDEX_BUFFER`) contains `numEdgeCreases` many pairs of
32\ bit vertex indices that specify unoriented edges. The edge crease
weight buffer (`RTC_EDGE_CREASE_WEIGHT_BUFFER`) stores for each of
theses crease edges a positive floating point weight. The larger this
weight, the sharper the edge. Specifying a weight of infinity is
supported and marks an edge as infinitely sharp. Storing an edge
multiple times with the same crease weight is allowed, but has lower
performance. Storing an edge multiple times with different crease
weights results in undefined behavior. For a stored edge (i,j), the
reverse direction edges (j,i) does not have to get stored, as both are
considered the same edge.

Optionally, the application can fill the sparse vertex crease buffers
to make some vertices appear sharper. The vertex crease index buffer
(`RTC_VERTEX_CREASE_INDEX_BUFFER`), contains `numVertexCreases` many
32\ bit vertex indices to specify a set of vertices. The vertex crease
weight buffer (`RTC_VERTEX_CREASE_WEIGHT_BUFFER`) specifies for each of
these vertices a positive floating point weight. The larger this
weight, the sharper the vertex. Specifying a weight of infinity is
supported and makes the vertex infinitely sharp. Storing a vertex
multiple times with the same crease weight is allowed, but has lower
performance. Storing a vertex multiple times with different crease
weights results in undefined behavior.

One triangles and quadrilaterals are supported as primitives of a
subdivision mesh. The parametrization of a triangle uses the first
vertex `p0` as base point, and the vector `p1 - p0` as u-direction and
`p2 - p0` as v-direction. The following picture additionally
illustrates the direction the geometry normal is pointing into.

![][imgTriangleUV]

Some texture coordinates `t0,t1,t2` can be linearly
interpolated over the triangle the following way:

    t_uv = (1-u-v)*t0 + u*(t1-t0) + v*(t2-t0)

The parametrization of a quadrilateral uses the first vertex `p0` as
base point, and the vector `p1 - p0` as u-direction and `p3 - p0` as
v-direction. The following picture additionally illustrates the
direction the geometry normal is pointing into.

![][imgQuadUV]

Some texture coordinates `t0,t1,t2,t3` can be bi-linearly
interpolated over the quadrilateral the following way:

    t_uv = (1-v)((1-u)*t0 + u*t1) + v*((1-u)*t3 + u*t2) 

To smoothly interpolate texture coordinates over the subdivision
surface we recommend using the `rtcInterpolate` function, which will
apply the standard subdivision rules for interpolation.

Using the `rtcSetBoundaryMode` API call one can specify how corner
vertices are handled. Specifying `RTC_BOUNDARY_NONE` ignores all
boundary patches, `RTC_BOUNDARY_EDGE_ONLY` makes all boundaries soft,
while `RTC_BOUNDARY_EDGE_AND_CORNER` makes corner vertices sharp.

The user can also specify a geometry mask and additional flags that
choose the strategy to handle that subdivision mesh in dynamic scenes.

The implementation of subdivision surfaces uses an internal software cache,
which can get configured to some desired size (see [Configuring Embree]).

Also see tutorial [Subdivision Geometry] for an example of how to create
subdivision surfaces.

### Line Segment Hair Geometry

Line segments are supported to render hair geometry. A line segment
consists of a start and and point, and start and end
radius. Individual line segments are considered to be subpixel sized which
allows the implementation to approximate the intersection
calculation. This in particular means that zooming onto one line segment might
show geometric artifacts.

Line segments are created using the `rtcNewLineSegments` function
call, and potentially deleted using the `rtcDeleteGeometry` function
call.

The number of line segments, the number of vertices, and optionally the
number of time steps (1 for normal curves, and 2 for linear motion blur)
have to get specified at construction time of the line segment geometry.

The segment indices can be set by mapping and writing to the index buffer
(`RTC_INDEX_BUFFER`) and the vertices can be set by mapping and
writing into the vertex buffer (`RTC_VERTEX_BUFFER`). In case of linear
motion blur, two vertex buffers (`RTC_VERTEX_BUFFER0` and
`RTC_VERTEX_BUFFER1`) have to get filled, one for each time step.

The index buffer contains an array of 32\ bit indices pointing to the
ID of the first of two vertices, while the vertex buffer
stores all control points in the form of a single precision position
and radius stored in `x`, `y`, `z`, `r` order in memory. The
radii have to be greater or equal zero. All buffers have to get
unmapped before an `rtcCommit` call to the scene.

Like for triangle meshes, the user can also specify a geometry mask and
additional flags that choose the strategy to handle that mesh in dynamic
scenes.

The following example demonstrates how to create some line segment geometry:

    unsigned geomID = rtcNewLineSegments(scene, geomFlags, numCurves,
      numVertices, 1);

    struct Vertex { float x, y, z, r; };

    Vertex* vertices = (Vertex*) rtcMapBuffer(scene, geomID, RTC_VERTEX_BUFFER);
    // fill vertices here
    rtcUnmapBuffer(scene, geomID, RTC_VERTEX_BUFFER);

    int* curves = (int*) rtcMapBuffer(scene, geomID, RTC_INDEX_BUFFER);
    // fill indices here
    rtcUnmapBuffer(scene, geomID, RTC_INDEX_BUFFER);

### Bezier Curve Hair Geometry

Hair geometries are supported, which consist of multiple hairs
represented as cubic Bézier curves with varying radius per control
point. Individual hairs are considered to be subpixel sized which allows
the implementation to approximate the intersection calculation. This in
particular means that zooming onto one hair might show geometric
artifacts.

Hair geometries are created using the `rtcNewHairGeometry` function
call, and potentially deleted using the `rtcDeleteGeometry` function
call.

The number of hair curves, the number of vertices, and optionally the
number of time steps (1 for normal curves, and 2 for linear motion blur)
have to get specified at construction time of the hair geometry.

The curve indices can be set by mapping and writing to the index buffer
(`RTC_INDEX_BUFFER`) and the control vertices can be set by mapping and
writing into the vertex buffer (`RTC_VERTEX_BUFFER`). In case of linear
motion blur, two vertex buffers (`RTC_VERTEX_BUFFER0` and
`RTC_VERTEX_BUFFER1`) have to get filled, one for each time step.

The index buffer contains an array of 32\ bit indices pointing to the
ID of the first of four control vertices, while the vertex buffer
stores all control points in the form of a single precision position
and radius stored in `x`, `y`, `z`, `r` order in memory. The hair
radii have to be greater or equal zero. All buffers have to get
unmapped before an `rtcCommit` call to the scene.

Like for triangle meshes, the user can also specify a geometry mask and
additional flags that choose the strategy to handle that mesh in dynamic
scenes.

The following example demonstrates how to create some hair geometry:

    unsigned geomID = rtcNewHairGeometry(scene, geomFlags, numCurves, numVertices);

    struct Vertex { float x, y, z, r; };

    Vertex* vertices = (Vertex*) rtcMapBuffer(scene, geomID, RTC_VERTEX_BUFFER);
    // fill vertices here
    rtcUnmapBuffer(scene, geomID, RTC_VERTEX_BUFFER);

    int* curves = (int*) rtcMapBuffer(scene, geomID, RTC_INDEX_BUFFER);
    // fill indices here
    rtcUnmapBuffer(scene, geomID, RTC_INDEX_BUFFER);

Also see tutorial [Hair] for an example of how to create and use hair
geometry.

### User Defined Geometry

User defined geometries make it possible to extend Embree with arbitrary
types of geometry. This is achieved by introducing arrays of user
geometries as a special geometry type. These objects do not contain a
single user geometry, but a set of such geometries, each specified by an
index. The user has to provide a data pointer per user geometry, a
bounding function closure (function and user pointer) as
well as user defined intersect and occluded functions to create a set of
user geometries. The user geometry to process is specified by passing
its geometry user data pointer and index to each invocation of the bounding,
intersect, and occluded function. The bounding function is used to query
the bounds of all timesteps of each user geometry. When performing ray queries, Embree
will invoke the user intersect (and occluded) functions to test rays for
intersection (and occlusion) with the specified user defined geometry.

As Embree supports different ray packet sizes, one potentially has to
provide different versions of user intersect and occluded function
pointers for these packet sizes. However, the ray packet size of the
called user function always matches the packet size of the originally
invoked ray query function. Consequently, an application only operating
on single rays only has to provide single ray intersect and occluded
function pointers.

User geometries are created using the `rtcNewUserGeometry` function
call, and potentially deleted using the `rtcDeleteGeometry` function
call. The the `rtcNewUserGeometry2` function additionally gets a
numTimeSteps paramter, which specifies the number of timesteps for
motion blur. The following example illustrates creating an array with
two user geometries:

    int numTimeSteps = 2;
    struct UserObject { ... };

    void userBoundsFunction(void* userPtr, UserObject* userGeomPtr, size_t i, RTCBounds* bounds)
    {
      for (size_t i=0; i<numTimeSteps; i++)
        bounds[i] = <bounds of userGeomPtr[i] at time i>;
    }

    void userIntersectFunction(UserObject* userGeomPtr, RTCRay& ray, size_t i)
    {
      if (<ray misses userGeomPtr[i] at time ray.time>)
        return;
      <update ray hit information>;
    }

    void userOccludedFunction(UserObject* userGeomPtr, RTCRay& ray, size_t i)
    {
      if (<ray misses userGeomPtr[i] at time ray.time>)
        return;
      geomID = 0;
    }

    ...

    UserObject* userGeomPtr = new UserObject[2];
    userGeomPtr[0] = ...
    userGeomPtr[1] = ...
    unsigned geomID = rtcNewUserGeometry2(scene, 2, numTimeSteps);
    rtcSetUserData(scene, geomID, userGeomPtr);
    rtcSetBoundsFunction2(scene, geomID, userBoundsFunction, userPtr);
    rtcSetIntersectFunction(scene, geomID, userIntersectFunction);
    rtcSetOccludedFunction(scene, geomID, userOccludedFunction);


The user bounds function (`userBoundsFunction`) get as input the
pointer provided at the `rtcSetBoundsFunction2` function call, the
geometry user pointer provided through the `rtcSetUserData` function
call, the i'th geometry to calculate the bounds for, and a pointer to
an array of bounds to fill (one bound for each timestep specified when
creating the user geometry).

The user intersect function (`userIntersectFunction`) and user occluded
function (`userOccludedFunction`) get as input the pointer provided
through the `rtcSetUserData` function call, a ray, and the index of the
geometry to process. For ray packets, the user intersect and occluded
functions also get a pointer to a valid mask as input. The user provided
functions should not modify any ray that is disabled by that valid mask.

The user intersect function should return without modifying the ray
structure if the user geometry is missed. If the geometry is hit, it has
to update the hit information of the ray (`tfar`, `u`, `v`, `Ng`,
`geomID`, `primID`).

Also the user occluded function should return without modifying the ray
structure if the user geometry is missed. If the geometry is hit, it
should set the `geomID` member of the ray to 0.

See tutorial [User Geometry] for an example of how to use the user
defined geometries.

### Instances

Embree supports instancing of scenes inside another scene by some
transformation. As the instanced scene is stored only a single time,
even if instanced to multiple locations, this feature can be used to
create extremely large scenes. Only single level instancing is supported
by Embree natively, however, multi-level instancing can principally be
implemented through user geometries.

Instances are created using the `rtcNewInstance` function call, and
potentially deleted using the `rtcDeleteGeometry` function call. To
instantiate a scene, one first has to generate the scene B to
instantiate. Now one can add an instance of this scene inside a scene A
the following way:

    unsigned instID = rtcNewInstance(sceneA, sceneB);
    rtcSetTransform(sceneA, instID, RTC_MATRIX_COLUMN_MAJOR, &column_matrix_3x4);

Both scenes have to belong to the same device. One has to call
`rtcCommit` on scene B before one calls `rtcCommit` on scene A. When
modifying scene B one has to call `rtcUpdate` for all instances of
that scene. If a ray hits the instance, then the `geomID` and `primID`
members of the ray are set to the geometry ID and primitive ID of the
primitive hit in scene B, and the `instID` member of the ray is set to
the instance ID returned from the `rtcNewInstance` function.

The `rtcSetTransform` call can be passed an affine transformation matrix
with different data layouts:

  ----------------------------------- ----------------------------------
  Layout                              Description
  ----------------------------------- ----------------------------------
  RTC_MATRIX_ROW_MAJOR                The 3×4 float matrix is laid out
                                      in row major form.

  RTC_MATRIX_COLUMN_MAJOR             The 3×4 float matrix is laid out
                                      in column major form.

  RTC_MATRIX_COLUMN_MAJOR_ALIGNED16   The 3×4 float matrix is laid out
                                      in column major form, with each
                                      column padded by an additional 4th
                                      component.
  ----------------------------------- ----------------------------------
  : Matrix layouts for `rtcSetTransform`.

Passing homogeneous 4×4 matrices is possible as long as the last row is
(0, 0, 0, 1). If this homogeneous matrix is laid out in row major form,
use the `RTC_MATRIX_ROW_MAJOR` layout. If this homogeneous matrix is
laid out in column major form, use the
`RTC_MATRIX_COLUMN_MAJOR_ALIGNED16` mode. In both cases, Embree will
ignore the last row of the matrix.

The transformation passed to `rtcSetTransform` transforms from the local
space of the instantiated scene to world space.

See tutorial [Instanced Geometry] for an example of how to use
instances.

Ray Queries
-----------

The API supports finding the closest hit of a ray segment with the scene
(`rtcIntersect` functions), and determining if any hit between a ray
segment and the scene exists (`rtcOccluded` functions).

    void rtcIntersect  (                   RTCScene scene, RTCRay&   ray);
    void rtcIntersect4 (const void* valid, RTCScene scene, RTCRay4&  ray);
    void rtcIntersect8 (const void* valid, RTCScene scene, RTCRay8&  ray);
    void rtcIntersect16(const void* valid, RTCScene scene, RTCRay16& ray);
    void rtcOccluded   (                   RTCScene scene, RTCRay&   ray);
    void rtcOccluded4  (const void* valid, RTCScene scene, RTCRay4&  ray);
    void rtcOccluded8  (const void* valid, RTCScene scene, RTCRay8&  ray);
    void rtcOccluded16 (const void* valid, RTCScene scene, RTCRay16& ray);

The ray layout to be passed to the ray tracing core is defined in the
`embree2/rtcore_ray.h` header file. It is up to the user if he wants
to use the ray structures defined in that file, or resemble the exact
same binary data layout with their own vector classes. The ray layout
might change with new Embree releases as new features get added,
however, will stay constant as long as the major Embree release number
does not change. The ray contains the following data members:

  Member  In/Out  Description
  ------- ------- ----------------------------------------------------------
  org     in      ray origin
  dir     in      ray direction (can be unnormalized)
  tnear   in      start of ray segment
  tfar    in/out  end of ray segment, set to hit distance after intersection
  time    in      time used for motion blur
  mask    in      ray mask to mask out geometries
  Ng      out     unnormalized geometry normal
  u       out     barycentric u-coordinate of hit
  v       out     barycentric v-coordinate of hit
  geomID  out     geometry ID of hit geometry
  primID  out     primitive ID of hit primitive
  instID  out     instance ID of hit instance
  ------- ------- ----------------------------------------------------------
  : Data fields of a ray.

This structure is in struct of array layout (SOA) for ray packets. Note
that the `tfar` member functions as an input and output.

In the ray packet mode (with packet size of N), the user has to provide
a pointer to N 32\ bit integers that act as a ray activity mask. If one
of these integers is set to `0x00000000` the corresponding ray is
considered inactive and if the integer is set to `0xFFFFFFFF`, the ray
is considered active. Rays that are inactive will not update any hit
information. Data alignment requirements for ray query functions
operating on single rays is 16 bytes for the ray.

Data alignment requirements for query functions operating on AOS packets
of 4, 8, or 16 rays, is 16, 32, and 64 bytes respectively, for the valid
mask and the ray. To operate on packets of 4 rays, the CPU has to
support SSE, to operate on packets of 8 rays, the CPU has to support
AVX-256, and to operate on packets of 16 rays, the CPU has to support
the Intel® Xeon Phi™ coprocessor instructions. Additionally, the
required ISA has to be enabled in Embree at compile time to use the
desired packet size.

Finding the closest hit distance is done through the `rtcIntersect`
functions. These get the activity mask, the scene, and a ray as input.
The user has to initialize the ray origin (`org`), ray direction
(`dir`), and ray segment (`tnear`, `tfar`). The ray segment has to be in
the range $[0, ∞)$, thus ranges that start behind the ray origin are
not valid, but ranges can reach to infinity. The geometry ID (`geomID`
member) has to get initialized to `RTC_INVALID_GEOMETRY_ID` (-1). If the
scene contains instances, also the instance ID (`instID`) has to get
initialized to `RTC_INVALID_GEOMETRY_ID` (-1). If the scene contains
linear motion blur, also the ray time (`time`) has to get initialized to
a value in the range $[0, 1]$. If ray masks are enabled at compile time,
also the ray mask (`mask`) has to get initialized. After tracing the
ray, the hit distance (`tfar`), geometry normal (`Ng`), local hit
coordinates (`u`, `v`), geometry ID (`geomID`), and primitive ID
(`primID`) are set. If the scene contains instances, also the instance
ID (`instID`) is set, if an instance is hit. The geometry ID corresponds
to the ID returned at creation time of the hit geometry, and the
primitive ID corresponds to the $n$th primitive of that geometry, e.g.
$n$th triangle. The instance ID corresponds to the ID returned at
creation time of the instance.

The following code properly sets up a ray and traces it through the
scene:

    RTCRay ray;
    ray.org = ray_origin;
    ray.dir = ray_direction;
    ray.tnear = 0.f;
    ray.tfar = inf;
    ray.geomID = RTC_INVALID_GEOMETRY_ID;
    ray.primID = RTC_INVALID_GEOMETRY_ID;
    ray.instID = RTC_INVALID_GEOMETRY_ID;
    ray.mask = 0xFFFFFFFF;
    ray.time = 0.f;
    rtcIntersect(scene, ray);

Testing if any geometry intersects with the ray segment is done through
the `rtcOccluded` functions. Initialization has to be done as for
`rtcIntersect`. If some geometry got found along the ray segment, the
geometry ID (`geomID`) will get set to 0. Other hit information of the
ray is undefined after calling `rtcOccluded`.

See tutorial [Triangle Geometry] for an example of how to trace rays.

Interpolation of Vertex Data
----------------------------

Smooth interpolation of per-vertex data is supported for triangle
meshes, hair geometry, and subdivision geometry using the
`rtcInterpolate` API call. This interpolation function does ignore
displacements and always interpolates the underlying base surface.

    void rtcInterpolate(RTCScene scene,
                        unsigned geomID, unsigned primID,
                        float u, float v,
                        RTCBufferType buffer, 
                        float* P, float* dPdu, float* dPdv,
                        size_t numFloats);

This call smoothly interpolates the per-vertex data stored in the
specified geometry buffer (`buffer` parameter) to the u/v location
(`u` and `v` parameters) of the primitive (`primID` parameter) of the
geometry (`geomID` parameter) of the specified scene (`scene`
parameter). The interpolation buffer (`buffer` parameter) has to
contain (at least) `numFloats` floating point values per vertex to
interpolate. As interpolation buffer one can specify the
`RTC_VERTEX_BUFFER0` and `RTC_VERTEX_BUFFER1` as well as one of two
special user vertex buffers `RTC_USER_VERTEX_BUFFER0` and
`RTC_USER_VERTEX_BUFFER1`. These user vertex buffers can only get set
using the `rtcSetBuffer` call, they cannot get managed internally by
Embree as they have no default layout. The last element of the buffer
has to be padded to 16 bytes, such that it can be read safely using
SSE instructions.

The `rtcInterpolate` call stores `numFloats` interpolated floating
point values to the memory location pointed to by `P`. The derivative
of the interpolation by u and v are stored at `dPdu` and `dPdv`. The
`P` pointer can be NULL to avoid calculating the interpolated
value. Similar the `dPdu` and `dPdv` parameters can both be NULL to
not calculate derivatives. If `dPdu` is NULL also `dPdv` has to be
NULL.

The `RTC_INTERPOLATE` algorithm flag of a scene has to be enabled to
perform interpolations.

It is explicitly allowed to call this function on disabled
geometries. This makes it possible to use a separate subdivision mesh
with different vertex creases, edge creases, and boundary handling for
interpolation of texture coordinates if that is necessary.

The applied interpolation will do linear interpolation for triangle
meshes, cubic Bézier interpolation for hair, and apply the full
subdivision rules for subdivision geometry.

There is also a second interpolate call `rtcInterpolateN` that can be
used for ray packets.

    void rtcInterpolateN(RTCScene scene, unsigned geomID, 
                         const void* valid, const unsigned* primIDs,
                         const float* u, const float* v, size_t numUVs, 
                         RTCBufferType buffer, 
                         float* dP, float* dPdu, float* dPdv,
                         size_t numFloats);

This call is similar to the first version, but gets passed `numUVs`
many u/v coordinates and a valid mask (`valid` parameter) that
specifies which of these coordinates are valid. The valid mask points
to `numUVs` integers and a value of -1 denotes valid and 0 invalid. If
the valid pointer is NULL all elements are considers valid. The
destination arrays are filled in structure of array (SoA) layout.

See tutorial [Interpolation] for an example of using the
`rtcInterpolate` function.

Buffer Sharing
--------------

Embree supports sharing of buffers with the application. Each buffer
that can be mapped for a specific geometry can also be shared with the
application, by pass a pointer, offset, and stride of the application
side buffer using the `rtcSetBuffer` API function.

    void rtcSetBuffer(RTCScene scene, unsigned geomID, RTCBufferType type,
                      void* ptr, size_t offset, size_t stride);

The `rtcSetBuffer` function has to get called before any call to
`rtcMapBuffer` for that buffer, otherwise the buffer will get allocated
internally and the call to `rtcSetBuffer` will fail. The buffer has to
remain valid as long as the geometry exists, and the user is responsible
to free the buffer when the geometry gets deleted. When a buffer is
shared, it is safe to modify that buffer without mapping and unmapping
it. However, for dynamic scenes one still has to call `rtcUpdate` for
modified geometries and the buffer data has to stay constant from the
`rtcCommit` call to after the last ray query invocation.

The `offset` parameter specifies a byte offset to the start of the first
element and the `stride` parameter specifies a byte stride between the
different elements of the shared buffer. This support for offset and
stride allows the application quite some freedom in the data layout of
these buffers, however, some restrictions apply. Index buffers always
store 32\ bit indices and vertex buffers always store single precision
floating point data. The start address ptr+offset and stride always have
to be aligned to 4 bytes on Intel® Xeon® CPUs and 16 bytes on Xeon Phi
accelerators, otherwise the `rtcSetBuffer` function will fail.

For vertex buffers (`RTC_VERTEX_BUFFER` and `RTC_USER_VERTEX_BUFFER`),
the last element must be readable using SSE instructions, thus padding
the last element to 16 bytes size is required for some layouts.

The following is an example of how to create a mesh with shared index
and vertex buffers:

    unsigned geomID = rtcNewTriangleMesh(scene, geomFlags, numTriangles, numVertices);
    rtcSetBuffer(scene, geomID, RTC_VERTEX_BUFFER, vertexPtr, 0, 3*sizeof(float));
    rtcSetBuffer(scene, geomID, RTC_INDEX_BUFFER, indexPtr, 0, 3*sizeof(int));

Sharing buffers can significantly reduce the memory required by the
application, thus we recommend using this feature. When enabling the
`RTC_COMPACT` scene flag, the spatial index structures of Embree might
also share the vertex buffer, resulting in even higher memory savings.

The support for offset and stride is enabled by default, but can get
disabled at compile time using the `RTCORE_BUFFER_STRIDE` parameter in
CMake. Disabling this feature enables the default offset and stride
which increases performance of spatial index structure build, thus can
be useful for dynamic content.

Linear Motion Blur
------------------

Triangle meshes and hair geometries with linear motion blur support are
created by setting the number of time steps to 2 at geometry
construction time. Specifying a number of time steps of 0 or larger than
2 is invalid. For a triangle mesh or hair geometry with linear motion
blur, the user has to set the `RTC_VERTEX_BUFFER0` and
`RTC_VERTEX_BUFFER1` vertex arrays, one for each time step.

    unsigned geomID = rtcNewTriangleMesh(scene, geomFlags, numTris, numVertices, 2);
    rtcSetBuffer(scene, geomID, RTC_VERTEX_BUFFER0, vertex0Ptr, 0, sizeof(Vertex));
    rtcSetBuffer(scene, geomID, RTC_VERTEX_BUFFER1, vertex1Ptr, 0, sizeof(Vertex));
    rtcSetBuffer(scene, geomID, RTC_INDEX_BUFFER, indexPtr, 0, sizeof(Triangle));

If a scene contains geometries with linear motion blur, the user has to
set the `time` member of the ray to a value in the range $[0, 1]$. The ray
will intersect the scene with the vertices of the two time steps
linearly interpolated to this specified time. Each ray can specify a
different time, even inside a ray packet.

User Data Pointer
---------------

A user data pointer can be specified and queried per geometry, to
efficiently map from the geometry ID returned by ray queries to the
application representation for that geometry.

    void  rtcSetUserData (RTCScene scene, unsigned geomID, void* ptr);
    void* rtcGetUserData (RTCScene scene, unsigned geomID);

The user data pointer of some user defined geometry get additionally
passed to the intersect and occluded callback functions of that user
geometry. Further, the user data pointer is also passed to
intersection filter callback functions attached to some geometry.

The `rtcGetUserData` function is on purpose not thread safe with
respect to other API calls that modify the scene. Consequently, this
function can be used to efficiently query the user data pointer during
rendering (also by multiple threads), but should not get called
while modifying the scene with other threads.

Geometry Mask
-------------

A 32\ bit geometry mask can be assigned to triangle meshes and hair
geometries using the `rtcSetMask` call.

    rtcSetMask(scene, geomID, mask);

Only if the bitwise `and` operation of this mask with the mask stored
inside the ray is not 0, primitives of this geometry are hit by a ray.
This feature can be used to disable selected triangle mesh or hair
geometries for specifically tagged rays, e.g. to disable shadow casting
for some geometry. This API feature is disabled in Embree by default at
compile time, and can be enabled in CMake through the
`RTCORE_ENABLE_RAY_MASK` parameter.

Filter Functions
----------------

The API supports per geometry filter callback functions that are invoked
for each intersection found during the `rtcIntersect` or `rtcOccluded`
calls. The former ones are called intersection filter functions, the
latter ones occlusion filter functions. The filter functions can be used
to implement various useful features, such as accumulating opacity for
transparent shadows, counting the number of surfaces along a ray,
collecting all hits along a ray, etc. Filter functions can also be used
to selectively reject hits to enable backface culling for some
geometries. If the backfaces should be culled in general for all
geometries then it is faster to enable `RTCORE_BACKFACE_CULLING` during
compilation of Embree instead of using filter functions.

The filter functions provided by the user have to have the following
signature:

    void FilterFunc  (                   void* userPtr, RTCRay&   ray);
    void FilterFunc4 (const void* valid, void* userPtr, RTCRay4&  ray);
    void FilterFunc8 (const void* valid, void* userPtr, RTCRay8&  ray);
    void FilterFunc16(const void* valid, void* userPtr, RTCRay16& ray);

The `valid` pointer points to a valid mask of the same format as
expected as input by the ray query functions. The `userPtr` is a user
pointer optionally set per geometry through the `rtcSetUserData`
function. The ray passed to the filter function is the ray structure
initially provided to the ray query function by the user. For that
reason, it is safe to extend the ray by additional data and access this
data inside the filter function (e.g. to accumulate opacity). All hit
information inside the ray is valid. If the hit geometry is instanced,
the `instID` member of the ray is valid and the ray origin, direction,
and geometry normal visible through the ray are in object space. The
filter function can reject a hit by setting the `geomID` member of the
ray to `RTC_INVALID_GEOMETRY_ID`, otherwise the hit is accepted. The
filter function is not allowed to modify the ray input data (`org`,
`dir`, `tnear`, `tfar`), but can modify the hit data of the ray
(`u`, `v`, `Ng`, `geomID`, `primID`).

The intersection filter functions for different ray types are set for
some geometry of a scene using the following API functions:

    void rtcSetIntersectionFilterFunction  (RTCScene, unsigned geomID, RTCFilterFunc  );
    void rtcSetIntersectionFilterFunction4 (RTCScene, unsigned geomID, RTCFilterFunc4 );
    void rtcSetIntersectionFilterFunction8 (RTCScene, unsigned geomID, RTCFilterFunc8 );
    void rtcSetIntersectionFilterFunction16(RTCScene, unsigned geomID, RTCFilterFunc16);

These functions are invoked during execution of the `rtcIntersect` type
queries of the matching ray type. The occlusion filter functions are set
using the following API functions:

    void rtcSetOcclusionFilterFunction  (RTCScene, unsigned geomID, RTCFilterFunc  );
    void rtcSetOcclusionFilterFunction4 (RTCScene, unsigned geomID, RTCFilterFunc4 );
    void rtcSetOcclusionFilterFunction8 (RTCScene, unsigned geomID, RTCFilterFunc8 );
    void rtcSetOcclusionFilterFunction16(RTCScene, unsigned geomID, RTCFilterFunc16);

See tutorial [Intersection Filter] for an example of how to use the
filter functions.

Displacement Mapping Functions
------------------------------

The API supports displacement mapping for subdivision meshes. A
displacement function can be set for some subdivision mesh using the
`rtcSetDisplacementFunction` API call.

    void rtcSetDisplacementFunction(RTCScene, unsigned geomID, RTCDisplacementFunc, RTCBounds*);

A displacement function of `NULL` will delete an already set
displacement function. The bounds parameter is optional. If `NULL` is
passed as bounds, then the displacement shader will get evaluated
during the build process to properly bound displaced geometry. If a
pointer to some bounds of the displacement are passed, then the
implementation can choose to use these bounds to bound displaced
geometry. When bounds are specified, then these bounds have to be
conservative and should be tight for best performance.

The displacement function has to have the following type:

    typedef void (*RTCDisplacementFunc)(void* ptr, unsigned geomID, unsigned primID,   
                                        const float* u,  const float* v,    
                                        const float* nx, const float* ny, const float* nz,   
                                        float* px, float* py, float* pz,         
                                        size_t N);

The displacement function is called with the user data pointer of the
geometry (`ptr`), the geometry ID (`geomID`) and primitive ID (`primID`)
of a patch to displace. For this patch, a number N of points to displace
are specified in a struct of array layout. For each point to displace
the local patch UV coordinates (`u` and `v` arrays), the normalized
geometry normal (`nx`, `ny`, and `nz` arrays), as well as world space
position (`px`, `py`, and `pz` arrays) are provided. The task of the
displacement function is to use this information and move the world
space position inside the allowed specified bounds around the point.

All passed arrays are guaranteed to be 64 bytes aligned, and properly
padded to make wide vector processing inside the displacement function
possible.

The displacement mapping functions might get called during the
`rtcCommit` call, or lazily during the `rtcIntersect` or
`rtcOccluded` calls.

Also see tutorial [Displacement Geometry] for an example of how to use
the displacement mapping functions.

Sharing Threads with Embree
---------------------------

On some implementations, Embree supports using the application threads
when building internal data structures, by using the

    void rtcCommitThread(RTCScene, unsigned threadIndex, unsigned threadCount);

API call to commit the scene. This function has to get called by all
threads that want to cooperate in the scene commit. Each call is
provided the scene to commit, the index of the calling thread in the
range [0, `threadCount`-1], and the number of threads that will call
into this commit operation for the scene. All threads will return
again from this function after the scene commit is finished.

Multiple such scene commit operations can also be running at the same
time, e.g. it is possible to commit many small scenes in parallel
using one thread per commit operation. Subsequent commit operations
for the same scene can use different number of threads in the
`rtcCommitThread` or use the Embree internal threads using the
`rtcCommit` call.

*Note:* When using Embree with the Intel® Threading Building Blocks
(which is the default) you should not use the `rtcCommitThread`
function. Sharing of your threads with TBB is not possible and TBB
will always generate its own set of threads. We recommend to also use
TBB inside your application to share threads with the Embree
library. When using TBB inside your application do never use the
`rtcCommitThread` function.

*Note:* When enabling the Embree internal tasking system the
`rtcCommitThread` feature will work as expected and use the
application threads for hierarchy building.

*Note:* On the Intel® Xeon Phi™ coprocessor the `rtcCommitThread`
feature is recommended to be used.

Join Build Operation
--------------------

If `rtcCommit` is called multiple times from different threads on
the same scene, then all these threads will join the same scene build
operation.

This feature allows a flexible way to lazily create hierarchies during
rendering. A thread reaching a not yet constructed sub-scene of a
two-level scene, can generate the sub-scene geometry and call
`rtcCommit` on that just generated scene. During construction, further
threads reaching the not-yet-built scene, can join the build operation
by also invoking `rtcCommit`. A thread that calls `rtcCommit` after
the build finishes, will directly return from the `rtcCommit`
call (even for static scenes).

*Note:* Due to some limitation of the task_arena implementation of the
Intel® Threading Building Blocks, threads that call `rtcCommit` to
join a running build will just wait for the build to finish. Thus the
join mode does just not work properly when using TBB, and might cause
the build to run sequential (if all threads want to join).

*Note:* The join mode works properly with the internal tasking
 scheduler of Embree.

Memory Monitor Callback
---------------------------

Using the memory monitor callback mechanism, the application can track
the memory consumption of an Embree device, and optionally terminate
API calls that consume too much memory.

The user provided memory monitor callback function has to have the
following signature:

    bool (*RTCMemoryMonitorFunc)(const ssize_t bytes, const bool post);

A single such callback function per device can be registered by calling

    rtcDeviceSetMemoryMonitorFunction(RTCDevice device, RTCMemoryMonitorFunc func);

and deregistered again by calling it with `NULL`. Once registered the
Embree device will invoke the callback function before or after it
allocates or frees important memory blocks. The callback function
might get called from multiple threads concurrently.

The application can track the current memory usage of the Embree
device by atomically accumulating the provided `bytes` input
parameter. This parameter will be >0 for allocations and <0 for
deallocations. The `post` input parameter is true if the callback
function was invoked after the allocation or deallocation, otherwise
it is false.

Embree will continue its operation normally when returning true from
the callback function. If false is returned, Embree will cancel the
current operation with the RTC_OUT_OF_MEMORY error code. Cancelling
will only happen when the callback was called for allocations (bytes >
0), otherwise the cancel request will be ignored. If a callback that
was invoked before the allocation happens (`post == false`) cancels
the operation, then the `bytes` parameter should not get accumulated,
as the allocation will never happen. If a callback that was called
after the allocation happened (`post == true`) cancels the operation,
then the `bytes` parameter should get accumulated, as the allocation
properly happened. Issuing multiple cancel requests for the same
operation is allowed.

Progress Monitor Callback
---------------------------

The progress monitor callback mechanism can be used to report progress
of hierarchy build operations and to cancel long lasting build
operations.

The user provided progress monitor callback function has to have the
following signature:

    bool (*RTCProgressMonitorFunc)(void* userPtr, const double n);

A single such callback function can be registered per scene by
calling

    rtcSetProgressMonitorFunction(RTCScene, RTCProgressMonitorFunc, void* userPtr);

and deregistered again by calling it with `NULL` for the callback
function. Once registered Embree will invoke the callback function
multiple times during hierarchy build operations of the scene, by
providing the `userPtr` pointer that was set at registration time, and a
double `n` in the range $[0, 1]$ estimating the completion amount of the
operation. The callback function might get called from multiple threads
concurrently.

When returning `true` from the callback function, Embree will continue
the build operation normally. When returning `false` Embree will
cancel the build operation with the RTC_CANCELLED error code. Issuing
multiple cancel requests for the same build operation is allowed.

Configuring Embree
------------------

Some internal device parameters can get configured using the
`rtcDeviceSetParameter1i` API call. 

Currently we support to configure the size of the internal software
cache that is used to handle subdivision surfaces by setting the
`RTC_SOFTWARE_CACHE_SIZE` parameter to the desired size of the cache
in bytes:

    rtcDeviceSetParameter1i(device, RTC_SOFTWARE_CACHE_SIZE, bytes);

The software cache cannot get configured while any Embree API call is
executed. Best configure the size of the cache only once at
application start.

Limiting number of Build Threads
--------------------------------

You can use the TBB API to limit the number of threads used by Embree
during hierarchy construction. Therefore just create a global
taskscheduler_init object, initialized with the number of threads to
use:

    #include <tbb/tbb.h>

    tbb::task_scheduler_init init(numThreads);
Embree Tutorials
================

Embree comes with a set of tutorials aimed at helping users understand
how Embree can be used and extended. All tutorials exist in an ISPC and
C version to demonstrate the two versions of the API. Look for files
named `tutorialname_device.ispc` for the ISPC implementation of the
tutorial, and files named `tutorialname_device.cpp` for the single ray C++
version of the tutorial. To start the C++ version use the `tutorialname`
executables, to start the ISPC version use the `tutorialname_ispc`
executables.

Under Linux Embree also comes with an ISPC version of all tutorials
for the Intel® Xeon Phi™ coprocessor. The executables of this version
of the tutorials are named `tutorialname_xeonphi` and only work if a
Xeon Phi™ coprocessor is present in the system. The Xeon Phi™ version of
the tutorials get started on the host CPU, just like all other
tutorials, and will connect automatically to one installed Xeon Phi™
coprocessor in the system. For the Intel® Xeon Phi™ coprocessor to
find to Embree library you have to add the path to
`libembree_xeonphi.so` to the `SINK_LD_LIBRARY_PATH` variable.

For all tutorials, you can select an initial camera using the `-vp`
(camera position), `-vi` (camera look-at point), `-vu` (camera up
vector), and `-fov` (vertical field of view) command line parameters:

    ./triangle_geometry -vp 10 10 10 -vi 0 0 0

You can select the initial windows size using the `-size` command line
parameter, or start the tutorials in fullscreen using the `-fullscreen`
parameter:

    ./triangle_geometry -size 1024 1024
    ./triangle_geometry -fullscreen

Implementation specific parameters can be passed to the ray tracing core
through the `-rtcore` command line parameter, e.g.:

    ./triangle_geometry -rtcore verbose=2,threads=1,accel=bvh4.triangle1

The navigation in the interactive display mode follows the camera orbit
model, where the camera revolves around the current center of interest.
With the left mouse button you can rotate around the center of interest
(the point initially set with `-vi`). Holding Control pressed while
clicking the left mouse button rotates the camera around its location.
You can also use the arrow keys for navigation.

You can use the following keys:

F1
:   Default shading

F2
:   Gray EyeLight shading

F3
:   Wireframe shading

F4
:   UV Coordinate visualization

F5
:   Geometry normal visualization

F6
:   Geometry ID visualization

F7
:   Geometry ID and Primitive ID visualization

F8
:   Simple shading with 16 rays per pixel for benchmarking.

F9
:   Switches to render cost visualization. Pressing again reduces
    brightness.

F10
:   Switches to render cost visualization. Pressing again increases
    brightness.

f
:   Enters or leaves full screen mode.

c
:   Prints camera parameters.

ESC
:   Exits the tutorial.

q
:   Exits the tutorial.

Triangle Geometry
-----------------

![][imgTriangleGeometry]

This tutorial demonstrates the creation of a static cube and ground
plane using triangle meshes. It also demonstrates the use of the
`rtcIntersect` and `rtcOccluded` functions to render primary visibility
and hard shadows. The cube sides are colored based on the ID of the hit
primitive.

Dynamic Scene
-------------

![][imgDynamicScene]

This tutorial demonstrates the creation of a dynamic scene, consisting
of several deformed spheres. Half of the spheres use the
`RTC_GEOMETRY_DEFORMABLE` flag, which allows Embree to use a refitting
strategy for these spheres, the other half uses the
`RTC_GEOMETRY_DYNAMIC` flag, causing a rebuild of their spatial data
structure each frame. The spheres are colored based on the ID of the hit
sphere geometry.

User Geometry
-------------

![][imgUserGeometry]

This tutorial shows the use of user defined geometry, to re-implement
instancing and to add analytic spheres. A two level scene is created,
with a triangle mesh as ground plane, and several user geometries, that
instance other scenes with a small number of spheres of different kind.
The spheres are colored using the instance ID and geometry ID of the hit
sphere, to demonstrate how the same geometry, instanced in different
ways can be distinguished.

Viewer
------

![][imgViewer]

This tutorial demonstrates a simple OBJ viewer that traces primary
visibility rays only. A scene consisting of multiple meshes is created,
each mesh sharing the index and vertex buffer with the application.
Demonstrated is also how to support additional per vertex data, such as
shading normals.

You need to specify an OBJ file at the command line for this tutorial to
work:

    ./viewer -i model.obj

Instanced Geometry
------------------

![][imgInstancedGeometry]

This tutorial demonstrates the in-build instancing feature of Embree, by
instancing a number of other scenes build from triangulated spheres. The
spheres are again colored using the instance ID and geometry ID of the
hit sphere, to demonstrate how the same geometry, instanced in different
ways can be distinguished.

Intersection Filter
-------------------

![][imgIntersectionFilter]

This tutorial demonstrates the use of filter callback functions to
efficiently implement transparent objects. The filter function used for
primary rays, lets the ray pass through the geometry if it is entirely
transparent. Otherwise the shading loop handles the transparency
properly, by potentially shooting secondary rays. The filter function
used for shadow rays accumulates the transparency of all surfaces along
the ray, and terminates traversal if an opaque occluder is hit.

Pathtracer
----------

![][imgPathtracer]

This tutorial is a simple path tracer, building on the viewer tutorial.

You need to specify an OBJ file and light source at the command line for
this tutorial to work:

    ./pathtracer -i model.obj -ambientlight 1 1 1

As example models we provide the "Austrian Imperial Crown" model by
[Martin Lubich](www.loramel.net) and the "Asian Dragon" model from the
[Stanford 3D Scanning Repository](http://graphics.stanford.edu/data/3Dscanrep/).

[crown.zip](https://github.com/embree/models/releases/download/release/crown.zip)

[asian_dragon.zip](https://github.com/embree/models/releases/download/release/asian_dragon.zip)

To render these models execute the following:

    ./pathtracer -c crown/crown.ecs
    ./pathtracer -c asian_dragon/asian_dragon.ecs

Hair
----

![][imgHairGeometry]

This tutorial demonstrates the use of the hair geometry to render a
hairball.

Subdivision Geometry
--------------------

![][imgSubdivisionGeometry]

This tutorial demonstrates the use of Catmull Clark subdivision
surfaces. Per default the edge tessellation level is set adaptively
based on the distance to the camera origin. Embree currently supports
three different modes for efficiently handling subdivision surfaces in
various rendering scenarios. These three modes can be selected at the
command line, e.g. `-lazy` builds internal per subdivision patch data
structures on demand, `-cache` uses a small (per thread) tessellation
cache for caching per patch data, and `-pregenerate` to generate and
store most per patch data during the initial build process. The
`cache` mode is most effective for coherent rays while providing a
fixed memory footprint. The `pregenerate` modes is most effective for
incoherent ray distributions while requiring more memory. The `lazy`
mode works similar to the `pregenerate` mode but provides a middle
ground in terms of memory consumption as it only builds and stores
data only when the corresponding patch is accessed during the ray
traversal. The `cache` mode is currently a bit more efficient at
handling dynamic scenes where only the edge tessellation levels are
changing per frame.

Displacement Geometry
---------------------

![][imgDisplacementGeometry]

This tutorial demonstrates the use of Catmull Clark subdivision
surfaces with procedural displacement mapping using a constant edge
tessellation level.

Motion Blur Geometry
--------------------

![][imgMotionBlurGeometry]

This tutorial demonstrates rendering motion blur using the linear
motion blur feature for triangles and hair geometry.

Interpolation
-------------

![][imgInterpolation]

This tutorial demonstrates interpolation of user defined per vertex data.

BVH Builder
-----------

This tutorial demonstrates how to use the templated hierarchy builders
of Embree to build a bounding volume hierarchy with a user defined
memory layout using a high quality SAH builder and very fast morton
builder.

BVH Access
-----------

This tutorial demonstrates how to access the internal triangle
acceleration structure build by Embree. Please be aware that the
internal Embree data structures might change between Embree updates.

Find Embree
-----------

This tutorial demonstrates how to use the `FIND_PACKAGE` CMake feature
to use an installed Embree. Under Linux and Mac\ OS\ X the tutorial finds
the Embree installation automatically, under Windows the `embree_DIR`
CMake variable has to be set to the following folder of the Embree
installation: `C:\Program Files\Intel\Embree
X.Y.Z\lib\cmake\embree-X.Y.Z`.

[Embree API]: #embree-api
[Embree Example Renderer]: https://embree.github.io/renderer.html
[Triangle Geometry]: #triangle-geometry
[User Geometry]: #user-geometry
[Instanced Geometry]: #instanced-geometry
[Intersection Filter]: #intersection-filter
[Hair]: #hair
[Subdivision Geometry]: #subdivision-geometry
[Displacement Geometry]: #displacement-geometry
[BVH Builder]: #bvh-builder
[Interpolation]: #interpolation
[Configuring Embree]: #configuring-embree
[Individual Contributor License Agreement (ICLA)]: https://embree.github.io/data/Embree-ICLA.pdf
[Corporate Contributor License Agreement (CCLA)]: https://embree.github.io/data/Embree-CCLA.pdf
[imgTriangleUV]: https://embree.github.io/images/triangle_uv.png
[imgQuadUV]: https://embree.github.io/images/quad_uv.png
[imgTriangleGeometry]: https://embree.github.io/images/triangle_geometry.jpg
[imgDynamicScene]: https://embree.github.io/images/dynamic_scene.jpg
[imgUserGeometry]: https://embree.github.io/images/user_geometry.jpg
[imgViewer]: https://embree.github.io/images/viewer.jpg
[imgInstancedGeometry]: https://embree.github.io/images/instanced_geometry.jpg
[imgIntersectionFilter]: https://embree.github.io/images/intersection_filter.jpg
[imgPathtracer]: https://embree.github.io/images/pathtracer.jpg
[imgHairGeometry]: https://embree.github.io/images/hair_geometry.jpg
[imgSubdivisionGeometry]: https://embree.github.io/images/subdivision_geometry.jpg
[imgDisplacementGeometry]: https://embree.github.io/images/displacement_geometry.jpg
[imgMotionBlurGeometry]: https://embree.github.io/images/motion_blur_geometry.jpg
[imgInterpolation]: https://embree.github.io/images/interpolation.jpg
