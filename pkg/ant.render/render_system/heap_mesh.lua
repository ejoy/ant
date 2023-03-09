local ecs = ...
local world = ecs.world
local w = world.w

local math3d 	= require "math3d"
local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant
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

local function get_aabb(center, extent, cur_n, edge, xx, yy, zz)
    local height = (cur_n - 1) / (edge * edge) + 1
    local min = math3d.sub(center, extent)
    local max= math3d.vector(math3d.add(min, math3d.vector(edge*xx, height*yy, edge*zz)))
    return min, max
end

local function create_heap_compute(numToDraw, idb_handle, itb_handle, u1, u2, u3, u4)
    local dispatchsize = {
		math.floor(numToDraw / 64 + 1), 1 , 1
	}
    local dis = {}
	dis.size = dispatchsize
    local idb = {
		build_stage = 0,
		build_access = "w",
		name = "indirect_buffer",
		handle = idb_handle      
    }

    local itb = {
		build_stage = 1,
		build_access = "w",
		name = "instance_buffer",
        layout = declmgr.get "t47NIf".handle,
		handle = itb_handle         
    }

    local mo = heap_mesh_material.object
	mo:set_attrib("u_heapParams", u1)
	mo:set_attrib("u_meshOffset", u2)
	mo:set_attrib("u_instanceParams", u3)
    mo:set_attrib("u_worldOffset", u4)
    mo:set_attrib("indirectBuffer", icompute.create_buffer_property(idb, "build"))
	mo:set_attrib("instanceBufferOut", icompute.create_buffer_property(itb, "build"))

	dis.material = mo:instance()
	dis.fx = heap_mesh_material._data.fx
    icompute.dispatch(main_viewid, dis)

end

function hm_sys:init()
	heap_mesh_material = assetmgr.resource("/pkg/ant.resources/materials/heapmesh/heapmesh.material")
end

function hm_sys:heap_mesh()
    for e in w:select "heapmesh:update render_object?update bounding?update scene?in" do
        local heapmesh = e.heapmesh
        local curSideSize = heapmesh.curSideSize
        local curHeapNum = heapmesh.curHeapNum

        local lastSideSize
        if heapmesh.lastSideSize == nil then
            lastSideSize = curSideSize
        else
            lastSideSize = heapmesh.lastSideSize
        end

        local lastHeapNum
        if heapmesh.lastHeapNum == nil then
            lastHeapNum = 0
        else
            lastHeapNum = heapmesh.lastHeapNum
        end

        if curHeapNum >= curSideSize ^ 3 then
            curHeapNum = curSideSize ^ 3
        elseif curHeapNum <= 0 then
            curHeapNum = 0
        end

        if lastHeapNum == curHeapNum and lastSideSize == curSideSize or curHeapNum == 0 then
        else
            local sx, sy, sz = math3d.index(e.scene.s, 1, 2, 3)
            local ro = e.render_object
            math3d.unmark(e.bounding.aabb)
            
            local aabb_center, aabb_extent
            if e.heapmesh.aabb_center == nil and e.heapmesh.aabb_extent == nil then
                aabb_center, aabb_extent = math3d.aabb_center_extents(e.bounding.aabb)
                e.heapmesh.aabb_center, e.heapmesh.aabb_extent = math3d.mark(aabb_center), math3d.mark(aabb_extent)
            else
                aabb_center, aabb_extent = e.heapmesh.aabb_center, e.heapmesh.aabb_extent
            end
            local aabb_x, aabb_y, aabb_z = math3d.index(aabb_extent, 1, 2, 3)
            aabb_x, aabb_y, aabb_z = sx * 2 * aabb_x, sy * 2 * aabb_y, sz * 2 * aabb_z
            local heapParams = math3d.vector(curHeapNum, curSideSize, 0, 0)
            local meshOffset = math3d.vector(aabb_x, aabb_y, aabb_z, 0)
            local instanceParams = math3d.vector(0, ro.vb_num, 0, ro.ib_num)
            local indirectBuffer_handle = bgfx.create_indirect_buffer(curHeapNum)
            local instanceBufferOut_handle = bgfx.create_dynamic_vertex_buffer(curHeapNum, declmgr.get "t47NIf".handle, "w")
            local aabb_min, aabb_max = get_aabb(aabb_center, aabb_extent, curHeapNum, curSideSize, aabb_x, aabb_y, aabb_z)
            e.bounding.aabb = math3d.mark(math3d.aabb(aabb_min, aabb_max))
            local _, extent = math3d.aabb_center_extents(e.bounding.aabb)
            local worldOffset = math3d.vector(extent, 0)
            create_heap_compute(curHeapNum, indirectBuffer_handle, instanceBufferOut_handle, heapParams, meshOffset, instanceParams, worldOffset)
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

function iheapmesh.update_heap_mesh_number(num, name)
    for e in w:select "heapmesh:update" do
        if e.heapmesh.glbName == name then
            e.heapmesh.curHeapNum = num
        end
    end
end

function iheapmesh.update_heap_mesh_sidesize(size, name)
    for e in w:select "heapmesh:update" do
        if e.heapmesh.glbName == name then
            e.heapmesh.curSideSize = size
        end
    end
end