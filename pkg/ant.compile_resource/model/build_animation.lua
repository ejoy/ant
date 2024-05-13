local utility           = require "model.utility"
local serialize         = import_package "ant.serialize"
local lfs               = require "bee.filesystem"
local depends           = require "depends"

local function serialize_path(path)
    if path:sub(1,1) ~= "/" then
        return serialize.path(path)
    end
    return path
end

local function compile_animation(status, skeleton, name, file)
    if lfs.path(file):extension() ~= ".anim" then
        return serialize_path(file)
    end
    local anim2ozz = require "model.anim2ozz"
    local vfs_fastio = require "vfs_fastio"
    local fastio = require "fastio"
    local skecontent = skeleton:sub(1,1) == "/"
         and vfs_fastio.readall_f(status.setting, skeleton)
         or fastio.readall_f((status.output / "animations" / skeleton):string())
    depends.add_vpath(status.depfiles, status.setting, file)
    anim2ozz(status.setting, skecontent, file, (status.output / "animations" / (name..".bin")):string())
    return serialize.path(name..".bin")
end

-- function build_animation_prefab(status)
return function (status)
    utility.save_txt_file(status, "animations/animation.ozz", status.animation, function (t)
        if t.skeleton then
            if t.animations then
                for name, file in pairs(t.animations) do
                    t.animations[name] = compile_animation(status, t.skeleton, name, file)
                end
            end
            if t.skins then
                for i, file in ipairs(t.skins) do
                    t.skins[i] = serialize_path(file)
                end
            end
            t.skeleton = serialize_path(t.skeleton)
        end
        return t
    end)
end
