 local ecs = ...
local world = ecs.world
local w = world.w

local math3d 	= require "math3d"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = import_package "ant.render".declmgr
local main_viewid = viewidmgr.get "csm_fb"
local bgfx 			= require "bgfx"
local assetmgr  = import_package "ant.asset"
local icompute = ecs.import.interface "ant.render|icompute"
local iheapmesh = ecs.interface "iheapmesh"

local hm_sys = ecs.system "heap_mesh"

local heap_mesh_material

local function get_offset(edge, xx, yy, zz, interval)
    local edgeX, edgeY, edgeZ = edge[1], edge[2], edge[3]
    local x = ((edgeX - 1) * xx + (edgeX - 1) * interval[1] * xx) * 0.5
    local z = ((edgeZ - 1) * zz + (edgeZ - 1) * interval[3] * zz) * 0.5
    local y = ((edgeY - 1) * yy + (edgeY - 1) * interval[2] * yy) * 0.5
    local offset = math3d.vector(x, y, z)
    return offset
end

local function create_heap_compute(numToDraw, idb_handle, itb_handle, u1, u2, u3, u4, u5)
    local dispatchsize = {
		math.floor((numToDraw - 1) / 64) + 1, 1, 1
	}
    local dis = { size = dispatchsize }
    local mo = heap_mesh_material.object
    if dis.material then
        dis.material:release()
    end
    dis.material = mo:instance()
    local m = dis.material

    m.u_heapParams		= u1
    m.u_meshOffset      = u2
    m.u_instanceParams  = u3
    m.u_worldOffset     = u4
    m.u_intervalParam   = u5
    m.indirectBuffer      = idb_handle
    m.instanceBufferOut   = itb_handle
	dis.fx = heap_mesh_material._data.fx
    icompute.dispatch(main_viewid, dis)
end

local function calc_max_num(side_size_table)
    return side_size_table[1] * side_size_table[2] * side_size_table[3]
end

function hm_sys:init()
	heap_mesh_material = assetmgr.resource("/pkg/ant.resources/materials/heapmesh/heapmesh.material")
end

local function check_destroy(ro)
    if ro and ro.idb_handle ~= 0xffffffff then
        bgfx.destroy(ro.idb_handle)
    end
    if ro and ro.idb_handle ~= 0xffffffff then
        bgfx.destroy(ro.itb_handle)
    end
end

function hm_sys:heap_mesh()
    for e in w:select "heapmesh:update render_object?update bounding?update scene?in" do
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
            local sx, sy, sz = math3d.index(e.scene.s, 1, 2, 3)
            local ro = e.render_object
            math3d.unmark(e.bounding.aabb)
            
            local aabb_center, aabb_extent
            if not e.heapmesh.aabb_center and not e.heapmesh.aabb_extent then
                aabb_center, aabb_extent = math3d.aabb_center_extents(e.bounding.aabb)
                e.heapmesh.aabb_center, e.heapmesh.aabb_extent = math3d.mark(aabb_center), math3d.mark(aabb_extent)
            else
                aabb_center, aabb_extent = e.heapmesh.aabb_center, e.heapmesh.aabb_extent
            end
            
            local aabb_x, aabb_y, aabb_z = math3d.index(aabb_extent, 1, 2, 3)
            aabb_x, aabb_y, aabb_z = sx * 2 * aabb_x, sy * 2 * aabb_y, sz * 2 * aabb_z
            local heapParams = math3d.vector(curHeapNum, curSideSize[1], curSideSize[2], curSideSize[3])
            local meshOffset = math3d.vector(aabb_x, aabb_y, aabb_z, 0)
            local instanceParams = math3d.vector(0, ro.vb_num, 0, ro.ib_num)
            local indirectBuffer_handle = bgfx.create_indirect_buffer(curHeapNum)
            local instanceBufferOut_handle = bgfx.create_dynamic_vertex_buffer(curHeapNum, declmgr.get "t47NIf".handle, "w")
            local intervalParam = math3d.vector(aabb_x * interval[1], aabb_y * interval[2], aabb_z * interval[3], 0)
            local offset_extent = get_offset(curSideSize, aabb_x, aabb_y, aabb_z, interval)
            e.bounding.aabb = math3d.mark(math3d.aabb())

            local worldOffset = math3d.vector(offset_extent, 0)

            create_heap_compute(curHeapNum, indirectBuffer_handle, instanceBufferOut_handle, heapParams, meshOffset, instanceParams, worldOffset, intervalParam)
            check_destroy(e.render_object)
            e.render_object.idb_handle = indirectBuffer_handle
            e.render_object.itb_handle = instanceBufferOut_handle
        end

        e.heapmesh.curHeapNum = curHeapNum
        e.heapmesh.lastHeapNum = curHeapNum
        e.heapmesh.curSideSize = curSideSize
        e.heapmesh.lastSideSize = curSideSize
        e.render_object.draw_num = curHeapNum
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
