local log = log and log(...) or print
local menubar = {}; menubar.__index = menubar



--[[
local sub_item = iup.submenu({
    iup.menu({
        iup.item({title="sub1_item"})
    });
    title="sub1"
})
local sep = iup.separator({})
local item = iup.item({title="item1"})
local test_menu = menubar.new({})
--test add
test_menu:add_items({sub_item,sep,item},{"Aaaaa","Bbbbb"})
--test remove
test_menu:remove_item(sub_item)
test_menu:remove_item({sep,item})
--test get
print( test_menu:get_item("Aaaaa","Bbbbb","sub1","sub1_item") )
]]


local CLASS_ITEM = "item"
local CLASS_MENU = "menu"
local CLASS_SUBMENU = "submenu"
local CLASS_SEPARATOR = "separator"

local SORT_ATTR = "_SORT_INDEX"

--return brother_item:item / sep / submenu / nil
local function find_next_brother(menu,sort_index)
    if not sort_index then
        return nil
    else
        local childnum = iup.GetChildCount(menu)
        --to do:use binary search
        for i = 0,childnum - 1 do
            local child = iup.GetChild(menu,i)
            local a = type(child[SORT_ATTR])
            local b = type(sort_index)
            if not child[SORT_ATTR] or sort_index <=tonumber(child[SORT_ATTR]) then
                return child
            end
        end
    end
end

--item_list:{ { iupsubmenu / iupitem / separator,... }, }
--parent_path_tbl: {"File","Recent Files",...} or nil( <=> root) must point to a menu or submenu
--sort_index:controll position,can be nil(add to end)
--return true if success,false if fail()
function menubar:add_items(item_list,parent_path_tbl,sort_index)

    local menu = self:_force_get_menu(parent_path_tbl or {})
    local next_brother = find_next_brother(menu,sort_index)
    if menu then
        for i,item in ipairs(item_list) do
            local item_class = iup.GetClassName(item)
            assert( (item_class == CLASS_SUBMENU) 
                or (item_class == CLASS_ITEM)
                or (item_class == CLASS_SEPARATOR),
                "child must be submenu/item/separator")
            if not next_brother then
                menu:append(item)
            else
                menu:insert(next_brother,item)
            end
            item[SORT_ATTR] = sort_index
            iup.Map(item)
        end
        return true
    else
        return false
    end
end

function menubar:add_item(item,parent_path_tbl,sort_index)
    return self:add_items({item},parent_path_tbl)
end

function menubar:remove_items(childs)
    for i,item in ipairs(childs) do
        iup.Detach(item)
    end
end

--child: item or submenu
--return true if success
function menubar:remove_item(child)
    iup.Detach(child)
end

--return nil if iupitem occur in the path(iupitem can't be parent)
function menubar:_force_get_menu(path_tbl)
    local target = self._root
    for i,name in ipairs(path_tbl) do
        local count = iup.GetChildCount(target)
        local found = nil
        for j = 0,count-1 do
            local sub = iup.GetChild(target,j)
            if sub["TITLE"] == name then
                if iup.GetClassName(sub) == CLASS_SUBMENU then
                    if not iup.GetChild(sub,0) then
                        local new_menu = iup.menu({})
                        sub:append(new_menu)
                        iup.Map(new_menu)
                    end
                    found = iup.GetChild(sub,0)
                    break
                else
                    return nil
                end
            end
        end
        if found then
            target = found
        else
            local sub = iup.submenu { iup.menu({}), title=name }
            target:append(sub)
            iup.Map(sub)
            target = iup.GetChild(sub,0)
        end
    end
    return target
end


--return nil / submenu / item /separator
function menubar:get_item(path_tbl)
    local function find_child(parent,name)
        local count = iup.GetChildCount(parent)
        local found = nil
        for j = 0,count-1 do
            local sub = iup.GetChild(parent,j)
            if sub["TITLE"] == name then
                return sub,iup.GetClassName(sub)
            end
        end
    end
    local cur_target = self._root
    local index = 0
    while index < #path_tbl do
        index = index + 1
        local name = path_tbl[index]
        assert(name and (#name > 0))
        local child,class = find_child(cur_target,name)
        if child then
            if (index < #path_tbl) and class == CLASS_SUBMENU then
                cur_target = iup.GetChild(child,0)
            elseif index == #path_tbl then
                return child
            else
                return nil
            end
        else
            return nil
        end

    end
    return cur_target
end

function menubar:get_view()
    return self._root
end


local function create_menu(config)
    local ins = {}
    ins._root = iup.menu(config or {})
    print_a(config)
    ins = setmetatable(ins, menubar)
    return ins
end

function menubar.new(config)
    ins = create_menu(config)
    return ins
end


return menubar