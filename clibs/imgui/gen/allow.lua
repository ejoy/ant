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

    ImGui_SetAllocatorFunctions = true,
    ImGui_GetAllocatorFunctions = true,
    ImGui_MemAlloc = true,
    ImGui_MemFree = true,

    ImGui_DebugTextEncoding = true,
    ImGui_DebugFlashStyleColor = true,
    ImGui_DebugCheckVersionAndDataLayout = true,

    ImGui_GetPlatformIO = true,
    ImGui_UpdatePlatformWindows = true,
    ImGui_RenderPlatformWindowsDefault = true,
    ImGui_RenderPlatformWindowsDefaultEx = true,
    ImGui_DestroyPlatformWindows = true,
    ImGui_FindViewportByID = true,
    ImGui_FindViewportByPlatformHandle = true,

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
    ImGui_GetDrawListSharedData = true,
    ImGui_SetStateStorage = true,
    ImGui_GetStateStorage = true,
    ImGui_ColorConvertU32ToFloat4 = true,
    ImGui_ColorConvertFloat4ToU32 = true,
    ImGui_ColorConvertRGBtoHSV = true,
    ImGui_ColorConvertHSVtoRGB = true,
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

local s <const> = "ImGui_TreeNode"

local within_scope = false

local function init()
    within_scope = false
end

local function allow(func_meta)
    if func_meta.is_internal then
        return
    end
    if func_meta.is_manual_helper then
        return
    end
    if func_meta.original_class then
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
    if within_scope then
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
    return false
end

return {
    init = init,
    query = query,
}
