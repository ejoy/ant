local compile = require "material.compile"
local datalist = require "datalist"
local fastio = require "fastio"
local depends = require "depends"

local function readdatalist(filepath)
	return datalist.parse(fastio.readall_f(filepath), function(args)
		return args[2]
	end)
end

return function (input, output, setting)
    local mat = readdatalist(input)
    local depfiles = depends.new()
    depends.add_lpath(depfiles, input)
    compile(depfiles, mat, input, output, setting)
    return true, depfiles
end
