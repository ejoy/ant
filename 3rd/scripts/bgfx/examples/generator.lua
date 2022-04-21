local BgfxDir = ...

local fs = require "bee.filesystem"

local function readall(file)
    local f <close> = assert(io.open(file, "rb"))
    return f:read "a"
end

local function generator(name)
    local s = {}
    local function write(text)
        s[#s+1] = text
    end

    local projectdir = BgfxDir.."/examples/"..name
    local c_sources = {}
    local cpp_sources = {}
    local shaders = {}
    local meshes = {}
    local textures = {}
    local copyfiles = {}
    local STDC_FORMAT_MACROS = false

    for file in fs.pairs(projectdir) do
        local filename = file:filename():string()
        local ext = file:extension():string():lower()
        if ext == ".c" then
            c_sources[#c_sources+1] = filename
        elseif ext == ".cpp" then
            cpp_sources[#cpp_sources+1] = filename
        elseif ext == ".sc" then
            if filename:match "^[cfv]s_" then
                if not fs.exists(file:replace_extension ".bin.h") then
                    shaders[#shaders+1] = filename
                end
            end
        end
    end

    table.sort(c_sources)
    table.sort(cpp_sources)
    table.sort(shaders)

    for _, filename in ipairs(cpp_sources) do
        local content = readall(projectdir.."/"..filename)
        content:gsub('"(%w+)/([^/]+%.%w+)"', function (dir, file)
            if dir == "meshes" then
                if file == "unit_sphere.bin" then
                    copyfiles[#copyfiles+1] = "meshes/"..file
                else
                    meshes[#meshes+1] = file:match "^([^/]+)%.bin$"
                end
            elseif dir == "textures" then
                if file:match "%%s" then
                    assert(name == "18-ibl")
                    textures[#textures+1] = file:format "bolonga"
                    textures[#textures+1] = file:format "kyoto"
                else
                    textures[#textures+1] = file
                end
            elseif dir == "font" then
                if file:match "%.ttf$" then
                    copyfiles[#copyfiles+1] = "font/"..file
                elseif file:match "%.otf$" then
                    copyfiles[#copyfiles+1] = "font/"..file
                end
            elseif dir == "text" then
                copyfiles[#copyfiles+1] = "text/"..file
            end
        end)
        :gsub("PRIx64", function ()
            assert(name == "07-callback")
            STDC_FORMAT_MACROS = true
        end)
    end
    table.sort(meshes)
    table.sort(textures)
    table.sort(copyfiles)

    write "local lm = require 'luamake'"
    if #shaders > 0 then
        write "local shaderc = require 'examples.shaderc'"
    end
    if #meshes > 0 then
        write "local geometryc = require 'examples.geometryc'"
    end
    if #textures > 0 then
        write "local texturec = require 'examples.texturec'"
    end
    if #copyfiles > 0 then
        write "local copy = require 'examples.copyfile'"
    end
    write ""
    write "lm:exe '${NAME}' {"
    write "    rootdir = lm.BgfxDir,"
    write "    deps = {"
    write "        'example-runtime',"
    for _, shader in ipairs(shaders) do
        write(("        shaderc.compile 'examples/${NAME}/%s',"):format(shader))
    end
    for _, mesh in ipairs(meshes) do
        if mesh == "test_scene" then
            write "        geometryc.compile 'examples/assets/sky/test_scene.obj',"
        else
            write(("        geometryc.compile 'examples/assets/meshes/%s.obj',"):format(mesh))
        end
    end
    for _, texture in ipairs(textures) do
        write(("        texturec.compile 'examples/runtime/textures/%s',"):format(texture))
    end
    for _, copyfile in ipairs(copyfiles) do
        write(("        copy.compile 'examples/runtime/%s',"):format(copyfile))
    end
    write "    },"
    write "    defines = 'ENTRY_CONFIG_IMPLEMENT_MAIN=1',"
    write "    includes = {"
    write "        lm.BxDir / 'include',"
    write "        lm.BimgDir / 'include',"
    write "        lm.BgfxDir / 'include',"
    write "        lm.BgfxDir / 'examples/common',"
    write "        lm.BgfxDir / '3rdparty',"
    write "    },"
    write "    sources = {"
    for _, filename in ipairs(c_sources) do
        write(("        'examples/${NAME}/%s',"):format(filename))
    end
    for _, filename in ipairs(cpp_sources) do
        write(("        'examples/${NAME}/%s',"):format(filename))
    end
    write "    },"
    if STDC_FORMAT_MACROS then
        write "    msvc = {"
        write "        defines = '__STDC_FORMAT_MACROS'"
        write "    }"
    end
    write "}"
    write ""

    local result = table.concat(s, "\n")
        : gsub("${(%u+)}", {
            NAME = name,
        })
    local f <close> = assert(io.open("./examples/"..name..".lua", "wb"))
    f:write(result)
end

for example in fs.pairs(BgfxDir.."/examples/") do
    local name = example:string():match '/(%d%d%-[^/]*)$'
    if name then
        generator(name)
    end
end
