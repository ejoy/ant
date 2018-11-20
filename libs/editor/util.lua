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

local iup_keymap = {}
for k,v in pairs(iup) do
	if type(k) == "string" and type(v) == "number" and k:sub(1,2) == "K_" then
		iup_keymap[v] = k:sub(3)
	end
end

function util.regitster_iup(msgqueue, ctrl)	
	local ctrl_cb = {
		"button",
		"motion",		
		"resize",
		"wheel"
	}

	for _, name in ipairs(ctrl_cb) do
		ctrl[name .. "_cb"] = function(_, ...)
			msgqueue:push(name, ...)
		end
	end

	local function translate_key(key)
		local nkey = iup.XkeyBase(key)
		
		if 0 <= nkey and nkey < 256 then
			return string.char(nkey)
		end

		return iup_keymap[nkey]
	end

	ctrl.keypress_cb = function(_, key, press)
		local ch = translate_key(key)
		local syskey_states = string.format("%s%s%s", 
			iup.isCtrlXkey(key) and "c" or "_",
			iup.isAltXkey(key) and "a" or "_",
			iup.isShiftXkey(key) and "s" or "_")
		msgqueue:push("keypress", ch, press ~= 0, syskey_states)
	end
end

return util
