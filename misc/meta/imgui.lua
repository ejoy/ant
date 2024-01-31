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

---@class _ImGuiDataType_Name
---@field S8 ImGuiDataType #  signed char / char (with sensible compilers)
---@field U8 ImGuiDataType #  unsigned char
---@field S16 ImGuiDataType #  short
---@field U16 ImGuiDataType #  unsigned short
---@field S32 ImGuiDataType #  int
---@field U32 ImGuiDataType #  unsigned int
---@field S64 ImGuiDataType #  long long / __int64
---@field U64 ImGuiDataType #  unsigned long long / unsigned __int64
---@field Float ImGuiDataType #  float
---@field Double ImGuiDataType #  double
ImGui.Enum.DataType = {}

--
-- A cardinal direction
--
---@class ImGuiDir

---@class _ImGuiDir_Name
---@field None ImGuiDir
---@field Left ImGuiDir
---@field Right ImGuiDir
---@field Up ImGuiDir
---@field Down ImGuiDir
ImGui.Enum.Dir = {}

--
-- A sorting direction
--
---@class ImGuiSortDirection

---@class _ImGuiSortDirection_Name
---@field None ImGuiSortDirection
---@field Ascending ImGuiSortDirection #  Ascending = 0->9, A->Z etc.
---@field Descending ImGuiSortDirection #  Descending = 9->0, Z->A etc.
ImGui.Enum.SortDirection = {}

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

---@class _ImGuiKey_Name
---@field None ImGuiKey
---@field Tab ImGuiKey #  == ImGuiKey_NamedKey_BEGIN
---@field LeftArrow ImGuiKey
---@field RightArrow ImGuiKey
---@field UpArrow ImGuiKey
---@field DownArrow ImGuiKey
---@field PageUp ImGuiKey
---@field PageDown ImGuiKey
---@field Home ImGuiKey
---@field End ImGuiKey
---@field Insert ImGuiKey
---@field Delete ImGuiKey
---@field Backspace ImGuiKey
---@field Space ImGuiKey
---@field Enter ImGuiKey
---@field Escape ImGuiKey
---@field LeftCtrl ImGuiKey
---@field LeftShift ImGuiKey
---@field LeftAlt ImGuiKey
---@field LeftSuper ImGuiKey
---@field RightCtrl ImGuiKey
---@field RightShift ImGuiKey
---@field RightAlt ImGuiKey
---@field RightSuper ImGuiKey
---@field Menu ImGuiKey
---@field [0] ImGuiKey
---@field [1] ImGuiKey
---@field [2] ImGuiKey
---@field [3] ImGuiKey
---@field [4] ImGuiKey
---@field [5] ImGuiKey
---@field [6] ImGuiKey
---@field [7] ImGuiKey
---@field [8] ImGuiKey
---@field [9] ImGuiKey
---@field A ImGuiKey
---@field B ImGuiKey
---@field C ImGuiKey
---@field D ImGuiKey
---@field E ImGuiKey
---@field F ImGuiKey
---@field G ImGuiKey
---@field H ImGuiKey
---@field I ImGuiKey
---@field J ImGuiKey
---@field K ImGuiKey
---@field L ImGuiKey
---@field M ImGuiKey
---@field N ImGuiKey
---@field O ImGuiKey
---@field P ImGuiKey
---@field Q ImGuiKey
---@field R ImGuiKey
---@field S ImGuiKey
---@field T ImGuiKey
---@field U ImGuiKey
---@field V ImGuiKey
---@field W ImGuiKey
---@field X ImGuiKey
---@field Y ImGuiKey
---@field Z ImGuiKey
---@field F1 ImGuiKey
---@field F2 ImGuiKey
---@field F3 ImGuiKey
---@field F4 ImGuiKey
---@field F5 ImGuiKey
---@field F6 ImGuiKey
---@field F7 ImGuiKey
---@field F8 ImGuiKey
---@field F9 ImGuiKey
---@field F10 ImGuiKey
---@field F11 ImGuiKey
---@field F12 ImGuiKey
---@field F13 ImGuiKey
---@field F14 ImGuiKey
---@field F15 ImGuiKey
---@field F16 ImGuiKey
---@field F17 ImGuiKey
---@field F18 ImGuiKey
---@field F19 ImGuiKey
---@field F20 ImGuiKey
---@field F21 ImGuiKey
---@field F22 ImGuiKey
---@field F23 ImGuiKey
---@field F24 ImGuiKey
---@field Apostrophe ImGuiKey #  '
---@field Comma ImGuiKey #  ,
---@field Minus ImGuiKey #  -
---@field Period ImGuiKey #  .
---@field Slash ImGuiKey #  /
---@field Semicolon ImGuiKey #  ;
---@field Equal ImGuiKey #  =
---@field LeftBracket ImGuiKey #  [
---@field Backslash ImGuiKey #  \ (this text inhibit multiline comment caused by backslash)
---@field RightBracket ImGuiKey #  ]
---@field GraveAccent ImGuiKey #  `
---@field CapsLock ImGuiKey
---@field ScrollLock ImGuiKey
---@field NumLock ImGuiKey
---@field PrintScreen ImGuiKey
---@field Pause ImGuiKey
---@field Keypad0 ImGuiKey
---@field Keypad1 ImGuiKey
---@field Keypad2 ImGuiKey
---@field Keypad3 ImGuiKey
---@field Keypad4 ImGuiKey
---@field Keypad5 ImGuiKey
---@field Keypad6 ImGuiKey
---@field Keypad7 ImGuiKey
---@field Keypad8 ImGuiKey
---@field Keypad9 ImGuiKey
---@field KeypadDecimal ImGuiKey
---@field KeypadDivide ImGuiKey
---@field KeypadMultiply ImGuiKey
---@field KeypadSubtract ImGuiKey
---@field KeypadAdd ImGuiKey
---@field KeypadEnter ImGuiKey
---@field KeypadEqual ImGuiKey
---@field AppBack ImGuiKey #  Available on some keyboard/mouses. Often referred as "Browser Back"
---@field AppForward ImGuiKey
---@field GamepadStart ImGuiKey #  Menu (Xbox)      + (Switch)   Start/Options (PS)
---@field GamepadBack ImGuiKey #  View (Xbox)      - (Switch)   Share (PS)
---@field GamepadFaceLeft ImGuiKey #  X (Xbox)         Y (Switch)   Square (PS)        // Tap: Toggle Menu. Hold: Windowing mode (Focus/Move/Resize windows)
---@field GamepadFaceRight ImGuiKey #  B (Xbox)         A (Switch)   Circle (PS)        // Cancel / Close / Exit
---@field GamepadFaceUp ImGuiKey #  Y (Xbox)         X (Switch)   Triangle (PS)      // Text Input / On-screen Keyboard
---@field GamepadFaceDown ImGuiKey #  A (Xbox)         B (Switch)   Cross (PS)         // Activate / Open / Toggle / Tweak
---@field GamepadDpadLeft ImGuiKey #  D-pad Left                                       // Move / Tweak / Resize Window (in Windowing mode)
---@field GamepadDpadRight ImGuiKey #  D-pad Right                                      // Move / Tweak / Resize Window (in Windowing mode)
---@field GamepadDpadUp ImGuiKey #  D-pad Up                                         // Move / Tweak / Resize Window (in Windowing mode)
---@field GamepadDpadDown ImGuiKey #  D-pad Down                                       // Move / Tweak / Resize Window (in Windowing mode)
---@field GamepadL1 ImGuiKey #  L Bumper (Xbox)  L (Switch)   L1 (PS)            // Tweak Slower / Focus Previous (in Windowing mode)
---@field GamepadR1 ImGuiKey #  R Bumper (Xbox)  R (Switch)   R1 (PS)            // Tweak Faster / Focus Next (in Windowing mode)
---@field GamepadL2 ImGuiKey #  L Trig. (Xbox)   ZL (Switch)  L2 (PS) [Analog]
---@field GamepadR2 ImGuiKey #  R Trig. (Xbox)   ZR (Switch)  R2 (PS) [Analog]
---@field GamepadL3 ImGuiKey #  L Stick (Xbox)   L3 (Switch)  L3 (PS)
---@field GamepadR3 ImGuiKey #  R Stick (Xbox)   R3 (Switch)  R3 (PS)
---@field GamepadLStickLeft ImGuiKey #  [Analog]                                         // Move Window (in Windowing mode)
---@field GamepadLStickRight ImGuiKey #  [Analog]                                         // Move Window (in Windowing mode)
---@field GamepadLStickUp ImGuiKey #  [Analog]                                         // Move Window (in Windowing mode)
---@field GamepadLStickDown ImGuiKey #  [Analog]                                         // Move Window (in Windowing mode)
---@field GamepadRStickLeft ImGuiKey #  [Analog]
---@field GamepadRStickRight ImGuiKey #  [Analog]
---@field GamepadRStickUp ImGuiKey #  [Analog]
---@field GamepadRStickDown ImGuiKey #  [Analog]
---@field MouseLeft ImGuiKey
---@field MouseRight ImGuiKey
---@field MouseMiddle ImGuiKey
---@field MouseX1 ImGuiKey
---@field MouseX2 ImGuiKey
---@field MouseWheelX ImGuiKey
---@field MouseWheelY ImGuiKey
---@field Ctrl ImGuiKey #  Ctrl
---@field Shift ImGuiKey #  Shift
---@field Alt ImGuiKey #  Option/Menu
---@field Super ImGuiKey #  Cmd/Super/Windows
---@field Shortcut ImGuiKey #  Alias for Ctrl (non-macOS) _or_ Super (macOS).
---@field KeysData_SIZE ImGuiKey #  Size of KeysData[]: only hold named keys
---@field KeysData_OFFSET ImGuiKey #  Accesses to io.KeysData[] must use (key - ImGuiKey_KeysData_OFFSET) index.
ImGui.Enum.Key = {}

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

---@class _ImGuiCol_Name
---@field Text ImGuiCol
---@field TextDisabled ImGuiCol
---@field WindowBg ImGuiCol #  Background of normal windows
---@field ChildBg ImGuiCol #  Background of child windows
---@field PopupBg ImGuiCol #  Background of popups, menus, tooltips windows
---@field Border ImGuiCol
---@field BorderShadow ImGuiCol
---@field FrameBg ImGuiCol #  Background of checkbox, radio button, plot, slider, text input
---@field FrameBgHovered ImGuiCol
---@field FrameBgActive ImGuiCol
---@field TitleBg ImGuiCol #  Title bar
---@field TitleBgActive ImGuiCol #  Title bar when focused
---@field TitleBgCollapsed ImGuiCol #  Title bar when collapsed
---@field MenuBarBg ImGuiCol
---@field ScrollbarBg ImGuiCol
---@field ScrollbarGrab ImGuiCol
---@field ScrollbarGrabHovered ImGuiCol
---@field ScrollbarGrabActive ImGuiCol
---@field CheckMark ImGuiCol #  Checkbox tick and RadioButton circle
---@field SliderGrab ImGuiCol
---@field SliderGrabActive ImGuiCol
---@field Button ImGuiCol
---@field ButtonHovered ImGuiCol
---@field ButtonActive ImGuiCol
---@field Header ImGuiCol #  Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem
---@field HeaderHovered ImGuiCol
---@field HeaderActive ImGuiCol
---@field Separator ImGuiCol
---@field SeparatorHovered ImGuiCol
---@field SeparatorActive ImGuiCol
---@field ResizeGrip ImGuiCol #  Resize grip in lower-right and lower-left corners of windows.
---@field ResizeGripHovered ImGuiCol
---@field ResizeGripActive ImGuiCol
---@field Tab ImGuiCol #  TabItem in a TabBar
---@field TabHovered ImGuiCol
---@field TabActive ImGuiCol
---@field TabUnfocused ImGuiCol
---@field TabUnfocusedActive ImGuiCol
---@field DockingPreview ImGuiCol #  Preview overlay color when about to docking something
---@field DockingEmptyBg ImGuiCol #  Background color for empty node (e.g. CentralNode with no window docked into it)
---@field PlotLines ImGuiCol
---@field PlotLinesHovered ImGuiCol
---@field PlotHistogram ImGuiCol
---@field PlotHistogramHovered ImGuiCol
---@field TableHeaderBg ImGuiCol #  Table header background
---@field TableBorderStrong ImGuiCol #  Table outer and header borders (prefer using Alpha=1.0 here)
---@field TableBorderLight ImGuiCol #  Table inner borders (prefer using Alpha=1.0 here)
---@field TableRowBg ImGuiCol #  Table row background (even rows)
---@field TableRowBgAlt ImGuiCol #  Table row background (odd rows)
---@field TextSelectedBg ImGuiCol
---@field DragDropTarget ImGuiCol #  Rectangle highlighting a drop target
---@field NavHighlight ImGuiCol #  Gamepad/keyboard: current highlighted item
---@field NavWindowingHighlight ImGuiCol #  Highlight window when using CTRL+TAB
---@field NavWindowingDimBg ImGuiCol #  Darken/colorize entire screen behind the CTRL+TAB window list, when active
---@field ModalWindowDimBg ImGuiCol #  Darken/colorize entire screen behind a modal window, when one is active
ImGui.Enum.Col = {}

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

