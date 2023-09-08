local ecs = ...
local world = ecs.world
local iom           = ecs.require "ant.objcontroller|obj_motion"
local ivs		    = ecs.require "ant.render|visible_state"
local computil      = ecs.require "ant.render|components.entity"
local irq           = ecs.require "ant.render|render_system.renderqueue"
local icamera       = ecs.require "ant.camera|camera"
local mathutils     = ecs.require "mathutils"
local camera_mgr    = ecs.require "camera.camera_manager"
local gridmesh_view = ecs.require "widget.gridmesh_view"
local brush_sys     = ecs.system "grid_brush_system"
local widget_utils  = require "widget.utils"
local math3d        = require "math3d"
local bgfx          = require "bgfx"
local utils         = require "common.utils"
local global_data   = require "common.global_data"
local brush_def     = require "brush_def"
--local default_color = {1.0, 1.0, 1.0, 0.5}
local current_brush_color = 0x7fffffff
local current_brush_id
local grid = {
    brush = {}
}
local brush_size = 1
local grid_vb
local grid_ib
local grid_eid

local function color_clamp(c)
    if c < 0 then return 0 end
    if c > 255 then return 255 end
    return c
end

local function fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

local function tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

local function get_brush_id(color)
    for i, c in ipairs(grid.brush) do
        if color == c then
            return i
        end
    end
    grid.brush[#grid.brush + 1] = color
    return #grid.brush
end

function grid:clear()
    if grid_eid then
        world.w:remove(grid_eid)
    end
end
local function clamp_row(row)
    if row > grid.row then row = grid.row end
    if row < 1 then row = 1 end
    return row
end
local function clamp_col(col)
    if col > grid.col then col = grid.col end
    if col < 1 then col = 1 end
    return col
end

local function set_color(irow, icol, color)
    local rad = brush_size - 1
    local start_row = clamp_row(irow - rad)
    local start_col = clamp_col(icol - rad)
    local end_row = clamp_row(irow + rad)
    local end_col = clamp_col(icol + rad)
    for row = start_row, end_row do
        for col = start_col, end_col do
            local vb_offset = ((row - 1) * grid.col + (col - 1)) * 4 * 4
            grid_vb[vb_offset + 4] = color
            grid_vb[vb_offset + 8] = color
            grid_vb[vb_offset + 12] = color
            grid_vb[vb_offset + 16] = color
            local vb = {}
            for i = vb_offset + 1, vb_offset + 16 do
                vb[#vb + 1] = grid_vb[i]
            end
            local e <close> = world.world:entity(grid_eid, "render_object:in")
            local vbdesc = e.render_object.vb
            bgfx.update(vbdesc.handles[1], vb_offset / 4, bgfx.memory_buffer("fffd", vb));
            grid.data[row][col][1] = current_brush_id
        end
    end
end

local function get_color(row, col)
    return grid_vb[((row - 1) * grid.col + (col - 1)) * 4 * 4 + 4]
end

function grid:init(size, row, col)
    self:clear()
    self.size = size
    self.row = row
    self.col = col
    self.total_width = size * col
    self.total_height = size * row
    self.data = {}
    self.visible = true
    grid_vb, grid_eid = computil.create_grid_mesh_entity(col, row, size, brush_def.color[1], "/pkg/ant.resources/materials/vertexcolor_nocull.material", "translucent")
    for i = 1, row do
        local rowdata = {}
        for j = 1, col do
            rowdata[#rowdata + 1] = {1}
        end
        self.data[#self.data + 1] = rowdata
    end
end

function grid:show(show)
    if not grid_eid then return end
    self.visible = show
    local e <close> = world.world:entity(grid_eid)
    ivs.set_state(e, "main_view", show)
end

function grid:load(path)
    local source = dofile(path)
    --local source = require(string.gsub(filename, "/", "."))
    if not source or not source.size or not source.row or not source.col then return end
    local color = {}
    for i = 1, source.row do
        local rowdata = {}
        for j = 1, source.col do
            local tile = source.data[i][j]
            rowdata[#rowdata + 1] = self.brush[tile[1]]
        end
        color[#color + 1] = rowdata
    end
    self:clear()
    grid_vb, grid_eid = computil.create_grid_mesh_entity(source.col, source.row, source.size, color, "/pkg/ant.resources/materials/vertexcolor_nocull.material", "translucent")
    self.size = source.size
    self.row = source.row
    self.col = source.col
    self.total_width = source.total_width
    self.total_height = source.total_height
    self.data = source.data
    self.filename = path
    self.visible = true
end

function grid:save(filename)
    if not filename then
        local newfilename = widget_utils.get_saveas_path("Lua", "lua")
        if not newfilename then return end
        self.filename = newfilename
    end

    local temp = utils.deep_copy(self)
    temp.filename = nil
    temp.show = nil
    temp.save = nil
    temp.init = nil
    temp.clear = nil
    temp.load = nil
    temp.brush = nil
    utils.write_file(self.filename, "return " .. utils.table_to_string(temp))
end

function brush_sys:init(size, row, col)
    gridmesh_view.set_grid(grid)
end

local function get_row_col(sx, sy)
    local c = icamera.find_camera(irq.main_camera())
    local rawpos = mathutils.ray_hit_plane(iom.ray(c.viewprojmat, {sx, sy}), {dir = {0,1,0}, pos = {0,0,0}})
    if not rawpos then
        return
    end
    local pos = math3d.totable(rawpos)
    local min_x, min_y = -0.5 * grid.total_width, -0.5 * grid.total_height
    local max_x, max_y = 0.5 * grid.total_width, 0.5 * grid.total_height
    if pos[1] < min_x or pos[1] > max_x or pos[3] < min_y or pos[3] > max_y then
        return
    else
        return math.floor((pos[3] - min_y) / grid.size) + 1, math.floor((pos[1] - min_x) / grid.size) + 1
    end
end

local last_row, last_col
local function on_row_col_select(row, col)
    if not row or not col or (last_row==row and last_col==col) then return end
    set_color(row, col, current_brush_color)
    last_row, last_col = row, col
end

local event_keyboard = world:sub{"keyboard"}
local event_mouse_down = world:sub {"mousedown"}
local event_mouseup = world:sub {"mouseup"}
local event_mouse_drag = world:sub {"mousedrag"}
local event_gridmesh = world:sub {"GridMesh"}

local event_reset = world:sub {"ResetEditor"}

local brush_state = false

function brush_sys:handle_event()
    if true then
        return
    end
    if not grid then return end

    for _, what in event_reset:unpack() do
        grid:clear()
    end

    for _, what, x, y in event_mouseup:unpack() do
		if what == "LEFT" then
            last_row, last_col = nil, nil
        end
    end

    for _, what, p1, p2, p3, p4 in event_gridmesh:unpack() do
        if what == "create" then
            grid:init(p1, p2, p3)
        elseif what == "brushcolor" then
            current_brush_id = p1
            current_brush_color = p2
        elseif what == "brushsize" then
            brush_size = p1
        end
    end

    for _, key, press, state in event_keyboard:unpack() do
        brush_state = state.CTRL
    end

    for _, what, sx, sy in event_mouse_down:unpack() do
		if what == "LEFT" and brush_state then
            on_row_col_select(get_row_col(sx, sy))
        end
    end
    
    for _, what, sx, sy, dx, dy in event_mouse_drag:unpack() do
		if what == "LEFT" and brush_state then
            on_row_col_select(get_row_col(sx, sy))
        end
    end
end

function brush_sys:post_init()

end