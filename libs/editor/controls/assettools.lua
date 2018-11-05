--luacheck: globals iup
local require = import and import(...) or require
local tree = require "tree"

local assettool = {}; assettool.__index = assettool

local atmt = {}; atmt.__index = atmt
function assettool.new()
	local t = {}
	t.window = tree.new()
	return setmetatable({}, atmt)
end

return assettool