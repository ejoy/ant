local lm = require "luamake"

lm.rootdir = lm.AntDir.."/3rd/bee.lua"

local OS = {
    "win",
    "posix",
    "osx",
    "linux",
    "bsd",
}

local function need(lst)
    local map = {}
    if type(lst) == "table" then
        for _, v in ipairs(lst) do
            map[v] = true
        end
    else
        map[lst] = true
    end
    local t = {}
    for _, v in ipairs(OS) do
        if not map[v] then
            t[#t+1] = "!bee/**/*_"..v..".cpp"
            t[#t+1] = "!bee/"..v.."/**/*.cpp"
        end
    end
    return t
end

lm:source_set "bee" {
    sources = "3rd/fmt/format.cc",
}

lm:source_set "bee" {
    includes = {
        ".",
        "3rd/lua",
    },
    sources = "bee/**/*.cpp",
    windows = {
        sources = need "win"
    },
    macos = {
        sources = {
            "bee/**/*.mm",
            need {
                "osx",
                "posix",
            }
        }
    },
    ios = {
        sources = {
            "bee/**/*.mm",
            "!bee/filewatch/**/",
            need {
                "osx",
                "posix",
            }
        }
    },
    linux = {
        sources = need {
            "linux",
            "posix",
        }
    },
    android = {
        sources = need {
            "linux",
            "posix",
        }
    }
}

lm:lua_src "bee" {
    includes = {
        "3rd/lua-seri",
        "."
    },
    defines = "BEE_STATIC",
    sources = "binding/*.cpp",
    windows = {
        defines = "_CRT_SECURE_NO_WARNINGS",
        sources = {
            "binding/port/lua_windows.cpp",
        },
        links = {
            "ntdll",
            "ws2_32",
            "ole32",
            "user32",
            "version",
            "synchronization",
        },
    },
    mingw = {
        links = {
            "uuid",
            "stdc++fs"
        }
    },
    linux = {
        links = {
            "pthread",
	    "bfd",
	    "unwind",
        }
    },
    macos = {
        frameworks = {
            "Foundation",
            "CoreFoundation",
            "CoreServices",
        }
    },
    ios = {
        sources = {
            "!binding/lua_filewatch.cpp",
        },
        frameworks = {
            "Foundation",
        }
    },
}
