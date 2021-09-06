local lm = require "luamake"
lm.rootdir = "../SDL"
lm.includes = "include"
lm.defines = {
    "SDL_DYNAMIC_API=0",
    "SDL_dynapi_h_",
}
lm.macos = {
    sys = "macos10.6",
}

-- timer
lm:source_set "sdl" {
    sources = "src/timer/*.c",
    windows = {
        sources = "src/timer/windows/*.c",
    },
    macos = {
        sources = "src/timer/unix/*.c",
    }
}

-- atomic
lm:source_set "sdl" {
    sources = "src/atomic/*.c"
}

-- thread
lm:source_set "sdl" {
    sources = {
        "src/thread/*.c",
        "src/thread/generic/SDL_syscond.c",
    },
    defines = "SDL_THREAD_GENERIC_COND_SUFFIX=1",
    windows = {
        sources = {
            "src/thread/windows/*.c",
        },
        defines = "SDL_THREAD_WINDOWS=1"
    },
    macos = {
        sources = {
            "src/thread/pthread/*.c",
        },
        defines = "SDL_THREAD_PTHREAD=1"
    }
}

-- render
lm:source_set "sdl" {
    sources = "src/render/SDL_render.c",
    defines = {
        "SDL_RENDER_DISABLED=1",
        "SDL_LEAN_AND_MEAN=1",
    }
}

-- video
lm:source_set "sdl" {
    sources = {
        "src/video/*.c",
        "!src/video/SDL_yuv.c",
        "!src/video/SDL_egl.c",
        "!src/video/SDL_RLEaccel.c",
        "src/video/dummy/*.c",
    },
    defines = {
        "SDL_LOADSO_DISABLED=1",
        "SDL_LEAN_AND_MEAN=1",
        "SDL_VIDEO_RENDER_D3D=0",
        "SDL_VIDEO_RENDER_OGL=0",
        "SDL_VIDEO_RENDER_OGL_ES2=0",
        "SDL_VIDEO_RENDER_SW=0",
        "SDL_VIDEO_OPENGL=0",
        "SDL_VIDEO_OPENGL_ES2=0",
        "SDL_VIDEO_OPENGL_EGL=0",
        "SDL_VIDEO_OPENGL_WGL=0",
        "SDL_VIDEO_OPENGL_CGL=0",
        --"SDL_VIDEO_RENDER_D3D11=0",
        --"SDL_VIDEO_VULKAN=0",
    },
    windows = {
        sources = {
            "src/video/windows/*.c",
            "!src/video/windows/SDL_windowsvulkan.c",
            "!src/video/windows/SDL_windowsopengl.c",
            "!src/video/windows/SDL_windowsopengles.c",
        }
    },
    macos = {
        sources = {
            "src/video/cocoa/*.m",
            "!src/video/cocoa/SDL_cocoavulkan.m",
            "!src/video/cocoa/SDL_cocoaopengl.m",
            "!src/video/cocoa/SDL_cocoaopengles.m",
        }
    }
}

-- event
lm:source_set "sdl" {
    sources = "src/events/*.c",
    defines = {
        "SDL_JOYSTICK_DISABLED=1",
        "SDL_SENSOR_DISABLED=1",
    }
}

-- stdlib
lm:source_set "sdl" {
    sources = "src/stdlib/*.c",
    defines = "HAVE_LIBC",
}

-- other
lm:source_set "sdl" {
    sources = {
        "src/*.c",
        "!src/SDL.c",
        "src/file/*.c",
        "src/cpuinfo/*.c",
        "../scripts/sdl/*.c",
    },
    windows = {
        sources = {
            "src/loadso/windows/*.c",
            "src/core/windows/*.c",
        }
    },
    macos = {
        sources = {
            "src/loadso/dlopen/*.c",
            "src/file/cocoa/*.m",
        }
    }
}

-- main
lm:source_set "sdl" {
    includes = "include",
    sources = {
        "src/SDL.c",
    },
    defines = {
        "SDL_JOYSTICK_DISABLED=1",
        "SDL_AUDIO_DISABLED=1",
        "SDL_HAPTIC_DISABLED=1",
        "SDL_SENSOR_DISABLED=1",
        "SDL_RENDER_DISABLED=1",
        "SDL_LOADSO_DISABLED=1",
        "HAVE_LIBC",
    },
    windows = {
        links = {
            "version",
            "winmm",
            "advapi32",
            "oleaut32",
        },
    }
}
