local ecs = ...
local world = ecs.world
local w = world.w
local vfs = require "vfs"
local image  = require "image"
local fastio = require "fastio"
local fs = require "bee.filesystem"
local as = ecs.system "atlas_system"
local bgfx = require "bgfx"
local serialize = import_package "ant.serialize"
local iatlas = {}

function iatlas.collect_sub_files(atlas)
    local files = {}
    for p in fs.pairs(atlas.rpath) do
        if p:equal_extension ".png" then
            files[#files + 1] = p
        end
    end
    atlas.files = files
end

function iatlas.generate_atlas_file(atlas)
    local file_rpath = string.format("%s/%s.png", atlas.rpath, atlas.name and atlas.name or "atlas")
    local file_vpath = string.format("%s/%s.png", atlas.vpath, atlas.name and atlas.name or "atlas")
    local storageSize = 4 * atlas.w * atlas.h
    local info = {
        format          = "RGBA8",
        storageSize     = storageSize,
		width           = atlas.w,
		height          = atlas.h,
		depth           = 1,
		numLayers       = 1,
		numMips         = 1,
        bitsPerPixel    = 4,
        cubeMap         = false 
    }
    local config = {
        type            = "png",
        format          = "RGBA8",
        srgb            = true
    }
    local texture_content = {
        compress = {
            android = "ASTC6x6",
            ios = "ASTC6x6",
            windows = "BC3"
        },
        width  = atlas.w,
        height = atlas.h,
        colorspace = "sRGB",
        noresize = true,
        normalmap = false,
        path = file_vpath,
        sampler = {
            MAG = "LINEAR",
            MIN = "LINEAR",
            U = "WRAP",
            V = "WRAP"
        },
        type = "texture",
    }
    local texture_rpath = string.format("%s/%s.texture", atlas.rpath, atlas.name and atlas.name or "atlas")
    local texture_vpath = string.format("%s/%s.texture", atlas.vpath, atlas.name and atlas.name or "atlas")
    atlas.file_path, atlas.texture_vpath, atlas.info, atlas.config = file_rpath, texture_vpath, info, config
    local atlas_memory = bgfx.memory_buffer(storageSize)
    local content = image.encode_image(info, atlas_memory, config)
    local fa <close> = assert(io.open(file_rpath, "wb"))
	fa:write(content)
    local ft <close> = assert(io.open(texture_rpath, "wb"))
    ft:write(serialize.stringify(texture_content)) 
end

function iatlas.clip_sub_rects(atlas)
    local rects = {}
    for _, file in ipairs(atlas.files) do
        local tt = {}
        local path = file:string()
        local c = fastio.readall_f(path)
        tt.name = string.match(path, "%w+/(%w+_?%w+).png")
        tt.rpath = path
        tt.vpath = string.format("%s/%s.png", atlas.vpath, tt.name)
        tt.w, tt.h, tt.dx, tt.dy, tt.dw, tt.dh = image.png.cliprect(c)
        rects[#rects+1] = tt
    end
    atlas.rects = rects
end

function iatlas.pack_sub_rects(atlas, need_sort)
    
    local rect_sort = 
    function(a, b) 
        if a.dw * a.dh < b.dw * b.dh then
            return true
        end
        return false
    end

    local rects = atlas.rects

    if need_sort then table.sort(rects, rect_sort) end

    local i = 1
    local num_rects = #rects
    while i <= num_rects do
        local rect = rects[i]
        if atlas.x + rect.dw > atlas.w then
            atlas.x = 1
            atlas.y = atlas.bottom_y
        end
        if atlas.y + rect.dh > atlas.h then
            break
        end
        rect.x = atlas.x
        rect.y = atlas.y
        rect.was_packed = true
        atlas.x = atlas.x + rect.dw
        if atlas.y + rect.dh > atlas.bottom_y then
            atlas.bottom_y = atlas.y + rect.dh
        end
        i = i + 1
    end
    while i <= num_rects do
        rects[i].was_packed = nil
        i = i + 1
    end
end

function iatlas.generate_sub_atlas(atlas)
    local rects = atlas.rects
    for _, rect in ipairs(rects) do
        local texture_rpath = string.format("%s/%s.atlas", atlas.rpath, rect.name)
        local texture_content = {
            atlas = {
                rect = {
                    w = rect.w,
                    h = rect.h,
                    dx = rect.dx,
                    dy = rect.dy,
                    dw = rect.dw,
                    dh = rect.dh
                },
                path = atlas.texture_vpath
            }
        }
        local f <close> = assert(io.open(texture_rpath, "wb"))
        f:write(serialize.stringify(texture_content))  
    end
end

function iatlas.update_atlas_file(atlas)
    local file_path = atlas.file_path
    local _, atlas_memory = image.parse(fastio.readall_f(file_path), "true")
    for _, rect in ipairs(atlas.rects) do
        local _, rect_memory = image.parse(fastio.readall_f(rect.rpath), "true")
        if rect.was_packed then
            image.png.updateAtlas(atlas_memory, rect_memory, rect.x, rect.y, rect.dx, rect.dy, rect.dw, rect.dh, rect.w, atlas.w) 
        end
    end
    local content = image.encode_image(atlas.info, bgfx.memory_buffer(atlas_memory), atlas.config)
    local f <close> = assert(io.open(file_path, "w+b"))
    f:write(content)

end

function iatlas.set_atlas(atlas)

    iatlas.collect_sub_files(atlas)

    iatlas.generate_atlas_file(atlas)

    iatlas.clip_sub_rects(atlas)

    iatlas.pack_sub_rects(atlas, true)

    iatlas.generate_sub_atlas(atlas)

    iatlas.update_atlas_file(atlas)
end

return iatlas