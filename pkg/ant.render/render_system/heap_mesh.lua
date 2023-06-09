local ecs = ...
local world = ecs.world
local w = world.w
local idrawindirect = ecs.import.interface "ant.render|idrawindirect"
local math3d 	= require "math3d"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = import_package "ant.render".declmgr
local main_viewid = viewidmgr.get "csm_fb"
local bgfx 			= require "bgfx"
local assetmgr  = import_package "ant.asset"
local icompute = ecs.import.interface "ant.render|icompute"
local iheapmesh = ecs.interface "iheapmesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local hm_sys = ecs.system "heap_mesh"

local function get_offset(edge, xx, yy, zz, interval)
    local edgeX, edgeY, edgeZ = edge[1], edge[2], edge[3]
    local x = ((edgeX - 1) * xx + (edgeX - 1) * interval[1] * xx) * 0.5
    local z = ((edgeZ - 1) * zz + (edgeZ - 1) * interval[3] * zz) * 0.5
    local y = ((edgeY - 1) * yy + (edgeY - 1) * interval[2] * yy) * 0.5
    local offset = math3d.vector(x, y, z)
    return offset
end

local function update_heap_compute(draw_indirect, dispatch, numToDraw, u1, u2, u3, u4, u5)
    local idb_handle, itb_handle = draw_indirect.idb_handle, draw_indirect.itb_handle
    dispatch.size[1] = math.floor((numToDraw - 1) / 64) + 1
    local m = dispatch.material
    m.u_heapParams		= u1
    m.u_meshOffset      = u2
    m.u_instanceParams  = u3
    m.u_worldOffset     = u4
    m.u_intervalParam   = u5
    m.indirectBuffer     = idb_handle
    m.instanceBufferOut  = itb_handle
    icompute.dispatch(main_viewid, dispatch)
end

local function calc_max_num(side_size_table)
    return side_size_table[1] * side_size_table[2] * side_size_table[3]
end


function hm_sys:entity_init()
    for e in w:select "INIT heapmesh:update render_object?update mesh:in scene:in heapmesh_ready?update indirect?update" do
        local heapmesh = e.heapmesh
        local curSideSize = heapmesh.curSideSize
        local curMaxSize  = calc_max_num(curSideSize)
        local max_num = curMaxSize
        local draw_indirect_eid = ecs.create_entity {
            policy = {
                "ant.render|compute_policy",
                "ant.render|draw_indirect"
            },
            data = {
                material    = "/pkg/ant.resources/materials/heapmesh/heapmesh.material",
                dispatch    = {
                    size    = {0, 0, 0},
                },
                compute = true,
                draw_indirect = {
                    itb_flag = "w",
                    max_num = max_num
                },
                on_ready = function()
                    heapmesh.draw_indirect_ready = true
                end 
            }
        }
        heapmesh.draw_indirect_eid = draw_indirect_eid
        e.render_object.draw_num = 0
        e.heapmesh_ready = true
    end
end

function hm_sys:entity_ready()
    for e in w:select "heapmesh_ready heapmesh:update bounding:in scene:in material:in indirect:in" do
        local _, extent = math3d.aabb_center_extents(e.bounding.aabb)
        extent = math3d.mul(e.scene.s, math3d.mul(2, extent))
        e.heapmesh.extent = math3d.tovalue(extent)
        local draw_indirect_type = idrawindirect.get_draw_indirect_type(e.indirect)
        imaterial.set_property(e, "u_draw_indirect_type", math3d.vector(draw_indirect_type))
    end
end

function hm_sys:entity_remove()
    for e in w:select "REMOVED heapmesh:update" do
        w:remove(e.heapmesh.draw_indirect_eid)
    end
end

function hm_sys:heap_mesh()
    for e in w:select "heapmesh:update render_object?update bounding?update scene?in" do
        if not e.heapmesh.draw_indirect_ready then
            goto continue
        end
        local heapmesh = e.heapmesh
        local interval = heapmesh.interval
        local curSideSize = heapmesh.curSideSize
        local curMaxSize  = calc_max_num(curSideSize)
        local curHeapNum = heapmesh.curHeapNum

        local lastSideSize
        if not heapmesh.lastSideSize then
            lastSideSize = curSideSize
        else
            lastSideSize = heapmesh.lastSideSize
        end

        local lastHeapNum
        if not heapmesh.lastHeapNum then
            lastHeapNum = 0
        else
            lastHeapNum = heapmesh.lastHeapNum
        end

        if curHeapNum >= curMaxSize then
            curHeapNum = curMaxSize
        elseif curHeapNum <= 0 then
            curHeapNum = 0
        end
        local heap_mesh_unchanged = lastHeapNum == curHeapNum and lastSideSize == curSideSize or curHeapNum == 0
        if not heap_mesh_unchanged then
            local ro = e.render_object
            local extent = e.heapmesh.extent
            local heapParams = math3d.vector(curHeapNum, curSideSize[1], curSideSize[2], curSideSize[3])
            local meshOffset = math3d.vector(extent[1], extent[2], extent[3], 0)
            local instanceParams = math3d.vector(0, ro.vb_num, 0, ro.ib_num)
            local intervalParam = math3d.vector(extent[1] * interval[1], extent[2] * interval[2], extent[3] * interval[3], 0)
            local offset_extent = get_offset(curSideSize, extent[1], extent[2], extent[3], interval)
            local worldOffset = math3d.vector(offset_extent, 0)
            local de <close> = w:entity(heapmesh.draw_indirect_eid, "draw_indirect:in dispatch:in")
            update_heap_compute(de.draw_indirect, de.dispatch, curHeapNum, heapParams, meshOffset, instanceParams, worldOffset, intervalParam)
            e.render_object.idb_handle = de.draw_indirect.idb_handle
            e.render_object.itb_handle = de.draw_indirect.itb_handle
        end
        e.heapmesh.curHeapNum = curHeapNum
        e.heapmesh.lastHeapNum = curHeapNum
        e.heapmesh.curSideSize = curSideSize
        e.heapmesh.lastSideSize = curSideSize
        e.render_object.draw_num = curHeapNum
        ::continue::
	end
end


function iheapmesh.update_heap_mesh_number(eid, num)
    local e <close> = w:entity(eid, "heapmesh:update")
    e.heapmesh.curHeapNum = num
end

function iheapmesh.update_heap_mesh_sidesize(eid, size)
    local e <close> = w:entity(eid, "heapmesh:update")
    e.heapmesh.curSideSize = size
end
