local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

local fs        = require "filesystem"
local datalist  = require "datalist"

local imesh     = ecs.import.interface "ant.asset|imesh"

local quad_ts = ecs.system "shape_terrain_system"

local function read_terrain_field(tf)
    if type(tf) == "string" then
        return datalist.parse(fs.open(fs.path(tf)):read "a")
    end

    return tf
end

local function is_power_of_2(n)
	if n ~= 0 then
		local l = math.log(n, 2)
		return math.ceil(l) == math.floor(l)
	end
end

local layout_name<const> = declmgr.correct_layout "p3|c40niu|t20"
local memfmt<const> = declmgr.vertex_desc_str(layout_name)

local function add_cube(vb, offset, color, unit)
    local x, y, z = offset[1], offset[2], offset[3]
    local nx, nz = x+unit, z+unit
    --TODO: how the uv work??
    --we need 24 vertices for a cube, and no ib buffer
    --compress this data:
    --  x, y, z for int16
    --  uv for int16/int8?
    local v = {
         x, 0.0,  z, color, 1.0, 0.0,
         x, 0.0, nz, color, 1.0, 1.0,
        nx, 0.0, nz, color, 0.0, 1.0,
        nx, 0.0,  z, color, 0.0, 0.0,
         x, y,    z, color, 0.0, 0.0,
         x, y,   nz, color, 0.0, 1.0,
        nx, y,   nz, color, 1.0, 1.0,
        nx, y,    z, color, 1.0, 0.0,
    }

    table.move(v, 1, #v, #vb+1, vb)
end

--[[
     5-------6
    /       /|
   /       / |
  4-------7  2
  |       |  /
  |       | /
  0-------3
]]

local default_cube_ib<const> = {
    --bottom
    3, 2, 1,
    1, 0, 3,
    --top
    4, 5, 6,
    6, 7, 4,
    --left
    1, 5, 4,
    4, 0, 1,
    --right
    3, 7, 6,
    6, 2, 3,
    --front
    0, 4, 7,
    7, 3, 0,
    --back
    2, 6, 5,
    5, 1, 2,
}

local function add_cube_ib(ib, offset)
    for i=1, #default_cube_ib do
        ib[#ib+1] = default_cube_ib[i] + offset
    end
end

local function add_quad(vb, offset, color, unit)
    local x, y, z = offset[1], 0.0, offset[2]
    local nx, nz = x+unit, z+unit
    local v = {
        x, y,    z, color, 0.0, 0.0,
        x, y,   nz, color, 0.0, 1.0,
       nx, y,   nz, color, 1.0, 1.0,
       nx, y,    z, color, 1.0, 0.0,
    }

    table.move(v, 1, #v, #vb+1, vb)
end

local default_quad_ib<const> = {
    0, 1, 2,
    2, 3, 0,
}

local function add_quad_ib(ib, offset)
    for i=1, #default_quad_ib do
        ib[#ib+1] = default_quad_ib[i] + offset
    end
end


local function build_section_mesh(sectionsize, sectionidx, unit, cterrainfileds)
    local vb, ib = {}, {}
    for ih=1, sectionsize do
        for iw=1, sectionsize do
            local field = cterrainfileds:get_field(sectionidx, iw, ih)
            if field.type == "grass" or field.type == "dust" then
                local colors<const> = {
                    grass   = 0xff00ff00,
                    dust    = 0xff00ffff,
                }
                local iboffset = #vb // #memfmt
                local x, z = cterrainfileds:get_offset(sectionidx)
                local h = field.height or 0
                add_cube(vb, {iw+x, h, ih+z}, colors[field.type], unit)
                add_cube_ib(ib, iboffset)
            end
        end
    end

    return {
        vb = {
            start = 0,
            num = #vb // #memfmt,
            {
                declname = layout_name,
                memory = {
                    memfmt,
                    vb,
                }
            }
        },
        ib = {
            flag = 'd',
            start = 0,
            num = #ib,
            memory = {
                "d",
                ib,
            }
        }
    }
end

local function build_section_edge_mesh(sectionsize, sectionidx, unit, cterrainfileds)
    
end

local cterrain_fields = {}

function cterrain_fields.new(terrain_fields, sectionsize, width, height)
    return setmetatable({
        terrain_fields  = terrain_fields,
        section_size    = sectionsize,
        width           = width,
        height          = height,
    }, {__index=cterrain_fields})
end

--[[
    field:
        type: [none, grass, dust]
        height: 0.0
        edge: {left, right, top, bottom}
]]
function cterrain_fields:get_field(sidx, iw, ih)
    local ish = (sidx-1) // self.section_size
    local isw = (sidx-1) % self.section_size

    local offset = (ish * self.section_size+ih-1) * self.width +
                    isw * self.section_size + iw

    return self.terrain_fields[offset]
end

function cterrain_fields:get_offset(sidx)
    local ish = (sidx-1) // self.section_size
    local isw = (sidx-1) % self.section_size
    return isw * self.section_size, ish * self.section_size
end

function quad_ts:entity_init()
    for e in w:select "INIT shape_terrain:in material:in" do
        local st = e.shape_terrain

        if st.terrain_fields == nil then
            error "need define terrain_field, it should be file or table"
        end
        st.terrain_fields = read_terrain_field(st.terrain_fields)

        local width, height = st.width, st.height
        if width * height ~= #st.terrain_fields then
            error(("height_fields data is not equal 'width' and 'height':%d, %d"):format(width, height))
        end

        if not (is_power_of_2(width) and is_power_of_2(height)) then
            error(("one of the 'width' or 'heigth' is not power of 2"):format(width, height))
        end

        local ss = st.section_size
        if not is_power_of_2(ss) then
            error(("'section_size':%d, is not power of 2"):format(ss))
        end

        if ss == 0 or ss > width or ss > height then
            error(("invalid 'section_size':%d, larger than 'width' or 'height' or it is 0: %d, %d"):format(ss, width, height))
        end

        st.section_width, st.section_height = width // ss, height // ss
        st.num_section = st.section_width * st.section_height

        local unit = st.unit
        local material = e.material

        local ctf = cterrain_fields.new(st.terrain_fields, ss, width, height)

        for ih=1, st.section_height do
            for iw=1, st.section_width do
                local sectionidx = (ih-1) * st.section_width+iw
                
                ecs.create_entity{
                    policy = {
                        "ant.scene|scene_object",
                        "ant.render|simplerender",
                        "ant.general|name",
                    },
                    data = {
                        scene = {
                            srt = {}
                        },
                        simplemesh  = imesh.init_mesh(build_section_mesh(ss, sectionidx, unit, ctf)),
                        material    = material,
                        state       = "visible|selectable",
                        name        = "section" .. sectionidx,
                        shape_terrain_drawer = true,
                    }
                }

                -- ecs.create_entity {
                --     policy = {
                --         "ant.scene|scene_object",
                --         "ant.render|simplerender",
                --         "ant.general|name",
                --     },
                --     data = {
                --         scene = {
                --             srt = {}
                --         },
                --         material    = material,
                --         simplemesh  = imesh.init_mesh(build_section_edge_mesh(ss, sectionidx, unit, ctf)),
                --         state       = "visible|selectable",
                --         name        = "section_edge" .. sectionidx,
                --         shape_terrain_edge_drawer = true,
                --     }
                -- }
            end
        end
    end
end