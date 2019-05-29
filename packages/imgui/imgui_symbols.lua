--this file is for create autocomplete symbols,not for running

function imgui.create() end
function imgui.destroy() end
function imgui.keymap() end
function imgui.begin_frame() end
function imgui.end_frame() end
function imgui.key_state() end
function imgui.input_char() end
function imgui.get_io_value() end
function imgui.get_io_key() end

function widget.Button() end
function widget.SmallButton() end
function widget.InvisibleButton() end
function widget.ArrowButton() end
function widget.Checkbox() end
function widget.RadioButton() end
function widget.ProgressBar() end
function widget.Bullet() end
function widget.DragFloat() end
function widget.DragInt() end
function widget.SliderFloat() end
function widget.SliderInt() end
function widget.SliderAngle() end
function widget.VSliderFloat() end
function widget.VSliderInt() end
function widget.ColorEdit() end
function widget.ColorPicker() end
function widget.ColorButton() end
function widget.InputText() end
function widget.InputFloat() end
function widget.InputInt() end
function widget.Text() end
function widget.TextDisabled() end
function widget.TextWrapped() end
function widget.LabelText() end
function widget.BulletText() end
function widget.BeginCombo() end
function widget.EndCombo() end
function widget.Selectable() end
function widget.TreeNode() end
function widget.TreePop() end
function widget.CollapsingHeader() end
function widget.SetNextTreeNodeOpen() end
function widget.PlotLines() end
function widget.PlotHistogram() end
function widget.BeginTooltip() end
function widget.EndTooltip() end
function widget.SetTooltip() end
function widget.BeginMainMenuBar() end
function widget.EndMainMenuBar() end
function widget.BeginMenuBar() end
function widget.EndMenuBar() end
function widget.BeginMenu() end
function widget.EndMenu() end
function widget.MenuItem() end
function widget.BeginListBox() end
function widget.BeginListBoxN() end
function widget.EndListBox() end
function widget.ListBox() end
function widget.Image() end
function widget.ImageButton() end

function cursor.Separator() end
function cursor.SameLine() end
function cursor.NewLine() end
function cursor.Spacing() end
function cursor.Dummy() end
function cursor.Indent() end
function cursor.Unindent() end
function cursor.BeginGroup() end
function cursor.EndGroup() end
function cursor.GetCursorPos() end
function cursor.SetCursorPos() end
function cursor.GetCursorStartPos() end
function cursor.GetCursorScreenPos() end
function cursor.SetCursorScreenPos() end
function cursor.AlignTextToFramePadding() end
function cursor.GetTextLineHeight() end
function cursor.GetTextLineHeightWithSpacing() end
function cursor.GetFrameHeight() end
function cursor.GetFrameHeightWithSpacing() end
function cursor.TreeAdvanceToLabelPos() end
function cursor.GetTreeNodeToLabelSpacing() end

function windows.Begin() end
function windows.End() end
function windows.BeginChild() end
function windows.EndChild() end
function windows.BeginTabBar() end
function windows.EndTabBar() end
function windows.BeginTabItem() end
function windows.EndTabItem() end
function windows.SetTabItemClosed() end
function windows.OpenPopup() end
function windows.BeginPopup() end
function windows.BeginPopupContextItem() end
function windows.BeginPopupContextWindow() end
function windows.BeginPopupContextVoid() end
function windows.BeginPopupModal() end
function windows.EndPopup() end
function windows.OpenPopupOnItemClick() end
function windows.IsPopupOpen() end
function windows.CloseCurrentPopup() end
function windows.IsWindowAppearing() end
function windows.IsWindowCollapsed() end
function windows.IsWindowFocused() end
function windows.IsWindowHovered() end
function windows.GetWindowPos() end
function windows.GetWindowSize() end
function windows.GetScrollX() end
function windows.GetScrollY() end
function windows.GetScrollMaxX() end
function windows.GetScrollMaxY() end
function windows.SetScrollX() end
function windows.SetScrollY() end
function windows.SetScrollHereY() end
function windows.SetScrollFromPosY() end
function windows.SetNextWindowPos() end
function windows.SetNextWindowSize() end
function windows.SetNextWindowSizeConstraints() end
function windows.SetNextWindowContentSize() end
function windows.SetNextWindowCollapsed() end
function windows.SetNextWindowFocus() end
function windows.SetNextWindowBgAlpha() end
function windows.GetContentRegionMax() end
function windows.GetContentRegionAvail() end
function windows.GetWindowContentRegionMin() end
function windows.GetWindowContentRegionMax() end
function windows.GetWindowContentRegionWidth() end
function windows.PushStyleColor() end
function windows.PopStyleColor() end
function windows.PushStyleVar() end
function windows.PopStyleVar() end

