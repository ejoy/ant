local seri = {}

function seri.load(filename)
	local data = {}
	local f, err = loadfile(filename, "t", data)
	if not f then
		return nil, err
	end
	local ok, err = pcall(f)
	if not ok then
		return nil, err
	end
	return data
end

function seri.serialize(v)
	local dup = {}
	local function seri_value(v)
		local function seri_table(t)
			local st = { "{ " }
			local num_keys = {}
			for k,v in ipairs(t) do
				table.insert(st, seri_value(v) .. ",")
				num_keys[k] = true
			end
			for k,v in pairs(t) do
				if not num_keys[k] then
					local value = seri_value(v)
					local tkey = type(k)
					if tkey == "number" then
						table.insert(st, string.format("[%I] = %s,", k, value))
					elseif tkey == "string" then
						if k:match "[_%a][_%w]*" == k then
							table.insert(st, string.format("%s = %s,", k, value))
						else
							table.insert(st, string.format("[%q] = %s,", k, value))
						end
					else
						error("Unsupport key type " .. tostring(k))
					end
				end
			end
			table.insert(st, "}")
			return table.concat(st)
		end
		if type(v) == "table" then
			--assert(dup[v] == nil)
			dup[v] = true
			return seri_table(v)
		else
			return string.format("%q",v)
		end
	end
	return seri_value(v)
end

function seri.save(filename, data)
	assert(type(data) == "table")
	local keys = {}
	for k in pairs(data) do
		assert(type(k) == "string" and k:match "[_%a][_%w]*" == k)
		table.insert(keys, k)
	end
	table.sort(keys)
	local f = assert(io.open(filename, "wb"))
	for _, key in ipairs(keys) do
		local value = seri.serialize(data[key])
		f:write(string.format("%s = %s\n", key, value))
	end
	f:close()
end

function seri.save_entity(w, eid, ms)
	local e = assert(w[eid])
    local e_tree = {}

    local arg = {world=w, math_stack = ms, eid = eid}

	for cn, cv in pairs(e) do
        local save_comp = assert(w._component_type[cn].save)        
        arg.comp = cn
        local s = save_comp(cv, arg)
        e_tree[cn] = s
    end
    
    return e_tree
end

function seri.load_entity(w, tree, ms, eid)
	if eid == nil then
		eid = w:new_entity()
	end

	local entity = w[eid]
	local args = {world = w, math_stack = ms, eid = eid}

	for k, v in pairs(tree) do
		local load_comp = assert(w._component_type[k].load)
		w:add_component(eid, k)
		args.comp = k
		load_comp(entity[k], v, args)
	end

	return eid
end
	

return seri
