if __ANT_RUNTIME__ then
    error "Cannot be imported in runtime mode."
end

local sha1    = require "sha1"
local depends = require "depends"
local ltask   = require "ltask"
local lfs = require "bee.filesystem"
local vfs = require "vfs"

local function init_config(setting)
    local os, renderer = setting:match "^(%w+)-(%w+)$"
    local binpath = lfs.path(vfs.repopath()) / "res" / setting
    lfs.create_directories(binpath)
    for _, ext in ipairs {"glb", "texture", "material"} do
        lfs.create_directory(binpath / ext)
    end
    return {
        binpath = binpath,
        compiling = {},
        setting = {
            os = os,
            renderer = renderer,
        },
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

local function compile_file(config, input)
    assert(input:sub(1,1) ~= ".")
    if config.compiling[input] then
        return ltask.multi_wait(config.compiling[input])
    end
    config.compiling[input] = {}
    local ext = input:match "[^/]%.([%w*?_%-]*)$"
    local output = config.binpath / ext / get_filename(input)
    local changed = depends.dirty(output / ".dep")
    if changed then
        local ok, deps = COMPILER[ext](input, output, config.setting, changed)
        if not ok then
            local err = deps
            error("compile failed: " .. input .. "\n" .. err)
        end
        depends.writefile(output / ".dep", deps)
    end
    ltask.multi_wakeup(config.compiling[input], output:string())
    config.compiling[input] = nil
    return output:string()
end

local function verify_file(config, input)
    assert(input:sub(1,1) ~= ".")
    if config.compiling[input] then
        return ltask.multi_wait(config.compiling[input])
    end
    local ext = input:match "[^/]%.([%w*?_%-]*)$"
    local output = config.binpath / ext / get_filename(input)
    local changed = depends.dirty(output / ".dep")
    if changed then
        lfs.remove_all(output)
        return false
    end
    return output:string()
end

return {
    init_config  = init_config,
    compile_file = compile_file,
    verify_file = verify_file,
}
