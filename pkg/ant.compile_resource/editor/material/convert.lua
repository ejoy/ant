local compile = require "editor.material.compile"
local depends = require "editor.depends"
local datalist = require "datalist"
local parallel_task = require "editor.parallel_task"

local function readfile(filename)
	local f <close> = assert(io.open(filename, "r"))
	return f:read "a"
end

local function readdatalist(filepath)
	return datalist.parse(readfile(filepath), function(args)
		return args[2]
	end)
end

return function(input, output, setting, localpath)
    local mat = readdatalist(input)
    local depfiles = {}
    local tasks = parallel_task.new()
    compile(tasks, depfiles, mat, input, output, setting, localpath)
    parallel_task.wait(tasks)
    depends.add(depfiles, localpath "/pkg/ant.settings/default/settings")
    depends.add(depfiles, localpath "/settings")
    return true, depfiles
end
