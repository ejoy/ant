local compile = require "material.compile"
local datalist = require "datalist"
local fastio = require "fastio"
local depends = require "depends"

local function readdatalist(filepath)
	return datalist.parse(fastio.readall_f(filepath), function(args)
		return args[2]
	end)
end

return function (lpath, vpath, output, setting)
    local mat = readdatalist(lpath)
    local depfiles = depends.new()
    depends.add_lpath(depfiles, lpath)
    compile(depfiles, mat, lpath, output, setting)
    return true, depfiles
end
