local BlackList <const> = {
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
}

local TodoList <const> = {
    ImGui_TableGetSortSpecs = true,
    ImGui_DockSpace = true,
    ImGui_DockSpaceEx = true,
    ImGui_SetNextWindowClass = true,
    ImGui_DockSpaceOverViewportEx = true,
    ImGui_GetMainViewport = true,
    ImGui_GetBackgroundDrawList = true,
    ImGui_GetForegroundDrawList = true,
    ImGui_GetBackgroundDrawListImGuiViewportPtr = true,
    ImGui_GetForegroundDrawListImGuiViewportPtr = true,
    ImGui_IsRectVisibleBySize = true,
    ImGui_IsRectVisible = true,
    ImGui_GetTime = true,
    ImGui_GetFrameCount = true,
    ImGui_GetDrawListSharedData = true,
    ImGui_GetStyleColorName = true,
    ImGui_SetStateStorage = true,
    ImGui_GetStateStorage = true,
    ImGui_ColorConvertU32ToFloat4 = true,
    ImGui_ColorConvertFloat4ToU32 = true,
    ImGui_ColorConvertRGBtoHSV = true,
    ImGui_ColorConvertHSVtoRGB = true,
}

local function conditionals(t)
    local cond = t.conditionals
    if not cond then
        return true
    end
    assert(#cond == 1)
    cond = cond[1]
    if cond.condition == "ifndef" then
        cond = cond.expression
        if cond == "IMGUI_DISABLE_OBSOLETE_KEYIO" then
            return
        end
        if cond == "IMGUI_DISABLE_OBSOLETE_FUNCTIONS" then
            return
        end
    elseif cond.condition == "ifdef" then
        cond = cond.expression
        if cond == "IMGUI_DISABLE_OBSOLETE_KEYIO" then
            return true
        end
        if cond == "IMGUI_DISABLE_OBSOLETE_FUNCTIONS" then
            return true
        end
    end
    assert(false, t.name)
end

local s <const> = "ImGui_BeginTable"
local e <const> = "ImGui_IsKeyChordPressed"

local within_scope = false
local skip = false

local function init()
    within_scope = false
    skip = false
end

local function allow(func_meta)
    if func_meta.is_internal then
        return
    end
    if not conditionals(func_meta) then
        return
    end
    if BlackList[func_meta.name] then
        return
    end
    if TodoList[func_meta.name] then
        return
    end
    return true
end

local function query(func_meta)
    if skip then
        return "skip"
    end
    if within_scope then
        if func_meta.name == e then
            skip = true
        end
        if allow(func_meta) then
            return true
        end
    else
        if func_meta.name == s then
            within_scope = true
            if allow(func_meta) then
                return true
            end
        end
    end
    if skip then
        return "skip"
    end
    return false
end

return {
    init = init,
    query = query,
}
