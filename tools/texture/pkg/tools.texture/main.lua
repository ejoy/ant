
local lfs = require "bee.filesystem"
local fs = require "filesystem"
local image = require "image"

local options = {}; 
do
    local function faces_refine(v)
        local vv = {}
        for p in v:gmatch "[^|]+" do
            vv[#vv+1] = p
        end
        return vv
    end

    local function default_read(v) return v end
    local function cvt2int(v) return math.tointeger(v) end
    local function cvt2size(v) local w, h = v:match "(%d+)[Xx](%d+)"; return {math.tointeger(w), math.tointeger(h)} end
    local options_keys = {
        {"--faces",            "-f", faces_refine},
        {"--cubemap2equirect", "-c", default_read},
        {"--equirect2cubemap", "-e", default_read},
        {"--facesize",         "-s", cvt2int},
        {"--size",             "-S", cvt2size},
        {"--outfile",          "-o", default_read},
    }
    for i=1, #arg do
        local a = arg[i]

        local function read_pairs(a, cfg)
            for i=1, 2 do
                local k = cfg[i]
                local v = a:match(k .. "=([^=]+)")
                if v then
                    local longname = cfg[1]
                    local op = cfg[3]
                    return longname:sub(3), op(v)
                end
            end
        end

        for _, key in ipairs(options_keys)do
            local k, v = read_pairs(a, key)
            if k and v then
                options[k] = v
            end
        end
    end
end

local function read_file(p)
    local f <close> = assert(io.open(p:localpath():string(), "rb"))
    return f:read "a"
end

local function write_file(p, c)
    local f <close> = assert(io.open(p:string(), "wb"))
    f:write(c)
end

local outfile = lfs.path(options.outfile)
if not outfile then
    error "output file should define"
end

local function which_file_format(f)
    local ext = f:extension()
    assert(ext:string():sub(1, 1) == '.')
    return ext:string():sub(2):upper()
end

local fileformat = which_file_format(outfile)

if options.faces then
    if #options.faces ~= 6 then
        error "need 6 texture for generate cubemap"
    end
    local faces_content = {}
    for idx, f in ipairs(options.faces) do
        faces_content[idx] = read_file(fs.path(f))
    end

    local cubemap_content = image.pack2cubemap(faces_content, false, fileformat)

    write_file(outfile, cubemap_content)
elseif options.cubemap2equirect then
    local cubemap_content = read_file(lfs.path(options.cubemap2equirect))
    local s = options.size
    local w, h = 2, 2
    if s then
        w, h = s[1], s[2]
    end
    local equirectangular = image.cubemap2equirectangular(cubemap_content, fileformat, w, h)
    write_file(outfile, equirectangular)
elseif options.equirect2cubemap then
    local equirectangular = read_file(lfs.path(options.equirect2cubemap))
    if outfile:extension():string():lower() ~= ".ktx" then
        error "cubemap file output file should be ktx format"
    end

    local cm = image.equirectangular2cubemap(equirectangular, options.facesize)
    write_file(outfile, cm)
end