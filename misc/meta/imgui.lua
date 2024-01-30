---@meta imgui

--
-- Automatically generated file; DO NOT EDIT.
--

local ImGui = {}

ImGui.Flags = {}
ImGui.Enum = {}

--
-- Flags for ImGui::Begin()
-- (Those are per-window flags. There are shared flags in ImGuiIO: io.ConfigWindowsResizeFromEdges and io.ConfigWindowsMoveFromTitleBarOnly)
--
---@class ImGuiWindowFlags

---@alias _ImGuiWindowFlags_Name
---| "None"
---| "NoTitleBar" #  Disable title-bar
---| "NoResize" #  Disable user resizing with the lower-right grip
---| "NoMove" #  Disable user moving the window
---| "NoScrollbar" #  Disable scrollbars (window can still scroll with mouse or programmatically)
---| "NoScrollWithMouse" #  Disable user vertically scrolling with mouse wheel. On child window, mouse wheel will be forwarded to the parent unless NoScrollbar is also set.
---| "NoCollapse" #  Disable user collapsing window by double-clicking on it. Also referred to as Window Menu Button (e.g. within a docking node).
---| "AlwaysAutoResize" #  Resize every window to its content every frame
---| "NoBackground" #  Disable drawing background color (WindowBg, etc.) and outside border. Similar as using SetNextWindowBgAlpha(0.0f).
---| "NoSavedSettings" #  Never load/save settings in .ini file
---| "NoMouseInputs" #  Disable catching mouse, hovering test with pass through.
---| "MenuBar" #  Has a menu-bar
---| "HorizontalScrollbar" #  Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
---| "NoFocusOnAppearing" #  Disable taking focus when transitioning from hidden to visible state
---| "NoBringToFrontOnFocus" #  Disable bringing window to front when taking focus (e.g. clicking on it or programmatically giving it focus)
---| "AlwaysVerticalScrollbar" #  Always show vertical scrollbar (even if ContentSize.y < Size.y)
---| "AlwaysHorizontalScrollbar" #  Always show horizontal scrollbar (even if ContentSize.x < Size.x)
---| "NoNavInputs" #  No gamepad/keyboard navigation within the window
---| "NoNavFocus" #  No focusing toward this window with gamepad/keyboard navigation (e.g. skipped by CTRL+TAB)
---| "UnsavedDocument" #  Display a dot next to the title. When used in a tab/docking context, tab is selected when clicking the X + closure is not assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
---| "NoDocking" #  Disable docking of this window
---| "NoNav"
---| "NoDecoration"
---| "NoInputs"
---| "AlwaysUseWindowPadding" #  Obsoleted in 1.90: Use ImGuiChildFlags_AlwaysUseWindowPadding in BeginChild() call.

---@param flags _ImGuiWindowFlags_Name[]
---@return ImGuiWindowFlags
function ImGui.Flags.Window(flags) end

