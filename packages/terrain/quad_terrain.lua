local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

local fs        = require "filesystem"
local datalist  = require "datalist"

local imesh     = ecs.import.interface "ant.asset|imesh"

local quad_ts = ecs.system "quad_terrain_system"

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

local vertex_layout = declmgr.layout "p3|t20"

local function add_cube(vb, offset, unit)
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

local function add_quad(vb, offset, unit)
    local x, y, z = offset[1], 0.0, offset[2]
    local nx, nz = x+unit, z+unit
    local v = {
        x, y,    z, 0.0, 0.0,
        x, y,   nz, 0.0, 1.0,
       nx, y,   nz, 1.0, 1.0,
       nx, y,    z, 1.0, 0.0,
    }

    table.move(v, 1, #v, #vb+1, vb)
end

local quad_ibs = {}
local default_quad_ib<const> = {
    1, 2, 3,
    3, 4, 1,
}
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


local function build_section_mesh(sectionsize, sectionidx, unit, cheightfields)
    local vb = {}
    for iw=1, sectionsize do
        for ih=1, sectionsize do
            local field = cheightfields:get_field(sectionidx, iw, ih)
            if field.type == "grass" or field.type == "dust" then
                add_quad(vb, {iw, ih}, unit)
            end
        end
    end
    local ib = quad_setction_ib(sectionsize)
    local numelem = sectionsize * sectionsize
    local num_vertices = numelem * 4    --8 vertices
    return {
        vb = {
            start = 0,
            num = num_vertices,
            {
                "fffff",
                vb,
            }
        },
        ib = {
            flag = 'd',
            start = 0,
            num = numelem * 6, -- #default_cube_ib
            memory = {
                "d",
                ib,
            }
        }
    }
end

local cterrain_fields = {}

function cterrain_fields.new(height_fields, sectionsize, width, height)
    return setmetatable({
        height_fields   = height_fields,
        section_size    = sectionsize,
        width           = width,
        height          = height,
    }, {__index=cterrain_fields})
end

function cterrain_fields:get_field(sidx, iw, ih)
    local ish = (sidx-1) // self.section_size
    local isw = (sidx-1) % self.section_size

    local offset = (ish+ih-1) * self.section_size * self.width + 
                    isw * self.section_size + iw

    return self.height_fields[offset]
end

--[[
    field:
        type: [none, grass, dust]
        

]]

function quad_ts:entity_init()
    for e in w:select "INIT terrain_field:in" do
        e.terrain_field = read_terrain_field(e.terrain_field)
    end

    for e in w:select "INIT cube_terrain:in" do
        local ct = e.quad_terrain
        local width, height = ct.width, ct.height
        if width * height ~= #e.height_fields then
            error(("height_fields data is not equal 'width' and 'height':%d, %d"):format(width, height))
        end

        if not (is_power_of_2(width) and is_power_of_2(height)) then
            error(("one of the 'width' or 'heigth' is not power of 2"):format(width, height))
        end

        local ss = ct.section_size
        if not is_power_of_2(ss) then
            error(("'section_size':%d, is not power of 2"):format(ss))
        end

        if ss == 0 or ss > width or ss > height then
            error(("invalid 'section_size':%d, larger than 'width' or 'height' or it is 0: %d, %d"):format(ss, width, height))
        end

        ct.section_width, ct.section_height = width // ss, height // ss
        ct.num_section = ct.section_width * ct.section_height

        local unit = ct.unit
        local material = e.material

        local ctf = cterrain_fields.new(e.height_fields, ss, width, height)

        for ih=1, ct.section_height do
            for iw=1, ct.section_width do
                local sectionidx = (ih-1) * ct.section_width+iw
                
                ecs.create_entity{
                    policy = {
                        "ant.scene|scene_object",
                        "ant.terrain|simplerender",
                        "ant.general|name",
                    },
                    data = {
                        scene = {
                            srt = {
                                t = {}
                            }
                        },
                        simplemesh  = imesh.init_mesh(build_section_mesh(ss, sectionidx, unit, ctf)),
                        material    = material,
                        state       = "visible|selectable",
                        name        = "section" .. sectionidx,
                    }
                }
            end
        end
    end
end