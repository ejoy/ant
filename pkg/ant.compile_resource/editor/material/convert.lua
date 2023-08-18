local compile = require "editor.material.compile"
local depends = require "editor.depends"
local datalist = require "datalist"
local fastio = require "fastio"
local parallel_task = require "editor.parallel_task"

local function readdatalist(filepath)
	return datalist.parse(fastio.readall(filepath), function(args)
		return args[2]
	end)
end

return function(input, output, setting, localpath)
    local mat = readdatalist(input)
    local depfiles = {}
    local tasks = parallel_task.new()
    compile(tasks, depfiles, mat, input, output, setting, localpath)
    assert(#tasks > 0)
    parallel_task.wait(tasks)
    depends.make_depend_graphic_settings(depfiles, localpath)
    return true, depfiles
end
