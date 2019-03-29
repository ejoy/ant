require "iuplua"
local log = log and log(...) or print
local iupcontrols = import_package "ant.iupcontrols"
local inputmgr = import_package "ant.inputmgr"
local pm = require "antpm"
local bgfx = require "bgfx"
-- local rhwi = import_package "ant.render".hardware_interface
local scene = import_package "ant.scene".util
local editor = import_package "ant.editor"
local mapiup = editor.mapiup
local task = editor.task
local renderpkg 	= import_package"ant.render"
local camera_util 	= renderpkg.camera
local render_util 	= renderpkg.util
local component_util= renderpkg.components
local view_id_mgr 	= renderpkg.viewidmgr
local fbmgr 		= renderpkg.renderpkg
local ms = import_package"ant.math".stack
local math3d = require "math3d"

local fs = require "filesystem"
local asset_view_hub = require "asset_view_hub"
-- local util = require "ant.util"

local asset_view = {}
asset_view.__index = asset_view

local packages = {"ant.testempty"}

local systems = {"asset_view_render_sys", "camera_controller",}

if __ANT_RUNTIME__ then
    local rt = require "runtime"
    rt.start(packages, systems)
    return
end

local DEFAULT_CANVAS_SIZE = 300

local CAM_CONTROL_CONFIG = {
    ["2d"] = {move = false,scale = true},
    ["3d"] = {move = true,scale = true},
    ["empty"] = {move = false,scale = false},
}

local DEAULT_TITLE = "preview"

local VIEW_TAG = "asset_view"


local function camera_reset(camera, cfg)
    local target = math3d.ref "vector"
    ms(target, cfg.target, "=")
    ms(camera.eyepos, cfg.eyepos, "=")
    ms(camera.viewdir, target, camera.eyepos, "-n=")
    print("camera.viewdir", tostring(camera.viewdir))
end

local camera_init_config = {
    ["2d"] = {eyepos = {0, 0, -8, 1}, target = {0, 0, 0, 1},},
    ["3d"] = {eyepos = {0, 8, -8, 1}, target = {0, 0, 0, 1},},
    ["empty"] = {eyepos = {0, 8, -8, 1}, target = {0, 0, 0, 1},}
}

function asset_view:_init_update()
    if self._mainloop then return end
    local task = editor.task
    local function mainloop()
        if self.maped and self:get_active() then
            self:update()
        end
    end
    task.loop(mainloop)
    self._mainloop = mainloop
end

function asset_view:_init()
    self._active = true
    self._mainloop = nil
    self.canvas = iup.canvas {EXPAND = "YES",BORDER = "NO"}
    self.hbox = iup.hbox {
        iup.space {},
        iup.vbox {
            iup.space {},
            self.canvas,
            iup.space {},
            ALIGNMENT = "ACENTER"
        },
        iup.space {},
        ALIGNMENT = "ACENTER"
    }
    -- print("self.hbox[1]:",self.hbox[1])
    local args = self.iup_args or {}
    table.insert(args,self.hbox)
    args.BGCOLOR = "#303030"
    args.TITLE = DEAULT_TITLE
    self.frame = iup.frame(args)
    self.maped = false
    self.cur_model_ids = {}
    self._current_frame_buffer = nil
    self.current_type = nil
    self._canvas_size = {DEFAULT_CANVAS_SIZE,DEFAULT_CANVAS_SIZE}
    self:_init_update()
    asset_view_hub.subscribe(self)
    
    self.canvas.resize_cb = function()
        self:_on_canvas_resize()
    end
    self.canvas.map_cb = function()
        self:_on_canvas_map()
        self:_on_canvas_resize()
    end

    self.canvas.unmap_cb = function()
        self:_on_canvas_unmap()
    end
end

function asset_view:_on_canvas_resize()
    if not self.frame.clientsize then return end
    --make sure canvas.width == height and expand to biggest
    local w,h = string.match(self.frame.clientsize,"(%d*)x(%d*)")
    w,h = tonumber(w),tonumber(h)
    if w > h then
        local fill_w = w-h
        local half_w = math.floor(fill_w*0.5)
        self.hbox[1]["RASTERSIZE"] = string.format("%dx%d",half_w,h)
        self.hbox[3]["RASTERSIZE"] = string.format("%dx%d",fill_w-half_w,h)
        self.hbox[2][1]["RASTERSIZE"] = "0x0"
        self.hbox[2][3]["RASTERSIZE"] = "0x0"
    else
        local fill_h = h-w
        local half_h = math.floor(fill_h*0.5)
        self.hbox[1]["RASTERSIZE"] = "0x0"
        self.hbox[3]["RASTERSIZE"] = "0x0"
        self.hbox[2][1]["RASTERSIZE"] = string.format("%dx%d",w,half_h)
        self.hbox[2][3]["RASTERSIZE"] = string.format("%dx%d",w,fill_h-half_h)
    end
    self._canvas_size = {w,h}
