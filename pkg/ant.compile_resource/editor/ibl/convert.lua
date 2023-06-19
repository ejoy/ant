local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local datalist  = require "datalist"
local image     = require "image"
local math3d    = require "math3d"
local ltask     = require "ltask"

local depends = require "editor.depends"

local setting   = import_package "ant.settings".setting
local irradianceSH_bandnum<const> = setting:get "graphic/ibl/irradiance_bandnum"

local texture_compile = require "editor.texture.compile"

local shpkg     = import_package "ant.sh"
local SH        = shpkg.sh
local texutil   = shpkg.texture

local function readfile(filename)
	local f <close> = assert(lfs.open(filename, "rb"))
	return f:read "a"
end

local function writefile(filename, c)
    local f <close> = lfs.open(filename, "wb")
    f:write(c)
end

local function readdatalist(filepath)
	return datalist.parse(readfile(filepath), function(args)
		return args[2]
	end)
end

local compress_SH; do
    local P<const> = {
        [2] = function (Eml)
            local m = math3d.transpose(math3d.matrix(Eml[1], Eml[2], Eml[3], Eml[4]))
            local c1, c2, c3 = math3d.index(m, 1, 2, 3)
            return {c1, c2, c3}
        end,
        [3] = function (Eml)
            local m1 = math3d.transpose(math3d.matrix(Eml[2], Eml[3], Eml[4], Eml[5]))
            local m2 = math3d.transpose(math3d.matrix(Eml[6], Eml[7], Eml[8], Eml[9]))
            local c1, c2, c3 = math3d.index(m1, 1, 2, 3)
            local c4, c5, c6 = math3d.index(m2, 1, 2, 3)
            return {Eml[1], c1, c2, c3, c4, c5, c6}
        end
    }

    compress_SH = P[irradianceSH_bandnum]
end

local function build_Eml(cm)
    local _, begin = ltask.now()
    print("start build irradiance SH, bandnum:", irradianceSH_bandnum)
    local Eml = SH.calc_Eml(cm, irradianceSH_bandnum)
    local _, now = ltask.now()
    print("finish build irradiance SH, time used:", now - begin)
    return Eml
end

local function serialize_results(Eml, output)
    local s = {}
    for _, e in ipairs(Eml) do
        s[#s+1] = math3d.serialize(e)
    end

    writefile(output / "main.bin", table.concat(s))
end

return function(input, output)
    local sh_desc = readdatalist(input)
    local texpath = fs.path(sh_desc.path):localpath()
    local tex_desc = readdatalist(texpath)

    local tex_outputpath = output / "image"

    local ok, err = texture_compile(tex_desc, tex_outputpath, function (path)
        if path:sub(1,1) == "/" then
            return fs.path(path):localpath()
        end
        return fs.absolute(output:parent_path() / (path:match "^%./(.+)$" or path))
    end)

    if not ok or err then
        error(("irradiance SH need texture file:%s, but it can not compile, error:%s"):format(texpath:string(), err))
    end

    local c = readfile(tex_outputpath / "main.bin")
    local nomip<const> = true
    local info, content = image.parse(c, true, "RGBA32F", nomip)
    assert(info.bitsPerPixel // 8 == 16)
    local cm = texutil.create_cubemap{w=info.width, h=info.height, texelsize=16, data=content}
    local Eml = compress_SH(build_Eml(cm))

    serialize_results(Eml, output)

    local deps = {}
    depends.add(deps, texpath:string())
    return true, deps
end