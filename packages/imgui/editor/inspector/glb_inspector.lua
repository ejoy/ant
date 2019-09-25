local imgui             = require "imgui_wrap"
local widget            = imgui.widget
local flags             = imgui.flags
local windows           = imgui.windows
local util              = imgui.util
local cursor            = imgui.cursor
local enum              = imgui.enum
local IO                = imgui.IO

local gui_util          = require "editor.gui_util"


local localfs = require "filesystem.local"

local glTF = import_package "ant.glTF"
local glb = glTF.glb

local assetmgr = import_package "ant.asset".mgr

local default_cfg = import_package "ant.fileconvert".default_cfg.mesh

local LAYOUT_CFG = {
    primTypeC2S = {
        p = "POSITION",
        n = "NORMAL",
        T = "TANGENT",
        b = "BITANGENT",
        t = "TEXCOORD",
        c = "COLOR",
        i = "INDICES",
        w = "WEIGHT",
    },
    primTypeS2C = {
        POSITION = "p",
        NORMAL = "n",
        TANGENT = "T",
        BITANGENT = "b",
        TEXCOORD = "t",
        COLOR = "c",
        INDICES = "i",
        WEIGHT = "w",
    },
    primTypeSort = {
        "POSITION",
        "NORMAL",
        "TANGENT",
        "BITANGENT",
        "TEXCOORD",
        "COLOR",
        "INDICES",
        "WEIGHT"
    },
    fieldSort = {
        "Name",
        "Count",
        "Channel",
        "Normalize",
        "IsInteger",
        "SaveType",
    },
    default = {
        Name = nil,
        Count = 3,
        Channel = 0,
        Normalize = false,
        IsInteger = false,
        SaveType = "FLOAT",
        Enable = true
    },
    saveTypeC2S = {
        f = "FLOAT",
        h = "HALF",
        u = "UINT8",
        U = "UINT10",
        i = "INT16",
    },
    saveTypeS2C = {
        FLOAT = "f",
        HALF = "h",
        UINT8 = "u",
        UINT10 = "U",
        INT16 = "i",
    },
    saveTypeSort = {
        "FLOAT",
        "HALF",
        "UINT8",
        "UINT10",
        "INT16",
    },
    AccessorType2Count = {
        SCALAR = 1,
        VEC2 = 2,
        VEC3 = 3,
        VEC4 = 4,
        MAT2 = 4,
        MAT3 = 9,
        MAT4 = 16,
    },
    ComponentType2Info = {
        [5120] = {"BYTE",true}, --type,isInt,
        [5121] = {"UNSIGNED_BYTE",true},
        [5122] = {"SHORT",true},
        [5123] = {"UNSIGNED_SHORT",true},
        [5125] = {"UNSIGNED_INT",true},
        [5126] = {"FLOAT",false},
    },
}

local function get_type_by_name( name )
    local ts,channel = nil,nil
    local c_index = string.find(name,"_")
    if c_index then
        ts = string.sub(name,1,c_index-1)
        channel = string.sub(name,c_index+1)
        channel = tonumber(channel)
    else
        ts = name
    end
    local tc = LAYOUT_CFG.primTypeS2C[ts]
    return ts,tc,channel
end

local function generate_glb_layout(glb_json_info)
    local result = {}
    repeat
        local mesh = glb_json_info.meshes and glb_json_info.meshes[1]

        if not mesh then break end
        local primitive = mesh.primitives and mesh.primitives[1]
        local attributes = primitive.attributes
        local accessors = glb_json_info.accessors
        for name,index in pairs(attributes) do
            local ts,tc,channel = get_type_by_name(name)
            result[ts] = result[ts] or {}
            local channels = result[ts]
            local channel_item = {Name=ts,Char=tc,Channel = channel}
            channels[channel or 0] = channel_item
            local accessor = accessors[index+1]
            channel_item.Count = LAYOUT_CFG.AccessorType2Count[accessor.type]
            assert(channel_item.Count)
            channel_item.Normalize = (tc=="n") -- normal need normalized
            channel_item.ComponentType = LAYOUT_CFG.ComponentType2Info[accessor.componentType][1]
            channel_item.IsInteger = LAYOUT_CFG.ComponentType2Info[accessor.componentType][2]
            channel_item.SaveType = "FLOAT"
        end
    until true
    return result
