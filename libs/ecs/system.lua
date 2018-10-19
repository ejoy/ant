local require = import and import(...) or require
local log = log and log(...) or print

-- load systems

local system = {}	-- module system

function system.singleton(sys, c)
	local s = {}
	for _,v in pairs(sys) do
		if v.singleton then
			for _, singleton_name in ipairs(v.singleton) do
				local singleton_typeobject = c[singleton_name]
				if not singleton_typeobject then
					error( singleton_name .. " is not defined")
				end
				if s[singleton_name] == nil then
					log("New singleton %s", singleton_name)
					s[singleton_name] = singleton_typeobject.new()
				end
			end
		end
	end
	return s
end

local function gen_proxy(sto, c, singletons)
	local inst = {}
	if sto.singleton then
		for _, singleton_name in ipairs(sto.singleton) do
			inst[singleton_name] = singletons[singleton_name]
			for method_name, f in pairs(c[singleton_name].method) do
				inst[method_name] = f
			end
		end
	end
	return inst
end

function system.proxy(sys, c, singletons)
	local p = {}
	for system_name, system_typeobject in pairs(sys) do
		p[system_name] = gen_proxy(system_typeobject, c, singletons)
	end
	return p
end

local function gen_methods(sto, c)
	local m = {}
	if sto.import then
		for _, cname in ipairs(sto.import) do
			for method_name, f in pairs(c[cname].method) do
				m[method_name] = f
			end
		end
	end
	return m
end

function system.component_methods(sys, c)
	local p = {}
	for system_name, system_typeobject in pairs(sys) do
		p[system_name] = gen_methods(system_typeobject, c)
	end
	return p
end

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

function system.init_list(sys)
	local depend_list = solve_depend(sys)
	local init_list = {}
	for _, sname in ipairs(depend_list) do
		local init = sys[sname].method.init
		if init then
			table.insert(init_list, { sname, init } )
		end
	end
	return init_list
end

function system.update_list(sys, order, obydp)
	local update_list = {}
	local norder = {}
	for sname in pairs(sys) do
		norder[sname] = true
	end
	if order then
		for _, sname in ipairs(order) do
			if sys[sname] then
				table.insert(update_list, sname)
				norder[sname] = nil
			end
		end
	end

	if obydp then
		local dp_list = solve_depend(sys)
		for _, n in ipairs(dp_list) do
			if norder[n] then
				table.insert(update_list, n)
				norder[n] = nil
			end
		end
	end

	local norder_list = {}
	for sname in pairs(norder) do
		table.insert(norder_list, sname)
	end
	table.sort(norder_list)
	table.move(norder_list, 1, #norder_list, #update_list+1,update_list)

	local ret = {}
	for _, sname in ipairs(update_list) do
		local update = sys[sname].method.update
		if update then
			table.insert(ret, { sname, update } )
		end
	end
	return ret
end

function system.notify_list(sys, proxy, methods)
	local notify = {}
	for sname, sobject in pairs(sys) do
		for cname, f in pairs(sobject.notify) do
			local functor = { sname, f, proxy[sname], methods[sname] }
			local list = notify[cname]
			if list == nil then
				notify[cname] = { functor }
			else
				table.insert(list, functor)
			end
		end
	end
	return notify
end

local switch_mt = {}; switch_mt.__index = switch_mt

function switch_mt:enable(name, enable)
	if enable ~= false then
		enable = nil
	end
	if self[name] ~= enable then
		self.__needupdate = true
		self[name] = enable
	end
end

function switch_mt:update()
	if self.__needupdate then
		local index = 1
		local all = self.__all
		local list = self.__list
		for i = 1, #all do
			local name = all[i][1]
			if self[name] ~= false then
				-- enable it
				list[index] = all[i]
				index = index + 1
			end
		end
		for i = index, #list do
			list[i] = nil
		end
		self.__needupdate = nil
	end
end

function system.list_switch(list)
	local all_list = {}
	for k,v in pairs(list) do
		all_list[k] = v
	end
	return setmetatable({
		__list = list,
		__all = all_list,
	} , switch_mt )
end

if TEST then
	system._solve_depend = solve_depend	-- for test
end

return system
