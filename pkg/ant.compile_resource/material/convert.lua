local compile = require "material.compile"
local datalist = require "datalist"
local fastio = require "fastio"
local parallel_task = require "parallel_task"

local function readdatalist(filepath)
	return datalist.parse(fastio.readall(filepath), function(args)
		return args[2]
	end)
end

return function (input, output, setting)
    local mat = readdatalist(input)
    local depfiles = {}
    local tasks = parallel_task.new()
    compile(tasks, depfiles, mat, input, output, setting)
    assert(#tasks > 0)
    parallel_task.wait(tasks)
    return true, depfiles
end
