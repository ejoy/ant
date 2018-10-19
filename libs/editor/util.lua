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


local ctrl_cb = {
	"button",
	"motion",
	"keypress",
	"resize",
	"wheel"
}

function util.regitster_iup(msgqueue, ctrl)
	for _, cb in ipairs(ctrl_cb) do
		ctrl[cb .. "_cb"] = function(_, ...)
			msgqueue:push(cb, ...)
		end
	end
end

return util