end

local function parse_layout(str)
    local i = 1
    local tbl = {}
    local cur = nil
    for c in str:gmatch(".") do
        if c == "|" then
            i = 1
            if cur then
                tbl[cur.Name] = tbl[cur.Name] or {}
                tbl[cur.Name][cur["Channel"]] = cur
                cur = nil
            end
        else
            if i == 1 then
                local name = LAYOUT_CFG.primTypeC2S[c]
                assert(name,"c:"..c)
                cur = setmetatable({},{__index=LAYOUT_CFG.default})
                cur.Name = name
            elseif i == 2 then
                cur["Count"] = tonumber(c)
            elseif i == 3 then
                cur["Channel"] = tonumber(c)
            elseif i == 4 then
                cur["Normalize"] = (c == "n")
            elseif i == 5 then
                cur["IsInteger"] = ( c == "i" )
            else
                cur["SaveType"] = LAYOUT_CFG.saveTypeC2S[c]
            end
            i = i + 1
        end
    end
    if cur then
        tbl[cur.Name] = tbl[cur.Name] or {}
        tbl[cur.Name][cur["Channel"]] = cur
    end
    local tbl_dump = dump_a({tbl},"\t")
    return tbl,tbl_dump
end


local function set_metatable_r(cfg,meta_cfg)
    for k,v in pairs(cfg) do
        if type(v) == "table" then
            set_metatable_r(v,meta_cfg[k])
        end
    end
    return setmetatable(cfg,{__index=meta_cfg})
end



local function single_layout(self,channeldata,parse_cache)
    --sub function
    local function copy_attr_from_layout(cfg,glb_layout_item)
        local change = false
        for _,field in ipairs(LAYOUT_CFG.fieldSort) do
            if cfg[field] ~= glb_layout_item[field] then
                cfg[field] = glb_layout_item[field]
                change = true
            end
        end
        return change
    end

    local cache_item = parse_cache[channeldata.Name] 
                        and parse_cache[channeldata.Name][channeldata.Channel or 0]
    local name = channeldata.Name
    if channeldata.Channel then
        name = name .. "_"..channeldata.Channel
    end
    
    if not cache_item then
        cache_item = setmetatable({},{__index=LAYOUT_CFG.default})
        cache_item.Enable = false
        copy_attr_from_layout(cache_item,channeldata)
        parse_cache[channeldata.Name] = parse_cache[channeldata.Name] or {}
        parse_cache[channeldata.Name][channeldata.Channel or 0] = cache_item
    end
    self:BeginColunms()
    local has_change,change = false,false
    change,cache_item.Enable = widget.Checkbox("###"..name,cache_item.Enable)
    if change then has_change = true end
    cursor.SameLine()
    local open =  widget.TreeNode(name)
    cursor.SameLine()
    cursor.NextColumn()
    if widget.Button("Reset from source") then
        if copy_attr_from_layout(cache_item,channeldata) then
            has_change = true
        end
    end
    cursor.NextColumn()
    if open then
        cursor.Indent()
        local change = false
        widget.Text("Count")
        cursor.NextColumn()
        widget.LabelText("###Count",tostring(cache_item.Count))
        cursor.NextColumn()
        widget.Text("Channel")
        cursor.NextColumn()
        widget.LabelText("###Channel",tostring(cache_item.Channel))
        cursor.NextColumn()
        widget.Text("Normalize")
        cursor.NextColumn()
        change,cache_item.Normalize = widget.Checkbox("###Normalize",cache_item.Normalize)
        if change then has_change = true end
        cursor.NextColumn()
        widget.Text("ReadAsInteger")
        cursor.NextColumn()
        change,cache_item.IsInteger = widget.Checkbox("###ReadAsInteger",cache_item.IsInteger)
        if change then has_change = true end
        local t = {cache_item.SaveType}
        cursor.NextColumn()
        widget.Text("SaveToType")
        cursor.NextColumn()
        if widget.BeginCombo("###SaveToType",t) then
            for _,v in ipairs(LAYOUT_CFG.saveTypeSort) do
                if widget.Selectable(v,t) then
                    if t[1] ~= v then
                        t[1] = v
                        cache_item.SaveType = v
                        change = true
                        has_change = true
                    end
                end
            end
            widget.EndCombo()
        end
        cursor.Unindent()
        widget.TreePop()
    end
    self:EndColunms()
    return has_change
