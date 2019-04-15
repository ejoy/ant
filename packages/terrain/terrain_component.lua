local ecs = ...

local bgfx = require "bgfx"

local declmgr = import_package 'ant.render'.declmgr

local terraincomp =
    ecs.component_alias('terrain', 'resource') {
    depend = {'mesh', 'material'}
}

local function create_buffer(terrainhandle, dynamic, declname)
    local vb, numvertices, ib, numindices = terrainhandle:buffer()

    local decl = declmgr.get(declname)

    local create_vb = dynamic and bgfx.create_dynamic_vertex_buffer or bgfx.create_vertex_buffer
    local create_ib = dynamic and bgfx.create_dynamic_index_buffer or bgfx.create_index_buffer
    return create_vb({'!', vb, numvertices}, decl.handle), create_ib({'!', ib, numindices})
end

function terraincomp:postinit(e)
    local mesh = e.mesh
    local terraininfo = e.terrain.assetinfo
    local terrainhandle = terraininfo.handle

    local numlayers = terraininfo.num_layers
    if numlayers ~= #e.material.content then
        error('terrain layer number is not equal material defined numbers')
    end

    local vbh, ibh = create_buffer(terrainhandle, terraininfo.dynamic, terraininfo.declname)

    local groups = {}
    for i = 1, numlayers do
        groups[#groups + 1] = {
            vb = {handles = {vbh}},
            ib = {handle = ibh}
        }
    end

    mesh.assetinfo = {
        handle = {
            bounding = terrainhandle:bounding(),
            groups = groups
        }
    }
end