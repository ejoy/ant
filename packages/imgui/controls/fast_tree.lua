--[[

]]
local imgui = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local class     = require "common.class"

-- Commond Struct
-- TreeNode
-- {
--     key:
--     data:{
--          
--     },
--     children:[node,...],
--     parent:TreeNode or nil
--     __cache:{
--        linear_index:%d, start from 0
--        indent:%d,
--     }
--     --
-- }

local FoldTree = class("FoldTree_ForFastImTree")
function FoldTree:_init(root_node,open_state_dic)
    self.root_node = root_node
    self.open_state_dic = open_state_dic
    self.__cache = {}
    self:build()
end

--desc:fill open_size, open_size means how many children is opened,include itself
function FoldTree:build()
    local open_state_dic = self.open_state_dic
    local function fill_node_r(node,indent)
        local open_size = 0
        if node.children then
            for _,child in ipairs(node.children) do
                child.parent = node
                open_size = open_size + fill_node_r(child,indent + 1)
            end
        end
        if open_state_dic[node.key] ~= false then
            open_size = open_size + 1
        else
            open_size = 1
        end
        node.__cache = node.__cache or {}
        node.__cache.open_size = open_size
        node.__cache.indent = indent
        return open_size
    end
    fill_node_r(self.root_node,0)
    self.__cache = {}
end

--desc:partition build for specific node,and bubble to root_node
function FoldTree:refresh_node(node)
    local open_state_dic = self.open_state_dic
    local function update_node_r(node)
        if open_state_dic[node.key] ~= false then --opened
            if node.children then
                local open_size = 0
                for i,child in ipairs(node.children) do
                    open_size = open_size + child.__cache.open_size
                end
                node.__cache.open_size = open_size + 1
            end
            
        else --closed
            node.__cache.open_size = 1
        end
        if node.parent then
            return update_node_r(node.parent)
        end
    end
    update_node_r(node)
    self.__cache = {}
end

--index:how many open node before it,start from 0,0 must be root
function FoldTree:get_node_index(node)
    --todo
    --maybe not usage
end

--index:how many open node before it,start from 0,0 must be root
function FoldTree:find_node_by_index(index)
    --todo to some cache
    local function find_index_r(from_node,index)
        assert(index >= 1,"index must greater than or equal to 0")
        assert(index<=from_node.__cache.open_size,"index must less then node.open_size ")
        if index == 1 then
            return from_node
        end
        --index >= 2
        index = index - 1
        assert(from_node.children)
        for i,child in ipairs(from_node.children) do
            local child_open_size = child.__cache.open_size
            if child_open_size >=1 and index<=child_open_size  then
                return find_index_r(child,index)
            else
                index = index - child_open_size
            end
        end
        assert(false,"Not match in child,program bug")
    end

    if index < 0 or index >= self.root_node.__cache.open_size then
        return nil
    end
    --index+ 1 turn range into [1,open_size]
    return find_index_r(self.root_node,index+1)
end

--return node
function FoldTree:find_next_index(node)
    local open_state_dic = self.open_state_dic
    local node_children = node.children
    if (open_state_dic[node.key] ~=false) then
        if node_children and #node_children>=1 then
            return node_children[1]
        end
    end
    local function find_next_brother_r(node)
        local parent = node.parent
        if parent then
            local brothers = parent.children
            assert(brothers,"Program Error,data is illegality")
            local next_brother = nil
            local self_found = false
            for i,child in ipairs(brothers) do
                if (not self_found) then
                    if  node == child then
                        self_found = true
                    end
                else -- self_found
                    next_brother = child
                    break
                end

            end
            if next_brother then
                return next_brother
            else
                return find_next_brother_r(parent)
            end
        else
            return nil
        end
    end
    return find_next_brother_r(node)
end