function util.SetColorEditOptions() end
function util.PushClipRect() end
function util.PopClipRect() end
function util.SetItemDefaultFocus() end
function util.SetKeyboardFocusHere() end
function util.IsItemHovered() end
function util.IsItemActive() end
function util.IsItemFocused() end
function util.IsItemClicked() end
function util.IsItemVisible() end
function util.IsItemEdited() end
function util.IsItemActivated() end
function util.IsItemDeactivated() end
function util.IsItemDeactivatedAfterEdit() end
function util.IsAnyItemHovered() end
function util.IsAnyItemActive() end
function util.IsAnyItemFocused() end
function util.GetItemRectMin() end
function util.GetItemRectMax() end
function util.GetItemRectSize() end
function util.SetItemAllowOverlap() end
function util.LoadIniSettings() end
function util.SaveIniSettings() end
function util.CaptureKeyboardFromApp() end
function util.CaptureMouseFromApp() end
function util.IsMouseDoubleClicked() end

function flags.ColorEdit.NoAlpha() end
function flags.ColorEdit.NoPicker() end
function flags.ColorEdit.NoOptions() end
function flags.ColorEdit.NoSmallPreview() end
function flags.ColorEdit.NoInputs() end
function flags.ColorEdit.NoTooltip() end
function flags.ColorEdit.NoLabel() end
function flags.ColorEdit.NoSidePreview() end
function flags.ColorEdit.NoDragDrop() end
function flags.ColorEdit.AlphaBar() end
function flags.ColorEdit.AlphaPreview() end
function flags.ColorEdit.AlphaPreviewHalf() end
function flags.ColorEdit.HDR() end
function flags.ColorEdit.DisplayRGB() end
function flags.ColorEdit.DisplayHSV() end
function flags.ColorEdit.DisplayHex() end
function flags.ColorEdit.Uint8() end
function flags.ColorEdit.Float() end
function flags.ColorEdit.PickerHueBar() end
function flags.ColorEdit.PickerHueWheel() end
function flags.ColorEdit.InputRGB() end
function flags.ColorEdit.InputHSV() end

function flags.InputText.CharsDecimal() end
function flags.InputText.CharsHexadecimal() end
function flags.InputText.CharsUppercase() end
function flags.InputText.CharsNoBlank() end
function flags.InputText.AutoSelectAll() end
function flags.InputText.EnterReturnsTrue() end
function flags.InputText.CallbackCompletion() end
function flags.InputText.CallbackHistory() end
function flags.InputText.CallbackCharFilter() end
function flags.InputText.AllowTabInput() end
function flags.InputText.CtrlEnterForNewLine() end
function flags.InputText.NoHorizontalScroll() end
function flags.InputText.AlwaysInsertMode() end
function flags.InputText.ReadOnly() end
function flags.InputText.Password() end
function flags.InputText.NoUndoRedo() end
function flags.InputText.CharsScientific() end
function flags.InputText.CallbackResize() end
function flags.InputText.Multiline() end

function flags.Combo.PopupAlignLeft() end
function flags.Combo.HeightSmall() end
function flags.Combo.HeightRegular() end
function flags.Combo.HeightLarge() end
function flags.Combo.HeightLargest() end
function flags.Combo.NoArrowButton() end
function flags.Combo.NoPreview() end

function flags.Selectable.DontClosePopups() end
function flags.Selectable.SpanAllColumns() end
function flags.Selectable.AllowDoubleClick() end

function flags.TreeNode.Selected() end
function flags.TreeNode.Framed() end
function flags.TreeNode.AllowItemOverlap() end
function flags.TreeNode.NoTreePushOnOpen() end
function flags.TreeNode.NoAutoOpenOnLog() end
function flags.TreeNode.DefaultOpen() end
function flags.TreeNode.OpenOnDoubleClick() end
function flags.TreeNode.OpenOnArrow() end
function flags.TreeNode.Leaf() end
function flags.TreeNode.Bullet() end
function flags.TreeNode.FramePadding() end
function flags.TreeNode.NavLeftJumpsBackHere() end
function flags.TreeNode.CollapsingHeader() end

