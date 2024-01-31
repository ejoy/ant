local BlackList <const> = {
    ImGui_GetCurrentContext = true,
    ImGui_SetCurrentContext = true,
    ImGui_GetIO = true,
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
    ImGui_GetVersion = true,
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
    ImGui_DebugCheckVersionAndDataLayout = true,

    ImGui_GetPlatformIO = true,
    ImGui_RenderPlatformWindowsDefaultEx = true,
    ImGui_DestroyPlatformWindows = true,
    ImGui_FindViewportByID = true,
    ImGui_FindViewportByPlatformHandle = true,

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
}

local TodoList <const> = {
    ImGui_TableGetSortSpecs = true,
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

    ImGui_InputText = true,
    ImGui_InputTextEx = true,
    ImGui_InputTextMultiline = true,
    ImGui_InputTextMultilineEx = true,
    ImGui_InputTextWithHint = true,
    ImGui_InputTextWithHintEx = true,

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
    ImGui_GetWindowViewport = true,
    ImGui_SetNextWindowSizeConstraints = true,
    ImGui_PushFont = true,
    ImGui_PopFont = true,
    ImGui_GetFont = true,
    ImGui_ComboChar = true,
    ImGui_ComboCharEx = true,
    ImGui_ComboCallback = true,
    ImGui_ComboCallbackEx = true,
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

return {
    allow = allow,
    conditionals = conditionals,
}