-- local root_node = {
--     key = 1,
--     children = {
--         {
--             key = 2,
--             children = {
--                 {
--                     key = 3
--                 },
--                 {
--                     key = 4,
--                 }
--             }
--         },
--         {
--             key = 5,
--             children = {
--                 {
--                     key = 6,
--                     children = {
--                         {
--                             key = 7,
--                         }
--                     }
--                 },
--                 {
--                     key = 8,
--                 }
--             }
--         }
        
--     },
-- }
-- local test_tree = FoldTree.new(root_node,{[2]=false})
-- test_tree:build()
-- for i = -1,9 do
--     local node = test_tree:find_node_by_index(i)
--     print("find_index:",i,node and node.key)

--     if node then
--         local n = test_tree:find_next_index(node)
--         print("\tnex_index:",n and n.key)
--     end
-- end


FastImTree = class("FastImTree")

-----
function FastImTree:_init()
    self.root_node = nil
    self.update_item_func = nil
    self.cur_indent_size = 0
    --split open_state_dic,so that we don't need to update this when tree_data do small modify;
    self.open_state_dic = {}--{key:open_stated} open_stated=true/nil or false
    self.fold_tree = nil
end


--refresh_all:if true,refresh open_state_dic;
function FastImTree:set_tree_data(root_node,open_state_dic)
    self.root_node = root_node
    self.open_state_dic = open_state_dic or self.open_state_dic 

    self.fold_tree = FoldTree.new(root_node,self.open_state_dic)
end

--func(data_item):is_opened
function FastImTree:set_update_item_func(func,target)
    assert(func)
    if target then
        local bind_func = function(...)
            return func(target,...)
        end
        self.update_item_func = bind_func
    else
        self.update_item_func = func
    end
end

function FastImTree:update()
    self.cur_indent_size = 0
    local open_state_dic = self.open_state_dic
    --todo
    
    --alway update first one,to get item height,and start pos_y
    if self.root_node then
         --prepare the pos
        local scrollPanelStartY = windows.GetScrollY()
        local sizeX,sizeY = windows.GetContentRegionAvail()
        sizeY = sizeY + 120
        self:update_root_node()

        local scrollPanelEndY = scrollPanelStartY +sizeY

        local start_index =  math.floor((scrollPanelStartY - self.item_start_pos_y)/self.item_height)
        start_index = math.max(1,start_index)
        local start_real_pos_y = start_index * self.item_height + self.item_start_pos_y
        local item_size = math.floor((sizeY)/self.item_height)+1
        cursor.SetCursorPos(nil,start_real_pos_y)
        --start traverse
        local cur_node = self.fold_tree:find_node_by_index(start_index)
        while cur_node and item_size>0 do
            item_size = item_size -1
            local x,y = cursor.GetCursorPos()
            self:_update_node(cur_node)
            cur_node = self.fold_tree:find_next_index(cur_node)
        end
        local open_size = self.root_node.__cache.open_size
        local contentEndY = open_size * self.item_height + self.item_start_pos_y
        cursor.SetCursorPos(nil,contentEndY)
    end
    self:fix_indent(0)
end

--render root and update item heihht
function FastImTree:update_root_node()
    local node =self.root_node
    local _,curY1 = cursor.GetCursorPos()
    self.item_start_pos_y = curY1
    local opened = self:_update_node(node)
    local _,curY2 = cursor.GetCursorPos()
    local item_height = curY2 - curY1
    if (not opened) ~= ( not self.open_state_dic[node.key]) then
        --open change
        self.open_state_dic[node.key] = opened
        self.fold_tree:refresh_node(node)
    end
    self.item_height = item_height
end

function FastImTree:fix_indent(target)
    local diff = target - self.cur_indent_size
    if diff > 0 then
        for i = 1,diff do
            cursor.Indent()
        end
    elseif diff <0 then
        for i = 1,-1*diff do
            cursor.Unindent()
        end
    end
    self.cur_indent_size= target
end

function FastImTree:_update_node(node)
    local need_indent = node.__cache.indent
    self:fix_indent(need_indent)
    local update_func = self.update_item_func
    local opened = update_func(node,self.open_state_dic[node.key]~=false)
    if (not opened) ~= ( not self.open_state_dic[node.key]) then
        --open change
        self.open_state_dic[node.key] = opened
        self.fold_tree:refresh_node(node)
    end
    return opened
end
------

return FastImTree