local util = {}; util.__index = util
local subprocess = require "subprocess"

function util.to_cmdline(commands)
    local s = ""
    for _, v in ipairs(commands) do
        if type(v) == "table" then
            for _, vv in ipairs(v) do
                s = s .. tostring(vv) .. " "
            end
        else
            s = s .. tostring(v) .. " "
        end
    end

    return s
end

local function def_check_msg(msg)
    return true, msg
end

function util.spawn_process(commands, checkmsg, notwait)
    checkmsg = checkmsg or def_check_msg
    local prog = subprocess.spawn(commands)
	print(util.to_cmdline(commands))

	if prog then
		local function wait_process()
			local stds = {
				{fd=prog.stdout, info="[stdout info]:"},
				{fd=prog.stderr, info="[stderr info]:"}
			}
	
			local success, msg = true, ""
			while #stds > 0 do
				for idx, std in ipairs(stds) do
					local fd = std.fd
					local num = subprocess.peek(fd)
					if num == nil then
						local s, m = checkmsg(std.info)
						success = success and s
						msg = msg .. "\n\n" .. m
						table.remove(stds, idx)
						break
					end
	
					if num ~= 0 then
						std.info = std.info .. fd:read(num)
					end
				end
			end

			local errcode = prog:wait()
			if errcode == 0 then
				return success, msg
			end
			return false, msg .. string.format("\nsubprocess failed, error code:%x", errcode)
		end
		
		if notwait then
			return {prog = prog, wait = wait_process}
		else
			return wait_process()
		end
    end
    
    return false, "Create process failed."
end

return util