--
-- Flags for ImGui::BeginChild()
-- (Legacy: bot 0 must always correspond to ImGuiChildFlags_Border to be backward compatible with old API using 'bool border = false'.
-- About using AutoResizeX/AutoResizeY flags:
-- - May be combined with SetNextWindowSizeConstraints() to set a min/max size for each axis (see "Demo->Child->Auto-resize with Constraints").
-- - Size measurement for a given axis is only performed when the child window is within visible boundaries, or is just appearing.
--   - This allows BeginChild() to return false when not within boundaries (e.g. when scrolling), which is more optimal. BUT it won't update its auto-size while clipped.
--     While not perfect, it is a better default behavior as the always-on performance gain is more valuable than the occasional "resizing after becoming visible again" glitch.
--   - You may also use ImGuiChildFlags_AlwaysAutoResize to force an update even when child window is not in view.
--     HOWEVER PLEASE UNDERSTAND THAT DOING SO WILL PREVENT BeginChild() FROM EVER RETURNING FALSE, disabling benefits of coarse clipping.
--
---@class ImGuiChildFlags

---@alias _ImGuiChildFlags_Name
---| "None"
---| "Border" #  Show an outer border and enable WindowPadding. (Important: this is always == 1 == true for legacy reason)
---| "AlwaysUseWindowPadding" #  Pad with style.WindowPadding even if no border are drawn (no padding by default for non-bordered child windows because it makes more sense)
---| "ResizeX" #  Allow resize from right border (layout direction). Enable .ini saving (unless ImGuiWindowFlags_NoSavedSettings passed to window flags)
---| "ResizeY" #  Allow resize from bottom border (layout direction). "
---| "AutoResizeX" #  Enable auto-resizing width. Read "IMPORTANT: Size measurement" details above.
---| "AutoResizeY" #  Enable auto-resizing height. Read "IMPORTANT: Size measurement" details above.
---| "AlwaysAutoResize" #  Combined with AutoResizeX/AutoResizeY. Always measure size even when child is hidden, always return true, always disable clipping optimization! NOT RECOMMENDED.
---| "FrameStyle" #  Style the child window like a framed item: use FrameBg, FrameRounding, FrameBorderSize, FramePadding instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.

---@param flags _ImGuiChildFlags_Name[]
---@return ImGuiChildFlags
function ImGui.Flags.Child(flags) end

--
-- Flags for ImGui::InputText()
-- (Those are per-item flags. There are shared flags in ImGuiIO: io.ConfigInputTextCursorBlink and io.ConfigInputTextEnterKeepActive)
--
---@class ImGuiInputTextFlags

---@alias _ImGuiInputTextFlags_Name
---| "None"
---| "CharsDecimal" #  Allow 0123456789.+-*/
---| "CharsHexadecimal" #  Allow 0123456789ABCDEFabcdef
---| "CharsUppercase" #  Turn a..z into A..Z
---| "CharsNoBlank" #  Filter out spaces, tabs
---| "AutoSelectAll" #  Select entire text when first taking mouse focus
---| "EnterReturnsTrue" #  Return 'true' when Enter is pressed (as opposed to every time the value was modified). Consider looking at the IsItemDeactivatedAfterEdit() function.
---| "CallbackCompletion" #  Callback on pressing TAB (for completion handling)
---| "CallbackHistory" #  Callback on pressing Up/Down arrows (for history handling)
---| "CallbackAlways" #  Callback on each iteration. User code may query cursor position, modify text buffer.
---| "CallbackCharFilter" #  Callback on character inputs to replace or discard them. Modify 'EventChar' to replace or discard, or return 1 in callback to discard.
---| "AllowTabInput" #  Pressing TAB input a '\t' character into the text field
---| "CtrlEnterForNewLine" #  In multi-line mode, unfocus with Enter, add new line with Ctrl+Enter (default is opposite: unfocus with Ctrl+Enter, add line with Enter).
---| "NoHorizontalScroll" #  Disable following the cursor horizontally
---| "AlwaysOverwrite" #  Overwrite mode
---| "ReadOnly" #  Read-only mode
---| "Password" #  Password mode, display all characters as '*'
---| "NoUndoRedo" #  Disable undo/redo. Note that input text owns the text data while active, if you want to provide your own undo/redo stack you need e.g. to call ClearActiveID().
---| "CharsScientific" #  Allow 0123456789.+-*/eE (Scientific notation input)
---| "CallbackResize" #  Callback on buffer capacity changes request (beyond 'buf_size' parameter value), allowing the string to grow. Notify when the string wants to be resized (for string types which hold a cache of their Size). You will be provided a new BufSize in the callback and NEED to honor it. (see misc/cpp/imgui_stdlib.h for an example of using this)
---| "CallbackEdit" #  Callback on any edit (note that InputText() already returns true on edit, the callback is useful mainly to manipulate the underlying buffer while focus is active)
---| "EscapeClearsAll" #  Escape key clears content if not empty, and deactivate otherwise (contrast to default behavior of Escape to revert)

---@param flags _ImGuiInputTextFlags_Name[]
---@return ImGuiInputTextFlags
function ImGui.Flags.InputText(flags) end

--
-- Flags for ImGui::TreeNodeEx(), ImGui::CollapsingHeader*()
--
---@class ImGuiTreeNodeFlags

---@alias _ImGuiTreeNodeFlags_Name
---| "None"
---| "Selected" #  Draw as selected
---| "Framed" #  Draw frame with background (e.g. for CollapsingHeader)
---| "AllowOverlap" #  Hit testing to allow subsequent widgets to overlap this one
---| "NoTreePushOnOpen" #  Don't do a TreePush() when open (e.g. for CollapsingHeader) = no extra indent nor pushing on ID stack
---| "NoAutoOpenOnLog" #  Don't automatically and temporarily open node when Logging is active (by default logging will automatically open tree nodes)
---| "DefaultOpen" #  Default node to be open
---| "OpenOnDoubleClick" #  Need double-click to open node
---| "OpenOnArrow" #  Only open when clicking on the arrow part. If ImGuiTreeNodeFlags_OpenOnDoubleClick is also set, single-click arrow or double-click all box to open.
---| "Leaf" #  No collapsing, no arrow (use as a convenience for leaf nodes).
---| "Bullet" #  Display a bullet instead of arrow. IMPORTANT: node can still be marked open/close if you don't set the _Leaf flag!
---| "FramePadding" #  Use FramePadding (even for an unframed text node) to vertically align text baseline to regular widget height. Equivalent to calling AlignTextToFramePadding().
---| "SpanAvailWidth" #  Extend hit box to the right-most edge, even if not framed. This is not the default in order to allow adding other items on the same line. In the future we may refactor the hit system to be front-to-back, allowing natural overlaps and then this can become the default.
---| "SpanFullWidth" #  Extend hit box to the left-most and right-most edges (bypass the indented area).
---| "SpanAllColumns" #  Frame will span all columns of its container table (text will still fit in current column)
---| "NavLeftJumpsBackHere" #  (WIP) Nav: left direction may move to this TreeNode() from any of its child (items submitted between TreeNode and TreePop)
---| "CollapsingHeader"
---| "AllowItemOverlap" #  Renamed in 1.89.7

---@param flags _ImGuiTreeNodeFlags_Name[]
---@return ImGuiTreeNodeFlags
function ImGui.Flags.TreeNode(flags) end

--
-- Flags for OpenPopup*(), BeginPopupContext*(), IsPopupOpen() functions.
-- - To be backward compatible with older API which took an 'int mouse_button = 1' argument, we need to treat
--   small flags values as a mouse button index, so we encode the mouse button in the first few bits of the flags.
--   It is therefore guaranteed to be legal to pass a mouse button index in ImGuiPopupFlags.
-- - For the same reason, we exceptionally default the ImGuiPopupFlags argument of BeginPopupContextXXX functions to 1 instead of 0.
--   IMPORTANT: because the default parameter is 1 (==ImGuiPopupFlags_MouseButtonRight), if you rely on the default parameter
--   and want to use another flag, you need to pass in the ImGuiPopupFlags_MouseButtonRight flag explicitly.
-- - Multiple buttons currently cannot be combined/or-ed in those functions (we could allow it later).
--
---@class ImGuiPopupFlags

---@alias _ImGuiPopupFlags_Name
---| "None"
---| "MouseButtonLeft" #  For BeginPopupContext*(): open on Left Mouse release. Guaranteed to always be == 0 (same as ImGuiMouseButton_Left)
---| "MouseButtonRight" #  For BeginPopupContext*(): open on Right Mouse release. Guaranteed to always be == 1 (same as ImGuiMouseButton_Right)
---| "MouseButtonMiddle" #  For BeginPopupContext*(): open on Middle Mouse release. Guaranteed to always be == 2 (same as ImGuiMouseButton_Middle)
---| "NoOpenOverExistingPopup" #  For OpenPopup*(), BeginPopupContext*(): don't open if there's already a popup at the same level of the popup stack
---| "NoOpenOverItems" #  For BeginPopupContextWindow(): don't return true when hovering items, only when hovering empty space
---| "AnyPopupId" #  For IsPopupOpen(): ignore the ImGuiID parameter and test for any popup.
---| "AnyPopupLevel" #  For IsPopupOpen(): search/test at any level of the popup stack (default test in the current level)
---| "AnyPopup"

---@param flags _ImGuiPopupFlags_Name[]
---@return ImGuiPopupFlags
function ImGui.Flags.Popup(flags) end

--
-- Flags for ImGui::Selectable()
--
---@class ImGuiSelectableFlags

---@alias _ImGuiSelectableFlags_Name
---| "None"
---| "DontClosePopups" #  Clicking this doesn't close parent popup window
---| "SpanAllColumns" #  Frame will span all columns of its container table (text will still fit in current column)
---| "AllowDoubleClick" #  Generate press events on double clicks too
---| "Disabled" #  Cannot be selected, display grayed out text
---| "AllowOverlap" #  (WIP) Hit testing to allow subsequent widgets to overlap this one
---| "AllowItemOverlap" #  Renamed in 1.89.7

---@param flags _ImGuiSelectableFlags_Name[]
---@return ImGuiSelectableFlags
function ImGui.Flags.Selectable(flags) end

--
-- Flags for ImGui::BeginCombo()
--
---@class ImGuiComboFlags

---@alias _ImGuiComboFlags_Name
---| "None"
---| "PopupAlignLeft" #  Align the popup toward the left by default
---| "HeightSmall" #  Max ~4 items visible. Tip: If you want your combo popup to be a specific size you can use SetNextWindowSizeConstraints() prior to calling BeginCombo()
---| "HeightRegular" #  Max ~8 items visible (default)
---| "HeightLarge" #  Max ~20 items visible
---| "HeightLargest" #  As many fitting items as possible
---| "NoArrowButton" #  Display on the preview box without the square arrow button
---| "NoPreview" #  Display only a square arrow button
---| "WidthFitPreview" #  Width dynamically calculated from preview contents

---@param flags _ImGuiComboFlags_Name[]
---@return ImGuiComboFlags
function ImGui.Flags.Combo(flags) end

--
-- Flags for ImGui::BeginTabBar()
--
---@class ImGuiTabBarFlags

---@alias _ImGuiTabBarFlags_Name
---| "None"
---| "Reorderable" #  Allow manually dragging tabs to re-order them + New tabs are appended at the end of list
---| "AutoSelectNewTabs" #  Automatically select new tabs when they appear
---| "TabListPopupButton" #  Disable buttons to open the tab list popup
---| "NoCloseWithMiddleMouseButton" #  Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You may handle this behavior manually on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
---| "NoTabListScrollingButtons" #  Disable scrolling buttons (apply when fitting policy is ImGuiTabBarFlags_FittingPolicyScroll)
---| "NoTooltip" #  Disable tooltips when hovering a tab
---| "FittingPolicyResizeDown" #  Resize tabs when they don't fit
---| "FittingPolicyScroll" #  Add scroll buttons when tabs don't fit

---@param flags _ImGuiTabBarFlags_Name[]
---@return ImGuiTabBarFlags
function ImGui.Flags.TabBar(flags) end

--
-- Flags for ImGui::BeginTabItem()
--
---@class ImGuiTabItemFlags

---@alias _ImGuiTabItemFlags_Name
---| "None"
---| "UnsavedDocument" #  Display a dot next to the title + set ImGuiTabItemFlags_NoAssumedClosure.
---| "SetSelected" #  Trigger flag to programmatically make the tab selected when calling BeginTabItem()
---| "NoCloseWithMiddleMouseButton" #  Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You may handle this behavior manually on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
---| "NoPushId" #  Don't call PushID()/PopID() on BeginTabItem()/EndTabItem()
---| "NoTooltip" #  Disable tooltip for the given tab
---| "NoReorder" #  Disable reordering this tab or having another tab cross over this tab
---| "Leading" #  Enforce the tab position to the left of the tab bar (after the tab list popup button)
---| "Trailing" #  Enforce the tab position to the right of the tab bar (before the scrolling buttons)
---| "NoAssumedClosure" #  Tab is selected when trying to close + closure is not immediately assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.

---@param flags _ImGuiTabItemFlags_Name[]
---@return ImGuiTabItemFlags
function ImGui.Flags.TabItem(flags) end

--
-- Flags for ImGui::IsWindowFocused()
--
---@class ImGuiFocusedFlags

---@alias _ImGuiFocusedFlags_Name
---| "None"
---| "ChildWindows" #  Return true if any children of the window is focused
---| "RootWindow" #  Test from root window (top most parent of the current hierarchy)
---| "AnyWindow" #  Return true if any window is focused. Important: If you are trying to tell how to dispatch your low-level inputs, do NOT use this. Use 'io.WantCaptureMouse' instead! Please read the FAQ!
---| "NoPopupHierarchy" #  Do not consider popup hierarchy (do not treat popup emitter as parent of popup) (when used with _ChildWindows or _RootWindow)
---| "DockHierarchy" #  Consider docking hierarchy (treat dockspace host as parent of docked window) (when used with _ChildWindows or _RootWindow)
---| "RootAndChildWindows"

---@param flags _ImGuiFocusedFlags_Name[]
---@return ImGuiFocusedFlags
function ImGui.Flags.Focused(flags) end

--
-- Flags for ImGui::IsItemHovered(), ImGui::IsWindowHovered()
-- Note: if you are trying to check whether your mouse should be dispatched to Dear ImGui or to your app, you should use 'io.WantCaptureMouse' instead! Please read the FAQ!
-- Note: windows with the ImGuiWindowFlags_NoInputs flag are ignored by IsWindowHovered() calls.
--
---@class ImGuiHoveredFlags

---@alias _ImGuiHoveredFlags_Name
---| "None" #  Return true if directly over the item/window, not obstructed by another window, not obstructed by an active popup or modal blocking inputs under them.
---| "ChildWindows" #  IsWindowHovered() only: Return true if any children of the window is hovered
---| "RootWindow" #  IsWindowHovered() only: Test from root window (top most parent of the current hierarchy)
---| "AnyWindow" #  IsWindowHovered() only: Return true if any window is hovered
---| "NoPopupHierarchy" #  IsWindowHovered() only: Do not consider popup hierarchy (do not treat popup emitter as parent of popup) (when used with _ChildWindows or _RootWindow)
---| "DockHierarchy" #  IsWindowHovered() only: Consider docking hierarchy (treat dockspace host as parent of docked window) (when used with _ChildWindows or _RootWindow)
---| "AllowWhenBlockedByPopup" #  Return true even if a popup window is normally blocking access to this item/window
---| "AllowWhenBlockedByActiveItem" #  Return true even if an active item is blocking access to this item/window. Useful for Drag and Drop patterns.
---| "AllowWhenOverlappedByItem" #  IsItemHovered() only: Return true even if the item uses AllowOverlap mode and is overlapped by another hoverable item.
---| "AllowWhenOverlappedByWindow" #  IsItemHovered() only: Return true even if the position is obstructed or overlapped by another window.
---| "AllowWhenDisabled" #  IsItemHovered() only: Return true even if the item is disabled
---| "NoNavOverride" #  IsItemHovered() only: Disable using gamepad/keyboard navigation state when active, always query mouse
---| "AllowWhenOverlapped"
---| "RectOnly"
---| "RootAndChildWindows"
---| "ForTooltip" #  Shortcut for standard flags when using IsItemHovered() + SetTooltip() sequence.
---| "Stationary" #  Require mouse to be stationary for style.HoverStationaryDelay (~0.15 sec) _at least one time_. After this, can move on same item/window. Using the stationary test tends to reduces the need for a long delay.
---| "DelayNone" #  IsItemHovered() only: Return true immediately (default). As this is the default you generally ignore this.
---| "DelayShort" #  IsItemHovered() only: Return true after style.HoverDelayShort elapsed (~0.15 sec) (shared between items) + requires mouse to be stationary for style.HoverStationaryDelay (once per item).
---| "DelayNormal" #  IsItemHovered() only: Return true after style.HoverDelayNormal elapsed (~0.40 sec) (shared between items) + requires mouse to be stationary for style.HoverStationaryDelay (once per item).
---| "NoSharedDelay" #  IsItemHovered() only: Disable shared delay system where moving from one item to the next keeps the previous timer for a short time (standard for tooltips with long delays)

---@param flags _ImGuiHoveredFlags_Name[]
---@return ImGuiHoveredFlags
function ImGui.Flags.Hovered(flags) end

--
-- Flags for ImGui::DockSpace(), shared/inherited by child nodes.
-- (Some flags can be applied to individual nodes directly)
-- FIXME-DOCK: Also see ImGuiDockNodeFlagsPrivate_ which may involve using the WIP and internal DockBuilder api.
--
---@class ImGuiDockNodeFlags

---@alias _ImGuiDockNodeFlags_Name
---| "None"
---| "KeepAliveOnly" #        // Don't display the dockspace node but keep it alive. Windows docked into this dockspace node won't be undocked.
---| "NoDockingOverCentralNode" #        // Disable docking over the Central Node, which will be always kept empty.
---| "PassthruCentralNode" #        // Enable passthru dockspace: 1) DockSpace() will render a ImGuiCol_WindowBg background covering everything excepted the Central Node when empty. Meaning the host window should probably use SetNextWindowBgAlpha(0.0f) prior to Begin() when using this. 2) When Central Node is empty: let inputs pass-through + won't display a DockingEmptyBg background. See demo for details.
---| "NoDockingSplit" #        // Disable other windows/nodes from splitting this node.
---| "NoResize" #  Saved // Disable resizing node using the splitter/separators. Useful with programmatically setup dockspaces.
---| "AutoHideTabBar" #        // Tab bar will automatically hide when there is a single window in the dock node.
---| "NoUndocking" #        // Disable undocking this node.
---| "NoSplit" #  Renamed in 1.90
---| "NoDockingInCentralNode" #  Renamed in 1.90

---@param flags _ImGuiDockNodeFlags_Name[]
---@return ImGuiDockNodeFlags
function ImGui.Flags.DockNode(flags) end

--
-- Flags for ImGui::BeginDragDropSource(), ImGui::AcceptDragDropPayload()
--
---@class ImGuiDragDropFlags

---@alias _ImGuiDragDropFlags_Name
---| "None"
---| "SourceNoPreviewTooltip" #  Disable preview tooltip. By default, a successful call to BeginDragDropSource opens a tooltip so you can display a preview or description of the source contents. This flag disables this behavior.
---| "SourceNoDisableHover" #  By default, when dragging we clear data so that IsItemHovered() will return false, to avoid subsequent user code submitting tooltips. This flag disables this behavior so you can still call IsItemHovered() on the source item.
---| "SourceNoHoldToOpenOthers" #  Disable the behavior that allows to open tree nodes and collapsing header by holding over them while dragging a source item.
---| "SourceAllowNullID" #  Allow items such as Text(), Image() that have no unique identifier to be used as drag source, by manufacturing a temporary identifier based on their window-relative position. This is extremely unusual within the dear imgui ecosystem and so we made it explicit.
---| "SourceExtern" #  External source (from outside of dear imgui), won't attempt to read current item/window info. Will always return true. Only one Extern source can be active simultaneously.
---| "SourceAutoExpirePayload" #  Automatically expire the payload if the source cease to be submitted (otherwise payloads are persisting while being dragged)
---| "AcceptBeforeDelivery" #  AcceptDragDropPayload() will returns true even before the mouse button is released. You can then call IsDelivery() to test if the payload needs to be delivered.
---| "AcceptNoDrawDefaultRect" #  Do not draw the default highlight rectangle when hovering over target.
---| "AcceptNoPreviewTooltip" #  Request hiding the BeginDragDropSource tooltip from the BeginDragDropTarget site.
---| "AcceptPeekOnly" #  For peeking ahead and inspecting the payload before delivery.

---@param flags _ImGuiDragDropFlags_Name[]
---@return ImGuiDragDropFlags
function ImGui.Flags.DragDrop(flags) end

--
-- A primary data type
--
---@class ImGuiDataType

--
-- A cardinal direction
--
---@class ImGuiDir

--
-- A sorting direction
--
---@class ImGuiSortDirection

--
-- A key identifier (ImGuiKey_XXX or ImGuiMod_XXX value): can represent Keyboard, Mouse and Gamepad values.
-- All our named keys are >= 512. Keys value 0 to 511 are left unused as legacy native/opaque key values (< 1.87).
-- Since >= 1.89 we increased typing (went from int to enum), some legacy code may need a cast to ImGuiKey.
-- Read details about the 1.87 and 1.89 transition : https://github.com/ocornut/imgui/issues/4921
-- Note that "Keys" related to physical keys and are not the same concept as input "Characters", the later are submitted via io.AddInputCharacter().
--
--
-- Forward declared enum type ImGuiKey
--
---@class ImGuiKey

--
-- Configuration flags stored in io.ConfigFlags. Set by user/application.
--
---@class ImGuiConfigFlags

---@alias _ImGuiConfigFlags_Name
---| "None"
---| "NavEnableKeyboard" #  Master keyboard navigation enable flag. Enable full Tabbing + directional arrows + space/enter to activate.
---| "NavEnableGamepad" #  Master gamepad navigation enable flag. Backend also needs to set ImGuiBackendFlags_HasGamepad.
---| "NavEnableSetMousePos" #  Instruct navigation to move the mouse cursor. May be useful on TV/console systems where moving a virtual mouse is awkward. Will update io.MousePos and set io.WantSetMousePos=true. If enabled you MUST honor io.WantSetMousePos requests in your backend, otherwise ImGui will react as if the mouse is jumping around back and forth.
---| "NavNoCaptureKeyboard" #  Instruct navigation to not set the io.WantCaptureKeyboard flag when io.NavActive is set.
---| "NoMouse" #  Instruct imgui to clear mouse position/buttons in NewFrame(). This allows ignoring the mouse information set by the backend.
---| "NoMouseCursorChange" #  Instruct backend to not alter mouse cursor shape and visibility. Use if the backend cursor changes are interfering with yours and you don't want to use SetMouseCursor() to change mouse cursor. You may want to honor requests from imgui by reading GetMouseCursor() yourself instead.
---| "DockingEnable" #  Docking enable flags.
---| "ViewportsEnable" #  Viewport enable flags (require both ImGuiBackendFlags_PlatformHasViewports + ImGuiBackendFlags_RendererHasViewports set by the respective backends)
---| "DpiEnableScaleViewports" #  [BETA: Don't use] FIXME-DPI: Reposition and resize imgui windows when the DpiScale of a viewport changed (mostly useful for the main viewport hosting other window). Note that resizing the main window itself is up to your application.
---| "DpiEnableScaleFonts" #  [BETA: Don't use] FIXME-DPI: Request bitmap-scaled fonts to match DpiScale. This is a very low-quality workaround. The correct way to handle DPI is _currently_ to replace the atlas and/or fonts in the Platform_OnChangedViewport callback, but this is all early work in progress.
---| "IsSRGB" #  Application is SRGB-aware.
---| "IsTouchScreen" #  Application is using a touch screen instead of a mouse.

---@param flags _ImGuiConfigFlags_Name[]
---@return ImGuiConfigFlags
function ImGui.Flags.Config(flags) end

--
-- Backend capabilities flags stored in io.BackendFlags. Set by imgui_impl_xxx or custom backend.
--
---@class ImGuiBackendFlags

---@alias _ImGuiBackendFlags_Name
---| "None"
---| "HasGamepad" #  Backend Platform supports gamepad and currently has one connected.
---| "HasMouseCursors" #  Backend Platform supports honoring GetMouseCursor() value to change the OS cursor shape.
---| "HasSetMousePos" #  Backend Platform supports io.WantSetMousePos requests to reposition the OS mouse position (only used if ImGuiConfigFlags_NavEnableSetMousePos is set).
---| "RendererHasVtxOffset" #  Backend Renderer supports ImDrawCmd::VtxOffset. This enables output of large meshes (64K+ vertices) while still using 16-bit indices.
---| "PlatformHasViewports" #  Backend Platform supports multiple viewports.
---| "HasMouseHoveredViewport" #  Backend Platform supports calling io.AddMouseViewportEvent() with the viewport under the mouse. IF POSSIBLE, ignore viewports with the ImGuiViewportFlags_NoInputs flag (Win32 backend, GLFW 3.30+ backend can do this, SDL backend cannot). If this cannot be done, Dear ImGui needs to use a flawed heuristic to find the viewport under.
---| "RendererHasViewports" #  Backend Renderer supports multiple viewports.

---@param flags _ImGuiBackendFlags_Name[]
---@return ImGuiBackendFlags
function ImGui.Flags.Backend(flags) end

--
-- Enumeration for PushStyleColor() / PopStyleColor()
--
---@class ImGuiCol

--
-- Enumeration for PushStyleVar() / PopStyleVar() to temporarily modify the ImGuiStyle structure.
-- - The enum only refers to fields of ImGuiStyle which makes sense to be pushed/popped inside UI code.
--   During initialization or between frames, feel free to just poke into ImGuiStyle directly.
-- - Tip: Use your programming IDE navigation facilities on the names in the _second column_ below to find the actual members and their description.
--   In Visual Studio IDE: CTRL+comma ("Edit.GoToAll") can follow symbols in comments, whereas CTRL+F12 ("Edit.GoToImplementation") cannot.
--   With Visual Assist installed: ALT+G ("VAssistX.GoToImplementation") can also follow symbols in comments.
-- - When changing this enum, you need to update the associated internal table GStyleVarInfo[] accordingly. This is where we link enum values to members offset/type.
--
---@class ImGuiStyleVar

--
-- Flags for InvisibleButton() [extended in imgui_internal.h]
--
---@class ImGuiButtonFlags

---@alias _ImGuiButtonFlags_Name
---| "None"
---| "MouseButtonLeft" #  React on left mouse button (default)
---| "MouseButtonRight" #  React on right mouse button
---| "MouseButtonMiddle" #  React on center mouse button

---@param flags _ImGuiButtonFlags_Name[]
---@return ImGuiButtonFlags
function ImGui.Flags.Button(flags) end

--
-- Flags for ColorEdit3() / ColorEdit4() / ColorPicker3() / ColorPicker4() / ColorButton()
--
---@class ImGuiColorEditFlags

---@alias _ImGuiColorEditFlags_Name
---| "None"
---| "NoAlpha" #               // ColorEdit, ColorPicker, ColorButton: ignore Alpha component (will only read 3 components from the input pointer).
---| "NoPicker" #               // ColorEdit: disable picker when clicking on color square.
---| "NoOptions" #               // ColorEdit: disable toggling options menu when right-clicking on inputs/small preview.
---| "NoSmallPreview" #               // ColorEdit, ColorPicker: disable color square preview next to the inputs. (e.g. to show only the inputs)
---| "NoInputs" #               // ColorEdit, ColorPicker: disable inputs sliders/text widgets (e.g. to show only the small preview color square).
---| "NoTooltip" #               // ColorEdit, ColorPicker, ColorButton: disable tooltip when hovering the preview.
---| "NoLabel" #               // ColorEdit, ColorPicker: disable display of inline text label (the label is still forwarded to the tooltip and picker).
---| "NoSidePreview" #               // ColorPicker: disable bigger color preview on right side of the picker, use small color square preview instead.
---| "NoDragDrop" #               // ColorEdit: disable drag and drop target. ColorButton: disable drag and drop source.
---| "NoBorder" #               // ColorButton: disable border (which is enforced by default)
---| "AlphaBar" #               // ColorEdit, ColorPicker: show vertical alpha bar/gradient in picker.
---| "AlphaPreview" #               // ColorEdit, ColorPicker, ColorButton: display preview as a transparent color over a checkerboard, instead of opaque.
---| "AlphaPreviewHalf" #               // ColorEdit, ColorPicker, ColorButton: display half opaque / half checkerboard, instead of opaque.
---| "HDR" #               // (WIP) ColorEdit: Currently only disable 0.0f..1.0f limits in RGBA edition (note: you probably want to use ImGuiColorEditFlags_Float flag as well).
---| "DisplayRGB" #  [Display]    // ColorEdit: override _display_ type among RGB/HSV/Hex. ColorPicker: select any combination using one or more of RGB/HSV/Hex.
---| "DisplayHSV" #  [Display]    // "
---| "DisplayHex" #  [Display]    // "
---| "Uint8" #  [DataType]   // ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0..255.
---| "Float" #  [DataType]   // ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0.0f..1.0f floats instead of 0..255 integers. No round-trip of value via integers.
---| "PickerHueBar" #  [Picker]     // ColorPicker: bar for Hue, rectangle for Sat/Value.
---| "PickerHueWheel" #  [Picker]     // ColorPicker: wheel for Hue, triangle for Sat/Value.
---| "InputRGB" #  [Input]      // ColorEdit, ColorPicker: input and output data in RGB format.
---| "InputHSV" #  [Input]      // ColorEdit, ColorPicker: input and output data in HSV format.

---@param flags _ImGuiColorEditFlags_Name[]
---@return ImGuiColorEditFlags
function ImGui.Flags.ColorEdit(flags) end

--
-- Flags for DragFloat(), DragInt(), SliderFloat(), SliderInt() etc.
-- We use the same sets of flags for DragXXX() and SliderXXX() functions as the features are the same and it makes it easier to swap them.
-- (Those are per-item flags. There are shared flags in ImGuiIO: io.ConfigDragClickToInputText)
--
---@class ImGuiSliderFlags

---@alias _ImGuiSliderFlags_Name
---| "None"
---| "AlwaysClamp" #  Clamp value to min/max bounds when input manually with CTRL+Click. By default CTRL+Click allows going out of bounds.
---| "Logarithmic" #  Make the widget logarithmic (linear otherwise). Consider using ImGuiSliderFlags_NoRoundToFormat with this if using a format-string with small amount of digits.
---| "NoRoundToFormat" #  Disable rounding underlying value to match precision of the display format string (e.g. %.3f values are rounded to those 3 digits)
---| "NoInput" #  Disable CTRL+Click or Enter key allowing to input text directly into the widget

---@param flags _ImGuiSliderFlags_Name[]
---@return ImGuiSliderFlags
function ImGui.Flags.Slider(flags) end

--
-- Identify a mouse button.
-- Those values are guaranteed to be stable and we frequently use 0/1 directly. Named enums provided for convenience.
--
---@class ImGuiMouseButton

--
-- Enumeration for GetMouseCursor()
-- User code may request backend to display given cursor by calling SetMouseCursor(), which is why we have some cursors that are marked unused here
--
---@class ImGuiMouseCursor

--
-- Enumeration for AddMouseSourceEvent() actual source of Mouse Input data.
-- Historically we use "Mouse" terminology everywhere to indicate pointer data, e.g. MousePos, IsMousePressed(), io.AddMousePosEvent()
-- But that "Mouse" data can come from different source which occasionally may be useful for application to know about.
-- You can submit a change of pointer type using io.AddMouseSourceEvent().
--
--
-- Forward declared enum type ImGuiMouseSource
--
---@class ImGuiMouseSource

--
-- Enumeration for ImGui::SetNextWindow***(), SetWindow***(), SetNextItem***() functions
-- Represent a condition.
-- Important: Treat as a regular enum! Do NOT combine multiple values using binary operators! All the functions above treat 0 as a shortcut to ImGuiCond_Always.
--
---@class ImGuiCond

--
-- Flags for ImGui::BeginTable()
-- - Important! Sizing policies have complex and subtle side effects, much more so than you would expect.
--   Read comments/demos carefully + experiment with live demos to get acquainted with them.
-- - The DEFAULT sizing policies are:
--    - Default to ImGuiTableFlags_SizingFixedFit    if ScrollX is on, or if host window has ImGuiWindowFlags_AlwaysAutoResize.
--    - Default to ImGuiTableFlags_SizingStretchSame if ScrollX is off.
-- - When ScrollX is off:
--    - Table defaults to ImGuiTableFlags_SizingStretchSame -> all Columns defaults to ImGuiTableColumnFlags_WidthStretch with same weight.
--    - Columns sizing policy allowed: Stretch (default), Fixed/Auto.
--    - Fixed Columns (if any) will generally obtain their requested width (unless the table cannot fit them all).
--    - Stretch Columns will share the remaining width according to their respective weight.
--    - Mixed Fixed/Stretch columns is possible but has various side-effects on resizing behaviors.
--      The typical use of mixing sizing policies is: any number of LEADING Fixed columns, followed by one or two TRAILING Stretch columns.
--      (this is because the visible order of columns have subtle but necessary effects on how they react to manual resizing).
-- - When ScrollX is on:
--    - Table defaults to ImGuiTableFlags_SizingFixedFit -> all Columns defaults to ImGuiTableColumnFlags_WidthFixed
--    - Columns sizing policy allowed: Fixed/Auto mostly.
--    - Fixed Columns can be enlarged as needed. Table will show a horizontal scrollbar if needed.
--    - When using auto-resizing (non-resizable) fixed columns, querying the content width to use item right-alignment e.g. SetNextItemWidth(-FLT_MIN) doesn't make sense, would create a feedback loop.
--    - Using Stretch columns OFTEN DOES NOT MAKE SENSE if ScrollX is on, UNLESS you have specified a value for 'inner_width' in BeginTable().
--      If you specify a value for 'inner_width' then effectively the scrolling space is known and Stretch or mixed Fixed/Stretch columns become meaningful again.
-- - Read on documentation at the top of imgui_tables.cpp for details.
--
---@class ImGuiTableFlags

---@alias _ImGuiTableFlags_Name
---| "None"
---| "Resizable" #  Enable resizing columns.
---| "Reorderable" #  Enable reordering columns in header row (need calling TableSetupColumn() + TableHeadersRow() to display headers)
---| "Hideable" #  Enable hiding/disabling columns in context menu.
---| "Sortable" #  Enable sorting. Call TableGetSortSpecs() to obtain sort specs. Also see ImGuiTableFlags_SortMulti and ImGuiTableFlags_SortTristate.
---| "NoSavedSettings" #  Disable persisting columns order, width and sort settings in the .ini file.
---| "ContextMenuInBody" #  Right-click on columns body/contents will display table context menu. By default it is available in TableHeadersRow().
---| "RowBg" #  Set each RowBg color with ImGuiCol_TableRowBg or ImGuiCol_TableRowBgAlt (equivalent of calling TableSetBgColor with ImGuiTableBgFlags_RowBg0 on each row manually)
---| "BordersInnerH" #  Draw horizontal borders between rows.
---| "BordersOuterH" #  Draw horizontal borders at the top and bottom.
---| "BordersInnerV" #  Draw vertical borders between columns.
---| "BordersOuterV" #  Draw vertical borders on the left and right sides.
---| "BordersH" #  Draw horizontal borders.
---| "BordersV" #  Draw vertical borders.
---| "BordersInner" #  Draw inner borders.
---| "BordersOuter" #  Draw outer borders.
---| "Borders" #  Draw all borders.
---| "NoBordersInBody" #  [ALPHA] Disable vertical borders in columns Body (borders will always appear in Headers). -> May move to style
---| "NoBordersInBodyUntilResize" #  [ALPHA] Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers). -> May move to style
---| "SizingFixedFit" #  Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching contents width.
---| "SizingFixedSame" #  Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching the maximum contents width of all columns. Implicitly enable ImGuiTableFlags_NoKeepColumnsVisible.
---| "SizingStretchProp" #  Columns default to _WidthStretch with default weights proportional to each columns contents widths.
---| "SizingStretchSame" #  Columns default to _WidthStretch with default weights all equal, unless overridden by TableSetupColumn().
---| "NoHostExtendX" #  Make outer width auto-fit to columns, overriding outer_size.x value. Only available when ScrollX/ScrollY are disabled and Stretch columns are not used.
---| "NoHostExtendY" #  Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit). Only available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.
---| "NoKeepColumnsVisible" #  Disable keeping column always minimally visible when ScrollX is off and table gets too small. Not recommended if columns are resizable.
---| "PreciseWidths" #  Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.
---| "NoClip" #  Disable clipping rectangle for every individual columns (reduce draw command count, items will be able to overflow into other columns). Generally incompatible with TableSetupScrollFreeze().
---| "PadOuterX" #  Default if BordersOuterV is on. Enable outermost padding. Generally desirable if you have headers.
---| "NoPadOuterX" #  Default if BordersOuterV is off. Disable outermost padding.
---| "NoPadInnerX" #  Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off).
---| "ScrollX" #  Enable horizontal scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size. Changes default sizing policy. Because this creates a child window, ScrollY is currently generally recommended when using ScrollX.
---| "ScrollY" #  Enable vertical scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size.
---| "SortMulti" #  Hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).
---| "SortTristate" #  Allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).
---| "HighlightHoveredColumn" #  Highlight column headers when hovered (may evolve into a fuller highlight)

---@param flags _ImGuiTableFlags_Name[]
---@return ImGuiTableFlags
function ImGui.Flags.Table(flags) end

--
-- Flags for ImGui::TableSetupColumn()
--
---@class ImGuiTableColumnFlags

---@alias _ImGuiTableColumnFlags_Name
---| "None"
---| "Disabled" #  Overriding/master disable flag: hide column, won't show in context menu (unlike calling TableSetColumnEnabled() which manipulates the user accessible state)
---| "DefaultHide" #  Default as a hidden/disabled column.
---| "DefaultSort" #  Default as a sorting column.
---| "WidthStretch" #  Column will stretch. Preferable with horizontal scrolling disabled (default if table sizing policy is _SizingStretchSame or _SizingStretchProp).
---| "WidthFixed" #  Column will not stretch. Preferable with horizontal scrolling enabled (default if table sizing policy is _SizingFixedFit and table is resizable).
---| "NoResize" #  Disable manual resizing.
---| "NoReorder" #  Disable manual reordering this column, this will also prevent other columns from crossing over this column.
---| "NoHide" #  Disable ability to hide/disable this column.
---| "NoClip" #  Disable clipping for this column (all NoClip columns will render in a same draw command).
---| "NoSort" #  Disable ability to sort on this field (even if ImGuiTableFlags_Sortable is set on the table).
---| "NoSortAscending" #  Disable ability to sort in the ascending direction.
---| "NoSortDescending" #  Disable ability to sort in the descending direction.
---| "NoHeaderLabel" #  TableHeadersRow() will not submit horizontal label for this column. Convenient for some small columns. Name will still appear in context menu or in angled headers.
---| "NoHeaderWidth" #  Disable header text width contribution to automatic column width.
---| "PreferSortAscending" #  Make the initial sort direction Ascending when first sorting on this column (default).
---| "PreferSortDescending" #  Make the initial sort direction Descending when first sorting on this column.
---| "IndentEnable" #  Use current Indent value when entering cell (default for column 0).
---| "IndentDisable" #  Ignore current Indent value when entering cell (default for columns > 0). Indentation changes _within_ the cell will still be honored.
---| "AngledHeader" #  TableHeadersRow() will submit an angled header row for this column. Note this will add an extra row.
---| "IsEnabled" #  Status: is enabled == not hidden by user/api (referred to as "Hide" in _DefaultHide and _NoHide) flags.
---| "IsVisible" #  Status: is visible == is enabled AND not clipped by scrolling.
---| "IsSorted" #  Status: is currently part of the sort specs
---| "IsHovered" #  Status: is hovered by mouse

---@param flags _ImGuiTableColumnFlags_Name[]
---@return ImGuiTableColumnFlags
function ImGui.Flags.TableColumn(flags) end

--
-- Flags for ImGui::TableNextRow()
--
---@class ImGuiTableRowFlags

---@alias _ImGuiTableRowFlags_Name
---| "None"
---| "Headers" #  Identify header row (set default background color + width of its contents accounted differently for auto column width)

---@param flags _ImGuiTableRowFlags_Name[]
---@return ImGuiTableRowFlags
function ImGui.Flags.TableRow(flags) end

--
-- Enum for ImGui::TableSetBgColor()
-- Background colors are rendering in 3 layers:
--  - Layer 0: draw with RowBg0 color if set, otherwise draw with ColumnBg0 if set.
--  - Layer 1: draw with RowBg1 color if set, otherwise draw with ColumnBg1 if set.
--  - Layer 2: draw with CellBg color if set.
-- The purpose of the two row/columns layers is to let you decide if a background color change should override or blend with the existing color.
-- When using ImGuiTableFlags_RowBg on the table, each row has the RowBg0 color automatically set for odd/even rows.
-- If you set the color of RowBg0 target, your color will override the existing RowBg0 color.
-- If you set the color of RowBg1 or ColumnBg1 target, your color will blend over the RowBg0 color.
--
---@class ImGuiTableBgTarget

--
-- Flags for ImDrawList functions
-- (Legacy: bit 0 must always correspond to ImDrawFlags_Closed to be backward compatible with old API using a bool. Bits 1..3 must be unused)
--
---@class ImDrawFlags

---@alias _ImDrawFlags_Name
---| "None"
---| "Closed" #  PathStroke(), AddPolyline(): specify that shape should be closed (Important: this is always == 1 for legacy reason)
---| "RoundCornersTopLeft" #  AddRect(), AddRectFilled(), PathRect(): enable rounding top-left corner only (when rounding > 0.0f, we default to all corners). Was 0x01.
---| "RoundCornersTopRight" #  AddRect(), AddRectFilled(), PathRect(): enable rounding top-right corner only (when rounding > 0.0f, we default to all corners). Was 0x02.
---| "RoundCornersBottomLeft" #  AddRect(), AddRectFilled(), PathRect(): enable rounding bottom-left corner only (when rounding > 0.0f, we default to all corners). Was 0x04.
---| "RoundCornersBottomRight" #  AddRect(), AddRectFilled(), PathRect(): enable rounding bottom-right corner only (when rounding > 0.0f, we default to all corners). Wax 0x08.
---| "RoundCornersNone" #  AddRect(), AddRectFilled(), PathRect(): disable rounding on all corners (when rounding > 0.0f). This is NOT zero, NOT an implicit flag!
---| "RoundCornersTop"
---| "RoundCornersBottom"
---| "RoundCornersLeft"
---| "RoundCornersRight"
---| "RoundCornersAll"

---@param flags _ImDrawFlags_Name[]
---@return ImDrawFlags
function ImGui.Flags.nil(flags) end

--
-- Flags for ImDrawList instance. Those are set automatically by ImGui:: functions from ImGuiIO settings, and generally not manipulated directly.
-- It is however possible to temporarily alter flags between calls to ImDrawList:: functions.
--
---@class ImDrawListFlags

---@alias _ImDrawListFlags_Name
---| "None"
---| "AntiAliasedLines" #  Enable anti-aliased lines/borders (*2 the number of triangles for 1.0f wide line or lines thin enough to be drawn using textures, otherwise *3 the number of triangles)
---| "AntiAliasedLinesUseTex" #  Enable anti-aliased lines/borders using textures when possible. Require backend to render with bilinear filtering (NOT point/nearest filtering).
---| "AntiAliasedFill" #  Enable anti-aliased edge around filled shapes (rounded rectangles, circles).
---| "AllowVtxOffset" #  Can emit 'VtxOffset > 0' to allow large meshes. Set when 'ImGuiBackendFlags_RendererHasVtxOffset' is enabled.

---@param flags _ImDrawListFlags_Name[]
---@return ImDrawListFlags
function ImGui.Flags.nil(flags) end

--
-- Flags for ImFontAtlas build
--
---@class ImFontAtlasFlags

---@alias _ImFontAtlasFlags_Name
---| "None"
---| "NoPowerOfTwoHeight" #  Don't round the height to next power of two
---| "NoMouseCursors" #  Don't build software mouse cursors into the atlas (save a little texture memory)
---| "NoBakedLines" #  Don't build thick line textures into the atlas (save a little texture memory, allow support for point/nearest filtering). The AntiAliasedLinesUseTex features uses them, otherwise they will be rendered using polygons (more expensive for CPU/GPU).

---@param flags _ImFontAtlasFlags_Name[]
---@return ImFontAtlasFlags
function ImGui.Flags.nil(flags) end

--
-- Flags stored in ImGuiViewport::Flags, giving indications to the platform backends.
--
---@class ImGuiViewportFlags

---@alias _ImGuiViewportFlags_Name
---| "None"
---| "IsPlatformWindow" #  Represent a Platform Window
---| "IsPlatformMonitor" #  Represent a Platform Monitor (unused yet)
---| "OwnedByApp" #  Platform Window: Was created/managed by the user application? (rather than our backend)
---| "NoDecoration" #  Platform Window: Disable platform decorations: title bar, borders, etc. (generally set all windows, but if ImGuiConfigFlags_ViewportsDecoration is set we only set this on popups/tooltips)
---| "NoTaskBarIcon" #  Platform Window: Disable platform task bar icon (generally set on popups/tooltips, or all windows if ImGuiConfigFlags_ViewportsNoTaskBarIcon is set)
---| "NoFocusOnAppearing" #  Platform Window: Don't take focus when created.
---| "NoFocusOnClick" #  Platform Window: Don't take focus when clicked on.
---| "NoInputs" #  Platform Window: Make mouse pass through so we can drag this window while peaking behind it.
---| "NoRendererClear" #  Platform Window: Renderer doesn't need to clear the framebuffer ahead (because we will fill it entirely).
---| "NoAutoMerge" #  Platform Window: Avoid merging this window into another host window. This can only be set via ImGuiWindowClass viewport flags override (because we need to now ahead if we are going to create a viewport in the first place!).
---| "TopMost" #  Platform Window: Display on top (for tooltips only).
---| "CanHostOtherWindows" #  Viewport can host multiple imgui windows (secondary viewports are associated to a single window). // FIXME: In practice there's still probably code making the assumption that this is always and only on the MainViewport. Will fix once we add support for "no main viewport".
---| "IsMinimized" #  Platform Window: Window is minimized, can skip render. When minimized we tend to avoid using the viewport pos/size for clipping window or testing if they are contained in the viewport.
---| "IsFocused" #  Platform Window: Window is focused (last call to Platform_GetWindowFocus() returned true)

---@param flags _ImGuiViewportFlags_Name[]
---@return ImGuiViewportFlags
function ImGui.Flags.Viewport(flags) end


--
-- Tables
-- - Full-featured replacement for old Columns API.
-- - See Demo->Tables for demo code. See top of imgui_tables.cpp for general commentary.
-- - See ImGuiTableFlags_ and ImGuiTableColumnFlags_ enums for a description of available flags.
-- The typical call flow is:
-- - 1. Call BeginTable(), early out if returning false.
-- - 2. Optionally call TableSetupColumn() to submit column name/flags/defaults.
-- - 3. Optionally call TableSetupScrollFreeze() to request scroll freezing of columns/rows.
-- - 4. Optionally call TableHeadersRow() to submit a header row. Names are pulled from TableSetupColumn() data.
-- - 5. Populate contents:
--    - In most situations you can use TableNextRow() + TableSetColumnIndex(N) to start appending into a column.
--    - If you are using tables as a sort of grid, where every column is holding the same type of contents,
--      you may prefer using TableNextColumn() instead of TableNextRow() + TableSetColumnIndex().
--      TableNextColumn() will automatically wrap-around into the next row if needed.
--    - IMPORTANT: Comparatively to the old Columns() API, we need to call TableNextColumn() for the first column!
--    - Summary of possible call flow:
--        - TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
--        - TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
--        -                   TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
--        - TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
-- - 5. Call EndTable()
--
--
-- Implied outer_size = ImVec2(0.0f, 0.0f), inner_width = 0.0f
--
---@param str_id string
---@param column integer
---@param flags? ImGuiTableFlags | `ImGui.Flags.Table { "None" }`
---@return boolean
function ImGui.BeginTable(str_id, column, flags) end

---@param str_id string
---@param column integer
---@param flags? ImGuiTableFlags | `ImGui.Flags.Table { "None" }`
---@param outer_size_x? number | `0.0`
---@param outer_size_y? number | `0.0`
---@param inner_width? number | `0.0`
---@return boolean
function ImGui.BeginTableEx(str_id, column, flags, outer_size_x, outer_size_y, inner_width) end

--
-- only call EndTable() if BeginTable() returns true!
--
function ImGui.EndTable() end

--
-- Implied row_flags = 0, min_row_height = 0.0f
--
function ImGui.TableNextRow() end

--
-- append into the first cell of a new row.
--
---@param row_flags? ImGuiTableRowFlags | `ImGui.Flags.TableRow { "None" }`
---@param min_row_height? number | `0.0`
function ImGui.TableNextRowEx(row_flags, min_row_height) end

--
-- append into the next column (or first column of next row if currently in last column). Return true when column is visible.
--
---@return boolean
function ImGui.TableNextColumn() end

--
-- append into the specified column. Return true when column is visible.
--
---@param column_n integer
---@return boolean
function ImGui.TableSetColumnIndex(column_n) end

--
-- Tables: Headers & Columns declaration
-- - Use TableSetupColumn() to specify label, resizing policy, default width/weight, id, various other flags etc.
-- - Use TableHeadersRow() to create a header row and automatically submit a TableHeader() for each column.
--   Headers are required to perform: reordering, sorting, and opening the context menu.
--   The context menu can also be made available in columns body using ImGuiTableFlags_ContextMenuInBody.
-- - You may manually submit headers using TableNextRow() + TableHeader() calls, but this is only useful in
--   some advanced use cases (e.g. adding custom widgets in header row).
-- - Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when scrolled.
--
--
-- Implied init_width_or_weight = 0.0f, user_id = 0
--
---@param label string
---@param flags? ImGuiTableColumnFlags | `ImGui.Flags.TableColumn { "None" }`
function ImGui.TableSetupColumn(label, flags) end

---@param label string
---@param flags? ImGuiTableColumnFlags | `ImGui.Flags.TableColumn { "None" }`
---@param init_width_or_weight? number | `0.0`
---@param user_id? integer | `0`
function ImGui.TableSetupColumnEx(label, flags, init_width_or_weight, user_id) end

--
-- lock columns/rows so they stay visible when scrolled.
--
---@param cols integer
---@param rows integer
function ImGui.TableSetupScrollFreeze(cols, rows) end

--
-- submit one header cell manually (rarely used)
--
---@param label string
function ImGui.TableHeader(label) end

--
-- submit a row with headers cells based on data provided to TableSetupColumn() + submit context menu
--
function ImGui.TableHeadersRow() end

--
-- submit a row with angled headers for every column with the ImGuiTableColumnFlags_AngledHeader flag. MUST BE FIRST ROW.
--
function ImGui.TableAngledHeadersRow() end

--
-- return number of columns (value passed to BeginTable)
--
---@return integer
function ImGui.TableGetColumnCount() end

--
-- return current column index.
--
---@return integer
function ImGui.TableGetColumnIndex() end

--
-- return current row index.
--
---@return integer
function ImGui.TableGetRowIndex() end

--
-- return "" if column didn't have a name declared by TableSetupColumn(). Pass -1 to use current column.
--
---@param column_n? integer | `-1`
---@return string
function ImGui.TableGetColumnName(column_n) end

--
-- return column flags so you can query their Enabled/Visible/Sorted/Hovered status flags. Pass -1 to use current column.
--
---@param column_n? integer | `-1`
---@return ImGuiTableColumnFlags
function ImGui.TableGetColumnFlags(column_n) end

--
-- change user accessible enabled/disabled state of a column. Set to false to hide the column. User can use the context menu to change this themselves (right-click in headers, or right-click in columns body with ImGuiTableFlags_ContextMenuInBody)
--
---@param column_n integer
---@param v boolean
function ImGui.TableSetColumnEnabled(column_n, v) end

--
-- change the color of a cell, row, or column. See ImGuiTableBgTarget_ flags for details.
--
---@param target ImGuiTableBgTarget
---@param color integer
---@param column_n? integer | `-1`
function ImGui.TableSetBgColor(target, color, column_n) end

--
-- Tab Bars, Tabs
-- - Note: Tabs are automatically created by the docking system (when in 'docking' branch). Use this to create tab bars/tabs yourself.
--
--
-- create and append into a TabBar
--
---@param str_id string
---@param flags? ImGuiTabBarFlags | `ImGui.Flags.TabBar { "None" }`
---@return boolean
function ImGui.BeginTabBar(str_id, flags) end

--
-- only call EndTabBar() if BeginTabBar() returns true!
--
function ImGui.EndTabBar() end

--
-- create a Tab. Returns true if the Tab is selected.
--
---@param label string
---@param p_open true | nil
---@param flags? ImGuiTabItemFlags | `ImGui.Flags.TabItem { "None" }`
---@return boolean
---@return boolean p_open
function ImGui.BeginTabItem(label, p_open, flags) end

--
-- only call EndTabItem() if BeginTabItem() returns true!
--
function ImGui.EndTabItem() end

--
-- create a Tab behaving like a button. return true when clicked. cannot be selected in the tab bar.
--
---@param label string
---@param flags? ImGuiTabItemFlags | `ImGui.Flags.TabItem { "None" }`
---@return boolean
function ImGui.TabItemButton(label, flags) end

--
-- notify TabBar or Docking system of a closed tab/window ahead (useful to reduce visual flicker on reorderable tab bars). For tab-bar: call after BeginTabBar() and before Tab submissions. Otherwise call with a window name.
--
---@param tab_or_docked_window_label string
function ImGui.SetTabItemClosed(tab_or_docked_window_label) end

--
-- Implied viewport = NULL, flags = 0, window_class = NULL
--
---@return integer
function ImGui.DockSpaceOverViewport() end

--
-- set next window dock id
--
---@param dock_id integer
---@param cond? ImGuiCond | `ImGui.Flags.nil { "None" }`
function ImGui.SetNextWindowDockID(dock_id, cond) end

---@return integer
function ImGui.GetWindowDockID() end

--
-- is current window docked into another window?
--
---@return boolean
function ImGui.IsWindowDocked() end

--
-- Drag and Drop
-- - On source items, call BeginDragDropSource(), if it returns true also call SetDragDropPayload() + EndDragDropSource().
-- - On target candidates, call BeginDragDropTarget(), if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
-- - If you stop calling BeginDragDropSource() the payload is preserved however it won't have a preview tooltip (we currently display a fallback "..." tooltip, see #1725)
-- - An item can be both drag source and drop target.
--
--
-- call after submitting an item which may be dragged. when this return true, you can call SetDragDropPayload() + EndDragDropSource()
--
---@param flags? ImGuiDragDropFlags | `ImGui.Flags.DragDrop { "None" }`
---@return boolean
function ImGui.BeginDragDropSource(flags) end

--
-- type is a user defined string of maximum 32 characters. Strings starting with '_' are reserved for dear imgui internal types. Data is copied and held by imgui. Return true when payload has been accepted.
--
---@param type string
---@param data string
---@param cond? ImGuiCond | `ImGui.Flags.nil { "None" }`
---@return boolean
function ImGui.SetDragDropPayload(type, data, cond) end

--
-- only call EndDragDropSource() if BeginDragDropSource() returns true!
--
function ImGui.EndDragDropSource() end

--
-- call after submitting an item that may receive a payload. If this returns true, you can call AcceptDragDropPayload() + EndDragDropTarget()
--
---@return boolean
function ImGui.BeginDragDropTarget() end

--
-- accept contents of a given type. If ImGuiDragDropFlags_AcceptBeforeDelivery is set you can peek into the payload before the mouse button is released.
--
---@param type string
---@param flags? ImGuiDragDropFlags | `ImGui.Flags.DragDrop { "None" }`
---@return string | nil
function ImGui.AcceptDragDropPayload(type, flags) end

--
-- only call EndDragDropTarget() if BeginDragDropTarget() returns true!
--
function ImGui.EndDragDropTarget() end

--
-- peek directly into the current payload from anywhere. returns NULL when drag and drop is finished or inactive. use ImGuiPayload::IsDataType() to test for the payload type.
--
---@return string | nil
function ImGui.GetDragDropPayload() end

--
-- Disabling [BETA API]
-- - Disable all user interactions and dim items visuals (applying style.DisabledAlpha over current colors)
-- - Those can be nested but it cannot be used to enable an already disabled section (a single BeginDisabled(true) in the stack is enough to keep everything disabled)
-- - BeginDisabled(false) essentially does nothing useful but is provided to facilitate use of boolean expressions. If you can avoid calling BeginDisabled(False)/EndDisabled() best to avoid it.
--
---@param disabled? boolean | `true`
function ImGui.BeginDisabled(disabled) end

function ImGui.EndDisabled() end

--
-- Clipping
-- - Mouse hovering is affected by ImGui::PushClipRect() calls, unlike direct calls to ImDrawList::PushClipRect() which are render only.
--
---@param clip_rect_min_x number
---@param clip_rect_min_y number
---@param clip_rect_max_x number
---@param clip_rect_max_y number
---@param intersect_with_current_clip_rect boolean
function ImGui.PushClipRect(clip_rect_min_x, clip_rect_min_y, clip_rect_max_x, clip_rect_max_y, intersect_with_current_clip_rect) end

function ImGui.PopClipRect() end

return ImGui
