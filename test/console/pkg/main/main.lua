local M = {}

function M.start(arg)
	dofile "/engine/ltask.lua" {
		bootstrap = {
			["main|startup"] = {
				args = arg,
				unique = false,
			}
		}
	}
end

return M