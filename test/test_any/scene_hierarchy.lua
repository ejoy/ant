-- luacheck: globals log
local log = log and log(...) or print
require "iuplua"
local iupcontrols   = import_package "ant.iupcontrols"
local tree = iupcontrols.tree
local popupmenu = iupcontrols.popupmenu
local util = require "util"
local scene_hierarchy_hub = require "scene_hierarchy_hub"
local Serialize = import_package 'ant.serialize'
local scene_hierarchy = setmetatable({},{__index = tree})

function scene_hierarchy:on_open_world(serialize_world)
    local world = self.editor_window:get_editor_world()
    for _, eid in world:each 'serialize' do
        world:remove_entity(eid)
    end
    Serialize.load_world(world, serialize_world)
    local htree, ud_table = self:build_hierarchy_tree(world)
    print("sssssssssssssssssssssssssssssssssssssssssssssssssssss")
    print_a(world._schema.map)
    self:build(htree, ud_table)
end

function scene_hierarchy:build_hierarchy_tree(world)
    local htree = {}
    local ud_table = {}
    local eidin_hierarchy = {}

    local function add_entity(eid, defname)
        assert(not eidin_hierarchy[eid])
        eidin_hierarchy[eid] = true
        local e = world[eid]
        local name = e.name or defname
        ud_table[name] = e.serialize
        table.insert(htree, name)
    end

    for _, maincomp in ipairs {"main_queue", } do
        for _, eid in world:each(maincomp) do
            local defname = maincomp
            add_entity(eid, defname)
        end
    end
    
    local function is_transform_obj(e)      
        for _, n in ipairs {"pos_transform", "scale_transform", "rotator_transform"} do
            if e[n] then
                return true
            end
        end

        return false
    end

    for _, eid in world:each("editable_hierarchy") do
        eidin_hierarchy[eid] = true     
        local e = world[eid]
        
        if not is_transform_obj(e) then
            local hierarchy_tree = e.editable_hierarchy.assetinfo.handle
            local name_mapper = e.hierarchy_name_mapper
            local function build_hierarchy_entity_tree(ehierarchy, name_mapper)
                local t = {}
                local num = #ehierarchy
                for i=1, num do
                    local child = ehierarchy[i]
                    local childnum = #child
                    local ceid = name_mapper[child.name]
                    if ceid and eidin_hierarchy[ceid] == nil then
                        eidin_hierarchy[ceid] = true
                        ud_table[child.name] = child.serialize
                        if childnum ~= 0 then
                            local ct = build_hierarchy_entity_tree(child, name_mapper)
                            t[child.name] = ct
                        else
                            table.insert(t, child.name)
                        end
                    end

                end
                return t
            end

            local t = build_hierarchy_entity_tree(hierarchy_tree, name_mapper)        
            local name = e.name or "hierarchy_entity"
            htree[name] = t         
            ud_table[name] = e.serialize
        end
    end

    for _, eid in world:each("can_render") do
        if not eidin_hierarchy[eid] then            
            local e = world[eid]
            if not is_transform_obj(e) and e.can_render then                
                local name = e.name or "entity"
                table.insert(htree, name)
                ud_table[name] = e.serialize
            end
        end
    end
    
    return htree, ud_table
end

local function ordered_pairs(t)
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


function scene_hierarchy:build(htree, ud_table)       
    local function constrouct_treeview(tr, parent)
        for k, v in ordered_pairs(tr) do
            local ktype = type(k)
            if ktype == "string" or ktype == "number" then
                local vtype = type(v)
                local function add_child(parent, name)
                    local child = self:add_child(parent, name)
                    local eid = assert(ud_table[name])
                    child.eid = eid        
                    return child
                end
                
                if vtype == "table" then
                    local child = add_child(parent, k)
                    constrouct_treeview(v, child)
                elseif vtype == "string" then
                    add_child(parent, v)
                end
            else
                log("not support ktype : ", ktype)
            end
    
        end
    end

    self:clear()
    constrouct_treeview(htree, nil) 
    self:clear_selections()
end

function scene_hierarchy:init( )
    function self.view.selection_cb(tree_ctrl,id, status)
        if status == 1 then
            -- local tree = tree_ctrl
            local node = self:findchild_byid(id)
            if node then
                local eid = node.eid
                local world = self.editor_window:get_editor_world()
                
                -- build_pv(eid, get_extendtree(eid))
                print("todo build pv")
                -- local camerautil = import_package "ant.render".camera
                -- local world = self.editor_window:get_editor_world()
                -- camerautil.focus_selected_obj(world, eid)
                scene_hierarchy_hub.publish_foucs_entity(eid)
            end
        end
    end

    --luacheck: ignore self
    function self.view.rightclick_cb(tree_ctrl)
        local m = popupmenu.new {
            recipe = {
                {name="create entity...", type="item", action=function ()               
            end}
            },
            open_cb = nil,
            menclose_cb = nil,
        }
        local x, y = eu.get_cursor_pos()
        m:show(x, y)
    end
end

function scene_hierarchy.new(config,editor_window)
    local default_config = {
        HIDEBUTTONS ="YES",
        HIDELINES   ="YES", 
        IMAGELEAF   ="IMGLEAF",
        IMAGEBRANCHCOLLAPSED = "IMGLEAF",
        IMAGEBRANCHEXPANDED = "IMGLEAF"
    }
    local merge_config
    if config ~= nil then
        merge_config = util.merge_config(config,default_config)
    else
        merge_config = default_config
    end
    local tree = tree.new(merge_config)
    local ins =  setmetatable(tree,{ __index = scene_hierarchy })
    ins.editor_window = editor_window
    ins:init()
    scene_hierarchy_hub.subscibe(ins)
    return ins

end

function scene_hierarchy:get_view()
    return self.view
end

return scene_hierarchy