Version History
---------------

### New Features in Embree 2.8.0

-   Added support for line segment geometry.
-   Added support for quad geometry (replaces triangle-pairs feature).
-   Added support for linear motion blur of user geometries.
-   Improved performance through AVX512 optimizations.
-   Improved performance of lazy scene build (when using TBB 4.4 update 2).
-   Improved performance through huge page support under linux.

### New Features in Embree 2.7.1

-   Internal tasking system supports cancellation of build operations.
-   ISPC mode for robust and compact scenes got significantly faster
    (implemented hybrid traversal for bvh4.triangle4v and bvh4.triangle4i).
-   Hair rendering got faster as we fixed some issues with the SAH
    heuristic cost factors.
-   BVH8 got slight faster for single ray traversal (improved sorting
    when hitting more than 4 boxes).
-   BVH build performance got up to 30% faster on CPUs with high core
    counts (improved parallel partition code).
-   High quality build mode again working properly (spatial splits had been
    deactivated in v2.7.0 due to some bug).
-   Support for merging two adjacent triangles sharing a common edge
    into a triangle-pair primitive (can reduce memory consumption and
    BVH build times by up to 50% for mostly quad-based input meshes).
-   Internal cleanups (reduced number of traversal kernels by more templating)
-   Reduced stack size requirements of BVH builders.
-   Fixed crash for dynamic scenes, triggered by deleting all
    geometries from the scene.

### New Features in Embree 2.7.0

-   Added device concept to Embree to allow different components of an
    application to use Embree without interfering with each other.
-   Fixed memory leak in twolevel builder used for dynamic scenes.
-   Fixed bug in tesselation cache that caused crashes for subdivision
    surfaces.
-   Fixed bug in internal task scheduler that caused deadlocks when
    using rtcCommitThread.
-   Improved hit-distance accuracy for thin triangles in robust mode.
-   Added support to disable ray packet support in cmake.

### New Features in Embree 2.6.2

-   Fixed bug triggered by instantiating motion blur geometry.
-   Fixed bug in hit UV coordinates of static subdivision geometries.
-   Performance improvements when only changing tessellation levels for
    subdivision geometry per frame.
-   Added ray packet intersectors for subdivision geometry, resulting in
    improved performance for coherent rays.
-   Reduced virtual address space usage for static geometries.
-   Fixed some AVX2 code paths when compiling with GCC or Clang.
-   Bugfix for subdiv patches with non-matching winding order.
-   Bugfix in ISA detection of AVX512.

### New Features in Embree 2.6.1

-   Major performance improvements for ray tracing subdivision surfaces,
    e.g. up to 2× faster for scenes where only the tessellation levels
    are changing per frame, and up to 3× faster for scenes with lots of
    crease features
-   Initial support for architectures supporting the new 16-wide AVX512
    ISA
-   Implemented intersection filter callback support for subdivision
    surfaces
-   Added `RTC_IGNORE_INVALID_RAYS` CMake option which makes the ray
    intersectors more robust against full tree traversal caused by
    invalid ray inputs (e.g. INF, NaN, etc)

### New Features in Embree 2.6.0

-   Added `rtcInterpolate` function to interpolate per vertex
    attributes
-   Added `rtcSetBoundaryMode` function that can be used to select the
    boundary handling for subdivision surfaces
-   Fixed a traversal bug that caused rays with very small ray
    direction components to miss geometry
-   Performance improvements for the robust traversal mode
-   Fixed deadlock when calling `rtcCommit` from multiple
    threads on same scene

### New Features in Embree 2.5.1

-   On dual socket workstations, the initial BVH build performance
    almost doubled through a better memory allocation scheme
-   Reduced memory usage for subdivision surface objects with crease
    features
-   `rtcCommit` performance is robust against unset "flush to zero" and
    "denormals are zero" flags. However, enabling these flags in your
    application is still recommended
-   Reduced memory usage for subdivision surfaces with borders and
    infinitely sharp creases
-   Lots of internal cleanups and bug fixes for both Intel® Xeon® and
    Intel® Xeon Phi™

### New Features in Embree 2.5.0

-   Improved hierarchy build performance on both Intel Xeon and Intel
    Xeon Phi
-   Vastly improved tessellation cache for ray tracing subdivision
    surfaces
-   Added `rtcGetUserData` API call to query per geometry user pointer
    set through `rtcSetUserData`
-   Added support for memory monitor callback functions to track and
    limit memory consumption
-   Added support for progress monitor callback functions to track build
    progress and cancel long build operations
-   BVH builders can be used to build user defined hierarchies inside
    the application (see tutorial [BVH Builder])
-   Switched to TBB as default tasking system on Xeon to get even faster
    hierarchy build times and better integration for applications that
    also use TBB
-   `rtcCommit` can get called from multiple TBB threads to join the
    hierarchy build operations

### New Features in Embree 2.4

