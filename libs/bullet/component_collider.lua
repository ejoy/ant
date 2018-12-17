local ecs = ...
local world = ecs.world
--[[
local box_collider = ecs.component "box_collider" {
    info = {
        type = "userdata",
        default = {
            type = "box",              
            center = {0,0,0},
            sx = 1, sy = 1, sz = 1, 
        },
        save = function(v,arg)
            print(v,arg)
        end,
        load = function(v,arg)
            print(v,arg)
        end,
        -- delete ,no exist ,datatype(gen_delete) ignore it
        -- delete = function (v, arg)
        --     print(v,arg)
        -- end  
    },
}
-- install delete function here for release
function box_collider:delete()
    -- if use message notify, decoupling will be better?
    local Physics = world.args.Physics     
    if Physics then
       Physics:delete_object( self.info.obj,self.info.shape)
    end 
    -- or use message notify mechanism
    print("delete box collider",self.info.type)
end 

-- the other collders same as box_collider
ecs.component "capsule_collider" {
    info = {
        type = "userdata",
        default = {
            center = {0,0,0},
            radius = 2,
            height = 6,
            axis = 1,
        }
    }
}

ecs.component "cylinder_collider" {
    info = {
        type = "userdata",
        default = {
            center = {0,0,0},
            radius = 2,
            height = 6,
            axis = 1,
        }
    }
}

ecs.component "sphere_collider" {
    info = {
        type = "userdata",
        default = {
            type = "sphere",
            center = {0,0,0},
            radius = 1,
        }
    }
}

ecs.component "plane_collider" {
    info = {
        type = "userdata",
        default = {
            center = {0,0,0},
            nx = 0,ny = 1 ,nz = 0,
            dist = 0,
        }
    }
}

--]] 

ecs.component_struct "terrain_collider" {
    info = {
        type = "userdata",
        default = {
            type = "terrain"
            -- auto building from terrain instance,just like unity,
            -- not parameters, but need a root stuff 
        }
    }
}

------
-- combine all collider component into one componet
-- so user could query it by only one name "collider"
local collider = ecs.component_struct "collider" {
    info = {
        type = "userdata",          -- for ecs 
        default = {                 -- for user 
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

        },
        -- serialize/unrerialize
        save = function(v,arg)
            print(v,arg)
        end,
        load = function(v,arg)
            print(v,arg)
        end,
        -- delete
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


    



