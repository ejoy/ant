local imgui             = require "imgui_wrap"
local widget            = imgui.widget
local flags             = imgui.flags
local windows           = imgui.windows
local util              = imgui.util
local cursor            = imgui.cursor
local enum              = imgui.enum
local IO                = imgui.IO

local pm                = require "antpm"
local gui_input         = require "gui_input"
local gui_mgr           = require "gui_mgr"
local gui_util          = require "editor.gui_util"
local fs                = require "filesystem"
local lfs               = require "filesystem.local"

local project_data_accessor    = require "editor.projects.project_data_accessor"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local ProjectMgr = class("ProjectMgr")

function ProjectMgr:_init()
    self:_init_subcribe()
end

function ProjectMgr:getIns()
    if not ProjectMgr.ins then
        ProjectMgr.ins = ProjectMgr.new()
    end
end

---event process
function ProjectMgr:_init_subcribe()
    hub.subscribe(Event.ETE.RequestAddPackageToProject,self.on_request_add_package_to_project,self)
end

function ProjectMgr:on_request_add_package_to_project(typ,path)
    log.info("on_request_add_package_to_project:",typ,path)
    self:add_package_to_cur_project(typ,path)
end
---

function ProjectMgr:getCurProject()
end

function ProjectMgr:openProject()
end

function ProjectMgr:closeProject()
end

return ProjectMgr

