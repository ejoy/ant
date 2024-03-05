local M = {}

function M.start(arg)
	dofile "/engine/ltask.lua" {
		bootstrap = { "main|startup", table.unpack(arg) },
		exclusive = { "timer" },
	}
end

return M