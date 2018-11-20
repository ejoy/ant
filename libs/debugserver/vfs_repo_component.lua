local ecs = ...

local vfs_update_component = ecs.component_struct "vfs_update_component" {}
function vfs_update_component:init()
    self.do_update = false
end

local vfs_root_component = ecs.component_struct "vfs_root_component" {}
function vfs_root_component:init()
    self.root = nil
end

local vfs_load_component = ecs.component_struct "vfs_load_component" {}
function vfs_load_component:init()
    self.load_request_queue = {}
end