local M = {}

function M.start(arg)
	dofile "/engine/ltask.lua" {
		bootstrap = {
			["ant.ltask|logger"] = {},
			["main|startup"] = {
				args = arg,
				unique = false,
			}
		}
	}
end

return M