local ImGui     = import_package "ant.imgui"

local m = {
    show_skeleton = false,
    joint_map = {},
    joint_list = {},
}

function m:get_joints()
    return self.joint_map, self.joint_list
end

function m:init(skeleton)
    self.skeleton = skeleton
    local ske = self.skeleton
    local new_list = {}
    local new_map = {root = nil, joint_map = {}}
    local function construct(current_joints, skeleton, joint_idx)
        if current_joints.joint_map[joint_idx] then
            return current_joints.joint_map[joint_idx]
        end
        local new_joint = {
            index = joint_idx,
            name = skeleton:joint_name(joint_idx),
            children = {}
        }
        current_joints.joint_map[joint_idx] = new_joint
        if skeleton:isroot(joint_idx) then
            current_joints.root = new_joint
        else
            local parent_idx = skeleton:parent(joint_idx)
            if parent_idx > 0 then
                new_joint.parent = current_joints.joint_map[parent_idx] or construct(current_joints, ske, ske:parent(parent_idx))
                table.insert(current_joints.joint_map[parent_idx].children, new_joint)
            end
        end 
    end
    local num = ske:num_joints()
    for i=1, num do
        construct(new_map, ske, i)
    end
    local real_bone_index = {}
    real_bone_index[new_map.root.index] = true
    local function get_real_bones(root, real_bone_index)
        if #root.children < 1 then
            return
        end
        for _, value in ipairs(root.children) do
            real_bone_index[value.index] = true
            get_real_bones(value, real_bone_index)
        end
    end
    get_real_bones(new_map.root, real_bone_index)
    for i=1, num do
        if not real_bone_index[i] then
            new_map.joint_map[i] = nil
        end
    end
    local function setup_joint_list(joint)
        new_list[#new_list + 1] = joint
        for _, child_joint in ipairs(joint.children) do
            setup_joint_list(child_joint)
        end
    end
    setup_joint_list(new_map.root)
    self.joint_list = new_list
    self.joint_map = new_map
    return new_map, new_list
end

function m:show_joints(root)
    local base_flags = ImGui.Flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((self.current_joint and (self.current_joint.name == root.name)) and ImGui.Flags.TreeNode{"Selected"} or 0)
    local flags = base_flags
    local has_child = true
    if #root.children == 0 then
        flags = base_flags | ImGui.Flags.TreeNode { "Leaf", "NoTreePushOnOpen" }
        has_child = false
    end
    local open = ImGui.TreeNode(root.name, flags)
    if ImGui.IsItemClicked() then
        if self.on_select_joint then
            self.on_select_joint(self.current_joint, root)
        end
        self.current_joint = root
    end
    if open and has_child then
        for _, joint in ipairs(root.children) do
            self:show_joints(joint)
        end
        ImGui.TreePop()
    end
end

function m:get_joint_by_name(ske, name)
    if not name then return end
    for _, value in ipairs(self.joint_list) do
        if value.name == name then
            return value
        end
    end
end

function m:set_current_joint(ske, name)
    local joint = self:get_joint_by_name(ske, name)
    if joint then
        if self.on_select_joint then
            self.on_select_joint(self.current_joint, joint)
        end
    end
    self.current_joint = joint
end

function m:get_current_skeleton()
    return self.skeleton
end

function m:update_pose(root_mat)
    if self.update_joint_pose and self.show_skeleton then
        self.update_joint_pose(root_mat, self.joint_list)
    end
end

return m