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
local vertex_layout = declmgr.get(layout_name)

local function add_cube(vb, offset, color, unit)
    local x, y, z = offset[1], offset[2], offset[3]
    local nx, nz = x+unit, z+unit
    --TODO: how the uv work??
    local v = {
         x, 0.0,  z, 1.0, 0.0,
         x, 0.0, nz, 1.0, 1.0,
        nx, 0.0, nz, 0.0, 1.0,
        nx, 0.0,  z, 0.0, 0.0,
         x, y,    z, 0.0, 0.0,
         x, y,   nz, 0.0, 1.0,
        nx, y,   nz, 1.0, 1.0,
        nx, y,    z, 1.0, 0.0,
    }

    table.move(vb, 1, #vb+1, v)
end

local default_cube_ib<const> = {
    3, 2, 1,
    1, 0, 3,
    4, 5, 6,
    6, 7, 4,
}

local cube_ibs = {}

local function cube_setction_ib(sectionsize)
    local ib = cube_ibs[sectionsize]
    if ib == nil then
        local numelem = sectionsize*sectionsize
        local num_vertices<const> = 8
        ib = {}
        table.move(ib, 1, #ib+1, default_cube_ib)
        for i=2, numelem do
            for j=1, #default_cube_ib do
                ib[#ib+1] = default_cube_ib[j]+num_vertices
            end
        end

        cube_ibs[sectionsize] = ib
    end

    return ib
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

local quad_ibs = {}
local default_quad_ib<const> = {
    0, 1, 2,
    2, 3, 0,
}

local function add_quad_ib(ib, offset)
    for i=1, #default_quad_ib do
        ib[#ib+1] = default_quad_ib[i] + offset
    end
end

local function quad_setction_ib(sectionsize)
    local ib = quad_ibs[sectionsize]
    if ib == nil then
        ib = {}
        table.move(default_quad_ib, 1, #default_cube_ib, 1, ib)
        for i=2, sectionsize*sectionsize do
            for j=1, #default_quad_ib do
                ib[#ib+1] = default_quad_ib[j] + 4  --4 for quad vertex number
            end
        end

        quad_ibs[sectionsize] = ib
    end
    return ib
end


local function build_section_mesh(sectionsize, sectionidx, unit, cterrainfileds)
    local vb, ib = {}, {}
    local memfmt<const> = "fffdff"
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
                add_quad(vb, {iw+x, ih+z}, colors[field.type], unit)
                add_quad_ib(ib, iboffset)
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

                ecs.create_entity {
                    policy = {
                        "ant.scene|scene_object",
                        "ant.render|simplerender",
                        "ant.general|name",
                    },
                    data = {
                        scene = {
                            srt = {}
                        },
                        material    = material,
                        simplemesh  = imesh.init_mesh(build_section_edge_mesh(ss, sectionidx, unit, ctf)),
                        state       = "visible|selectable",
                        name        = "section_edge" .. sectionidx,
                        shape_terrain_edge_drawer = true,
                    }
                }
            end
        end
    end
end