---@class _ImGuiStyleVar_Name
---@field Alpha ImGuiStyleVar #  float     Alpha
---@field DisabledAlpha ImGuiStyleVar #  float     DisabledAlpha
---@field WindowPadding ImGuiStyleVar #  ImVec2    WindowPadding
---@field WindowRounding ImGuiStyleVar #  float     WindowRounding
---@field WindowBorderSize ImGuiStyleVar #  float     WindowBorderSize
---@field WindowMinSize ImGuiStyleVar #  ImVec2    WindowMinSize
---@field WindowTitleAlign ImGuiStyleVar #  ImVec2    WindowTitleAlign
---@field ChildRounding ImGuiStyleVar #  float     ChildRounding
---@field ChildBorderSize ImGuiStyleVar #  float     ChildBorderSize
---@field PopupRounding ImGuiStyleVar #  float     PopupRounding
---@field PopupBorderSize ImGuiStyleVar #  float     PopupBorderSize
---@field FramePadding ImGuiStyleVar #  ImVec2    FramePadding
---@field FrameRounding ImGuiStyleVar #  float     FrameRounding
---@field FrameBorderSize ImGuiStyleVar #  float     FrameBorderSize
---@field ItemSpacing ImGuiStyleVar #  ImVec2    ItemSpacing
---@field ItemInnerSpacing ImGuiStyleVar #  ImVec2    ItemInnerSpacing
---@field IndentSpacing ImGuiStyleVar #  float     IndentSpacing
---@field CellPadding ImGuiStyleVar #  ImVec2    CellPadding
---@field ScrollbarSize ImGuiStyleVar #  float     ScrollbarSize
---@field ScrollbarRounding ImGuiStyleVar #  float     ScrollbarRounding
---@field GrabMinSize ImGuiStyleVar #  float     GrabMinSize
---@field GrabRounding ImGuiStyleVar #  float     GrabRounding
---@field TabRounding ImGuiStyleVar #  float     TabRounding
---@field TabBarBorderSize ImGuiStyleVar #  float     TabBarBorderSize
---@field ButtonTextAlign ImGuiStyleVar #  ImVec2    ButtonTextAlign
---@field SelectableTextAlign ImGuiStyleVar #  ImVec2    SelectableTextAlign
---@field SeparatorTextBorderSize ImGuiStyleVar #  float  SeparatorTextBorderSize
---@field SeparatorTextAlign ImGuiStyleVar #  ImVec2    SeparatorTextAlign
---@field SeparatorTextPadding ImGuiStyleVar #  ImVec2    SeparatorTextPadding
---@field DockingSeparatorSize ImGuiStyleVar #  float     DockingSeparatorSize
ImGui.Enum.StyleVar = {}

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

---@class _ImGuiMouseButton_Name
---@field Left ImGuiMouseButton
---@field Right ImGuiMouseButton
---@field Middle ImGuiMouseButton
ImGui.Enum.MouseButton = {}

--
-- Enumeration for GetMouseCursor()
-- User code may request backend to display given cursor by calling SetMouseCursor(), which is why we have some cursors that are marked unused here
--
---@class ImGuiMouseCursor

---@class _ImGuiMouseCursor_Name
---@field None ImGuiMouseCursor
---@field Arrow ImGuiMouseCursor
---@field TextInput ImGuiMouseCursor #  When hovering over InputText, etc.
---@field ResizeAll ImGuiMouseCursor #  (Unused by Dear ImGui functions)
---@field ResizeNS ImGuiMouseCursor #  When hovering over a horizontal border
---@field ResizeEW ImGuiMouseCursor #  When hovering over a vertical border or a column
---@field ResizeNESW ImGuiMouseCursor #  When hovering over the bottom-left corner of a window
---@field ResizeNWSE ImGuiMouseCursor #  When hovering over the bottom-right corner of a window
---@field Hand ImGuiMouseCursor #  (Unused by Dear ImGui functions. Use for e.g. hyperlinks)
---@field NotAllowed ImGuiMouseCursor #  When hovering something with disallowed interaction. Usually a crossed circle.
ImGui.Enum.MouseCursor = {}

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

---@class _ImGuiMouseSource_Name
---@field Mouse ImGuiMouseSource #  Input is coming from an actual mouse.
---@field TouchScreen ImGuiMouseSource #  Input is coming from a touch screen (no hovering prior to initial press, less precise initial press aiming, dual-axis wheeling possible).
---@field Pen ImGuiMouseSource #  Input is coming from a pressure/magnetic pen (often used in conjunction with high-sampling rates).
ImGui.Enum.MouseSource = {}

--
-- Enumeration for ImGui::SetNextWindow***(), SetWindow***(), SetNextItem***() functions
-- Represent a condition.
-- Important: Treat as a regular enum! Do NOT combine multiple values using binary operators! All the functions above treat 0 as a shortcut to ImGuiCond_Always.
--
---@class ImGuiCond

---@class _ImGuiCond_Name
---@field None ImGuiCond #  No condition (always set the variable), same as _Always
---@field Always ImGuiCond #  No condition (always set the variable), same as _None
---@field Once ImGuiCond #  Set the variable once per runtime session (only the first call will succeed)
---@field FirstUseEver ImGuiCond #  Set the variable if the object/window has no persistently saved data (no entry in .ini file)
---@field Appearing ImGuiCond #  Set the variable if the object/window is appearing after being hidden/inactive (or the first time)
ImGui.Enum.Cond = {}

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

---@class _ImGuiTableBgTarget_Name
---@field None ImGuiTableBgTarget
---@field RowBg0 ImGuiTableBgTarget #  Set row background color 0 (generally used for background, automatically set when ImGuiTableFlags_RowBg is used)
---@field RowBg1 ImGuiTableBgTarget #  Set row background color 1 (generally used for selection marking)
---@field CellBg ImGuiTableBgTarget #  Set cell background color (top-most color)
ImGui.Enum.TableBgTarget = {}

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
function ImGui.Flags.Draw(flags) end

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
function ImGui.Flags.DrawList(flags) end

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
function ImGui.Flags.FontAtlas(flags) end

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


---@alias ImGuiKeyChord ImGuiKey
---@alias ImTextureID integer

--
-- Windows
-- - Begin() = push window to the stack and start appending to it. End() = pop window from the stack.
-- - Passing 'bool* p_open != NULL' shows a window-closing widget in the upper-right corner of the window,
--   which clicking will set the boolean to false when clicked.
-- - You may append multiple times to the same window during the same frame by calling Begin()/End() pairs multiple times.
--   Some information such as 'flags' or 'p_open' will only be considered by the first call to Begin().
-- - Begin() return false to indicate the window is collapsed or fully clipped, so you may early out and omit submitting
--   anything to the window. Always call a matching End() for each Begin() call, regardless of its return value!
--   [Important: due to legacy reason, Begin/End and BeginChild/EndChild are inconsistent with all other functions
--    such as BeginMenu/EndMenu, BeginPopup/EndPopup, etc. where the EndXXX call should only be called if the corresponding
--    BeginXXX function returned true. Begin and BeginChild are the only odd ones out. Will be fixed in a future update.]
-- - Note that the bottom of window stack always contains a window called "Debug".
--
---@param name string
---@param p_open true | nil
---@param flags? ImGuiWindowFlags | `ImGui.Flags.Window { "None" }`
---@return boolean
---@return boolean p_open
function ImGui.Begin(name, p_open, flags) end

function ImGui.End() end

--
-- Child Windows
-- - Use child windows to begin into a self-contained independent scrolling/clipping regions within a host window. Child windows can embed their own child.
-- - Before 1.90 (November 2023), the "ImGuiChildFlags child_flags = 0" parameter was "bool border = false".
--   This API is backward compatible with old code, as we guarantee that ImGuiChildFlags_Border == true.
--   Consider updating your old call sites:
--      BeginChild("Name", size, false)   -> Begin("Name", size, 0); or Begin("Name", size, ImGuiChildFlags_None);
--      BeginChild("Name", size, true)    -> Begin("Name", size, ImGuiChildFlags_Border);
-- - Manual sizing (each axis can use a different setting e.g. ImVec2(0.0f, 400.0f)):
--     == 0.0f: use remaining parent window size for this axis.
--      > 0.0f: use specified size for this axis.
--      < 0.0f: right/bottom-align to specified distance from available content boundaries.
-- - Specifying ImGuiChildFlags_AutoResizeX or ImGuiChildFlags_AutoResizeY makes the sizing automatic based on child contents.
--   Combining both ImGuiChildFlags_AutoResizeX _and_ ImGuiChildFlags_AutoResizeY defeats purpose of a scrolling region and is NOT recommended.
-- - BeginChild() returns false to indicate the window is collapsed or fully clipped, so you may early out and omit submitting
--   anything to the window. Always call a matching EndChild() for each BeginChild() call, regardless of its return value.
--   [Important: due to legacy reason, Begin/End and BeginChild/EndChild are inconsistent with all other functions
--    such as BeginMenu/EndMenu, BeginPopup/EndPopup, etc. where the EndXXX call should only be called if the corresponding
--    BeginXXX function returned true. Begin and BeginChild are the only odd ones out. Will be fixed in a future update.]
--
---@param str_id string
---@param size_x? number | `0`
---@param size_y? number | `0`
---@param child_flags? ImGuiChildFlags | `ImGui.Flags.Child { "None" }`
---@param window_flags? ImGuiWindowFlags | `ImGui.Flags.Window { "None" }`
---@return boolean
function ImGui.BeginChild(str_id, size_x, size_y, child_flags, window_flags) end

---@param id integer
---@param size_x? number | `0`
---@param size_y? number | `0`
---@param child_flags? ImGuiChildFlags | `ImGui.Flags.Child { "None" }`
---@param window_flags? ImGuiWindowFlags | `ImGui.Flags.Window { "None" }`
---@return boolean
function ImGui.BeginChildID(id, size_x, size_y, child_flags, window_flags) end

function ImGui.EndChild() end

--
-- Windows Utilities
-- - 'current window' = the window we are appending into while inside a Begin()/End() block. 'next window' = next window we will Begin() into.
--
---@return boolean
function ImGui.IsWindowAppearing() end

---@return boolean
function ImGui.IsWindowCollapsed() end

--
-- is current window focused? or its root/child, depending on flags. see flags for options.
--
---@param flags? ImGuiFocusedFlags | `ImGui.Flags.Focused { "None" }`
---@return boolean
function ImGui.IsWindowFocused(flags) end

