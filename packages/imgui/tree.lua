local imgui = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor

--

TreeNode = class("TreeNode")

--flag can be nil
function TreeNode:_init(label,data,opened,is_leaf)
    self.label = label
    self.data = data
    self.is_leaf = is_leaf
    self._parent = nil
    self._opening = false
    self._children = nil
    self._opened = opened
end

function TreeNode:set_flag(flag)
    self.flag = flag
end

--{[tree_node]*}
function TreeNode:set_children(children)
    self._children = children
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
    self.data_provider = nil
    --todo give default flag
    self.no_leaf_flag = no_leaf_flag
    self.leaf_flag = leaf_flag
end

--root
--root_visible:default value is true
function Tree:set_root(root,root_visible)
    self._root = _root
    self._root_visible = ( root_visible ~= false )
end

function Tree:get_root(tree_node)
    return self._root
end

--cb:function( cur_status )
----cur_status:true means change from close to open
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
            self:_render_node(self._root,false)
        else
            self:_render_children(self._root,false)
        end
    end
end

function Tree:_render_children(tree_node,change)
    --TODO
end

function Tree:_render_node(tree_node,change)
    local flag = self:get_node_flag(tree_node)
    if widget.TreeNode(tree_node.label,flag) then
        if not tree_node._opened then
            change = true
        end
        self:_render_children(tree_node,change)
        widget.TreePop()
    else
        tree_node._opened = true
    end

end

function Tree:_update_node(tree_node,change)
    local update_child = function(tree_node)
        local dp = self.data_provider
        local children = dp(tree_node)
        for _,node in ipairs(children) do
            self:_update_node(node)
        end
    end
    if tree_node then
        local flag = self:get_node_flag(tree_node)
        if widget.TreeNode(tree_node.label,flag) then
            update_child(tree_node)
            widget.TreePop()
        end
    else
        update_child(tree_node)
    end
end

function Tree:get_node_flag(tree_node)
    local flag = tree_node.flag
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