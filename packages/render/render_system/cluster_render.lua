local ecs = ...
local world = ecs.world
local crs = ecs.system "cluster_render_system"

-- cluster [forward] render system
--1. build cluster aabb
--2. find visble cluster. [opt]
--3. cull lights
--4. shading

local function create_cluster_render_queue()
    
end

local function cull_lights()
    
end

function crs:init()
    local eid = create_cluster_render_queue()
end

function crs:data_changed()

end

function crs:render_preprocess()
    cull_lights()
end

function crs:render_submit()
    
end