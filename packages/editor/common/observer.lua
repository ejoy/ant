local observers = {}; observers.__index = observers

function observers:find(which, name)
	local w = self.whichtypes[which]
	if w then
		for idx, ob in ipairs(w) do
			if ob.name == name then
				return idx
			end
		end
	end
end

local function check_add(inst, which)
	local w = inst.whichtypes[which]
	if w == nil then
		w = {}
		inst.whichtypes[which] = w
	end
	return w
end

function observers:add(which, name, ob)
	local w = check_add(self, which)
	assert(self:find(which, name) == nil)

	table.insert(w, {name, cb=ob})
end

function observers:remove(which, name)
	local idx = self:find(which, name)
	if idx then
		local w = self.whichtypes[which]
		table.remove(w, idx)
	end
end

function observers:notify(which, ...)
	local w = self.whichtypes[which]
	if w then
		for _, ob in ipairs(w) do
			ob.cb(...)
		end
	end

end

function observers.new()
	return setmetatable({whichtypes={}}, observers)
end

return observers