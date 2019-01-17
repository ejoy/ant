local ecs = ...
local world = ecs.world

ecs.component "terrain_collider" {
    info = {
        type = "terrain"
    }
}

------
-- combine all collider component into one componet
-- so user could query it by only one name "collider"
local collider = ecs.component "collider" {
    info = {                 -- for user 
        type = "box",           -- for collider component recognize type
        -- collider type string
        -- "box","sphere","cylinder","capsule","plane","compound","terrain"
        center = {0,0,0},
        sx = 1, sy = 1, sz = 1, 
        -- type: string
        -- params: size,radius etc
        -- [terrain]
           
        -- [box|cube]
        -- sx = 1, sy = 1, sz = 1, 
        -- [plane]
        -- nx = 0,ny = 1 ,nz = 0,
        -- dist = 0,
        -- [sphere]
        -- radius = 1,
        -- [capsule][cylinder]
        -- radius = 2,
        -- height = 6,
        -- axis = 1,
        -- runtime data,temporal
        obj = nil,
        shape = nil,
    }
}

-- install delete function here for release
function collider:delete()
    local Physics = world.args.Physics     -- if use message notify, decoupling will be better?
    if Physics then
        Physics:delete_object( self.info.obj,self.info.shape)
    end 
    -- or use message notify mechanism
    print("delete collider",self.info.type)
end


    



