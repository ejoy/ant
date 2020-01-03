local system = {}

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end

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

local function solve_depend(res, step, pipeline)
	for _, v in ipairs(pipeline) do
		if type(v) == "string" then
			if step[v] == false then
				error(("pipeline has duplicate step `%s`"):format(v))
			elseif step[v] ~= nil then
				table_append(res, step[v])
				step[v] = false
			end
		elseif type(v) == "table" then
			solve_depend(res, step, v)
		end
	end
end

local function find_entry(pipeline, what)
	for _, v in ipairs(pipeline) do
		if type(v) == "table" then
			if v.name == what then
				return v
			end
			local res = find_entry(v, what)
			if res then
				return res
			end
		end
	end
end

function system.steps(sys, pipeline)
	local mark = {}
	local res = setmetatable({}, {__index = function(t,k)
		local obj = {}
		t[k] = obj
		mark[k] = true
		return obj
	end})
	for sys_name, s in sortpairs(sys) do
		for step_name, func in pairs(s.method) do
			table.insert(res[step_name], { sys_name, func })
		end
		if s.step and s.method.update then
			local step_name = s.step[#s.step]
			table.insert(res[step_name], { sys_name, s.method.update })
		end
	end
	setmetatable(res, nil)

	local function check(pl)
		for _, v in ipairs(pl) do
			if type(v) == "string" then
				mark[v] = nil
			elseif type(v) == "table" then
				check(v)
			end
		end
	end
	check(pipeline)
	mark["update"] = nil

	for name in pairs(mark) do
		error(("pipeline is missing step `%s`, which is defined in system `%s`"):format(name, res[name][1][1]))
	end
	return res
end

function system.lists(steps, pipeline, what)
	local subpipeline = find_entry(pipeline, what)
	if not subpipeline then
		return
	end
	local res = {}
	solve_depend(res, steps, subpipeline)
	return res
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

return system
