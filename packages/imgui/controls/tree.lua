--[[
------------init----------------------
local root = Tree.Node.new( "Root",nil,{"this is root's data"},true)
local node1 = Tree.Node.new( "Node1",root,{"this is Node1's data"},true)
local node1_1 = Tree.Node.new( "node1_1",node1,nil,true)
local node2 = Tree.Node.new( "Node2",root,nil,true)
local node2_1 = Tree.Node.new( "node2_1",node2,nil,true)
local node2_2 = Tree.Node.new( "node2_2",node2,nil,false)
local node2_2_1 = Tree.Node.new( "node2_2_1",node2_2,nil,false,true)

local tree = Tree.new()
tree:set_root(root)
local function cb(node,change)
    print("cb",node.title,node.data,change)
end
tree:set_node_change_cb(cb)
--------------update--------------------
function on_update()
    ...
    tree:update()
    ...
end


]]--
local imgui = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local class     = require "common.class"

--

TreeNode = class("TreeNode")

--flag can be nil
function TreeNode:_init(title,parent,data,opened,is_leaf)
    self.title = title
    self.data = data
    self.is_leaf = is_leaf
    self._parent = nil
    self._opening = false
    self._children = nil
    self._opened = opened
    if parent then
        parent:add_child_at(self)
    end
end

function TreeNode:set_flag(flag)
    self._flag = flag
end

function TreeNode:add_child_at(child,index)
    if not self._children then
        self._children = {}
    end
    local children = self._children
    local size = #children
    local function remove_child_parent(child)
        if child._parent then
            child._parent:remove_child(child)
        end
        assert(not child._parent)
    end
    if not index or index > size then
        remove_child_parent(child)
        table.insert(children,child)
        child._parent = self
    else
        assert(index>=1,"Error because child index <= 0 ")
        remove_child_parent(child)
        table.insert(children,index,child)
        child._parent = self
    end
end

function TreeNode:remove_child(child)
    assert( child._parent == self)
    for i, c in ipairs(self._children) do
        if c == child then
            table.remove(self._children,i)
            break
        end
    end
    child._parent = nil
end

function TreeNode:is_ascendant_of(child_node)
    repeat
        local parent = child_node._parent
        if parent == self then
            return true
        end
    until parent == nil
    return false
end

Tree = class("Tree")
Tree.Node = TreeNode


function Tree:_init(no_leaf_flag,leaf_flag)
    --todo give default flag
    self.no_leaf_flag = no_leaf_flag
    self.leaf_flag = leaf_flag or flags.TreeNode.Leaf
end

--root
--root_visible:default value is true
function Tree:set_root(root,root_visible)
    self._root = root
    self._root_visible = ( root_visible ~= false )
end

function Tree:get_root(tree_node)
    return self._root
end

--cb:function( cur_status )
--  cur_status:true means change from close to open
--target can be nil
function Tree:set_node_change_cb(cb,target)
    if target then
        self._change_cb = function( ... )
            cb(target,...)
        end
    else
        self._change_cb = cb
    end
end

function Tree:update()
    if self._root then
        if self._root_visible then
            self:_render_node(self._root)
        else
            self:_render_children(self._root)
        end
    end
end

--render tree_node's children( no include itself)
function Tree:_render_children(tree_node)
    local children = tree_node._children
    if children then
        for i,child in ipairs(children) do
            self:_render_node(child)
        end
    end
end
--render tree_node itself
function Tree:_render_node(tree_node)
    local flag = self:get_node_flag(tree_node)
    widget.SetNextItemOpen(tree_node._opened)
    local cur_open = widget.TreeNode(tree_node.title,flag)
    if cur_open ~= tree_node._opened then
        tree_node._opened = cur_open
        self:_on_node_change(tree_node,cur_open)
    end
    if cur_open then
        self:_render_children(tree_node)
        widget.TreePop()
    end
    
end

function Tree:_on_node_change(node,opened)
    if self._change_cb then
        self._change_cb( node,opened )
    end
end

function Tree:get_node_flag(tree_node)
    local flag = tree_node._flag
    if flag then
        return flag
    elseif tree_node.is_leaf then
        return self.leaf_flag
    else
        return self.no_leaf_flag
    end
end

--return node
function Tree:get_clicked()

end

--return node
function Tree:get_double_clicked()

end

return Tree