--
-- is current window hovered and hoverable (e.g. not blocked by a popup/modal)? See ImGuiHoveredFlags_ for options. IMPORTANT: If you are trying to check whether your mouse should be dispatched to Dear ImGui or to your underlying app, you should not use this function! Use the 'io.WantCaptureMouse' boolean for that! Refer to FAQ entry "How can I tell whether to dispatch mouse/keyboard to Dear ImGui or my application?" for details.
--
---@param flags? ImGuiHoveredFlags | `ImGui.Flags.Hovered { "None" }`
---@return boolean
function ImGui.IsWindowHovered(flags) end

--
-- get DPI scale currently associated to the current window's viewport.
--
---@return number
function ImGui.GetWindowDpiScale() end

--
-- get current window position in screen space (note: it is unlikely you need to use this. Consider using current layout pos instead, GetCursorScreenPos())
--
---@return number
---@return number
function ImGui.GetWindowPos() end

--
-- get current window size (note: it is unlikely you need to use this. Consider using GetCursorScreenPos() and e.g. GetContentRegionAvail() instead)
--
---@return number
---@return number
function ImGui.GetWindowSize() end

--
-- get current window width (shortcut for GetWindowSize().x)
--
---@return number
function ImGui.GetWindowWidth() end

--
-- get current window height (shortcut for GetWindowSize().y)
--
---@return number
function ImGui.GetWindowHeight() end

--
-- Window manipulation
-- - Prefer using SetNextXXX functions (before Begin) rather that SetXXX functions (after Begin).
--
--
-- Implied pivot = ImVec2(0, 0)
--
---@param pos_x number
---@param pos_y number
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetNextWindowPos(pos_x, pos_y, cond) end

--
-- set next window position. call before Begin(). use pivot=(0.5f,0.5f) to center on given point, etc.
--
---@param pos_x number
---@param pos_y number
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
---@param pivot_x? number | `0`
---@param pivot_y? number | `0`
function ImGui.SetNextWindowPosEx(pos_x, pos_y, cond, pivot_x, pivot_y) end

--
-- set next window size. set axis to 0.0f to force an auto-fit on this axis. call before Begin()
--
---@param size_x number
---@param size_y number
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetNextWindowSize(size_x, size_y, cond) end

--
-- set next window content size (~ scrollable client area, which enforce the range of scrollbars). Not including window decorations (title bar, menu bar, etc.) nor WindowPadding. set an axis to 0.0f to leave it automatic. call before Begin()
--
---@param size_x number
---@param size_y number
function ImGui.SetNextWindowContentSize(size_x, size_y) end

--
-- set next window collapsed state. call before Begin()
--
---@param collapsed boolean
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetNextWindowCollapsed(collapsed, cond) end

--
-- set next window to be focused / top-most. call before Begin()
--
function ImGui.SetNextWindowFocus() end

--
-- set next window scrolling value (use < 0.0f to not affect a given axis).
--
---@param scroll_x number
---@param scroll_y number
function ImGui.SetNextWindowScroll(scroll_x, scroll_y) end

--
-- set next window background color alpha. helper to easily override the Alpha component of ImGuiCol_WindowBg/ChildBg/PopupBg. you may also use ImGuiWindowFlags_NoBackground.
--
---@param alpha number
function ImGui.SetNextWindowBgAlpha(alpha) end

--
-- set next window viewport
--
---@param viewport_id integer
function ImGui.SetNextWindowViewport(viewport_id) end

--
-- (not recommended) set current window position - call within Begin()/End(). prefer using SetNextWindowPos(), as this may incur tearing and side-effects.
--
---@param pos_x number
---@param pos_y number
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetWindowPos(pos_x, pos_y, cond) end

--
-- (not recommended) set current window size - call within Begin()/End(). set to ImVec2(0, 0) to force an auto-fit. prefer using SetNextWindowSize(), as this may incur tearing and minor side-effects.
--
---@param size_x number
---@param size_y number
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetWindowSize(size_x, size_y, cond) end

--
-- (not recommended) set current window collapsed state. prefer using SetNextWindowCollapsed().
--
---@param collapsed boolean
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetWindowCollapsed(collapsed, cond) end

--
-- (not recommended) set current window to be focused / top-most. prefer using SetNextWindowFocus().
--
function ImGui.SetWindowFocus() end

--
-- [OBSOLETE] set font scale. Adjust IO.FontGlobalScale if you want to scale all windows. This is an old API! For correct scaling, prefer to reload font + rebuild ImFontAtlas + call style.ScaleAllSizes().
--
---@param scale number
function ImGui.SetWindowFontScale(scale) end

--
-- set named window position.
--
---@param name string
---@param pos_x number
---@param pos_y number
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetWindowPosStr(name, pos_x, pos_y, cond) end

--
-- set named window size. set axis to 0.0f to force an auto-fit on this axis.
--
---@param name string
---@param size_x number
---@param size_y number
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetWindowSizeStr(name, size_x, size_y, cond) end

--
-- set named window collapsed state
--
---@param name string
---@param collapsed boolean
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetWindowCollapsedStr(name, collapsed, cond) end

--
-- set named window to be focused / top-most. use NULL to remove focus.
--
---@param name string
function ImGui.SetWindowFocusStr(name) end

--
-- Content region
-- - Retrieve available space from a given point. GetContentRegionAvail() is frequently useful.
-- - Those functions are bound to be redesigned (they are confusing, incomplete and the Min/Max return values are in local window coordinates which increases confusion)
--
--
-- == GetContentRegionMax() - GetCursorPos()
--
---@return number
---@return number
function ImGui.GetContentRegionAvail() end

--
-- current content boundaries (typically window boundaries including scrolling, or current column boundaries), in windows coordinates
--
---@return number
---@return number
function ImGui.GetContentRegionMax() end

--
-- content boundaries min for the full window (roughly (0,0)-Scroll), in window coordinates
--
---@return number
---@return number
function ImGui.GetWindowContentRegionMin() end

--
-- content boundaries max for the full window (roughly (0,0)+Size-Scroll) where Size can be overridden with SetNextWindowContentSize(), in window coordinates
--
---@return number
---@return number
function ImGui.GetWindowContentRegionMax() end

--
-- Windows Scrolling
-- - Any change of Scroll will be applied at the beginning of next frame in the first call to Begin().
-- - You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this delay, as an alternative to using SetScrollX()/SetScrollY().
--
--
-- get scrolling amount [0 .. GetScrollMaxX()]
--
---@return number
function ImGui.GetScrollX() end

--
-- get scrolling amount [0 .. GetScrollMaxY()]
--
---@return number
function ImGui.GetScrollY() end

--
-- set scrolling amount [0 .. GetScrollMaxX()]
--
---@param scroll_x number
function ImGui.SetScrollX(scroll_x) end

--
-- set scrolling amount [0 .. GetScrollMaxY()]
--
---@param scroll_y number
function ImGui.SetScrollY(scroll_y) end

--
-- get maximum scrolling amount ~~ ContentSize.x - WindowSize.x - DecorationsSize.x
--
---@return number
function ImGui.GetScrollMaxX() end

--
-- get maximum scrolling amount ~~ ContentSize.y - WindowSize.y - DecorationsSize.y
--
---@return number
function ImGui.GetScrollMaxY() end

--
-- adjust scrolling amount to make current cursor position visible. center_x_ratio=0.0: left, 0.5: center, 1.0: right. When using to make a "default/current item" visible, consider using SetItemDefaultFocus() instead.
--
---@param center_x_ratio? number | `0.5`
function ImGui.SetScrollHereX(center_x_ratio) end

--
-- adjust scrolling amount to make current cursor position visible. center_y_ratio=0.0: top, 0.5: center, 1.0: bottom. When using to make a "default/current item" visible, consider using SetItemDefaultFocus() instead.
--
---@param center_y_ratio? number | `0.5`
function ImGui.SetScrollHereY(center_y_ratio) end

--
-- adjust scrolling amount to make given position visible. Generally GetCursorStartPos() + offset to compute a valid position.
--
---@param local_x number
---@param center_x_ratio? number | `0.5`
function ImGui.SetScrollFromPosX(local_x, center_x_ratio) end

--
-- adjust scrolling amount to make given position visible. Generally GetCursorStartPos() + offset to compute a valid position.
--
---@param local_y number
---@param center_y_ratio? number | `0.5`
function ImGui.SetScrollFromPosY(local_y, center_y_ratio) end

function ImGui.PopFont() end

--
-- modify a style color. always use this if you modify the style after NewFrame().
--
---@param idx ImGuiCol
---@param col integer
function ImGui.PushStyleColor(idx, col) end

---@param idx ImGuiCol
---@param col_x number
---@param col_y number
---@param col_z number
---@param col_w number
function ImGui.PushStyleColorImVec4(idx, col_x, col_y, col_z, col_w) end

--
-- Implied count = 1
--
function ImGui.PopStyleColor() end

---@param count? integer | `1`
function ImGui.PopStyleColorEx(count) end

--
-- modify a style float variable. always use this if you modify the style after NewFrame().
--
---@param idx ImGuiStyleVar
---@param val number
function ImGui.PushStyleVar(idx, val) end

--
-- modify a style ImVec2 variable. always use this if you modify the style after NewFrame().
--
---@param idx ImGuiStyleVar
---@param val_x number
---@param val_y number
function ImGui.PushStyleVarImVec2(idx, val_x, val_y) end

--
-- Implied count = 1
--
function ImGui.PopStyleVar() end

---@param count? integer | `1`
function ImGui.PopStyleVarEx(count) end

--
-- == tab stop enable. Allow focusing using TAB/Shift-TAB, enabled by default but you can disable it for certain widgets
--
---@param tab_stop boolean
function ImGui.PushTabStop(tab_stop) end

function ImGui.PopTabStop() end

--
-- in 'repeat' mode, Button*() functions return repeated true in a typematic manner (using io.KeyRepeatDelay/io.KeyRepeatRate setting). Note that you can call IsItemActive() after any Button() to tell if the button is held in the current frame.
--
---@param arg_repeat boolean
function ImGui.PushButtonRepeat(arg_repeat) end

function ImGui.PopButtonRepeat() end

--
-- Parameters stacks (current window)
--
--
-- push width of items for common large "item+label" widgets. >0.0f: width in pixels, <0.0f align xx pixels to the right of window (so -FLT_MIN always align width to the right side).
--
---@param item_width number
function ImGui.PushItemWidth(item_width) end

function ImGui.PopItemWidth() end

--
-- set width of the _next_ common large "item+label" widget. >0.0f: width in pixels, <0.0f align xx pixels to the right of window (so -FLT_MIN always align width to the right side)
--
---@param item_width number
function ImGui.SetNextItemWidth(item_width) end

--
-- width of item given pushed settings and current cursor position. NOT necessarily the width of last item unlike most 'Item' functions.
--
---@return number
function ImGui.CalcItemWidth() end

--
-- push word-wrapping position for Text*() commands. < 0.0f: no wrapping; 0.0f: wrap to end of window (or column); > 0.0f: wrap at 'wrap_pos_x' position in window local space
--
---@param wrap_local_pos_x? number | `0.0`
function ImGui.PushTextWrapPos(wrap_local_pos_x) end

function ImGui.PopTextWrapPos() end

--
-- get current font size (= height in pixels) of current font with current scale applied
--
---@return number
function ImGui.GetFontSize() end

--
-- get UV coordinate for a while pixel, useful to draw custom shapes via the ImDrawList API
--
---@return number
---@return number
function ImGui.GetFontTexUvWhitePixel() end

--
-- Implied alpha_mul = 1.0f
--
---@param idx ImGuiCol
---@return integer
function ImGui.GetColorU32(idx) end