end

function asset_view:_on_canvas_map()
    if not self.world then
        local input_queue = inputmgr.queue()
        mapiup(input_queue, self.canvas)
        input_queue.world = "normal_world"
		local hwnd = iup.GetAttributeData(self.canvas, "HWND")
		fbmgr.bind_native_handle("assetview", hwnd)
        local fb_width, fb_height = self._canvas_size[1],self._canvas_size[2]
        print("self.canvas:DrawGetSize()",fb_width,fb_height)
        
		self.world = scene.start_new_world(input_queue, fb_width, fb_height, packages, systems)		
		--self:_create_frame_buffer(hwnd,fb_width,fb_height,self.view_id)
		
        -- -----create 3d camera
        -- local camera_eid_3d = render_util.create_general_render_queue(
        --     self.world,
        --     {w=fb_width, h=fb_height},
        --     "asset_viewtag_3d",
        --     self.view_id
        -- )
        -- -- self.world:add_component(camera_eid_3d, "camera_control", true)
        -- self.world:add_component(camera_eid_3d, "show_light", true)
        -- self.world:add_component(camera_eid_3d, "show_grid", true)
        -- self.world[camera_eid_3d].testname = "camera3d"
		-- self.world[camera_eid_3d].visible = false
		
		local default_viewdir = { -25, -45, 0, 0 }
		local default_eyepos = { 5, 5, -5, 1 }

		local function default_camera()
			return {
				type = "assetview",
				eyepos = default_eyepos,
				viewdir = default_viewdir,
				updir = {0, 1, 0, 0},
				frustum = {
					type = "mat",
					n = 0.1, f = 100000,
					fov = 60, aspect = fb_width / fb_height,
				},
			}
		end

		local function default_viewport()
			return {
				rect = {x=0,y=0,w=fb_width,h=fb_height},
				clear_state = {
					color = 0x303030ff,
					depth = 1,
					stencil = 0,
				},
			}
		end

		local function default_primitive_filter(viewtag)
			{
				view_tag = viewtag,
				filter_tag = "can_render",
			},
		end

		local camera_eid_3d = self.world:create_entity {
			camera = default_camera(),
			render_target = {
				viewport = default_viewport(),
				wnd_frame_buffer = {
					wndhandle = {
						name = "asset_view",
					},
					w = fb_width,
					h = fb_height,
				},
			},
			viewid = self.view_id,
			primitive_filter = default_primitive_filter "asset_viewtag_3d",
			name = "camera3d",
			show_light = true,
			show_grid = true,
			visible = false,
		}

        -----create 2d camera
        -- local camera_eid_2d = render_util.create_general_render_queue(
        --     self.world,
        --     {w=fb_width, h=fb_height},
        --     "asset_viewtag_2d",
        --     self.view_id
		-- )
		local camera_eid_2d = self.world:create_entity {
			camera = default_camera(),
			render_target = {
				viewport = default_viewport(),
			},
			viewid = self.view_id,
			primitive_filter = default_primitive_filter "asset_viewtag_2d",
			show_light = true,
			name = "camera2d",
			visible = false,
		}

        -- self.world:add_component(
        --     camera_eid_2d,
        --     "camera_control",
        --     {move = false, scale = true}
        -- )
        -- self.world:add_component(camera_eid_2d, "show_light", true)
        -- local camera_2d = self.world[camera_eid_2d]
        -- camera_2d.testname = "camera2d"
        -- camera_2d.visible = false
        -- print_a(">.>>>>", camera_2d.camera_control)
        -- -- camera_2d.camera_control.move = false
        local camera_2d = self.world[camera_eid_2d]
        camera_reset(
            camera_2d.camera,
            camera_init_config["2d"]
        )

        -----create 2d quad entity 
        local texture_tbl = {
            s_texColor = {
                name = "tex color",
                ref_path = fs.path "//ant.resources/PVPScene/siegeweapon_d.texture",
                stage = 0,
                type = "texture",
            }
        }
        self.texture_id = component_util.create_quad_entity(self.world, texture_tbl, "asset_viewtag_2d")

        -----create empty camera
        local camera_eid_empty = render_util.create_general_render_queue(
            self.world,
            {w=fb_width, h=fb_height},
            "asset_viewtag_empty",
            self.view_id
        )
        -- self.world:add_component(camera_eid_3d, "camera_control", true)
        self.world[camera_eid_empty].name = "camera_empty"
        self.world[camera_eid_empty].visible = true

        self.camera_id_dic = {["2d"] = camera_eid_2d, 
                            ["3d"] = camera_eid_3d, 
                            ["empty"]=camera_eid_empty}
        self:show_camera("empty")

        task.loop(scene.loop(self.world,{update = {"timesystem", "message_system"}}))
        self.world_update_func = self.world:update_func("update", {"timesystem", "message_system"})

    end
    self.maped = true
