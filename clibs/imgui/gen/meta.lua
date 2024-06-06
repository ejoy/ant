local TodoFunction <const> = {
    ImGui_GetStyle = true,
    ImGui_GetDrawData = true,
    ImGui_ShowDemoWindow = true,
    ImGui_ShowMetricsWindow = true,
    ImGui_ShowDebugLogWindow = true,
    ImGui_ShowIDStackToolWindow = true,
    ImGui_ShowIDStackToolWindowEx = true,
    ImGui_ShowAboutWindow = true,
    ImGui_ShowStyleEditor = true,
    ImGui_ShowStyleSelector = true,
    ImGui_ShowFontSelector = true,
    ImGui_ShowUserGuide = true,
    ImGui_StyleColorsDark = true,
    ImGui_StyleColorsLight = true,
    ImGui_StyleColorsClassic = true,

    ImGui_Columns = true,
    ImGui_ColumnsEx = true,
    ImGui_NextColumn = true,
    ImGui_GetColumnIndex = true,
    ImGui_GetColumnWidth = true,
    ImGui_SetColumnWidth = true,
    ImGui_GetColumnOffset = true,
    ImGui_SetColumnOffset = true,
    ImGui_GetColumnsCount = true,

    ImGui_LogToTTY = true,
    ImGui_LogToFile = true,
    ImGui_LogToClipboard = true,
    ImGui_LogFinish = true,
    ImGui_LogButtons = true,
    ImGui_LogText = true,
    ImGui_LogTextUnformatted = true,
    ImGui_LogTextV = true,

    ImGui_SetAllocatorFunctions = true,
    ImGui_GetAllocatorFunctions = true,
    ImGui_MemAlloc = true,
    ImGui_MemFree = true,

    ImGui_DebugTextEncoding = true,
    ImGui_DebugFlashStyleColor = true,
    ImGui_DebugStartItemPicker = true,
    ImGui_DebugCheckVersionAndDataLayout = true,

    ImGui_GetPlatformIO = true,

    ImGui_TextUnformatted = true,
    ImGui_TextUnformattedEx = true,
    ImGui_TextV = true,
    ImGui_TextColoredUnformatted = true,
    ImGui_TextColoredV = true,
    ImGui_TextDisabledUnformatted = true,
    ImGui_TextDisabledV = true,
    ImGui_TextWrappedUnformatted = true,
    ImGui_TextWrappedV = true,
    ImGui_LabelTextUnformatted = true,
    ImGui_LabelTextV = true,
    ImGui_BulletTextUnformatted = true,
    ImGui_BulletTextV = true,

    ImGui_SetTooltipUnformatted = true,
    ImGui_SetTooltipV = true,
    ImGui_SetItemTooltipUnformatted = true,
    ImGui_SetItemTooltipV = true,
    ImGui_TreeNodeStrUnformatted = true,
    ImGui_TreeNodePtrUnformatted = true,
    ImGui_TreeNodeV = true,
    ImGui_TreeNodeVPtr = true,
    ImGui_TreeNodeExStrUnformatted = true,
    ImGui_TreeNodeExPtrUnformatted = true,
    ImGui_TreeNodeExV = true,
    ImGui_TreeNodeExVPtr = true,

    ImGui_ColorConvertRGBtoHSV = true,
    ImGui_ColorConvertHSVtoRGB = true,

    ImGui_TableGetSortSpecs = true,
    ImGui_DockSpaceOverViewportEx = true,
    ImGui_GetBackgroundDrawList = true,
    ImGui_GetForegroundDrawList = true,
    ImGui_GetBackgroundDrawListImGuiViewportPtr = true,
    ImGui_GetForegroundDrawListImGuiViewportPtr = true,
    ImGui_GetDrawListSharedData = true,
    ImGui_SetStateStorage = true,
    ImGui_GetStateStorage = true,
    ImGui_IsMousePosValid = true,

    ImGui_PlotLines = true,
    ImGui_PlotLinesEx = true,
    ImGui_PlotLinesCallback = true,
    ImGui_PlotLinesCallbackEx = true,
    ImGui_PlotHistogram = true,
    ImGui_PlotHistogramEx = true,
    ImGui_PlotHistogramCallback = true,
    ImGui_PlotHistogramCallbackEx = true,

    ImGui_ListBox = true,
    ImGui_ListBoxCallback = true,
    ImGui_ListBoxCallbackEx = true,

    ImGui_ColorPicker4 = true,

    ImGui_InputScalar = true,
    ImGui_InputScalarEx = true,
    ImGui_InputScalarN = true,
    ImGui_InputScalarNEx = true,
    ImGui_DragScalar = true,
    ImGui_DragScalarEx = true,
    ImGui_DragScalarN = true,
    ImGui_DragScalarNEx = true,
    ImGui_SliderScalar = true,
    ImGui_SliderScalarEx = true,
    ImGui_SliderScalarN = true,
    ImGui_SliderScalarNEx = true,
    ImGui_VSliderScalar = true,
    ImGui_VSliderScalarEx = true,
    ImGui_VSliderScalarN = true,
    ImGui_VSliderScalarNEx = true,

    ImGui_GetWindowDrawList  = true,
    ImGui_SetNextWindowSizeConstraints = true,
    ImGui_ComboChar = true,
    ImGui_ComboCharEx = true,
    ImGui_ComboCallback = true,
    ImGui_ComboCallbackEx = true,
    ImFontAtlas_GetTexDataAsAlpha8 = true,
    ImFontAtlas_GetTexDataAsRGBA32 = true,
    ImFontAtlas_GetCustomRectByIndex = true,
}

