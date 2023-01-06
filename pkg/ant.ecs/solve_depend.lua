local function get_sort_keys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end

	table.sort(keys)
	return keys
end

local function solve_depend(graph)
	-- topological sorting
	local ret = {}	-- sorted result
	local S = {}	-- nodes with no depend
	local G = {}	-- nodes with depend
	local function insert_result(k)
		table.insert(ret, k)
		S[k] = true
	end

	local graphkeys = get_sort_keys(graph)

	-- combine depend and dependby
	local dp_table = {}
	--for k,v in pairs(graph) do
	for _, k in ipairs(graphkeys) do
		local v = graph[k]
		local function get_dp(t, k)
			local dp = t[k]
			if dp == nil then
				t[k] = {}
				dp = t[k]
			end
			return dp
		end

		local depend = v.depend
		if depend then
			assert(type(depend) == "table", k)
			local dp = get_dp(dp_table, k)
			table.move(depend, 1, #depend, #dp+1, dp)
		end

		local dependby = v.dependby
		if dependby then
			for _, n in ipairs(dependby) do
				assert(type(dependby) == "table", k)
				local dpby = get_dp(dp_table, n)
				table.insert(dpby, k)
			end
		end
	end

	--for k,v in pairs(graph) do
	for _, k in ipairs(graphkeys) do
		-- local depend = v.depend
		local depend = dp_table[k]
		if depend then
			assert(type(depend) == "table", k)
			local depend_keys = {}
			for _, key in ipairs(depend) do
				if not S[key] then
					if graph[key] == nil then
						error(key .. " not exist")
					end
					depend_keys[key] = true
				end
			end
			if next(depend_keys) then
				G[k] = depend_keys
			else
				insert_result(k)
			end
		else
			insert_result(k)
		end
	end
	while next(G) do
		local reduce
		local Gkeys = get_sort_keys(G)

		--for name,depends in pairs(G) do
		for _, name in ipairs(Gkeys) do
			local depends = G[name]
			for depend in pairs(depends) do
				if S[depend] then
					depends[depend] = nil
				end
			end
			if next(depends) == nil then
				insert_result(name)
				G[name] = nil
				reduce = true
			end
		end
		if not reduce then
			local tmp = { "Circular dependency : "}
			for k, v in pairs(G) do
				local line = { k .. " :" }
				for depend in pairs(v) do
					table.insert(line, depend)
				end
				table.insert(tmp, table.concat(line, " "))
			end
			error(table.concat(tmp, "\n"))
		end
	end
	return ret
end

return solve_depend
