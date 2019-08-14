-- load systems
local solve_depend = require "solve_depend"
local system = {}	-- module system

local function get_singleton(sys, c)
	local s = {}
	for _,v in pairs(sys) do
		if v.singleton then
			for _, singleton_name in ipairs(v.singleton) do
				local singleton_typeobject = c[singleton_name]
				if not singleton_typeobject then
					error( singleton_name .. " is not defined")
				end
				if s[singleton_name] == nil then
					log.info("New singleton", singleton_name)
					local init = singleton_typeobject.method.init
					s[singleton_name] = init and init() or {}
				end
			end
		end
	end
	return s
end

local function gen_proxy(sto, singletons)
	local inst = {}
	if sto.singleton then
		for _, singleton_name in ipairs(sto.singleton) do
			inst[singleton_name] = singletons[singleton_name]
		end
	end
	return inst
end

function system.proxy(sys, c)
	local singletons = get_singleton(sys, c)
	local p = {}
	for system_name, system_typeobject in pairs(sys) do
		p[system_name] = gen_proxy(system_typeobject, singletons)
	end
	return p
end

function system.lists(sys)
	local r = setmetatable( {} , { __index = function(t,k)
			local obj = {}
			t[k] = obj
			return obj
		end } )
	local depend_list = solve_depend(sys)
	for _, sname in ipairs(depend_list) do
		for what, func in pairs(sys[sname].method) do
			table.insert(r[what], { sname, func })
		end
	end
	setmetatable(r, nil)
	return r
end

function system.order_list(list, order)
	local update_list = {}
	local norder = {}
	for _, sname in ipairs(list) do
		norder[sname] = true
	end
	for _, sname in ipairs(order) do
		if norder[sname] then
			table.insert(update_list, sname)
			norder[sname] = nil
		end
	end

	for _, n in ipairs(list) do
		if norder[n] then
			table.insert(update_list, n)
			norder[n] = nil
		end
	end

	local norder_list = {}
	for sname in pairs(norder) do
		table.insert(norder_list, sname)
	end
	table.sort(norder_list)
	table.move(norder_list, 1, #norder_list, #update_list+1,update_list)

	return update_list
end

function system.notify_list(sys, proxy)
	local notify = {}
	for sname, sobject in pairs(sys) do
		for cname, f in pairs(sobject.notify) do
			local functor = { sname, f, proxy[sname] }
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