local TodoStruct <const> = {
    ImFont = true,
    ImFontGlyph = true,
    ImFontGlyphRangesBuilder = true,
    ImFontAtlasCustomRect = true,
    ImFontBuilderIO = true,
    ImDrawData = true,
    ImDrawList = true,
    ImDrawCmd = true,
    ImDrawListSplitter = true,
    ImDrawListSharedData = true,
    ImDrawVert = true,
    ImGuiTextBuffer = true,
    ImGuiListClipper = true,
    ImGuiPayload = true,
    ImGuiStyle = true,
    ImGuiTableSortSpecs = true,
    ImGuiPlatformIO = true,
    ImGuiPlatformMonitor = true,
    ImGuiPlatformImeData = true,
    ImGuiTableColumnSortSpecs = true,
    ImGuiSizeCallbackData = true,
}

local TodoType <const> = {
    ImTextureID = true,
    ImGuiKeyChord = true,
}

local Reference <const> = {
    ImGuiIO = true,
    ImGuiPlatformIO = true,
}

local BuiltinLuaType <const> = {
    ["signed char"] = "integer",
    ["unsigned char"] = "integer",
    ["signed short"] = "integer",
    ["unsigned short"] = "integer",
    ["signed int"] = "integer",
    ["unsigned int"] = "integer",
    ["signed long long"] = "integer",
    ["unsigned long long"] = "integer",
}

local Readonly <const> = {
    ImGuiViewport = true,
}

local Marcos <const> = {
    IMGUI_DISABLE_OBSOLETE_KEYIO = true,
    IMGUI_DISABLE_OBSOLETE_FUNCTIONS = true,
    IMGUI_USE_WCHAR32 = true,
}