-   Support for Catmull Clark subdivision surfaces (triangle/quad base
    primitives)
-   Support for vector displacements on Catmull Clark subdivision
    surfaces
-   Various bug fixes (e.g. 4-byte alignment of vertex buffers works)

### New Features in Embree 2.3.3

-   BVH builders more robustly handle invalid input data (Intel Xeon
    processor family)
-   Motion blur support for hair geometry (Xeon)
-   Improved motion blur performance for triangle geometry (Xeon)
-   Improved robust ray tracing mode (Xeon)
-   Added `rtcCommitThread` API call for easier integration into
    existing tasking systems (Xeon and Intel Xeon Phi coprocessor)
-   Added support for recording and replaying all
    `rtcIntersect`/`rtcOccluded` calls (Xeon and Xeon Phi)

### New Features in Embree 2.3.2

-   Improved mixed AABB/OBB-BVH for hair geometry (Xeon Phi)
-   Reduced amount of pre-allocated memory for BVH builders (Xeon Phi)
-   New 64\ bit Morton code-based BVH builder (Xeon Phi)
-   (Enhanced) Morton code-based BVH builders use now tree rotations to
    improve BVH quality (Xeon Phi)
-   Bug fixes (Xeon and Xeon Phi)

### New Features in Embree 2.3.1

-   High quality BVH mode improves spatial splits which result in up to
    30% performance improvement for some scenes (Xeon)
-   Compile time enabled intersection filter functions do not reduce
    performance if no intersection filter is used in the scene (Xeon and
    Xeon Phi)
-   Improved ray tracing performance for hair geometry by \>20% on Xeon
    Phi. BVH for hair geometry requires 20% less memory
-   BVH8 for AVX/AVX2 targets improves performance for single ray
    tracing on Haswell by up to 12% and by up to 5% for hybrid (Xeon)
-   Memory conservative BVH for Xeon Phi now uses BVH node quantization
    to lower memory footprint (requires half the memory footprint of the
    default BVH)

### New Features in Embree 2.3

-   Support for ray tracing hair geometry (Xeon and Xeon Phi)
-   Catching errors through error callback function
-   Faster hybrid traversal (Xeon and Xeon Phi)
-   New memory conservative BVH for Xeon Phi
-   Faster Morton code-based builder on Xeon
-   Faster binned-SAH builder on Xeon Phi
-   Lots of code cleanups/simplifications/improvements (Xeon and Xeon
    Phi)

### New Features in Embree 2.2

-   Support for motion blur on Xeon Phi
-   Support for intersection filter callback functions
-   Support for buffer sharing with the application
-   Lots of AVX2 optimizations, e.g. \~20% faster 8-wide hybrid
    traversal
-   Experimental support for 8-wide (AVX/AVX2) and 16-wide BVHs (Xeon
    Phi)

### New Features in Embree 2.1

-   New future proof API with a strong focus on supporting dynamic
    scenes
-   Lots of optimizations for 8-wide AVX2 (Haswell architecture)
-   Automatic runtime code selection for SSE, AVX, and AVX2
-   Support for user-defined geometry
-   New and improved BVH builders:
    -   Fast adaptive Morton code-based builder (without SAH-based
        top-level rebuild)
    -   Both the SAH and Morton code-based builders got faster (Xeon
        Phi)
    -   New variant of the SAH-based builder using triangle pre-splits
        (Xeon Phi)

### Example Performance Numbers for Embree 2.1

BVH rebuild performance (including triangle accel generation, excluding
memory allocation) for scenes with 2--12 million triangles:

-   Intel® Core™ i7 (Haswell-based CPU, 4 cores @ 3.0\ GHz)
    -   7--8 million triangles/s for the SAH-based BVH builder
    -   30--36 million triangles/s for the Morton code-based BVH builder
-   Intel® Xeon Phi™ 7120
    -   37--40 million triangles/s for the SAH-based BVH builder
    -   140--160 million triangles/s for the Morton code-based BVH
        builder

Rendering of the Crown model (`crown.ecs`) with 4\ samples per pixel
(`-spp 4`):

-   Intel® Core™ i7 (Haswell-based CPU, 4 cores CPU @ 3.0\ GHz)
    -   1024×1024 resolution: 7.8 million rays per sec
    -   1920×1080 resolution: 9.9 million rays per sec
-   Intel® Xeon Phi™ 7120
    -   1024×1024 resolution: 47.1 million rays per sec
    -   1920×1080 resolution: 61.1 million rays per sec

### New Features in Embree 2.0

-   Support for the Intel® Xeon Phi™ coprocessor platform
-   Support for high-performance "packet" kernels on SSE, AVX, and Xeon
    Phi
-   Integration with the Intel® SPMD Program Compiler (ISPC)
-   Instantiation and fast BVH reconstruction
-   Example photo-realistic rendering engine for both C++ and ISPC
