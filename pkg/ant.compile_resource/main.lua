if __ANT_RUNTIME__ then
    error "Cannot be imported in runtime mode."
end

local sha1    = require "sha1"
local depends = require "depends"
local ltask   = require "ltask"
local lfs = require "bee.filesystem"

local function init_setting(vfs, setting)
    local os, renderer = setting:match "^(%w+)-(%w+)$"
    local rootpath = lfs.path(vfs.repopath())
    local respath = rootpath / "res" / setting
    local scpath = rootpath / ".build" / "sc"
    local shaderpath = rootpath / ".build" / "shader"
    lfs.create_directories(respath)
    lfs.create_directories(scpath)
    lfs.create_directories(shaderpath)
    for _, ext in ipairs {"glb", "texture", "material"} do
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
    texture = require "texture.convert",
    material = require "material.convert",
}

local function compile_file(setting, input)
    assert(input:sub(1,1) ~= ".")
    if setting.compiling[input] then
        return ltask.multi_wait(setting.compiling[input])
    end
    setting.compiling[input] = {}
    local ext = input:match "[^/]%.([%w*?_%-]*)$"
    local output = setting.respath / ext / get_filename(input)
    local changed = depends.dirty(setting, output / ".dep")
    if changed then
        local ok, deps = COMPILER[ext](input, output, setting, changed)
        if not ok then
            local err = deps
            error("compile failed: " .. input .. "\n" .. err)
        end
        depends.writefile(output / ".dep", deps)
    end
    ltask.multi_wakeup(setting.compiling[input], output:string())
    setting.compiling[input] = nil
    return output:string()
end

local function verify_file(setting, input)
    assert(input:sub(1,1) ~= ".")
    if setting.compiling[input] then
        return ltask.multi_wait(setting.compiling[input])
    end
    local ext = input:match "[^/]%.([%w*?_%-]*)$"
    local output = setting.respath / ext / get_filename(input)
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