end

function asset_view:_create_frame_buffer(hwnd,w,h,viewid)
    render_util.create_frame_buffer(self.world,hwnd,w,h,viewid)
    -- if self._current_frame_buffer then
    --     bgfx.destroy(self._current_frame_buffer)
    --     self._current_frame_buffer = nil
    -- end
    -- local hwnd = iup.GetAttributeData(self.canvas, "HWND")
    -- local fb = bgfx.create_frame_buffer(hwnd, self._canvas_size[1], self._canvas_size[2])
    -- self._current_frame_buffer = fb

end

function asset_view:_on_canvas_unmap()
    self.maped = false 
end


function asset_view:set_active(value)
    self._active = (value and true) or false
end
function asset_view:get_active(value) 
    return self._active 
end

function asset_view:create_foucs_entity(mesh, material)
    if material == nil then
        material = {
            content = {
                {
                    ref_path = fs.path "//ant.resources/singlecolor.material"
                }
            }
        }
    end
    local math = require "math"

    local id = self.world:create_entity{
        transform = {           
            s = {1, 1, 1, 0},
            r = {0, 0, 0, 0},
            t = {0, 0, 0, 1},
        },
        can_render = true,
        mesh = {ref_path = mesh},
        material = material,
        asset_viewtag_3d = true,
    }
    return id
end

-- value = "2d"/"3d" or nil
function asset_view:show_camera(value)
    if value == self.current_type then return end
    if self.current_type then
        local current_camera_eid = self.camera_id_dic[self.current_type]
        local current_camera = self.world[current_camera_eid]
        self.world:remove_component(current_camera_eid, "camera_control")
        current_camera.visible = false
    end
    value = value or "empty"
    self.current_type = value
    local new_camera_id = self.camera_id_dic[self.current_type]
    local new_camera = self.world[new_camera_id]
    self.world:add_component(
        new_camera_id,
        "camera_control",
        CAM_CONTROL_CONFIG[value]
    )
    new_camera.visible = true
    camera_reset(new_camera.camera, camera_init_config[value])
end

function asset_view:clear_cur_models()
    for _, eid in ipairs(self.cur_model_ids) do
        print("remove_id:", eid)
        self.world:remove_entity(eid)
    end
    self.cur_model_ids = {}
end

-- {"ant.resources", "PVPScene/siegeweapon_d.texture"}
function asset_view:set_texture(texture_res)
    print(self.texture_id)
    if self.texture_id then
        local entity = self.world[self.texture_id]
        local texture_tbl = {
            s_texColor = {
                name = "tex color",
                ref_path = texture_res,
                stage = 0,
                type = "texture",
            }
        }
        component_util.change_textures(entity["material"].content[1], texture_tbl)
        self:show_camera("2d")
    else
        print("not model to set")
    end
end

function asset_view:set_model(model_res)
    self:clear_cur_models()
    self.cur_model_ids = {self:create_foucs_entity(model_res, nil)}
    self:show_camera("3d")
end

-- selected_res:[ref_path]
function asset_view:set_select_files(selected_res)
    print_a(selected_res)
    if #selected_res == 0 then
        self:clear_cur_models()
        self:show_camera(nil)
        self.frame.title = DEAULT_TITLE
    else
        local first_ref_path = selected_res[1]
        local filetype = (first_ref_path:extension()):string()
        -- local filepath = (first_ref_path.filename):string()
        -- local filename =  ((first_ref_path.filename):filename()):string()

        print_a("first_ref_path:",first_ref_path,filetype)
        if filetype == ".texture" then
            self:set_texture(first_ref_path)
            self.frame.title = filename
        elseif filetype == ".mesh" then
            self:set_model(first_ref_path)
            self.frame.title = filename
        else
            print(string.format("Viewer for [%s] not supported",filetype))
            self:show_camera(nil)
            self.frame.title = DEAULT_TITLE
        end
    end

end


function asset_view:get_view()
    if not self.frame then self:_init() end
    return self.frame
end

function asset_view:destroy()
    bgfx.set_view_frame_buffer(self.view_id)
    -- view_id_mgr.release_view_id(self.view_id)
    self.view_id = nil
    bgfx.destroy(self.fbh)
    self.fbh = nil
end

function asset_view:update()
    self.world_update_func()
end

function asset_view.new(iup_args)
    local view_id = view_id_mgr.generate(VIEW_TAG)
    if not view_id then log("Can't create more asset_view,max_num") end
    local ins = setmetatable({}, asset_view)
    ins.view_id = view_id
    ins.iup_args = iup_args
    return ins
end

return asset_view

