local log = log and log(...) or print

require "iupluacontrols"

local iupcontrols   = import_package "ant.iupcontrols"
local treecontrol = iupcontrols.tree
local mv_control = iupcontrols.matrixview
local ctrlutil = iupcontrols.util
local editor = import_package "ant.editor"
local eu = editor.util
local math = import_package "ant.math"
local ms = math.stack
local su = import_package "ant.serialize"

local propertyview = {}; propertyview.__index = propertyview

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

local function create_tree_branch(node, parent, treeview)
    local ntype = type(node)
    if ntype ~= "table" then
        return
    end

    for k, v in ordered_pairs(node) do
        local child = treeview:add_child(parent, k)
        child.userdata = v
    end
end

function propertyview:build(properties, extend_trees)
    local ps = properties
    properties = su.parse(ps)
    properties = properties[2]
    print_a("propertyview:build:",properties, extend_trees)
    --todo unserialize properties
    local treeview = self.tree
    treeview:clear()

    local function init_property_tree(properties, treeview, extend_trees)
        create_tree_branch(properties, nil, treeview)

        if extend_trees then
            local function create_branch(properties, etree, parentnode)
                for k, v in pairs(etree) do
                    local property = properties[k]
                    local childnode = treeview:findchild_byname(parentnode or treeview, k)
                    create_tree_branch(property, childnode, treeview)                   
                    create_branch(property, v, childnode)
                end
            end
            create_branch(properties, extend_trees, nil)
        end
    end

    init_property_tree(properties, treeview, extend_trees)
    
    treeview:clear_selections()
end


function propertyview:on_focus_entity(serialize)
    local function build_pv(eid, extend_tree)
        local world = self.editor_window:get_editor_world()
        local properties = su.save_entity(world, eid, ms)
        self:build(properties, extend_tree)

        local treectrl = self.tree.view
        local detailctrl = self.detail.view
        
        local origin_executeleaf_cb = treectrl.executeleaf_cb
        function treectrl:executeleaf_cb(id)
            origin_executeleaf_cb(self, id)
            
            local extend_tree = extend_tree
    
            local names = {}
            local curid = id
            repeat
                local name = self:node_name(curid)
                table.insert(names, name)
                local parent = self:parent(curid)                   
                curid = parent and tonumber(parent) or nil      
            until(curid == nil)
            
            local parent = extend_tree
            for i=#names, 1, -1 do
                local name = names[i]
                local p = parent[name]
                if p == nil then
                    parent[name] = {}
                else
                    parent = p
                end
            end
        end

        function treectrl:rightclick_cb(id)
            local addsubmenu = {name="Add", type="submenu",}
        
            local add_action =  function(menuitem)
                local cname = menuitem.TITLE
                local node = get_hv_selnode()
                if node then
                    local eid = node.eid
                    world:add_component(eid, cname)
                    build_pv(eid, get_extendtree(eid))
                else
                    log("add component failed, component is : ", cname, 
                    ", but could not get hierarchy view select node, return nil")
                end

            end

            local added_components = {}
            for i=0, self.COUNT-1 do
                local name = self["TITLE" .. i]
                added_components[name] = true
            end

            for cname in pairs(world._component_type) do
                local active = added_components[cname] and "NO" or "YES"
                table.insert(addsubmenu, {name=cname, type="item", action=add_action, active=active})
            end
    
            local m = menu.new {
                recipe = {
                    addsubmenu,
                    {name="Delete", type="item", action=function ()
                        local hvnode = get_hv_selnode()                     
                        local eid = hvnode.eid
                        local cname = self["TITLE"..id]
                        world:remove_component(eid, cname)
                        build_pv(eid, get_extendtree(eid))
                    end},
                }
            }
    
            local x, y = eu.get_cursor_pos()
            m:show(x, y)
        end

        function detailctrl:valuechanged_cb()
            local function which_component()
                local tree = treectrl.owner
                local selnode = tree:get_selected_node()    
                local pid = selnode.id
                local compname
                repeat
                    compname = tree:node_name(pid)
                    pid = tonumber(tree:parent(pid))
                until(pid==nil)

                return compname
            end

            local edited_comp = which_component()
            local entity = world[eid]
            local load_comp_op = assert(world._component_type[edited_comp].load)

            local args = {world = world, eid = eid}
            world:remove_component(eid, edited_comp)
            world:add_component(eid, edited_comp)
            load_comp_op(entity[edited_comp], properties[edited_comp], args)
        end
    end
    local world = self.editor_window:get_editor_world()
    local eid = world:find_serialize(serialize)
    build_pv(eid,self.extend_trees)
