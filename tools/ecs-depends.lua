local config = {
    [[libs\render]],
    [[libs\serialize]],
    [[libs\editor\ecs]],
    [[libs\scene\filter_component.lua]],
    [[libs\scene\filter_system.lua]],
    [[libs\scene\cull_system.lua]],
    [[libs\scene\hierarchy\hierarchy.lua]],
    [[libs\inputmgr\message_system.lua]],
    [[libs\animation\animation.lua]],
    [[libs\timer\timer.lua]],
    [[libs\scene\terrain\terrain.lua]],
}

local exepath = package.cpath:sub(1, (package.cpath:find(';') or 0)-6)
local root = exepath .. [[..\]]

package.path  = root .. [[libs\?.lua]]
package.cpath = root .. [[clibs\?.dll]]

local function searchpath(name, path)
	--TODO
	local f = io.open(name)
	if f then
		f:close()
		return name
	end
	local err = ''
	name = string.gsub(name, '%.', '/')
	for c in string.gmatch(path, '[^;]+') do
		local filename = string.gsub(c, '%?', name)
		local f = io.open(filename)
		if f then
			f:close()
			return filename
		end
		err = err .. ("\n\tno file '%s'"):format(filename)
	end
	return nil, err
end

local function sortkpairs(t)
    local sort = {}
    for k, v in pairs(t) do
        sort[#sort+1] = {k, v}
    end
    table.sort(sort, function (a, b)
        return a[1] < b[1]
    end)
    local n = 1
    return function()
        local v = sort[n]
        if not v then
            return
        end
        n = n + 1
        return v[1], v[2]
    end
end

local function sortvpairs(t)
    local sort = {}
    for k, v in pairs(t) do
        sort[#sort+1] = {k, v}
    end
    table.sort(sort, function (a, b)
        return a[2] < b[2]
    end)
    local n = 1
    return function()
        local v = sort[n]
        if not v then
            return
        end
        n = n + 1
        return v[1], v[2]
    end
end

local fs = require 'cppfs'
local fs_util = require 'debugger.filesystem'
local typeclass = require 'ecs.typeclass'

root = fs_util.normalize_native(root)

local filetree = {
    branchname = "file",
    userid = {},
    marked = "YES",
}

local function checkfile(path)
    return pcall(function()
        local global = {
            require = function() end,
        }
        local reg = typeclass({}, function() end)
        local f = assert(io.open(path:string()))
        local code = f:read 'a'
        f:close()
        assert(load(code, '=(CHECK)', 't', global))(reg)
    end)
end

local function insert_filetree(t, split, path, ok)
    if #split == 1 then
        if ok then
            t[#t+1] = {
                leafname = split[1],
                userid = {path},
            }
        else
            t[#t+1] = {
                leafname = split[1],
                userid = {},
                color = "255 92 92"
            }
        end
        return
    end
    for _, dir in ipairs(t) do
        if type(dir) == 'table' and dir.branchname == split[#split] then
            split[#split] = nil
            if ok then
                dir.userid[#dir.userid+1] = path
            else
                dir.color = "255 92 92"
            end
            return insert_filetree(dir, split, path, ok)
        end
    end
    local dir = {
        branchname = split[#split],
        state = "COLLAPSED",
        userid = { },
    }
    if ok then
        dir.userid[1] = path
    else
        dir.color = "255 92 92"
    end
    split[#split] = nil
    t[#t+1] = dir
    return insert_filetree(dir, split, path, ok)
end

local function add_filetree(path)
    local subpath = fs.path(path:string():sub(#root+2))
    local split = {}
    while true do
        local name = subpath:filename():string()
        if name == '' then
            break
        end
        split[#split+1] = name
        subpath = subpath:parent_path()
    end
    for _, name in ipairs(split) do
        local ok, err = checkfile(path)
        if ok then
            filetree.userid[#filetree.userid+1] = path
        else
            print(err)
        end
        insert_filetree(filetree, split, path, ok)
    end
end

local function add_dirtree(dir)
    for file in dir:list_directory() do
        if fs.is_directory(file) then
            add_dirtree(file)
        elseif file:extension():string() == ".lua" then
            add_filetree(file)
        end
    end
end

for _, c in ipairs(config) do
    local path = fs.path(root .. '/' .. c)
    if fs.is_directory(path) then
        add_dirtree(path)
    else
        add_filetree(path)
    end
end

local cache = {}
local new_object

local function new_system(class, name, obj)
    if cache[name] then
        return cache[name]
    end
    local node = {
        branchname = name,
        state = "COLLAPSED",
        userid = obj.defined,
    }
    cache[name] = node
    if obj.depend then
        for _, n in sortvpairs(obj.depend) do
            node[#node+1] = new_object(class, n, "[depend]   ")
            if node[#node].color then
                node.color = node[#node].color
            end
        end
    end
    if obj.dependby then
        for _, n in sortvpairs(obj.dependby) do
            node[#node+1] = new_object(class, n, "[dependby] ")
            if node[#node].color then
                node.color = node[#node].color
            end
        end
    end
    if obj.singleton then
        for _, n in sortvpairs(obj.singleton) do
            node[#node+1] = new_object(class, n, "[singleton] ")
            if node[#node].color then
                node.color = node[#node].color
            end
        end
    end
    return node
end

local function new_component(class, name, obj)
    return {
        leafname = name,
        userid = obj.defined,
    }
end

local function new_unknown(class, name)
    return {
        leafname = name,
        userid = 'Error!',
        color = "255 92 92",
    }
end

function new_object(class, name, prefix)
    if class.system[name] then
        return new_system(class, name, class.system[name])
    elseif class.component[name] then
        return new_component(class, name, class.component[name])
    else
        return new_unknown(class, name)
    end
end

local label = iup.label {SIZE="400x10", PADDING="8x2"}
local tree1 = iup.tree{ SIZE="200x300", MARKMODE="MULTIPLE" }
local tree2 = iup.tree{ SIZE="400x290" }
local dlg = iup.dialog{ iup.hbox{tree1, iup.vbox{label, tree2}}, SIZE="600x300", TITLE="ecs depends"}
local ids = {}

local function select_filetree(ids)
    cache = {}

    local module_path = 'libs/?.lua;libs/?/?.lua'
	local mods = {}
	local function import(name)
		local path, err = searchpath(name, module_path)
		if not path then
			error(("module '%s' not found:%s"):format(name, err))
        end
        path = fs_util.normalize_native(path)
		if mods[path] then
			return
		end
		mods[#mods+1] = path
		mods[path] = true
	end
    
    local world = {}
    local reg, class = typeclass(world, import)
    local global = {
        require = function() end,
    }

    for _, id in ipairs(ids) do
        local userid = tree1:GetUserId(id)
        if userid then
            for _, file in ipairs(userid) do
                import(file:string())
            end
        end
    end

	while #mods > 0 do
		local path = mods[#mods]
		mods[#mods] = nil

        local f = assert(io.open(path))
        local code = f:read 'a'
        f:close()
        assert(load(code, path:sub(#root+2), 't', global))(reg)
    end

    local ecstree = {
        branchname = "ecs"
    }
    for name, obj in sortkpairs(class.system) do
        ecstree[#ecstree+1] = new_system(class, name, obj)
    end
    for name, obj in sortkpairs(class.component) do
        ecstree[#ecstree+1] = new_component(class, name, obj)
    end
    tree2.DELNODE0 = 'CHILDREN'
    iup.TreeAddNodes(tree2, ecstree)
end

dlg:map()
iup.TreeAddNodes(tree1, filetree)
ids = {0}
select_filetree(ids)
dlg:show()

function tree1:selection_cb(id, status)
    if status == 1 then
        for i, v in ipairs(ids) do
            if v == id then
                return
            end
        end
        table.insert(ids, id)
        select_filetree(ids)
    elseif status == 0 then
        for i, v in ipairs(ids) do
            if v == id then
                table.remove(ids, i)
                break
            end
        end
        select_filetree(ids)
    end
end

function tree2:selection_cb(id, status)
    if status == 1 then
        label.TITLE = self:GetUserId(id)
    elseif status == 0 then
        label.TITLE = ''
    end
end

if iup.MainLoopLevel() == 0 then
    iup.MainLoop()
    iup.Close()
end