local function conditionals(t)
    local cond = t.conditionals
    if not cond then
        return true
    end
    assert(#cond == 1)
    cond = cond[1]
    if cond.condition == "ifndef" then
        if Marcos[cond.expression] then
            return
        end
        return true
    elseif cond.condition == "ifdef" then
        if Marcos[cond.expression] then
            return true
        end
        return
    end
    assert(false, t.name)
end

local function allow_function(func_meta)
    if func_meta.is_internal then
        return
    end
    if func_meta.is_manual_helper then
        return
    end
    if func_meta.original_class then
        if func_meta.original_fully_qualified_name:match "^_" then
            return
        end
    end
    if not conditionals(func_meta) then
        return
    end
    if TodoFunction[func_meta.name] then
        return
    end
    return true
end

local function allow_struct(struct_meta)
    local name = struct_meta.name
    if struct_meta.is_internal then
        return
    end
    if struct_meta.is_anonymous then
        return
    end
    if struct_meta.by_value then
        return
    end
    if name:match "^ImVector_" then
        return
    end
    if TodoStruct[name] then
        return
    end
    return true
end

local function is_function_pointer(meta)
    if not meta.type.type_details then
        return
    end
    return meta.type.type_details.flavour == "function_pointer"
end

local function assert_lua_type(typename, types)
    if BuiltinLuaType[typename] then
        return
    end
    assert(types[typename], typename)
end

local function cimgui_json(AntDir)
    local json = dofile(AntDir.."/pkg/ant.json/main.lua")
    local function readall(path)
        local f <close> = assert(io.open(path, "rb"))
        return f:read "a"
    end
    return json.decode(readall(AntDir.."/clibs/imgui/dear_bindings/cimgui.json"))
end

local m = {}

function m.init(status)
    local meta = cimgui_json(status.AntDir)
    local types = {}
    local flags = {}
    local enums = {}
    local funcs = {}
    local structs = {}
    for _, struct_meta in ipairs(meta.structs) do
        if not allow_struct(struct_meta) then
            goto continue
        end
        local name = struct_meta.name
        local mode = Readonly[name] and "const_pointer" or "pointer"
        local struct = {
            name = name,
            mode = mode,
            reference = Reference[name],
            fields = struct_meta.fields,
            forward_declaration = struct_meta.forward_declaration,
        }
        structs[name] = struct
        structs[#structs+1] = struct
        ::continue::
    end
    for _, enum_meta in ipairs(meta.enums) do
        if not conditionals(enum_meta) then
            goto continue
        end
        local realname = enum_meta.name:match "(.-)_?$"
        if enum_meta.is_flags_enum then
            local elements = {}
            local name = realname:match "^ImGui(%a+)$" or realname:match "^Im(%a+)$"
            local flag = {
                name = name,
                realname = realname,
                elements = elements,
                comments = enum_meta.comments,
            }
            flags[realname] = flag
            flags[#flags+1] = flag
            for _, element in ipairs(enum_meta.elements) do
                if not element.is_internal and not element.is_count and not element.conditionals then
                    local enum_name = element.name:match "^%w+_(%w+)$"
                    elements[#elements+1] = {
                        name = enum_name,
                        value = element.value,
                        comments = element.comments,
                    }
                end
            end
        else
            local elements = {}
            local name = realname:match "^ImGui(%a+)$"
            local enum = {
                name = name,
                realname = realname,
                elements = elements,
                comments = enum_meta.comments,
            }
            enums[realname] = enum
            enums[#enums+1] = enum
            for _, element in ipairs(enum_meta.elements) do
                if not element.is_internal and not element.is_count and not element.conditionals then
                    local enum_type, enum_name = element.name:match "^(%w+)_(%w+)$"
                    if enum_type ~= realname then
                        local t = enums[enum_type]
                        if t then
                            t.elements[#t.elements+1] = {
                                name = enum_name,
                                value = element.value,
                                comments = element.comments,
                            }
                        else
                            local name = enum_type:match "^ImGui(%a+)$" or realname:match "^Im(%a+)$"
                            local enum = {
                                name = name,
                                realname = enum_type,
                                elements = {{
                                    name = enum_name,
                                    value = element.value,
                                    comments = element.comments,
                                }},
                            }
                            enums[enum_type] = enum
                            enums[#enums+1] = enum
                        end
                    else
                        elements[#elements+1] = {
                            name = enum_name,
                            value = element.value,
                            comments = element.comments,
                        }
                    end
                end
            end
        end
        ::continue::
    end
    for _, func_meta in ipairs(meta.functions) do
        if allow_function(func_meta) then
            if func_meta.original_class then
                if structs[func_meta.original_class] then
                    local v = structs[func_meta.original_class].funcs
                    if v then
                        v[#v+1] = func_meta
                    else
                        structs[func_meta.original_class].funcs= { func_meta }
                    end
                end
            else
                funcs[#funcs+1] = func_meta
            end
        end
    end
    for _, typedef_meta in ipairs(meta.typedefs) do
        if conditionals(typedef_meta)
            and not TodoType[typedef_meta.name]
            and not flags[typedef_meta.name]
            and not enums[typedef_meta.name]
            and not is_function_pointer(typedef_meta)
        then
            assert_lua_type(typedef_meta.type.declaration, types)
            local type = {
                name = typedef_meta.name,
                type = typedef_meta.type.declaration,
            }
            types[type.name] = type
            types[#types+1] = type
        end
    end
    status.types = types
    status.structs = structs
    status.flags = flags
    status.enums = enums
    status.funcs = funcs
end

return m