end

local function fill_matrixview(detail, node)
    local nodevalue = node.userdata
    if nodevalue == nil then
        return 
    end

    local ridx = 1
    if type(nodevalue) == "table" then
        detail:setcell(0, 1, "key")
        detail:setcell(0, 2, "value")       
        for k, v in ordered_pairs(nodevalue) do
            detail:setcell(ridx, 1, k)              
            if type(v) == "table" then
                detail:setuserdata(ridx, 2, {node=node, name=k})
            end

            detail:setcell(ridx, 2, tostring(v) or "nil")
            ridx = ridx + 1
        end
        detail:fit_col_content_size(1)
        ridx = ridx - 1

        detail:shrink(ridx, nil)
        detail:fit_col_content_size(2, 10)
    else
        detail:setcell(0, 1, "value")
        detail:shrink(1, 1)
        detail:setcell(1, 1, tostring(nodevalue) or "nil")
        detail:fit_col_content_size(1, 10)
    end
end

function propertyview:get_view()
    return self.view
end

function propertyview.new(config,editor_window)
    config.tree.NAME = "RESVIEW"
    config.detail.NAME = "RESDETAIL"

    local tree = treecontrol.new(config.tree)
    local detail = mv_control.new(config.detail)

    function tree.view:selection_cb(id, status)
        if status == 0 then
            return 
        end

        local node = tree:findchild_byid(id)
        fill_matrixview(detail, node)
    end

    function tree.view:executeleaf_cb(id)
        local child = tree:findchild_byid(id)
        local nodevalue = child.userdata
        if nodevalue then
            tree.view.ADDEXPANDED = "YES"
            create_tree_branch(nodevalue, child, self)
        end
    end

    function detail.view:click_cb(lin, col, status) 
        local isleftbtn = status:sub(3, 3) == '1'
        local isdbclick = status:sub(6, 6) == 'D'

        if not isleftbtn or not isdbclick then
            return 
        end
    
        local ud = detail:getuserdata(lin, col)
        if ud then
            local node = ud.node
            if not tree:isbranch(node) then
                create_tree_branch(node.userdata, node, tree)
            end

            tree:clear_selections()
            local selectnode = tree:findchild_byname(node, ud.name)
            tree:select_node(selectnode)

            fill_matrixview(detail, selectnode)
        end
    end

    function detail:value_edit_cb(lin, col, newstring)
        local function get_ud()
            local selnode = tree:get_selected_node()
            local ud = selnode.userdata
            if ud then
                if col == 1 then
                    local parentnode = tree:parent_node(selnode.id)
                    return parentnode.userdata, selnode.name
                end
                assert(col == 2)
                return ud, self:getcell(lin, col - 1)
            end

            local parentnode = tree:parent_node(selnode.id)
            return assert(parentnode.userdata), selnode.name
        end

        local ud, elemname = get_ud()

        if ud then
            local function check_name_is_number(t, name)
                if #t > 0 then
                    local n = tonumber(name)
                    if n then
                        return n
                    end
                end
                return name
            end

            elemname = check_name_is_number(ud, elemname)

            local nodevaluetype = type(assert(ud[tonumber(elemname) or elemname]))
            if nodevaluetype == "string" then
                ud[elemname] = newstring
            elseif nodevaluetype == "number" then
                ud[elemname] = tonumber(newstring)
            elseif nodevaluetype == "boolean" then
                local mm = {
                    ['true'] = true,
                    ['True'] = true,
                    ['TRUE'] = true,
                    ['false'] = false,
                    ['False'] = false,
                    ['FALSE'] = false,
                }
                local newvalue = mm[newstring]              
                ud[elemname] = newvalue or (tonumber(newstring) ~= 0)               
            else
                iup.Message("Warning", 
                    string.format("only support modify string/number/boolean, current type is : ", nodevaluetype))
            end
        end
    end

    local view = iup.split {
        tree.view,
        iup.tabs {
            TABTITLE0 = "Detail",
            detail.view,
        },
        showgrip = "NO",
        ORIENTATION="HORIZONTAL",
    }
    if config.view then
        for k,v in pairs(config.view) do
            view[k] = v
        end
    end
    local ins = setmetatable({}, propertyview)
    ins.view=view
    ins.tree=tree
    ins.detail = detail
    ins.extend_trees = {}
    ins.editor_window = editor_window

    local entity_property_hub = require "entity_property_hub"
    entity_property_hub.subscibe(ins)

    return ins
end

return propertyview