--
-- retrieve given style color with style alpha applied and optional extra alpha multiplier, packed as a 32-bit value suitable for ImDrawList
--
---@param idx ImGuiCol
---@param alpha_mul? number | `1.0`
---@return integer
function ImGui.GetColorU32Ex(idx, alpha_mul) end

--
-- retrieve given color with style alpha applied, packed as a 32-bit value suitable for ImDrawList
--
---@param col_x number
---@param col_y number
---@param col_z number
---@param col_w number
---@return integer
function ImGui.GetColorU32ImVec4(col_x, col_y, col_z, col_w) end

--
-- retrieve given color with style alpha applied, packed as a 32-bit value suitable for ImDrawList
--
---@param col integer
---@return integer
function ImGui.GetColorU32ImU32(col) end

--
-- Layout cursor positioning
-- - By "cursor" we mean the current output position.
-- - The typical widget behavior is to output themselves at the current cursor position, then move the cursor one line down.
-- - You can call SameLine() between widgets to undo the last carriage return and output at the right of the preceding widget.
-- - Attention! We currently have inconsistencies between window-local and absolute positions we will aim to fix with future API:
--    - Absolute coordinate:        GetCursorScreenPos(), SetCursorScreenPos(), all ImDrawList:: functions. -> this is the preferred way forward.
--    - Window-local coordinates:   SameLine(), GetCursorPos(), SetCursorPos(), GetCursorStartPos(), GetContentRegionMax(), GetWindowContentRegion*(), PushTextWrapPos()
-- - GetCursorScreenPos() = GetCursorPos() + GetWindowPos(). GetWindowPos() is almost only ever useful to convert from window-local to absolute coordinates.
--
--
-- cursor position in absolute coordinates (prefer using this, also more useful to work with ImDrawList API).
--
---@return number
---@return number
function ImGui.GetCursorScreenPos() end

--
-- cursor position in absolute coordinates
--
---@param pos_x number
---@param pos_y number
function ImGui.SetCursorScreenPos(pos_x, pos_y) end

--
-- [window-local] cursor position in window coordinates (relative to window position)
--
---@return number
---@return number
function ImGui.GetCursorPos() end

--
-- [window-local] "
--
---@return number
function ImGui.GetCursorPosX() end

--
-- [window-local] "
--
---@return number
function ImGui.GetCursorPosY() end

--
-- [window-local] "
--
---@param local_pos_x number
---@param local_pos_y number
function ImGui.SetCursorPos(local_pos_x, local_pos_y) end

--
-- [window-local] "
--
---@param local_x number
function ImGui.SetCursorPosX(local_x) end

--
-- [window-local] "
--
---@param local_y number
function ImGui.SetCursorPosY(local_y) end

--
-- [window-local] initial cursor position, in window coordinates
--
---@return number
---@return number
function ImGui.GetCursorStartPos() end

--
-- Other layout functions
--
--
-- separator, generally horizontal. inside a menu bar or in horizontal layout mode, this becomes a vertical separator.
--
function ImGui.Separator() end

--
-- Implied offset_from_start_x = 0.0f, spacing = -1.0f
--
function ImGui.SameLine() end

--
-- call between widgets or groups to layout them horizontally. X position given in window coordinates.
--
---@param offset_from_start_x? number | `0.0`
---@param spacing? number | `-1.0`
function ImGui.SameLineEx(offset_from_start_x, spacing) end

--
-- undo a SameLine() or force a new line when in a horizontal-layout context.
--
function ImGui.NewLine() end

--
-- add vertical spacing.
--
function ImGui.Spacing() end

--
-- add a dummy item of given size. unlike InvisibleButton(), Dummy() won't take the mouse click or be navigable into.
--
---@param size_x number
---@param size_y number
function ImGui.Dummy(size_x, size_y) end

--
-- Implied indent_w = 0.0f
--
function ImGui.Indent() end

--
-- move content position toward the right, by indent_w, or style.IndentSpacing if indent_w <= 0
--
---@param indent_w? number | `0.0`
function ImGui.IndentEx(indent_w) end

--
-- Implied indent_w = 0.0f
--
function ImGui.Unindent() end

--
-- move content position back to the left, by indent_w, or style.IndentSpacing if indent_w <= 0
--
---@param indent_w? number | `0.0`
function ImGui.UnindentEx(indent_w) end

--
-- lock horizontal starting position
--
function ImGui.BeginGroup() end

--
-- unlock horizontal starting position + capture the whole group bounding box into one "item" (so you can use IsItemHovered() or layout primitives such as SameLine() on whole group, etc.)
--
function ImGui.EndGroup() end

--
-- vertically align upcoming text baseline to FramePadding.y so that it will align properly to regularly framed items (call if you have text on a line before a framed item)
--
function ImGui.AlignTextToFramePadding() end

--
-- ~ FontSize
--
---@return number
function ImGui.GetTextLineHeight() end

--
-- ~ FontSize + style.ItemSpacing.y (distance in pixels between 2 consecutive lines of text)
--
---@return number
function ImGui.GetTextLineHeightWithSpacing() end

--
-- ~ FontSize + style.FramePadding.y * 2
--
---@return number
function ImGui.GetFrameHeight() end

--
-- ~ FontSize + style.FramePadding.y * 2 + style.ItemSpacing.y (distance in pixels between 2 consecutive lines of framed widgets)
--
---@return number
function ImGui.GetFrameHeightWithSpacing() end