end


local function display_layout(self,data_tbl,cfg)
    local layout_content = data_tbl[cfg.name]
    local str = layout_content[1]
    local parse_cache = layout_content[2]
    local list_dump = layout_content[3]
    if not parse_cache then
        parse_cache,list_dump = parse_layout(str)
    end
    layout_content[2] = parse_cache
    layout_content[3] = list_dump
    local ui_cache = layout_content[4]
    if not ui_cache then
        ui_cache = {}
        ui_cache[1] = {
            text = str,
            flags = flags.InputText{"ReadOnly"},
            width = -1,
        }
        ui_cache[2] = {
            text = list_dump,
            flags = flags.InputText{ "Multiline","ReadOnly"},
            width = -1,
        }
    end
    layout_content[4] = ui_cache
    local has_change = false
    if widget.TreeNode("layout##TreeNode",flags.TreeNode.DefaultOpen) then
        local change = widget.InputText("##raw",ui_cache[1])
        -- widget.InputText("##layoutdump",ui_cache[2])
        for _,typ in ipairs(LAYOUT_CFG.primTypeSort) do
            local channels = self.glb_info.layout[typ]
            if channels then
                for i = 0,#channels do
                    has_change = single_layout(self,channels[i],parse_cache) or has_change
                end
            end
        end
    end
    return has_change
end

local function create_layout_str(item)
    local len = 1
    for i,field in ipairs(LAYOUT_CFG.fieldSort) do
        if rawget(item,field) then
            len = i
        end
    end
    local tbl = {}
    for i = 1, len do
        local field = LAYOUT_CFG.fieldSort[i]
        local c
        local val = item[field]
        if field == "Name" then
            c = LAYOUT_CFG.primTypeS2C[val]
        elseif field == "Count" or field == "Channel" then
            c = tostring(val or 0)
        elseif field == "Normalize" then
            c = val and "n" or "N"
        elseif field == "IsInteger" then
            c = val and "i" or "I"
        elseif field == "SaveType" then
            c = LAYOUT_CFG.saveTypeS2C[val]
        end
        assert(c)
        table.insert(tbl,c)
    end
    return table.concat(tbl)
end

local function write_layout(self,data_tbl,cfg,tbl,indent)
    local layout_content = data_tbl[cfg.name]
    local result_str_tbl = {}
    local parse_cache = layout_content[2]
    for _,typ in ipairs(LAYOUT_CFG.primTypeSort) do
        local channels = parse_cache[typ]
        if channels then
            for i = 0,#channels do
                local str = create_layout_str(channels[i]) 
                table.insert(result_str_tbl,str)
            end
        end
    end
    local layout_str = table.concat(result_str_tbl,"|")
    table.insert(tbl,indent)
    table.insert(tbl,cfg.name)
    table.insert(tbl," = {\n")
    table.insert(tbl,indent .. '\t"')
    table.insert(tbl,layout_str)
    table.insert(tbl,'"\n'..indent..'},\n')
end

local function ani_list(self,data_tbl,meta_cfg)
    
end

local function write_ani_list(self,data_tbl,cfg,tbl,indent)
    table.insert(tbl,indent)
    table.insert(tbl,'ani_list = "all",\n')
