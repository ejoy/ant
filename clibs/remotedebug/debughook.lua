local rdebug = require "remotedebug"
assert(rdebug.status == "debugger")

local hook = {}

local probe_list = {}

function hook.probe(src, line, func)
	local list = probe_list[src]
	if list then
		list[line] = func
		if not func then
			if not next(list) then
				probe_list[src] = nil
				if not next(probe_list) then
					-- no more probe
					rdebug.hookmask()
				end
				return
			end
		end
	elseif func then
		probe_list[src] = { [line] = func }
	else
		return
	end
	rdebug.hookmask "crl"
end

local cr = { ["call"] = true, ["tail call"] = true, ["return"] = true }
local info = {}
local bp_list

function hook.hook(event, currentline)
	if cr[event] then
		bp_list = nil
		rdebug.hookmask "crl"
		return false
	end
	local source
	if bp_list == nil then
		-- first line after call/return
		local s = rdebug.getinfo(1,info)
		source = s.source
		local linedefined = s.linedefined
		local lastlinedefined = s.lastlinedefined
		bp_list = probe_list[source]
		if not bp_list then
			-- turn off line hook
			rdebug.hookmask "cr"
			return false
		else
			local capture = false
			for line, func in pairs(bp_list) do
				if line >= linedefined and line <= lastlinedefined then
					local activeline = rdebug.activeline(line)
					if activeline == nil then
						-- todo: print(line, "disable")
						bp_list[line] = nil
					else
						if activeline ~= line then
							bp_list[line] = nil
							bp_list[activeline] = func
						end
						capture = true
					end
				end
			end
			if not capture then
				-- turn off line hook
				rdebug.hookmask "cr"
				return false
			end
		end
	end

	-- trigger probe
	local f = bp_list[currentline]
	if f then
		f(source, currentline)
		return true
	end
	return false
end

return hook