--
-- ID stack/scopes
-- Read the FAQ (docs/FAQ.md or http://dearimgui.com/faq) for more details about how ID are handled in dear imgui.
-- - Those questions are answered and impacted by understanding of the ID stack system:
--   - "Q: Why is my widget not reacting when I click on it?"
--   - "Q: How can I have widgets with an empty label?"
--   - "Q: How can I have multiple widgets with the same label?"
-- - Short version: ID are hashes of the entire ID stack. If you are creating widgets in a loop you most likely
--   want to push a unique identifier (e.g. object pointer, loop index) to uniquely differentiate them.
-- - You can also use the "Label##foobar" syntax within widget label to distinguish them from each others.
-- - In this header file we use the "label"/"name" terminology to denote a string that will be displayed + used as an ID,
--   whereas "str_id" denote a string that is only used as an ID and not normally displayed.
--
--
-- push string into the ID stack (will hash string).
--
---@param str_id string
function ImGui.PushID(str_id) end

--
-- push string into the ID stack (will hash string).
--
---@param str_id_begin string
---@param str_id_end string
function ImGui.PushIDStr(str_id_begin, str_id_end) end

--
-- push pointer into the ID stack (will hash pointer).
--
---@param ptr_id lightuserdata
function ImGui.PushIDPtr(ptr_id) end

--
-- push integer into the ID stack (will hash integer).
--
---@param int_id integer
function ImGui.PushIDInt(int_id) end

--
-- pop from the ID stack.
--
function ImGui.PopID() end

--
-- calculate unique ID (hash of whole ID stack + given parameter). e.g. if you want to query into ImGuiStorage yourself
--
---@param str_id string
---@return integer
function ImGui.GetID(str_id) end

---@param str_id_begin string
---@param str_id_end string
---@return integer
function ImGui.GetIDStr(str_id_begin, str_id_end) end

---@param ptr_id lightuserdata
---@return integer
function ImGui.GetIDPtr(ptr_id) end

--
-- formatted text
--
---@param fmt string
---@param ...  any
function ImGui.Text(fmt, ...) end

--
-- shortcut for PushStyleColor(ImGuiCol_Text, col); Text(fmt, ...); PopStyleColor();
--
---@param col_x number
---@param col_y number
---@param col_z number
---@param col_w number
---@param fmt string
---@param ...  any
function ImGui.TextColored(col_x, col_y, col_z, col_w, fmt, ...) end

--
-- shortcut for PushStyleColor(ImGuiCol_Text, style.Colors[ImGuiCol_TextDisabled]); Text(fmt, ...); PopStyleColor();
--
---@param fmt string
---@param ...  any
function ImGui.TextDisabled(fmt, ...) end

--
-- shortcut for PushTextWrapPos(0.0f); Text(fmt, ...); PopTextWrapPos();. Note that this won't work on an auto-resizing window if there's no other widgets to extend the window width, yoy may need to set a size using SetNextWindowSize().
--
---@param fmt string
---@param ...  any
function ImGui.TextWrapped(fmt, ...) end

--
-- display text+label aligned the same way as value+label widgets
--
---@param label string
---@param fmt string
---@param ...  any
function ImGui.LabelText(label, fmt, ...) end

--
-- shortcut for Bullet()+Text()
--
---@param fmt string
---@param ...  any
function ImGui.BulletText(fmt, ...) end

--
-- currently: formatted text with an horizontal line
--
---@param label string
function ImGui.SeparatorText(label) end

--
-- Widgets: Main
-- - Most widgets return true when the value has been changed or when pressed/selected
-- - You may also use one of the many IsItemXXX functions (e.g. IsItemActive, IsItemHovered, etc.) to query widget state.
--
--
-- Implied size = ImVec2(0, 0)
--
---@param label string
---@return boolean
function ImGui.Button(label) end

--
-- button
--
---@param label string
---@param size_x? number | `0`
---@param size_y? number | `0`
---@return boolean
function ImGui.ButtonEx(label, size_x, size_y) end

--
-- button with (FramePadding.y == 0) to easily embed within text
--
---@param label string
---@return boolean
function ImGui.SmallButton(label) end

--
-- flexible button behavior without the visuals, frequently useful to build custom behaviors using the public api (along with IsItemActive, IsItemHovered, etc.)
--
---@param str_id string
---@param size_x number
---@param size_y number
---@param flags? ImGuiButtonFlags | `ImGui.Flags.Button { "None" }`
---@return boolean
function ImGui.InvisibleButton(str_id, size_x, size_y, flags) end

--
-- square button with an arrow shape
--
---@param str_id string
---@param dir ImGuiDir
---@return boolean
function ImGui.ArrowButton(str_id, dir) end

---@param label string
---@param v boolean[]
---@return boolean
---@return boolean v
function ImGui.Checkbox(label, v) end

---@param label string
---@param flags integer[]
---@param flags_value integer
---@return boolean
function ImGui.CheckboxFlagsIntPtr(label, flags, flags_value) end

--
-- use with e.g. if (RadioButton("one", my_value==1)) { my_value = 1; }
--
---@param label string
---@param active boolean
---@return boolean
function ImGui.RadioButton(label, active) end

--
-- shortcut to handle the above pattern when value is an integer
--
---@param label string
---@param v integer[]
---@param v_button integer
---@return boolean
function ImGui.RadioButtonIntPtr(label, v, v_button) end

---@param fraction number
---@param size_arg_x? number | `-math.huge`
---@param size_arg_y? number | `0`
---@param overlay? string
function ImGui.ProgressBar(fraction, size_arg_x, size_arg_y, overlay) end

--
-- draw a small circle + keep the cursor on the same line. advance cursor x position by GetTreeNodeToLabelSpacing(), same distance that TreeNode() uses
--
function ImGui.Bullet() end

--
-- Widgets: Images
-- - Read about ImTextureID here: https://github.com/ocornut/imgui/wiki/Image-Loading-and-Displaying-Examples
-- - Note that Image() may add +2.0f to provided size if a border is visible, ImageButton() adds style.FramePadding*2.0f to provided size.
--
--
-- Implied uv0 = ImVec2(0, 0), uv1 = ImVec2(1, 1), tint_col = ImVec4(1, 1, 1, 1), border_col = ImVec4(0, 0, 0, 0)
--
---@param user_texture_id ImTextureID
---@param image_size_x number
---@param image_size_y number
function ImGui.Image(user_texture_id, image_size_x, image_size_y) end

---@param user_texture_id ImTextureID
---@param image_size_x number
---@param image_size_y number
---@param uv0_x? number | `0`
---@param uv0_y? number | `0`
---@param uv1_x? number | `1`
---@param uv1_y? number | `1`
---@param tint_col_x? number | `1`
---@param tint_col_y? number | `1`
---@param tint_col_z? number | `1`
---@param tint_col_w? number | `1`
---@param border_col_x? number | `0`
---@param border_col_y? number | `0`
---@param border_col_z? number | `0`
---@param border_col_w? number | `0`
function ImGui.ImageEx(user_texture_id, image_size_x, image_size_y, uv0_x, uv0_y, uv1_x, uv1_y, tint_col_x, tint_col_y, tint_col_z, tint_col_w, border_col_x, border_col_y, border_col_z, border_col_w) end

--
-- Implied uv0 = ImVec2(0, 0), uv1 = ImVec2(1, 1), bg_col = ImVec4(0, 0, 0, 0), tint_col = ImVec4(1, 1, 1, 1)
--
---@param str_id string
---@param user_texture_id ImTextureID
---@param image_size_x number
---@param image_size_y number
---@return boolean
function ImGui.ImageButton(str_id, user_texture_id, image_size_x, image_size_y) end

---@param str_id string
---@param user_texture_id ImTextureID
---@param image_size_x number
---@param image_size_y number
---@param uv0_x? number | `0`
---@param uv0_y? number | `0`
---@param uv1_x? number | `1`
---@param uv1_y? number | `1`
---@param bg_col_x? number | `0`
---@param bg_col_y? number | `0`
---@param bg_col_z? number | `0`
---@param bg_col_w? number | `0`
---@param tint_col_x? number | `1`
---@param tint_col_y? number | `1`
---@param tint_col_z? number | `1`
---@param tint_col_w? number | `1`
---@return boolean
function ImGui.ImageButtonEx(str_id, user_texture_id, image_size_x, image_size_y, uv0_x, uv0_y, uv1_x, uv1_y, bg_col_x, bg_col_y, bg_col_z, bg_col_w, tint_col_x, tint_col_y, tint_col_z, tint_col_w) end

--
-- Widgets: Combo Box (Dropdown)
-- - The BeginCombo()/EndCombo() api allows you to manage your contents and selection state however you want it, by creating e.g. Selectable() items.
-- - The old Combo() api are helpers over BeginCombo()/EndCombo() which are kept available for convenience purpose. This is analogous to how ListBox are created.
--
---@param label string
---@param preview_value string
---@param flags? ImGuiComboFlags | `ImGui.Flags.Combo { "None" }`
---@return boolean
function ImGui.BeginCombo(label, preview_value, flags) end

--
-- only call EndCombo() if BeginCombo() returns true!
--
function ImGui.EndCombo() end

--
-- Implied popup_max_height_in_items = -1
--
---@param label string
---@param current_item integer[]
---@param items_separated_by_zeros string
---@return boolean
function ImGui.Combo(label, current_item, items_separated_by_zeros) end

--
-- Separate items with \0 within a string, end item-list with \0\0. e.g. "One\0Two\0Three\0"
--
---@param label string
---@param current_item integer[]
---@param items_separated_by_zeros string
---@param popup_max_height_in_items? integer | `-1`
---@return boolean
function ImGui.ComboEx(label, current_item, items_separated_by_zeros, popup_max_height_in_items) end

--
-- Widgets: Drag Sliders
-- - CTRL+Click on any drag box to turn them into an input box. Manually input values aren't clamped by default and can go off-bounds. Use ImGuiSliderFlags_AlwaysClamp to always clamp.
-- - For all the Float2/Float3/Float4/Int2/Int3/Int4 versions of every function, note that a 'float v[X]' function argument is the same as 'float* v',
--   the array syntax is just a way to document the number of elements that are expected to be accessible. You can pass address of your first element out of a contiguous set, e.g. &myvector.x
-- - Adjust format string to decorate the value with a prefix, a suffix, or adapt the editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs; "Biscuit: %.0f" -> Biscuit: 1; etc.
-- - Format string may also be set to NULL or use the default format ("%f" or "%d").
-- - Speed are per-pixel of mouse movement (v_speed=0.2f: mouse needs to move by 5 pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed is Max(v_speed, minimum_step_at_given_precision).
-- - Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual input can override those limits if ImGuiSliderFlags_AlwaysClamp is not used.
-- - Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
-- - We use the same sets of flags for DragXXX() and SliderXXX() functions as the features are the same and it makes it easier to swap them.
-- - Legacy: Pre-1.78 there are DragXXX() function signatures that take a final `float power=1.0f' argument instead of the `ImGuiSliderFlags flags=0' argument.
--   If you get a warning converting a float to ImGuiSliderFlags, read https://github.com/ocornut/imgui/issues/3361
--
--
-- Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@return boolean
function ImGui.DragFloat(label, v) end

--
-- If v_min >= v_max we have no bound
--
---@param label string
---@param v number[]
---@param v_speed? number | `1.0`
---@param v_min? number | `0.0`
---@param v_max? number | `0.0`
---@param format? string | `"%.3f"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragFloatEx(label, v, v_speed, v_min, v_max, format, flags) end

--
-- Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@return boolean
function ImGui.DragFloat2(label, v) end

---@param label string
---@param v number[]
---@param v_speed? number | `1.0`
---@param v_min? number | `0.0`
---@param v_max? number | `0.0`
---@param format? string | `"%.3f"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragFloat2Ex(label, v, v_speed, v_min, v_max, format, flags) end

--
-- Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@return boolean
function ImGui.DragFloat3(label, v) end

---@param label string
---@param v number[]
---@param v_speed? number | `1.0`
---@param v_min? number | `0.0`
---@param v_max? number | `0.0`
---@param format? string | `"%.3f"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragFloat3Ex(label, v, v_speed, v_min, v_max, format, flags) end

--
-- Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@return boolean
function ImGui.DragFloat4(label, v) end

---@param label string
---@param v number[]
---@param v_speed? number | `1.0`
---@param v_min? number | `0.0`
---@param v_max? number | `0.0`
---@param format? string | `"%.3f"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragFloat4Ex(label, v, v_speed, v_min, v_max, format, flags) end

--
-- Implied v_speed = 1.0f, v_min = 0.0f, v_max = 0.0f, format = "%.3f", format_max = NULL, flags = 0
--
---@param label string
---@param v_current_min number[]
---@param v_current_max number[]
---@return boolean
function ImGui.DragFloatRange2(label, v_current_min, v_current_max) end

---@param label string
---@param v_current_min number[]
---@param v_current_max number[]
---@param v_speed? number | `1.0`
---@param v_min? number | `0.0`
---@param v_max? number | `0.0`
---@param format? string | `"%.3f"`
---@param format_max? string
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragFloatRange2Ex(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags) end

--
-- Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", flags = 0
--
---@param label string
---@param v integer[]
---@return boolean
function ImGui.DragInt(label, v) end

--
-- If v_min >= v_max we have no bound
--
---@param label string
---@param v integer[]
---@param v_speed? number | `1.0`
---@param v_min? integer | `0`
---@param v_max? integer | `0`
---@param format? string | `"%d"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragIntEx(label, v, v_speed, v_min, v_max, format, flags) end

--
-- Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", flags = 0
--
---@param label string
---@param v integer[]
---@return boolean
function ImGui.DragInt2(label, v) end

---@param label string
---@param v integer[]
---@param v_speed? number | `1.0`
---@param v_min? integer | `0`
---@param v_max? integer | `0`
---@param format? string | `"%d"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragInt2Ex(label, v, v_speed, v_min, v_max, format, flags) end

--
-- Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", flags = 0
--
---@param label string
---@param v integer[]
---@return boolean
function ImGui.DragInt3(label, v) end

---@param label string
---@param v integer[]
---@param v_speed? number | `1.0`
---@param v_min? integer | `0`
---@param v_max? integer | `0`
---@param format? string | `"%d"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragInt3Ex(label, v, v_speed, v_min, v_max, format, flags) end

--
-- Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", flags = 0
--
---@param label string
---@param v integer[]
---@return boolean
function ImGui.DragInt4(label, v) end

---@param label string
---@param v integer[]
---@param v_speed? number | `1.0`
---@param v_min? integer | `0`
---@param v_max? integer | `0`
---@param format? string | `"%d"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragInt4Ex(label, v, v_speed, v_min, v_max, format, flags) end

--
-- Implied v_speed = 1.0f, v_min = 0, v_max = 0, format = "%d", format_max = NULL, flags = 0
--
---@param label string
---@param v_current_min integer[]
---@param v_current_max integer[]
---@return boolean
function ImGui.DragIntRange2(label, v_current_min, v_current_max) end

---@param label string
---@param v_current_min integer[]
---@param v_current_max integer[]
---@param v_speed? number | `1.0`
---@param v_min? integer | `0`
---@param v_max? integer | `0`
---@param format? string | `"%d"`
---@param format_max? string
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.DragIntRange2Ex(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags) end

--
-- Widgets: Regular Sliders
-- - CTRL+Click on any slider to turn them into an input box. Manually input values aren't clamped by default and can go off-bounds. Use ImGuiSliderFlags_AlwaysClamp to always clamp.
-- - Adjust format string to decorate the value with a prefix, a suffix, or adapt the editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs; "Biscuit: %.0f" -> Biscuit: 1; etc.
-- - Format string may also be set to NULL or use the default format ("%f" or "%d").
-- - Legacy: Pre-1.78 there are SliderXXX() function signatures that take a final `float power=1.0f' argument instead of the `ImGuiSliderFlags flags=0' argument.
--   If you get a warning converting a float to ImGuiSliderFlags, read https://github.com/ocornut/imgui/issues/3361
--
--
-- Implied format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@param v_min number
---@param v_max number
---@return boolean
function ImGui.SliderFloat(label, v, v_min, v_max) end

--
-- adjust format to decorate the value with a prefix or a suffix for in-slider labels or unit display.
--
---@param label string
---@param v number[]
---@param v_min number
---@param v_max number
---@param format? string | `"%.3f"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.SliderFloatEx(label, v, v_min, v_max, format, flags) end

--
-- Implied format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@param v_min number
---@param v_max number
---@return boolean
function ImGui.SliderFloat2(label, v, v_min, v_max) end

---@param label string
---@param v number[]
---@param v_min number
---@param v_max number
---@param format? string | `"%.3f"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.SliderFloat2Ex(label, v, v_min, v_max, format, flags) end

--
-- Implied format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@param v_min number
---@param v_max number
---@return boolean
function ImGui.SliderFloat3(label, v, v_min, v_max) end

---@param label string
---@param v number[]
---@param v_min number
---@param v_max number
---@param format? string | `"%.3f"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.SliderFloat3Ex(label, v, v_min, v_max, format, flags) end

--
-- Implied format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@param v_min number
---@param v_max number
---@return boolean
function ImGui.SliderFloat4(label, v, v_min, v_max) end

---@param label string
---@param v number[]
---@param v_min number
---@param v_max number
---@param format? string | `"%.3f"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.SliderFloat4Ex(label, v, v_min, v_max, format, flags) end

--
-- Implied v_degrees_min = -360.0f, v_degrees_max = +360.0f, format = "%.0f deg", flags = 0
--
---@param label string
---@param v_rad number[]
---@return boolean
function ImGui.SliderAngle(label, v_rad) end

---@param label string
---@param v_rad number[]
---@param v_degrees_min? number | `-360.0`
---@param v_degrees_max? number | `+360.0`
---@param format? string | `"%.0f deg"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.SliderAngleEx(label, v_rad, v_degrees_min, v_degrees_max, format, flags) end

--
-- Implied format = "%d", flags = 0
--
---@param label string
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@return boolean
function ImGui.SliderInt(label, v, v_min, v_max) end

---@param label string
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@param format? string | `"%d"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.SliderIntEx(label, v, v_min, v_max, format, flags) end

--
-- Implied format = "%d", flags = 0
--
---@param label string
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@return boolean
function ImGui.SliderInt2(label, v, v_min, v_max) end

---@param label string
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@param format? string | `"%d"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.SliderInt2Ex(label, v, v_min, v_max, format, flags) end

--
-- Implied format = "%d", flags = 0
--
---@param label string
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@return boolean
function ImGui.SliderInt3(label, v, v_min, v_max) end

---@param label string
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@param format? string | `"%d"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.SliderInt3Ex(label, v, v_min, v_max, format, flags) end

--
-- Implied format = "%d", flags = 0
--
---@param label string
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@return boolean
function ImGui.SliderInt4(label, v, v_min, v_max) end

---@param label string
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@param format? string | `"%d"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.SliderInt4Ex(label, v, v_min, v_max, format, flags) end

--
-- Implied format = "%.3f", flags = 0
--
---@param label string
---@param size_x number
---@param size_y number
---@param v number[]
---@param v_min number
---@param v_max number
---@return boolean
function ImGui.VSliderFloat(label, size_x, size_y, v, v_min, v_max) end

---@param label string
---@param size_x number
---@param size_y number
---@param v number[]
---@param v_min number
---@param v_max number
---@param format? string | `"%.3f"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.VSliderFloatEx(label, size_x, size_y, v, v_min, v_max, format, flags) end

--
-- Implied format = "%d", flags = 0
--
---@param label string
---@param size_x number
---@param size_y number
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@return boolean
function ImGui.VSliderInt(label, size_x, size_y, v, v_min, v_max) end

---@param label string
---@param size_x number
---@param size_y number
---@param v integer[]
---@param v_min integer
---@param v_max integer
---@param format? string | `"%d"`
---@param flags? ImGuiSliderFlags | `ImGui.Flags.Slider { "None" }`
---@return boolean
function ImGui.VSliderIntEx(label, size_x, size_y, v, v_min, v_max, format, flags) end

--
-- Widgets: Color Editor/Picker (tip: the ColorEdit* functions have a little color square that can be left-clicked to open a picker, and right-clicked to open an option menu.)
-- - Note that in C++ a 'float v[X]' function argument is the _same_ as 'float* v', the array syntax is just a way to document the number of elements that are expected to be accessible.
-- - You can pass the address of a first float element out of a contiguous structure, e.g. &myvector.x
--
---@param label string
---@param col number[]
---@param flags? ImGuiColorEditFlags | `ImGui.Flags.ColorEdit { "None" }`
---@return boolean
function ImGui.ColorEdit3(label, col, flags) end

---@param label string
---@param col number[]
---@param flags? ImGuiColorEditFlags | `ImGui.Flags.ColorEdit { "None" }`
---@return boolean
function ImGui.ColorEdit4(label, col, flags) end

---@param label string
---@param col number[]
---@param flags? ImGuiColorEditFlags | `ImGui.Flags.ColorEdit { "None" }`
---@return boolean
function ImGui.ColorPicker3(label, col, flags) end

--
-- Implied size = ImVec2(0, 0)
--
---@param desc_id string
---@param col_x number
---@param col_y number
---@param col_z number
---@param col_w number
---@param flags? ImGuiColorEditFlags | `ImGui.Flags.ColorEdit { "None" }`
---@return boolean
function ImGui.ColorButton(desc_id, col_x, col_y, col_z, col_w, flags) end

--
-- display a color square/button, hover for details, return true when pressed.
--
---@param desc_id string
---@param col_x number
---@param col_y number
---@param col_z number
---@param col_w number
---@param flags? ImGuiColorEditFlags | `ImGui.Flags.ColorEdit { "None" }`
---@param size_x? number | `0`
---@param size_y? number | `0`
---@return boolean
function ImGui.ColorButtonEx(desc_id, col_x, col_y, col_z, col_w, flags, size_x, size_y) end

--
-- initialize current options (generally on application startup) if you want to select a default format, picker type, etc. User will be able to change many settings, unless you pass the _NoOptions flag to your calls.
--
---@param flags ImGuiColorEditFlags
function ImGui.SetColorEditOptions(flags) end

--
-- Widgets: Trees
-- - TreeNode functions return true when the node is open, in which case you need to also call TreePop() when you are finished displaying the tree node contents.
--
---@param label string
---@return boolean
function ImGui.TreeNode(label) end

--
-- helper variation to easily decorelate the id from the displayed string. Read the FAQ about why and how to use ID. to align arbitrary text at the same level as a TreeNode() you can use Bullet().
--
---@param str_id string
---@param fmt string
---@param ...  any
---@return boolean
function ImGui.TreeNodeStr(str_id, fmt, ...) end

--
-- "
--
---@param ptr_id lightuserdata
---@param fmt string
---@param ...  any
---@return boolean
function ImGui.TreeNodePtr(ptr_id, fmt, ...) end

---@param label string
---@param flags? ImGuiTreeNodeFlags | `ImGui.Flags.TreeNode { "None" }`
---@return boolean
function ImGui.TreeNodeEx(label, flags) end

---@param str_id string
---@param flags ImGuiTreeNodeFlags
---@param fmt string
---@param ...  any
---@return boolean
function ImGui.TreeNodeExStr(str_id, flags, fmt, ...) end

---@param ptr_id lightuserdata
---@param flags ImGuiTreeNodeFlags
---@param fmt string
---@param ...  any
---@return boolean
function ImGui.TreeNodeExPtr(ptr_id, flags, fmt, ...) end

--
-- ~ Indent()+PushID(). Already called by TreeNode() when returning true, but you can call TreePush/TreePop yourself if desired.
--
---@param str_id string
function ImGui.TreePush(str_id) end

--
-- "
--
---@param ptr_id lightuserdata
function ImGui.TreePushPtr(ptr_id) end

--
-- ~ Unindent()+PopID()
--
function ImGui.TreePop() end

--
-- horizontal distance preceding label when using TreeNode*() or Bullet() == (g.FontSize + style.FramePadding.x*2) for a regular unframed TreeNode
--
---@return number
function ImGui.GetTreeNodeToLabelSpacing() end

--
-- if returning 'true' the header is open. doesn't indent nor push on ID stack. user doesn't have to call TreePop().
--
---@param label string
---@param flags? ImGuiTreeNodeFlags | `ImGui.Flags.TreeNode { "None" }`
---@return boolean
function ImGui.CollapsingHeader(label, flags) end

--
-- when 'p_visible != NULL': if '*p_visible==true' display an additional small close button on upper right of the header which will set the bool to false when clicked, if '*p_visible==false' don't display the header.
--
---@param label string
---@param p_visible boolean[]
---@param flags? ImGuiTreeNodeFlags | `ImGui.Flags.TreeNode { "None" }`
---@return boolean
---@return boolean p_visible
function ImGui.CollapsingHeaderBoolPtr(label, p_visible, flags) end

--
-- set next TreeNode/CollapsingHeader open state.
--
---@param is_open boolean
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
function ImGui.SetNextItemOpen(is_open, cond) end

--
-- Widgets: Selectables
-- - A selectable highlights when hovered, and can display another color when selected.
-- - Neighbors selectable extend their highlight bounds in order to leave no gap between them. This is so a series of selected Selectable appear contiguous.
--
--
-- Implied selected = false, flags = 0, size = ImVec2(0, 0)
--
---@param label string
---@return boolean
function ImGui.Selectable(label) end

--
-- "bool selected" carry the selection state (read-only). Selectable() is clicked is returns true so you can modify your selection state. size.x==0.0: use remaining width, size.x>0.0: specify width. size.y==0.0: use label height, size.y>0.0: specify height
--
---@param label string
---@param selected? boolean | `false`
---@param flags? ImGuiSelectableFlags | `ImGui.Flags.Selectable { "None" }`
---@param size_x? number | `0`
---@param size_y? number | `0`
---@return boolean
function ImGui.SelectableEx(label, selected, flags, size_x, size_y) end

--
-- Implied size = ImVec2(0, 0)
--
---@param label string
---@param p_selected boolean[]
---@param flags? ImGuiSelectableFlags | `ImGui.Flags.Selectable { "None" }`
---@return boolean
---@return boolean p_selected
function ImGui.SelectableBoolPtr(label, p_selected, flags) end

--
-- "bool* p_selected" point to the selection state (read-write), as a convenient helper.
--
---@param label string
---@param p_selected boolean[]
---@param flags? ImGuiSelectableFlags | `ImGui.Flags.Selectable { "None" }`
---@param size_x? number | `0`
---@param size_y? number | `0`
---@return boolean
---@return boolean p_selected
function ImGui.SelectableBoolPtrEx(label, p_selected, flags, size_x, size_y) end

--
-- Widgets: List Boxes
-- - This is essentially a thin wrapper to using BeginChild/EndChild with the ImGuiChildFlags_FrameStyle flag for stylistic changes + displaying a label.
-- - You can submit contents and manage your selection state however you want it, by creating e.g. Selectable() or any other items.
-- - The simplified/old ListBox() api are helpers over BeginListBox()/EndListBox() which are kept available for convenience purpose. This is analoguous to how Combos are created.
-- - Choose frame width:   size.x > 0.0f: custom  /  size.x < 0.0f or -FLT_MIN: right-align   /  size.x = 0.0f (default): use current ItemWidth
-- - Choose frame height:  size.y > 0.0f: custom  /  size.y < 0.0f or -FLT_MIN: bottom-align  /  size.y = 0.0f (default): arbitrary default height which can fit ~7 items
--
--
-- open a framed scrolling region
--
---@param label string
---@param size_x? number | `0`
---@param size_y? number | `0`
---@return boolean
function ImGui.BeginListBox(label, size_x, size_y) end

--
-- only call EndListBox() if BeginListBox() returned true!
--
function ImGui.EndListBox() end

--
-- Widgets: Menus
-- - Use BeginMenuBar() on a window ImGuiWindowFlags_MenuBar to append to its menu bar.
-- - Use BeginMainMenuBar() to create a menu bar at the top of the screen and append to it.
-- - Use BeginMenu() to create a menu. You can call BeginMenu() multiple time with the same identifier to append more items to it.
-- - Not that MenuItem() keyboardshortcuts are displayed as a convenience but _not processed_ by Dear ImGui at the moment.
--
--
-- append to menu-bar of current window (requires ImGuiWindowFlags_MenuBar flag set on parent window).
--
---@return boolean
function ImGui.BeginMenuBar() end

--
-- only call EndMenuBar() if BeginMenuBar() returns true!
--
function ImGui.EndMenuBar() end

--
-- create and append to a full screen menu-bar.
--
---@return boolean
function ImGui.BeginMainMenuBar() end

--
-- only call EndMainMenuBar() if BeginMainMenuBar() returns true!
--
function ImGui.EndMainMenuBar() end

--
-- Implied enabled = true
--
---@param label string
---@return boolean
function ImGui.BeginMenu(label) end

--
-- create a sub-menu entry. only call EndMenu() if this returns true!
--
---@param label string
---@param enabled? boolean | `true`
---@return boolean
function ImGui.BeginMenuEx(label, enabled) end

--
-- only call EndMenu() if BeginMenu() returns true!
--
function ImGui.EndMenu() end

--
-- Implied shortcut = NULL, selected = false, enabled = true
--
---@param label string
---@return boolean
function ImGui.MenuItem(label) end

--
-- return true when activated.
--
---@param label string
---@param shortcut? string
---@param selected? boolean | `false`
---@param enabled? boolean | `true`
---@return boolean
function ImGui.MenuItemEx(label, shortcut, selected, enabled) end

--
-- return true when activated + toggle (*p_selected) if p_selected != NULL
--
---@param label string
---@param shortcut string
---@param p_selected boolean[]
---@param enabled? boolean | `true`
---@return boolean
---@return boolean p_selected
function ImGui.MenuItemBoolPtr(label, shortcut, p_selected, enabled) end

--
-- Tooltips
-- - Tooltips are windows following the mouse. They do not take focus away.
-- - A tooltip window can contain items of any types. SetTooltip() is a shortcut for the 'if (BeginTooltip()) { Text(...); EndTooltip(); }' idiom.
--
--
-- begin/append a tooltip window.
--
---@return boolean
function ImGui.BeginTooltip() end

--
-- only call EndTooltip() if BeginTooltip()/BeginItemTooltip() returns true!
--
function ImGui.EndTooltip() end

--
-- set a text-only tooltip. Often used after a ImGui::IsItemHovered() check. Override any previous call to SetTooltip().
--
---@param fmt string
---@param ...  any
function ImGui.SetTooltip(fmt, ...) end

--
-- Tooltips: helpers for showing a tooltip when hovering an item
-- - BeginItemTooltip() is a shortcut for the 'if (IsItemHovered(ImGuiHoveredFlags_ForTooltip) && BeginTooltip())' idiom.
-- - SetItemTooltip() is a shortcut for the 'if (IsItemHovered(ImGuiHoveredFlags_ForTooltip)) { SetTooltip(...); }' idiom.
-- - Where 'ImGuiHoveredFlags_ForTooltip' itself is a shortcut to use 'style.HoverFlagsForTooltipMouse' or 'style.HoverFlagsForTooltipNav' depending on active input type. For mouse it defaults to 'ImGuiHoveredFlags_Stationary | ImGuiHoveredFlags_DelayShort'.
--
--
-- begin/append a tooltip window if preceding item was hovered.
--
---@return boolean
function ImGui.BeginItemTooltip() end

--
-- set a text-only tooltip if preceeding item was hovered. override any previous call to SetTooltip().
--
---@param fmt string
---@param ...  any
function ImGui.SetItemTooltip(fmt, ...) end

--
-- Popups, Modals
--  - They block normal mouse hovering detection (and therefore most mouse interactions) behind them.
--  - If not modal: they can be closed by clicking anywhere outside them, or by pressing ESCAPE.
--  - Their visibility state (~bool) is held internally instead of being held by the programmer as we are used to with regular Begin*() calls.
--  - The 3 properties above are related: we need to retain popup visibility state in the library because popups may be closed as any time.
--  - You can bypass the hovering restriction by using ImGuiHoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered() or IsWindowHovered().
--  - IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup and BeginPopup generally needs to be at the same level of the stack.
--    This is sometimes leading to confusing mistakes. May rework this in the future.
--  - BeginPopup(): query popup state, if open start appending into the window. Call EndPopup() afterwards if returned true. ImGuiWindowFlags are forwarded to the window.
--  - BeginPopupModal(): block every interaction behind the window, cannot be closed by user, add a dimming background, has a title bar.
--
--
-- return true if the popup is open, and you can start outputting to it.
--
---@param str_id string
---@param flags? ImGuiWindowFlags | `ImGui.Flags.Window { "None" }`
---@return boolean
function ImGui.BeginPopup(str_id, flags) end

--
-- return true if the modal is open, and you can start outputting to it.
--
---@param name string
---@param p_open true | nil
---@param flags? ImGuiWindowFlags | `ImGui.Flags.Window { "None" }`
---@return boolean
---@return boolean p_open
function ImGui.BeginPopupModal(name, p_open, flags) end

--
-- only call EndPopup() if BeginPopupXXX() returns true!
--
function ImGui.EndPopup() end

--
-- Popups: open/close functions
--  - OpenPopup(): set popup state to open. ImGuiPopupFlags are available for opening options.
--  - If not modal: they can be closed by clicking anywhere outside them, or by pressing ESCAPE.
--  - CloseCurrentPopup(): use inside the BeginPopup()/EndPopup() scope to close manually.
--  - CloseCurrentPopup() is called by default by Selectable()/MenuItem() when activated (FIXME: need some options).
--  - Use ImGuiPopupFlags_NoOpenOverExistingPopup to avoid opening a popup if there's already one at the same level. This is equivalent to e.g. testing for !IsAnyPopupOpen() prior to OpenPopup().
--  - Use IsWindowAppearing() after BeginPopup() to tell if a window just opened.
--  - IMPORTANT: Notice that for OpenPopupOnItemClick() we exceptionally default flags to 1 (== ImGuiPopupFlags_MouseButtonRight) for backward compatibility with older API taking 'int mouse_button = 1' parameter
--
--
-- call to mark popup as open (don't call every frame!).
--
---@param str_id string
---@param popup_flags? ImGuiPopupFlags | `ImGui.Flags.Popup { "None" }`
function ImGui.OpenPopup(str_id, popup_flags) end

--
-- id overload to facilitate calling from nested stacks
--
---@param id integer
---@param popup_flags? ImGuiPopupFlags | `ImGui.Flags.Popup { "None" }`
function ImGui.OpenPopupID(id, popup_flags) end

--
-- helper to open popup when clicked on last item. Default to ImGuiPopupFlags_MouseButtonRight == 1. (note: actually triggers on the mouse _released_ event to be consistent with popup behaviors)
--
---@param str_id? string
---@param popup_flags? ImGuiPopupFlags | `ImGui.Flags.Popup { "MouseButtonRight" }`
function ImGui.OpenPopupOnItemClick(str_id, popup_flags) end

--
-- manually close the popup we have begin-ed into.
--
function ImGui.CloseCurrentPopup() end

--
-- Popups: open+begin combined functions helpers
--  - Helpers to do OpenPopup+BeginPopup where the Open action is triggered by e.g. hovering an item and right-clicking.
--  - They are convenient to easily create context menus, hence the name.
--  - IMPORTANT: Notice that BeginPopupContextXXX takes ImGuiPopupFlags just like OpenPopup() and unlike BeginPopup(). For full consistency, we may add ImGuiWindowFlags to the BeginPopupContextXXX functions in the future.
--  - IMPORTANT: Notice that we exceptionally default their flags to 1 (== ImGuiPopupFlags_MouseButtonRight) for backward compatibility with older API taking 'int mouse_button = 1' parameter, so if you add other flags remember to re-add the ImGuiPopupFlags_MouseButtonRight.
--
--
-- Implied str_id = NULL, popup_flags = 1
--
---@return boolean
function ImGui.BeginPopupContextItem() end

--
-- open+begin popup when clicked on last item. Use str_id==NULL to associate the popup to previous item. If you want to use that on a non-interactive item such as Text() you need to pass in an explicit ID here. read comments in .cpp!
--
---@param str_id? string
---@param popup_flags? ImGuiPopupFlags | `ImGui.Flags.Popup { "MouseButtonRight" }`
---@return boolean
function ImGui.BeginPopupContextItemEx(str_id, popup_flags) end

--
-- Implied str_id = NULL, popup_flags = 1
--
---@return boolean
function ImGui.BeginPopupContextWindow() end

--
-- open+begin popup when clicked on current window.
--
---@param str_id? string
---@param popup_flags? ImGuiPopupFlags | `ImGui.Flags.Popup { "MouseButtonRight" }`
---@return boolean
function ImGui.BeginPopupContextWindowEx(str_id, popup_flags) end

--
-- Implied str_id = NULL, popup_flags = 1
--
---@return boolean
function ImGui.BeginPopupContextVoid() end

--
-- open+begin popup when clicked in void (where there are no windows).
--
---@param str_id? string
---@param popup_flags? ImGuiPopupFlags | `ImGui.Flags.Popup { "MouseButtonRight" }`
---@return boolean
function ImGui.BeginPopupContextVoidEx(str_id, popup_flags) end

--
-- Popups: query functions
--  - IsPopupOpen(): return true if the popup is open at the current BeginPopup() level of the popup stack.
--  - IsPopupOpen() with ImGuiPopupFlags_AnyPopupId: return true if any popup is open at the current BeginPopup() level of the popup stack.
--  - IsPopupOpen() with ImGuiPopupFlags_AnyPopupId + ImGuiPopupFlags_AnyPopupLevel: return true if any popup is open.
--
--
-- return true if the popup is open.
--
---@param str_id string
---@param flags? ImGuiPopupFlags | `ImGui.Flags.Popup { "None" }`
---@return boolean
function ImGui.IsPopupOpen(str_id, flags) end

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
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
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
---@param cond? ImGuiCond | `ImGui.Enum.Cond.None`
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

--
-- Focus, Activation
-- - Prefer using "SetItemDefaultFocus()" over "if (IsWindowAppearing()) SetScrollHereY()" when applicable to signify "this is the default item"
--
--
-- make last item the default focused item of a window.
--
function ImGui.SetItemDefaultFocus() end

--
-- Implied offset = 0
--
function ImGui.SetKeyboardFocusHere() end

--
-- focus keyboard on the next widget. Use positive 'offset' to access sub components of a multiple component widget. Use -1 to access previous widget.
--
---@param offset? integer | `0`
function ImGui.SetKeyboardFocusHereEx(offset) end

--
-- Overlapping mode
--
--
-- allow next item to be overlapped by a subsequent item. Useful with invisible buttons, selectable, treenode covering an area where subsequent items may need to be added. Note that both Selectable() and TreeNode() have dedicated flags doing this.
--
function ImGui.SetNextItemAllowOverlap() end

--
-- Item/Widgets Utilities and Query Functions
-- - Most of the functions are referring to the previous Item that has been submitted.
-- - See Demo Window under "Widgets->Querying Status" for an interactive visualization of most of those functions.
--
--
-- is the last item hovered? (and usable, aka not blocked by a popup, etc.). See ImGuiHoveredFlags for more options.
--
---@param flags? ImGuiHoveredFlags | `ImGui.Flags.Hovered { "None" }`
---@return boolean
function ImGui.IsItemHovered(flags) end

--
-- is the last item active? (e.g. button being held, text field being edited. This will continuously return true while holding mouse button on an item. Items that don't interact will always return false)
--
---@return boolean
function ImGui.IsItemActive() end

--
-- is the last item focused for keyboard/gamepad navigation?
--
---@return boolean
function ImGui.IsItemFocused() end

--
-- Implied mouse_button = 0
--
---@return boolean
function ImGui.IsItemClicked() end

--
-- is the last item hovered and mouse clicked on? (**)  == IsMouseClicked(mouse_button) && IsItemHovered()Important. (**) this is NOT equivalent to the behavior of e.g. Button(). Read comments in function definition.
--
---@param mouse_button? ImGuiMouseButton | `ImGui.Enum.MouseButton.Left`
---@return boolean
function ImGui.IsItemClickedEx(mouse_button) end

--
-- is the last item visible? (items may be out of sight because of clipping/scrolling)
--
---@return boolean
function ImGui.IsItemVisible() end

--
-- did the last item modify its underlying value this frame? or was pressed? This is generally the same as the "bool" return value of many widgets.
--
---@return boolean
function ImGui.IsItemEdited() end

--
-- was the last item just made active (item was previously inactive).
--
---@return boolean
function ImGui.IsItemActivated() end

--
-- was the last item just made inactive (item was previously active). Useful for Undo/Redo patterns with widgets that require continuous editing.
--
---@return boolean
function ImGui.IsItemDeactivated() end

--
-- was the last item just made inactive and made a value change when it was active? (e.g. Slider/Drag moved). Useful for Undo/Redo patterns with widgets that require continuous editing. Note that you may get false positives (some widgets such as Combo()/ListBox()/Selectable() will return true even when clicking an already selected item).
--
---@return boolean
function ImGui.IsItemDeactivatedAfterEdit() end

--
-- was the last item open state toggled? set by TreeNode().
--
---@return boolean
function ImGui.IsItemToggledOpen() end

--
-- is any item hovered?
--
---@return boolean
function ImGui.IsAnyItemHovered() end

--
-- is any item active?
--
---@return boolean
function ImGui.IsAnyItemActive() end

--
-- is any item focused?
--
---@return boolean
function ImGui.IsAnyItemFocused() end

--
-- get ID of last item (~~ often same ImGui::GetID(label) beforehand)
--
---@return integer
function ImGui.GetItemID() end

--
-- get upper-left bounding rectangle of the last item (screen space)
--
---@return number
---@return number
function ImGui.GetItemRectMin() end

--
-- get lower-right bounding rectangle of the last item (screen space)
--
---@return number
---@return number
function ImGui.GetItemRectMax() end

--
-- get size of last item
--
---@return number
---@return number
function ImGui.GetItemRectSize() end

--
-- Miscellaneous Utilities
--
--
-- test if rectangle (of given size, starting from cursor position) is visible / not clipped.
--
---@param size_x number
---@param size_y number
---@return boolean
function ImGui.IsRectVisibleBySize(size_x, size_y) end

--
-- test if rectangle (in screen space) is visible / not clipped. to perform coarse clipping on user's side.
--
---@param rect_min_x number
---@param rect_min_y number
---@param rect_max_x number
---@param rect_max_y number
---@return boolean
function ImGui.IsRectVisible(rect_min_x, rect_min_y, rect_max_x, rect_max_y) end

--
-- get global imgui time. incremented by io.DeltaTime every frame.
--
---@return number
function ImGui.GetTime() end

--
-- get global imgui frame count. incremented by 1 every frame.
--
---@return integer
function ImGui.GetFrameCount() end

--
-- get a string corresponding to the enum value (for display, saving, etc.).
--
---@param idx ImGuiCol
---@return string
function ImGui.GetStyleColorName(idx) end

--
-- Text Utilities
--
--
-- Implied text_end = NULL, hide_text_after_double_hash = false, wrap_width = -1.0f
--
---@param text string
---@return number
---@return number
function ImGui.CalcTextSize(text) end

---@param text string
---@param text_end? string
---@param hide_text_after_double_hash? boolean | `false`
---@param wrap_width? number | `-1.0`
---@return number
---@return number
function ImGui.CalcTextSizeEx(text, text_end, hide_text_after_double_hash, wrap_width) end

--
-- Color Utilities
--
---@param arg_in integer
---@return number
---@return number
---@return number
---@return number
function ImGui.ColorConvertU32ToFloat4(arg_in) end

---@param in_x number
---@param in_y number
---@param in_z number
---@param in_w number
---@return integer
function ImGui.ColorConvertFloat4ToU32(in_x, in_y, in_z, in_w) end

--
-- Inputs Utilities: Keyboard/Mouse/Gamepad
-- - the ImGuiKey enum contains all possible keyboard, mouse and gamepad inputs (e.g. ImGuiKey_A, ImGuiKey_MouseLeft, ImGuiKey_GamepadDpadUp...).
-- - before v1.87, we used ImGuiKey to carry native/user indices as defined by each backends. About use of those legacy ImGuiKey values:
--  - without IMGUI_DISABLE_OBSOLETE_KEYIO (legacy support): you can still use your legacy native/user indices (< 512) according to how your backend/engine stored them in io.KeysDown[], but need to cast them to ImGuiKey.
--  - with    IMGUI_DISABLE_OBSOLETE_KEYIO (this is the way forward): any use of ImGuiKey will assert with key < 512. GetKeyIndex() is pass-through and therefore deprecated (gone if IMGUI_DISABLE_OBSOLETE_KEYIO is defined).
--
--
-- is key being held.
--
---@param key ImGuiKey
---@return boolean
function ImGui.IsKeyDown(key) end

--
-- Implied repeat = true
--
---@param key ImGuiKey
---@return boolean
function ImGui.IsKeyPressed(key) end

--
-- was key pressed (went from !Down to Down)? if repeat=true, uses io.KeyRepeatDelay / KeyRepeatRate
--
---@param key ImGuiKey
---@param arg_repeat? boolean | `true`
---@return boolean
function ImGui.IsKeyPressedEx(key, arg_repeat) end

--
-- was key released (went from Down to !Down)?
--
---@param key ImGuiKey
---@return boolean
function ImGui.IsKeyReleased(key) end

--
-- was key chord (mods + key) pressed, e.g. you can pass 'ImGuiMod_Ctrl | ImGuiKey_S' as a key-chord. This doesn't do any routing or focus check, please consider using Shortcut() function instead.
--
---@param key_chord ImGuiKeyChord
---@return boolean
function ImGui.IsKeyChordPressed(key_chord) end

--
-- uses provided repeat rate/delay. return a count, most often 0 or 1 but might be >1 if RepeatRate is small enough that DeltaTime > RepeatRate
--
---@param key ImGuiKey
---@param repeat_delay number
---@param rate number
---@return integer
function ImGui.GetKeyPressedAmount(key, repeat_delay, rate) end

--
-- [DEBUG] returns English name of the key. Those names a provided for debugging purpose and are not meant to be saved persistently not compared.
--
---@param key ImGuiKey
---@return string
function ImGui.GetKeyName(key) end

--
-- Override io.WantCaptureKeyboard flag next frame (said flag is left for your application to handle, typically when true it instructs your app to ignore inputs). e.g. force capture keyboard when your widget is being hovered. This is equivalent to setting "io.WantCaptureKeyboard = want_capture_keyboard"; after the next NewFrame() call.
--
---@param want_capture_keyboard boolean
function ImGui.SetNextFrameWantCaptureKeyboard(want_capture_keyboard) end

--
-- Inputs Utilities: Mouse specific
-- - To refer to a mouse button, you may use named enums in your code e.g. ImGuiMouseButton_Left, ImGuiMouseButton_Right.
-- - You can also use regular integer: it is forever guaranteed that 0=Left, 1=Right, 2=Middle.
-- - Dragging operations are only reported after mouse has moved a certain distance away from the initial clicking position (see 'lock_threshold' and 'io.MouseDraggingThreshold')
--
--
-- is mouse button held?
--
---@param button ImGuiMouseButton
---@return boolean
function ImGui.IsMouseDown(button) end

--
-- Implied repeat = false
--
---@param button ImGuiMouseButton
---@return boolean
function ImGui.IsMouseClicked(button) end

--
-- did mouse button clicked? (went from !Down to Down). Same as GetMouseClickedCount() == 1.
--
---@param button ImGuiMouseButton
---@param arg_repeat? boolean | `false`
---@return boolean
function ImGui.IsMouseClickedEx(button, arg_repeat) end

--
-- did mouse button released? (went from Down to !Down)
--
---@param button ImGuiMouseButton
---@return boolean
function ImGui.IsMouseReleased(button) end

--
-- did mouse button double-clicked? Same as GetMouseClickedCount() == 2. (note that a double-click will also report IsMouseClicked() == true)
--
---@param button ImGuiMouseButton
---@return boolean
function ImGui.IsMouseDoubleClicked(button) end

--
-- return the number of successive mouse-clicks at the time where a click happen (otherwise 0).
--
---@param button ImGuiMouseButton
---@return integer
function ImGui.GetMouseClickedCount(button) end

--
-- Implied clip = true
--
---@param r_min_x number
---@param r_min_y number
---@param r_max_x number
---@param r_max_y number
---@return boolean
function ImGui.IsMouseHoveringRect(r_min_x, r_min_y, r_max_x, r_max_y) end

--
-- is mouse hovering given bounding rect (in screen space). clipped by current clipping settings, but disregarding of other consideration of focus/window ordering/popup-block.
--
---@param r_min_x number
---@param r_min_y number
---@param r_max_x number
---@param r_max_y number
---@param clip? boolean | `true`
---@return boolean
function ImGui.IsMouseHoveringRectEx(r_min_x, r_min_y, r_max_x, r_max_y, clip) end

--
-- [WILL OBSOLETE] is any mouse button held? This was designed for backends, but prefer having backend maintain a mask of held mouse buttons, because upcoming input queue system will make this invalid.
--
---@return boolean
function ImGui.IsAnyMouseDown() end

--
-- shortcut to ImGui::GetIO().MousePos provided by user, to be consistent with other calls
--
---@return number
---@return number
function ImGui.GetMousePos() end

--
-- retrieve mouse position at the time of opening popup we have BeginPopup() into (helper to avoid user backing that value themselves)
--
---@return number
---@return number
function ImGui.GetMousePosOnOpeningCurrentPopup() end

--
-- is mouse dragging? (if lock_threshold < -1.0f, uses io.MouseDraggingThreshold)
--
---@param button ImGuiMouseButton
---@param lock_threshold? number | `-1.0`
---@return boolean
function ImGui.IsMouseDragging(button, lock_threshold) end

--
-- return the delta from the initial clicking position while the mouse button is pressed or was just released. This is locked and return 0.0f until the mouse moves past a distance threshold at least once (if lock_threshold < -1.0f, uses io.MouseDraggingThreshold)
--
---@param button? ImGuiMouseButton | `ImGui.Enum.MouseButton.Left`
---@param lock_threshold? number | `-1.0`
---@return number
---@return number
function ImGui.GetMouseDragDelta(button, lock_threshold) end

--
-- Implied button = 0
--
function ImGui.ResetMouseDragDelta() end

--
--
--
---@param button? ImGuiMouseButton | `ImGui.Enum.MouseButton.Left`
function ImGui.ResetMouseDragDeltaEx(button) end

--
-- get desired mouse cursor shape. Important: reset in ImGui::NewFrame(), this is updated during the frame. valid before Render(). If you use software rendering by setting io.MouseDrawCursor ImGui will render those for you
--
---@return ImGuiMouseCursor
function ImGui.GetMouseCursor() end

--
-- set desired mouse cursor shape
--
---@param cursor_type ImGuiMouseCursor
function ImGui.SetMouseCursor(cursor_type) end

--
-- Override io.WantCaptureMouse flag next frame (said flag is left for your application to handle, typical when true it instucts your app to ignore inputs). This is equivalent to setting "io.WantCaptureMouse = want_capture_mouse;" after the next NewFrame() call.
--
---@param want_capture_mouse boolean
function ImGui.SetNextFrameWantCaptureMouse(want_capture_mouse) end

--
-- Clipboard Utilities
-- - Also see the LogToClipboard() function to capture GUI into clipboard, or easily output text data to the clipboard.
--
---@return string
function ImGui.GetClipboardText() end

---@param text string
function ImGui.SetClipboardText(text) end

--
-- Settings/.Ini Utilities
-- - The disk functions are automatically called if io.IniFilename != NULL (default is "imgui.ini").
-- - Set io.IniFilename to NULL to load/save manually. Read io.WantSaveIniSettings description about handling .ini saving manually.
-- - Important: default value "imgui.ini" is relative to current working dir! Most apps will want to lock this to an absolute path (e.g. same path as executables).
--
--
-- call after CreateContext() and before the first call to NewFrame(). NewFrame() automatically calls LoadIniSettingsFromDisk(io.IniFilename).
--
---@param ini_filename string
function ImGui.LoadIniSettingsFromDisk(ini_filename) end

--
-- call after CreateContext() and before the first call to NewFrame() to provide .ini data from your own data source.
--
---@param ini_data string
function ImGui.LoadIniSettingsFromMemory(ini_data) end

--
-- this is automatically called (if io.IniFilename is not empty) a few seconds after any modification that should be reflected in the .ini file (and also by DestroyContext).
--
---@param ini_filename string
function ImGui.SaveIniSettingsToDisk(ini_filename) end

--
-- return a zero-terminated string with the .ini data which you can save by your own mean. call when io.WantSaveIniSettings is set, then save data by your own mean and clear io.WantSaveIniSettings.
--
---@return string
function ImGui.SaveIniSettingsToMemory() end

---@param key ImGuiKey
---@return ImGuiKey
function ImGui.GetKeyIndex(key) end

return ImGui
