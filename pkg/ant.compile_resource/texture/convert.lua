local compile = require "texture.compile"
local datalist = require "datalist"
local fastio = require "fastio"
local depends = require "depends"
local lfs = require "bee.filesystem"
local fs = require "filesystem"

local function readdatalist(filepath)
	return datalist.parse(fastio.readall(filepath), function(args)
		return args[2]
	end)
end

local function absolute_path(base, path)
    if path:sub(1,1) == "/" then
        return fs.path(path):localpath()
    end
    return lfs.absolute(lfs.path(base):parent_path() / (path:match "^%./(.+)$" or path))
end

return function (input, output, setting)
	local param = readdatalist(input)
	if param.path then
		param.path = absolute_path(input, param.path)
	end
	local ok, err = compile(param, output, setting)
	if not ok then
		return nil, err
	end
	local depfiles = {}
	if param.path then
		depends.add(depfiles, param.path)
	end
	return ok, depfiles
end
