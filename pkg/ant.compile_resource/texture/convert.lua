local compile = require "texture.compile"
local datalist = require "datalist"
local fastio = require "fastio"
local depends = require "depends"
local lfs = require "bee.filesystem"

local function readdatalist(filepath)
	return datalist.parse(fastio.readall_f(filepath), function(args)
		return args[2]
	end)
end

local function absolute_path(setting, base, path)
    if path:sub(1,1) == "/" then
        return lfs.path(setting.vfs.realpath(path))
    end
    return lfs.absolute(lfs.path(base):parent_path() / (path:match "^%./(.+)$" or path))
end

return function (lpath, vpath, output, setting)
	local param = readdatalist(lpath)
	if param.path then
		param.path = absolute_path(setting, lpath, param.path)
	end
	local depfiles = depends.new()
    depends.add_lpath(depfiles, lpath)
	local ok, err = compile(param, output, setting, depfiles)
	if not ok then
		return nil, err
	end
	if param.path then
		depends.add_lpath(depfiles, param.path)
	end
	return ok, depfiles
end