function flags.Window.NoTitleBar() end
function flags.Window.NoResize() end
function flags.Window.NoMove() end
function flags.Window.NoScrollbar() end
function flags.Window.NoScrollWithMouse() end
function flags.Window.NoCollapse() end
function flags.Window.AlwaysAutoResize() end
function flags.Window.NoBackground() end
function flags.Window.NoSavedSettings() end
function flags.Window.NoMouseInputs() end
function flags.Window.MenuBar() end
function flags.Window.HorizontalScrollbar() end
function flags.Window.NoFocusOnAppearing() end
function flags.Window.NoBringToFrontOnFocus() end
function flags.Window.AlwaysVerticalScrollbar() end
function flags.Window.AlwaysHorizontalScrollbar() end
function flags.Window.AlwaysUseWindowPadding() end
function flags.Window.NoNavInputs() end
function flags.Window.NoNavFocus() end
function flags.Window.UnsavedDocument() end
function flags.Window.NoNav() end
function flags.Window.NoDecoration() end
function flags.Window.NoInputs() end

function flags.Focused.ChildWindows() end
function flags.Focused.RootWindow() end
function flags.Focused.AnyWindow() end
function flags.Focused.RootAndChildWindows() end

function flags.Hovered.ChildWindows() end
function flags.Hovered.RootWindow() end
function flags.Hovered.AnyWindow() end
function flags.Hovered.AllowWhenBlockedByPopup() end
function flags.Hovered.AllowWhenBlockedByActiveItem() end
function flags.Hovered.AllowWhenOverlapped() end
function flags.Hovered.AllowWhenDisabled() end
function flags.Hovered.RectOnly() end
function flags.Hovered.RootAndChildWindows() end

function flags.TabBar.Reorderable() end
function flags.TabBar.AutoSelectNewTabs() end
function flags.TabBar.TabListPopupButton() end
function flags.TabBar.NoCloseWithMiddleMouseButton() end
function flags.TabBar.NoTabListScrollingButtons() end
function flags.TabBar.NoTooltip() end
function flags.TabBar.FittingPolicyResizeDown() end
function flags.TabBar.FittingPolicyScroll() end

function enum.StyleCol.Text() end
function enum.StyleCol.TextDisabled() end
function enum.StyleCol.WindowBg() end              -- Background of normal windows
function enum.StyleCol.ChildBg() end               -- Background of child windows
function enum.StyleCol.PopupBg() end               -- Background of popups, menus, tooltips windows
function enum.StyleCol.Border() end
function enum.StyleCol.BorderShadow() end
function enum.StyleCol.FrameBg() end               -- Background of checkbox, radio button, plot, slider, text input
function enum.StyleCol.FrameBgHovered() end
function enum.StyleCol.FrameBgActive() end
function enum.StyleCol.TitleBg() end
function enum.StyleCol.TitleBgActive() end
function enum.StyleCol.TitleBgCollapsed() end
function enum.StyleCol.MenuBarBg() end
function enum.StyleCol.ScrollbarBg() end
function enum.StyleCol.ScrollbarGrab() end
function enum.StyleCol.ScrollbarGrabHovered() end
function enum.StyleCol.ScrollbarGrabActive() end
function enum.StyleCol.CheckMark() end
function enum.StyleCol.SliderGrab() end
function enum.StyleCol.SliderGrabActive() end
function enum.StyleCol.Button() end
function enum.StyleCol.ButtonHovered() end
function enum.StyleCol.ButtonActive() end
function enum.StyleCol.Header() end
function enum.StyleCol.HeaderHovered() end
function enum.StyleCol.HeaderActive() end
function enum.StyleCol.Separator() end
function enum.StyleCol.SeparatorHovered() end
function enum.StyleCol.SeparatorActive() end
function enum.StyleCol.ResizeGrip() end
function enum.StyleCol.ResizeGripHovered() end
function enum.StyleCol.ResizeGripActive() end
function enum.StyleCol.Tab() end
function enum.StyleCol.TabHovered() end
function enum.StyleCol.TabActive() end
function enum.StyleCol.TabUnfocused() end
function enum.StyleCol.TabUnfocusedActive() end
function enum.StyleCol.DockingPreview() end
function enum.StyleCol.DockingEmptyBg() end        -- Background color for empty node (e.g. CentralNode with no window docked into it)
function enum.StyleCol.PlotLines() end
function enum.StyleCol.PlotLinesHovered() end
function enum.StyleCol.PlotHistogram() end
function enum.StyleCol.PlotHistogramHovered() end
function enum.StyleCol.TextSelectedBg() end
function enum.StyleCol.DragDropTarget() end
function enum.StyleCol.NavHighlight() end          -- Gamepad/keyboard: current highlighted item
function enum.StyleCol.NavWindowingHighlight() end -- Highlight window when using CTRL+TAB
function enum.StyleCol.NavWindowingDimBg() end     -- Darken/colorize entire screen behind the CTRL+TAB window list, when active
function enum.StyleCol.ModalWindowDimBg() end      -- Darken/colorize entire screen behind a modal window, when one is active
function enum.StyleCol.COUNT() end