end

local GLB_LK_META = {
    {
        name = "animation",
        field = {
            {
                name = "ani_list",
                field = ani_list,
                write = write_ani_list,
            },
            {
                name = "cpu_skinning",
                field = "boolean",
            },
            {
                name = "load_skeleton",
                field = "boolean",
            },
        },
    },
    {
        name = "flags",
        field = {
            {
                name = "flip_uv",
                field = "boolean",
            },
            {
                name = "ib_32",
                field = "boolean",
            },
            {
                name = "invert_normal",
                field = "boolean",
            },
        }
    },
    {
        name = "layout",
        field = display_layout,
        write = write_layout,
    },
}

local InspectorBase = require "editor.inspector.inspector_base"

local GLBInspector = InspectorBase.derive("GLBInspector")

function GLBInspector:_init()
    InspectorBase._init(self)
    self.res_ext = "glb"
    self.glb_info = nil
end

function GLBInspector:before_res_open()
    --glb
    local glb_path = self.res_pkg_path
    local local_path = gui_util.pkg_path_to_local(glb_path)
    local glb_content = glb.decode(local_path)
    local info = glb_content.info
    local version = glb_content.version
    local json = glb_content.json
    local layout_info = generate_glb_layout(info)
    self.glb_info = {
        info = info,
        json = json,
        version = version,
        layout = layout_info,
    }
    --lk
    local lk_path = local_path..".lk"
    local lk_info = gui_util.load_local_file(lk_path)
    local lk_cfg = (lk_info and lk_info.config) or {}
    self.lk_info = set_metatable_r(lk_cfg,default_cfg)
    self.glb_info_cache = nil
    self.lk_info_cache = nil
    if not lk_info or not lk_info.config then
        self.modified = true
    end
end

function GLBInspector:clean_modify()
    local local_path = gui_util.pkg_path_to_local(self.res_pkg_path)
    local lk_path = local_path..".lk"
    local lk_info = gui_util.load_local_file(lk_path)
    local lk_cfg = lk_info.config or {}
    self.lk_info = set_metatable_r(lk_cfg,default_cfg)
    self.lk_info_cache = nil
    self.modified = nil
end

function GLBInspector:on_apply_modify()
    local tbl = {}
    table.insert(tbl,"config = {\n")
    self:write_cfg(self.lk_info,GLB_LK_META,tbl,"\t")
    table.insert(tbl,"}\n")
    table.insert(tbl,'sourcetype = "glb"\n')
    table.insert(tbl,'type = "mesh"')
    local str = table.concat(tbl)
    log(str)
    local local_path = gui_util.pkg_path_to_local(self.res_pkg_path)
    local lk_path = local_path..".lk"
    local f = io.open(lk_path,"w")
    f:write(str)
    f:close()
    self.modified = nil
    local vfs           = require "vfs"
    vfs.clean_build(self.res_pkg_path:string())
    if assetmgr.has_res(self.res_pkg_path) then
        assetmgr.unload(self.res_pkg_path)
    end
end

function GLBInspector:on_update()
    self:BeginProperty()
    widget.Text(self.res_pkg_path:string())
    self:update_lk_info()
    if self.modified then
        if widget.Button("Revert") then
            self:clean_modify()
        end
        cursor.SameLine()
        if widget.Button("Apply") then
            self:on_apply_modify()
        end
    end
    self:update_glb_info()
    self:EndProperty()
end



function GLBInspector:update_lk_info()
    self.modified = self:show_import_cfg(self.lk_info,GLB_LK_META) or self.modified
end

function GLBInspector:update_glb_info()
    if widget.CollapsingHeader("GLB Info") then
        if not self.glb_info_cache then
            self.glb_info_cache = {
                text = self.glb_info.json,
                flags = flags.InputText{ "Multiline","ReadOnly"},
                width = -1,
                -- height = -1,
            }
        end
        widget.InputText("##detail",self.glb_info_cache)
    end
end

return GLBInspector