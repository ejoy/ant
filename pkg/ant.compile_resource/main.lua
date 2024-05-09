local platform = require "bee.platform"

if platform.os == "ios" or platform.os == "android" then
    error "ios/android does not support compile resources."
end

local sha1    = require "sha1"
local depends = require "depends"
local ltask   = require "ltask"
local lfs     = require "bee.filesystem"

local function init_setting(vfs, setting)
    local os, renderer = setting:match "^(%w+)-(%w+)$"
    local rootpath = lfs.path(vfs.repopath())
    local respath = rootpath / "res" / setting
    local scpath = rootpath / ".app" / "build" / "sc"
    local shaderpath = rootpath / ".app" / "build" / "shader"
    lfs.create_directories(respath)
    lfs.create_directories(scpath)
    lfs.create_directories(shaderpath)
    for _, ext in ipairs {"glb", "gltf", "texture", "material"} do
        lfs.create_directory(respath / ext)
    end
    return {
        compiling = {},
        vfs = vfs,
        respath = respath,
        scpath = scpath,
        shaderpath = shaderpath,
        os = os,
        renderer = renderer,
    }
end

local function get_filename(pathname)
    pathname = pathname:lower()
    local filename = pathname:match "[/]?([^/]*)$"
    return filename.."_"..sha1(pathname)
end

local COMPILER <const> = {
    glb = require "model.glb",
    gltf = require "model.glb",
    texture = require "texture.convert",
    material = require "material.convert",
}

local function compile_file(setting, vpath, lpath)
    assert(lpath:sub(1,1) ~= ".")
    if setting.compiling[lpath] then
        return ltask.multi_wait(setting.compiling[lpath])
    end
    setting.compiling[lpath] = {}
    local ext = vpath:match "[^/]%.([%w*?_%-]*)$"
    local output = setting.respath / ext / get_filename(vpath)
    local changed = depends.dirty(setting, output / ".dep")
    if changed then
        local ok, deps = COMPILER[ext](lpath, vpath, output, setting, changed)
        if not ok then
            local err = deps
            error("compile failed: " .. lpath .. "\n" .. err)
        end
        depends.writefile(output / ".dep", deps)
    end
    ltask.multi_wakeup(setting.compiling[lpath], output:string())
    setting.compiling[lpath] = nil
    return output:string()
end

local function verify_file(setting, vpath, lpath)
    assert(lpath:sub(1,1) ~= ".")
    if setting.compiling[lpath] then
        return ltask.multi_wait(setting.compiling[lpath])
    end
    local ext = vpath:match "[^/]%.([%w*?_%-]*)$"
    local output = setting.respath / ext / get_filename(vpath)
    local changed = depends.dirty(setting, output / ".dep")
    if changed then
        lfs.remove_all(output)
        return false
    end
    return output:string()
end

return {
    init_setting  = init_setting,
    compile_file = compile_file,
    verify_file = verify_file,
}