function enum.StyleVar.Alpha() end               -- float     Alpha
function enum.StyleVar.WindowPadding() end       -- ImVec2    WindowPadding
function enum.StyleVar.WindowRounding() end      -- float     WindowRounding
function enum.StyleVar.WindowBorderSize() end    -- float     WindowBorderSize
function enum.StyleVar.WindowMinSize() end       -- ImVec2    WindowMinSize
function enum.StyleVar.WindowTitleAlign() end    -- ImVec2    WindowTitleAlign
function enum.StyleVar.ChildRounding() end       -- float     ChildRounding
function enum.StyleVar.ChildBorderSize() end     -- float     ChildBorderSize
function enum.StyleVar.PopupRounding() end       -- float     PopupRounding
function enum.StyleVar.PopupBorderSize() end     -- float     PopupBorderSize
function enum.StyleVar.FramePadding() end        -- ImVec2    FramePadding
function enum.StyleVar.FrameRounding() end       -- float     FrameRounding
function enum.StyleVar.FrameBorderSize() end     -- float     FrameBorderSize
function enum.StyleVar.ItemSpacing() end         -- ImVec2    ItemSpacing
function enum.StyleVar.ItemInnerSpacing() end    -- ImVec2    ItemInnerSpacing
function enum.StyleVar.IndentSpacing() end       -- float     IndentSpacing
function enum.StyleVar.ScrollbarSize() end       -- float     ScrollbarSize
function enum.StyleVar.ScrollbarRounding() end   -- float     ScrollbarRounding
function enum.StyleVar.GrabMinSize() end         -- float     GrabMinSize
function enum.StyleVar.GrabRounding() end        -- float     GrabRounding
function enum.StyleVar.TabRounding() end         -- float     TabRounding
function enum.StyleVar.ButtonTextAlign() end     -- ImVec2    ButtonTextAlign
function enum.StyleVar.SelectableTextAlign() end -- ImVec2    SelectableTextAlign
function enum.StyleVar.COUNT() end

function io.WantCaptureMouse()          -- When io.WantCaptureMouse is true, imgui will use the mouse inputs, do not dispatch them to your main game/application (in both cases, always pass on mouse inputs to imgui). (e.g. unclicked mouse is hovering over an imgui window, widget is active, mouse was clicked over an imgui window, etc.).
function io.WantCaptureKeyboard()       -- When io.WantCaptureKeyboard is true, imgui will use the keyboard inputs, do not dispatch them to your main game/application (in both cases, always pass keyboard inputs to imgui). (e.g. InputText active, or an imgui window is focused and navigation is enabled, etc.).
function io.WantTextInput()             -- Mobile/console: when io.WantTextInput is true, you may display an on-screen keyboard. This is set by ImGui when it wants textual keyboard input to happen (e.g. when a InputText widget is active).
function io.WantSetMousePos()           -- MousePos has been altered, back-end should reposition mouse on next frame. Set only when ImGuiConfigFlags_NavEnableSetMousePos flag is enabled.
function io.WantSaveIniSettings()       -- When manual .ini load/save is active (io.IniFilename == NULL), this will be set to notify your application that you can call SaveIniSettingsToMemory() and save yourself. IMPORTANT: You need to clear io.WantSaveIniSettings yourself.
function io.NavActive()                 -- Directional navigation is currently allowed (will handle ImGuiKey_NavXXX events) = a window is focused and it doesn't use the ImGuiWindowFlags_NoNavInputs flag.
function io.NavVisible()                -- Directional navigation is visible and allowed (will handle ImGuiKey_NavXXX events).
function io.Framerate()                 -- Application framerate estimation, in frame per second. Solely for convenience. Rolling average estimation based on IO.DeltaTime over 120 frames
function io.MetricsRenderVertices()     -- Vertices output during last call to Render()
function io.MetricsRenderIndices()      -- Indices output during last call to Render() = number of triangles * 3
function io.MetricsRenderWindows()      -- Number of visible windows
function io.MetricsActiveWindows()      -- Number of active windows
function io.MetricsActiveAllocations()  -- Number of active allocations, updated by MemAlloc/MemFree based on current context. May be off if you have multiple imgui contexts.
function io.MouseDelta()                -- Mouse delta. Note that this is zero if either current or previous position are invalid (-FLT_MAX,-FLT_MAX), so a disappearing/reappearing mouse won't have a huge delta.
