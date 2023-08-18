local compile = require "editor.texture.compile"
local datalist = require "datalist"
local fastio = require "fastio"
local depends = require "editor.depends"

local function readdatalist(filepath)
	return datalist.parse(fastio.readall(filepath), function(args)
		return args[2]
	end)
end

return function (input, output, setting, localpath)
	local param = readdatalist(input)
	local ok, err = compile(param, output, setting, localpath)
	if not ok then
		return nil, err
	end
	local depfiles = {}
	if param.path then
		depends.add(depfiles, param.local_texpath)
	end
	return ok, depfiles
end
