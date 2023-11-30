local compile = require "material.compile"
local datalist = require "datalist"
local fastio = require "fastio"
local parallel_task = require "parallel_task"
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
    local tasks = parallel_task.new()
    local post_tasks = parallel_task.new()
    compile(tasks, post_tasks, depfiles, mat, input, output, setting)
    assert(#tasks > 0)
    parallel_task.wait(tasks)
    parallel_task.wait(post_tasks)
    return true, depfiles
end
