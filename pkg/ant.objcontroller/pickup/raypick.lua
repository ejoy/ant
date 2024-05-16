local ecs   = ...
local world = ecs.world
local w     = world.w

local meshpkg = import_package "ant.mesh"
local mathpkg = import_package "ant.math"
local mc      = mathpkg.constant

local IDENTITY_MAT<const> = mc.IDENTITY_MAT

--TODO: maybe we should separate this triagnles's buffer to index base triangles
local TRIANGLES = {}
local irp = {}

function irp.add_triangles()
end

function irp.from_prefab_mesh(prefab)
end

function irp.from_mesh(meshres, transform)
    transform = transform or IDENTITY_MAT
    local mo = mathpkg.create(meshres, transform)

    for i=1, mo:numv() do
        
    end
end

function irp.find(screenx, screeny, viewrect, camera)
end

return irp