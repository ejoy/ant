--luacheck: globals iup
local util = {}

local counter = 0
function util.get_new_entity_counter()
	return counter + 1
end

function util.get_cursor_pos()
	local cursorpos = iup.GetGlobal("CURSORPOS")
	return cursorpos:match("(%d+)x(%d+)")
end

function util.add_callbacks(ctrl, inst, funcs)
	for _, name in ipairs(funcs) do
		ctrl[name] = function (ih, ...)
			local cb = inst[name]
			if cb then
				cb(inst, ...)
			end
		end
	end
end

function util.regitster_iup(msgqueue, ctrl)	
	local ctrl_cb = {
		button = "mouse_click",
		motion = "mouse_move",
		resize = "resize",
		wheel = "mouse_wheel",
	}

	for iupname, msgname in pairs(ctrl_cb) do
		ctrl[iupname .. "_cb"] = function(_, ...)
			msgqueue:push(msgname, ...)
		end
	end

	ctrl.keypress_cb = function(_, key, press)		
		local fmt = "     %s%s%s%s "	-- 5 spaces + ALT CTRL SYS SHIFT + 1 space

		local syskey_states = string.format(fmt,
			iup.isAltXkey(key) and "A" or " ",
			iup.isCtrlXkey(key) and "C" or " ",
			iup.isSysXkey(key) and "Y" or " ",
			iup.isShiftXkey(key) and "S" or " ")
		assert(#syskey_states == 10)
		msgqueue:push("keyboard", key, press, syskey_states)
	end
end

return util
