---@meta imgui

--
-- Automatically generated file; DO NOT EDIT.
--

---@class ImGui
local ImGui = {}

--
-- Flags for ImGui::Begin()
-- (Those are per-window flags. There are shared flags in ImGuiIO: io.ConfigWindowsResizeFromEdges and io.ConfigWindowsMoveFromTitleBarOnly)
--
---@class ImGui.WindowFlags

---@alias _ImGuiWindowFlags_Name
---| "None"
---| "NoTitleBar"                #  Disable title-bar
---| "NoResize"                  #  Disable user resizing with the lower-right grip
---| "NoMove"                    #  Disable user moving the window
---| "NoScrollbar"               #  Disable scrollbars (window can still scroll with mouse or programmatically)
---| "NoScrollWithMouse"         #  Disable user vertically scrolling with mouse wheel. On child window, mouse wheel will be forwarded to the parent unless NoScrollbar is also set.
---| "NoCollapse"                #  Disable user collapsing window by double-clicking on it. Also referred to as Window Menu Button (e.g. within a docking node).
---| "AlwaysAutoResize"          #  Resize every window to its content every frame
---| "NoBackground"              #  Disable drawing background color (WindowBg, etc.) and outside border. Similar as using SetNextWindowBgAlpha(0.0f).
---| "NoSavedSettings"           #  Never load/save settings in .ini file
---| "NoMouseInputs"             #  Disable catching mouse, hovering test with pass through.
---| "MenuBar"                   #  Has a menu-bar
---| "HorizontalScrollbar"       #  Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
---| "NoFocusOnAppearing"        #  Disable taking focus when transitioning from hidden to visible state
---| "NoBringToFrontOnFocus"     #  Disable bringing window to front when taking focus (e.g. clicking on it or programmatically giving it focus)
---| "AlwaysVerticalScrollbar"   #  Always show vertical scrollbar (even if ContentSize.y < Size.y)
---| "AlwaysHorizontalScrollbar" #  Always show horizontal scrollbar (even if ContentSize.x < Size.x)
---| "NoNavInputs"               #  No gamepad/keyboard navigation within the window
---| "NoNavFocus"                #  No focusing toward this window with gamepad/keyboard navigation (e.g. skipped by CTRL+TAB)
---| "UnsavedDocument"           #  Display a dot next to the title. When used in a tab/docking context, tab is selected when clicking the X + closure is not assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
---| "NoDocking"                 #  Disable docking of this window
---| "NoNav"
---| "NoDecoration"
---| "NoInputs"

---@param flags _ImGuiWindowFlags_Name[]
---@return ImGui.WindowFlags
function ImGui.WindowFlags(flags) end

--
-- Flags for ImGui::BeginChild()
-- (Legacy: bit 0 must always correspond to ImGuiChildFlags_Border to be backward compatible with old API using 'bool border = false'.
-- About using AutoResizeX/AutoResizeY flags:
-- - May be combined with SetNextWindowSizeConstraints() to set a min/max size for each axis (see "Demo->Child->Auto-resize with Constraints").
-- - Size measurement for a given axis is only performed when the child window is within visible boundaries, or is just appearing.
--   - This allows BeginChild() to return false when not within boundaries (e.g. when scrolling), which is more optimal. BUT it won't update its auto-size while clipped.
--     While not perfect, it is a better default behavior as the always-on performance gain is more valuable than the occasional "resizing after becoming visible again" glitch.
--   - You may also use ImGuiChildFlags_AlwaysAutoResize to force an update even when child window is not in view.
--     HOWEVER PLEASE UNDERSTAND THAT DOING SO WILL PREVENT BeginChild() FROM EVER RETURNING FALSE, disabling benefits of coarse clipping.
--
---@class ImGui.ChildFlags

---@alias _ImGuiChildFlags_Name
---| "None"
---| "Border"                 #  Show an outer border and enable WindowPadding. (IMPORTANT: this is always == 1 == true for legacy reason)
---| "AlwaysUseWindowPadding" #  Pad with style.WindowPadding even if no border are drawn (no padding by default for non-bordered child windows because it makes more sense)
---| "ResizeX"                #  Allow resize from right border (layout direction). Enable .ini saving (unless ImGuiWindowFlags_NoSavedSettings passed to window flags)
---| "ResizeY"                #  Allow resize from bottom border (layout direction). "
---| "AutoResizeX"            #  Enable auto-resizing width. Read "IMPORTANT: Size measurement" details above.
---| "AutoResizeY"            #  Enable auto-resizing height. Read "IMPORTANT: Size measurement" details above.
---| "AlwaysAutoResize"       #  Combined with AutoResizeX/AutoResizeY. Always measure size even when child is hidden, always return true, always disable clipping optimization! NOT RECOMMENDED.
---| "FrameStyle"             #  Style the child window like a framed item: use FrameBg, FrameRounding, FrameBorderSize, FramePadding instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.

---@param flags _ImGuiChildFlags_Name[]
---@return ImGui.ChildFlags
function ImGui.ChildFlags(flags) end

--
-- Flags for ImGui::InputText()
-- (Those are per-item flags. There are shared flags in ImGuiIO: io.ConfigInputTextCursorBlink and io.ConfigInputTextEnterKeepActive)
--
---@class ImGui.InputTextFlags

---@alias _ImGuiInputTextFlags_Name
---| "None"
---| "CharsDecimal"        #  Allow 0123456789.+-*/
---| "CharsHexadecimal"    #  Allow 0123456789ABCDEFabcdef
---| "CharsUppercase"      #  Turn a..z into A..Z
---| "CharsNoBlank"        #  Filter out spaces, tabs
---| "AutoSelectAll"       #  Select entire text when first taking mouse focus
---| "EnterReturnsTrue"    #  Return 'true' when Enter is pressed (as opposed to every time the value was modified). Consider looking at the IsItemDeactivatedAfterEdit() function.
---| "CallbackCompletion"  #  Callback on pressing TAB (for completion handling)
---| "CallbackHistory"     #  Callback on pressing Up/Down arrows (for history handling)
---| "CallbackAlways"      #  Callback on each iteration. User code may query cursor position, modify text buffer.
---| "CallbackCharFilter"  #  Callback on character inputs to replace or discard them. Modify 'EventChar' to replace or discard, or return 1 in callback to discard.
---| "AllowTabInput"       #  Pressing TAB input a '\t' character into the text field
---| "CtrlEnterForNewLine" #  In multi-line mode, unfocus with Enter, add new line with Ctrl+Enter (default is opposite: unfocus with Ctrl+Enter, add line with Enter).
---| "NoHorizontalScroll"  #  Disable following the cursor horizontally
---| "AlwaysOverwrite"     #  Overwrite mode
---| "ReadOnly"            #  Read-only mode
---| "Password"            #  Password mode, display all characters as '*'
---| "NoUndoRedo"          #  Disable undo/redo. Note that input text owns the text data while active, if you want to provide your own undo/redo stack you need e.g. to call ClearActiveID().
---| "CharsScientific"     #  Allow 0123456789.+-*/eE (Scientific notation input)
---| "CallbackResize"      #  Callback on buffer capacity changes request (beyond 'buf_size' parameter value), allowing the string to grow. Notify when the string wants to be resized (for string types which hold a cache of their Size). You will be provided a new BufSize in the callback and NEED to honor it. (see misc/cpp/imgui_stdlib.h for an example of using this)
---| "CallbackEdit"        #  Callback on any edit (note that InputText() already returns true on edit, the callback is useful mainly to manipulate the underlying buffer while focus is active)
---| "EscapeClearsAll"     #  Escape key clears content if not empty, and deactivate otherwise (contrast to default behavior of Escape to revert)

---@param flags _ImGuiInputTextFlags_Name[]
---@return ImGui.InputTextFlags
function ImGui.InputTextFlags(flags) end

--
-- Flags for ImGui::TreeNodeEx(), ImGui::CollapsingHeader*()
--
---@class ImGui.TreeNodeFlags

---@alias _ImGuiTreeNodeFlags_Name
---| "None"
---| "Selected"             #  Draw as selected
---| "Framed"               #  Draw frame with background (e.g. for CollapsingHeader)
---| "AllowOverlap"         #  Hit testing to allow subsequent widgets to overlap this one
---| "NoTreePushOnOpen"     #  Don't do a TreePush() when open (e.g. for CollapsingHeader) = no extra indent nor pushing on ID stack
---| "NoAutoOpenOnLog"      #  Don't automatically and temporarily open node when Logging is active (by default logging will automatically open tree nodes)
---| "DefaultOpen"          #  Default node to be open
---| "OpenOnDoubleClick"    #  Need double-click to open node
---| "OpenOnArrow"          #  Only open when clicking on the arrow part. If ImGuiTreeNodeFlags_OpenOnDoubleClick is also set, single-click arrow or double-click all box to open.
---| "Leaf"                 #  No collapsing, no arrow (use as a convenience for leaf nodes).
---| "Bullet"               #  Display a bullet instead of arrow. IMPORTANT: node can still be marked open/close if you don't set the _Leaf flag!
---| "FramePadding"         #  Use FramePadding (even for an unframed text node) to vertically align text baseline to regular widget height. Equivalent to calling AlignTextToFramePadding().
---| "SpanAvailWidth"       #  Extend hit box to the right-most edge, even if not framed. This is not the default in order to allow adding other items on the same line without using AllowOverlap mode.
---| "SpanFullWidth"        #  Extend hit box to the left-most and right-most edges (cover the indent area).
---| "SpanTextWidth"        #  Narrow hit box + narrow hovering highlight, will only cover the label text.
---| "SpanAllColumns"       #  Frame will span all columns of its container table (text will still fit in current column)
---| "NavLeftJumpsBackHere" #  (WIP) Nav: left direction may move to this TreeNode() from any of its child (items submitted between TreeNode and TreePop)
---| "CollapsingHeader"

---@param flags _ImGuiTreeNodeFlags_Name[]
---@return ImGui.TreeNodeFlags
function ImGui.TreeNodeFlags(flags) end

--
-- Flags for OpenPopup*(), BeginPopupContext*(), IsPopupOpen() functions.
-- - To be backward compatible with older API which took an 'int mouse_button = 1' argument instead of 'ImGuiPopupFlags flags',
--   we need to treat small flags values as a mouse button index, so we encode the mouse button in the first few bits of the flags.
--   It is therefore guaranteed to be legal to pass a mouse button index in ImGuiPopupFlags.
-- - For the same reason, we exceptionally default the ImGuiPopupFlags argument of BeginPopupContextXXX functions to 1 instead of 0.
--   IMPORTANT: because the default parameter is 1 (==ImGuiPopupFlags_MouseButtonRight), if you rely on the default parameter
--   and want to use another flag, you need to pass in the ImGuiPopupFlags_MouseButtonRight flag explicitly.
-- - Multiple buttons currently cannot be combined/or-ed in those functions (we could allow it later).
--
---@class ImGui.PopupFlags

---@alias _ImGuiPopupFlags_Name
---| "None"
---| "MouseButtonLeft"         #  For BeginPopupContext*(): open on Left Mouse release. Guaranteed to always be == 0 (same as ImGuiMouseButton_Left)
---| "MouseButtonRight"        #  For BeginPopupContext*(): open on Right Mouse release. Guaranteed to always be == 1 (same as ImGuiMouseButton_Right)
---| "MouseButtonMiddle"       #  For BeginPopupContext*(): open on Middle Mouse release. Guaranteed to always be == 2 (same as ImGuiMouseButton_Middle)
---| "NoReopen"                #  For OpenPopup*(), BeginPopupContext*(): don't reopen same popup if already open (won't reposition, won't reinitialize navigation)
---| "NoOpenOverExistingPopup" #  For OpenPopup*(), BeginPopupContext*(): don't open if there's already a popup at the same level of the popup stack
---| "NoOpenOverItems"         #  For BeginPopupContextWindow(): don't return true when hovering items, only when hovering empty space
---| "AnyPopupId"              #  For IsPopupOpen(): ignore the ImGuiID parameter and test for any popup.
---| "AnyPopupLevel"           #  For IsPopupOpen(): search/test at any level of the popup stack (default test in the current level)
---| "AnyPopup"

---@param flags _ImGuiPopupFlags_Name[]
---@return ImGui.PopupFlags
function ImGui.PopupFlags(flags) end

--
-- Flags for ImGui::Selectable()
--
---@class ImGui.SelectableFlags

---@alias _ImGuiSelectableFlags_Name
---| "None"
---| "DontClosePopups"  #  Clicking this doesn't close parent popup window
---| "SpanAllColumns"   #  Frame will span all columns of its container table (text will still fit in current column)
---| "AllowDoubleClick" #  Generate press events on double clicks too
---| "Disabled"         #  Cannot be selected, display grayed out text
---| "AllowOverlap"     #  (WIP) Hit testing to allow subsequent widgets to overlap this one

---@param flags _ImGuiSelectableFlags_Name[]
---@return ImGui.SelectableFlags
function ImGui.SelectableFlags(flags) end

--
-- Flags for ImGui::BeginCombo()
--
---@class ImGui.ComboFlags

---@alias _ImGuiComboFlags_Name
---| "None"
---| "PopupAlignLeft"  #  Align the popup toward the left by default
---| "HeightSmall"     #  Max ~4 items visible. Tip: If you want your combo popup to be a specific size you can use SetNextWindowSizeConstraints() prior to calling BeginCombo()
---| "HeightRegular"   #  Max ~8 items visible (default)
---| "HeightLarge"     #  Max ~20 items visible
---| "HeightLargest"   #  As many fitting items as possible
---| "NoArrowButton"   #  Display on the preview box without the square arrow button
---| "NoPreview"       #  Display only a square arrow button
---| "WidthFitPreview" #  Width dynamically calculated from preview contents

---@param flags _ImGuiComboFlags_Name[]
---@return ImGui.ComboFlags
function ImGui.ComboFlags(flags) end

--
-- Flags for ImGui::BeginTabBar()
--
---@class ImGui.TabBarFlags

---@alias _ImGuiTabBarFlags_Name
---| "None"
---| "Reorderable"                  #  Allow manually dragging tabs to re-order them + New tabs are appended at the end of list
---| "AutoSelectNewTabs"            #  Automatically select new tabs when they appear
---| "TabListPopupButton"           #  Disable buttons to open the tab list popup
---| "NoCloseWithMiddleMouseButton" #  Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You may handle this behavior manually on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
---| "NoTabListScrollingButtons"    #  Disable scrolling buttons (apply when fitting policy is ImGuiTabBarFlags_FittingPolicyScroll)
---| "NoTooltip"                    #  Disable tooltips when hovering a tab
---| "FittingPolicyResizeDown"      #  Resize tabs when they don't fit
---| "FittingPolicyScroll"          #  Add scroll buttons when tabs don't fit

---@param flags _ImGuiTabBarFlags_Name[]
---@return ImGui.TabBarFlags
function ImGui.TabBarFlags(flags) end

--
-- Flags for ImGui::BeginTabItem()
--
---@class ImGui.TabItemFlags

---@alias _ImGuiTabItemFlags_Name
---| "None"
---| "UnsavedDocument"              #  Display a dot next to the title + set ImGuiTabItemFlags_NoAssumedClosure.
---| "SetSelected"                  #  Trigger flag to programmatically make the tab selected when calling BeginTabItem()
---| "NoCloseWithMiddleMouseButton" #  Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You may handle this behavior manually on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
---| "NoPushId"                     #  Don't call PushID()/PopID() on BeginTabItem()/EndTabItem()
---| "NoTooltip"                    #  Disable tooltip for the given tab
---| "NoReorder"                    #  Disable reordering this tab or having another tab cross over this tab
---| "Leading"                      #  Enforce the tab position to the left of the tab bar (after the tab list popup button)
---| "Trailing"                     #  Enforce the tab position to the right of the tab bar (before the scrolling buttons)
---| "NoAssumedClosure"             #  Tab is selected when trying to close + closure is not immediately assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.

---@param flags _ImGuiTabItemFlags_Name[]
---@return ImGui.TabItemFlags
function ImGui.TabItemFlags(flags) end

--
-- Flags for ImGui::IsWindowFocused()
--
---@class ImGui.FocusedFlags

---@alias _ImGuiFocusedFlags_Name
---| "None"
---| "ChildWindows"        #  Return true if any children of the window is focused
---| "RootWindow"          #  Test from root window (top most parent of the current hierarchy)
---| "AnyWindow"           #  Return true if any window is focused. Important: If you are trying to tell how to dispatch your low-level inputs, do NOT use this. Use 'io.WantCaptureMouse' instead! Please read the FAQ!
---| "NoPopupHierarchy"    #  Do not consider popup hierarchy (do not treat popup emitter as parent of popup) (when used with _ChildWindows or _RootWindow)
---| "DockHierarchy"       #  Consider docking hierarchy (treat dockspace host as parent of docked window) (when used with _ChildWindows or _RootWindow)
---| "RootAndChildWindows"

---@param flags _ImGuiFocusedFlags_Name[]
---@return ImGui.FocusedFlags
function ImGui.FocusedFlags(flags) end

--
-- Flags for ImGui::IsItemHovered(), ImGui::IsWindowHovered()
-- Note: if you are trying to check whether your mouse should be dispatched to Dear ImGui or to your app, you should use 'io.WantCaptureMouse' instead! Please read the FAQ!
-- Note: windows with the ImGuiWindowFlags_NoInputs flag are ignored by IsWindowHovered() calls.
--
---@class ImGui.HoveredFlags

---@alias _ImGuiHoveredFlags_Name
---| "None"                         #  Return true if directly over the item/window, not obstructed by another window, not obstructed by an active popup or modal blocking inputs under them.
---| "ChildWindows"                 #  IsWindowHovered() only: Return true if any children of the window is hovered
---| "RootWindow"                   #  IsWindowHovered() only: Test from root window (top most parent of the current hierarchy)
---| "AnyWindow"                    #  IsWindowHovered() only: Return true if any window is hovered
---| "NoPopupHierarchy"             #  IsWindowHovered() only: Do not consider popup hierarchy (do not treat popup emitter as parent of popup) (when used with _ChildWindows or _RootWindow)
---| "DockHierarchy"                #  IsWindowHovered() only: Consider docking hierarchy (treat dockspace host as parent of docked window) (when used with _ChildWindows or _RootWindow)
---| "AllowWhenBlockedByPopup"      #  Return true even if a popup window is normally blocking access to this item/window
---| "AllowWhenBlockedByActiveItem" #  Return true even if an active item is blocking access to this item/window. Useful for Drag and Drop patterns.
---| "AllowWhenOverlappedByItem"    #  IsItemHovered() only: Return true even if the item uses AllowOverlap mode and is overlapped by another hoverable item.
---| "AllowWhenOverlappedByWindow"  #  IsItemHovered() only: Return true even if the position is obstructed or overlapped by another window.
---| "AllowWhenDisabled"            #  IsItemHovered() only: Return true even if the item is disabled
---| "NoNavOverride"                #  IsItemHovered() only: Disable using gamepad/keyboard navigation state when active, always query mouse
---| "AllowWhenOverlapped"
---| "RectOnly"
---| "RootAndChildWindows"
---| "ForTooltip"                   #  Shortcut for standard flags when using IsItemHovered() + SetTooltip() sequence.
---| "Stationary"                   #  Require mouse to be stationary for style.HoverStationaryDelay (~0.15 sec) _at least one time_. After this, can move on same item/window. Using the stationary test tends to reduces the need for a long delay.
---| "DelayNone"                    #  IsItemHovered() only: Return true immediately (default). As this is the default you generally ignore this.
---| "DelayShort"                   #  IsItemHovered() only: Return true after style.HoverDelayShort elapsed (~0.15 sec) (shared between items) + requires mouse to be stationary for style.HoverStationaryDelay (once per item).
---| "DelayNormal"                  #  IsItemHovered() only: Return true after style.HoverDelayNormal elapsed (~0.40 sec) (shared between items) + requires mouse to be stationary for style.HoverStationaryDelay (once per item).
---| "NoSharedDelay"                #  IsItemHovered() only: Disable shared delay system where moving from one item to the next keeps the previous timer for a short time (standard for tooltips with long delays)

---@param flags _ImGuiHoveredFlags_Name[]
---@return ImGui.HoveredFlags
function ImGui.HoveredFlags(flags) end

--
-- Flags for ImGui::DockSpace(), shared/inherited by child nodes.
-- (Some flags can be applied to individual nodes directly)
-- FIXME-DOCK: Also see ImGuiDockNodeFlagsPrivate_ which may involve using the WIP and internal DockBuilder api.
--
---@class ImGui.DockNodeFlags

---@alias _ImGuiDockNodeFlags_Name
---| "None"
---| "KeepAliveOnly"            #        // Don't display the dockspace node but keep it alive. Windows docked into this dockspace node won't be undocked.
---| "NoDockingOverCentralNode" #        // Disable docking over the Central Node, which will be always kept empty.
---| "PassthruCentralNode"      #        // Enable passthru dockspace: 1) DockSpace() will render a ImGuiCol_WindowBg background covering everything excepted the Central Node when empty. Meaning the host window should probably use SetNextWindowBgAlpha(0.0f) prior to Begin() when using this. 2) When Central Node is empty: let inputs pass-through + won't display a DockingEmptyBg background. See demo for details.
---| "NoDockingSplit"           #        // Disable other windows/nodes from splitting this node.
---| "NoResize"                 #  Saved // Disable resizing node using the splitter/separators. Useful with programmatically setup dockspaces.
---| "AutoHideTabBar"           #        // Tab bar will automatically hide when there is a single window in the dock node.
---| "NoUndocking"              #        // Disable undocking this node.

---@param flags _ImGuiDockNodeFlags_Name[]
---@return ImGui.DockNodeFlags
function ImGui.DockNodeFlags(flags) end

--
-- Flags for ImGui::BeginDragDropSource(), ImGui::AcceptDragDropPayload()
--
---@class ImGui.DragDropFlags

---@alias _ImGuiDragDropFlags_Name
---| "None"
---| "SourceNoPreviewTooltip"   #  Disable preview tooltip. By default, a successful call to BeginDragDropSource opens a tooltip so you can display a preview or description of the source contents. This flag disables this behavior.
---| "SourceNoDisableHover"     #  By default, when dragging we clear data so that IsItemHovered() will return false, to avoid subsequent user code submitting tooltips. This flag disables this behavior so you can still call IsItemHovered() on the source item.
---| "SourceNoHoldToOpenOthers" #  Disable the behavior that allows to open tree nodes and collapsing header by holding over them while dragging a source item.
---| "SourceAllowNullID"        #  Allow items such as Text(), Image() that have no unique identifier to be used as drag source, by manufacturing a temporary identifier based on their window-relative position. This is extremely unusual within the dear imgui ecosystem and so we made it explicit.
---| "SourceExtern"             #  External source (from outside of dear imgui), won't attempt to read current item/window info. Will always return true. Only one Extern source can be active simultaneously.
---| "SourceAutoExpirePayload"  #  Automatically expire the payload if the source cease to be submitted (otherwise payloads are persisting while being dragged)
---| "AcceptBeforeDelivery"     #  AcceptDragDropPayload() will returns true even before the mouse button is released. You can then call IsDelivery() to test if the payload needs to be delivered.
---| "AcceptNoDrawDefaultRect"  #  Do not draw the default highlight rectangle when hovering over target.
---| "AcceptNoPreviewTooltip"   #  Request hiding the BeginDragDropSource tooltip from the BeginDragDropTarget site.
---| "AcceptPeekOnly"           #  For peeking ahead and inspecting the payload before delivery.

---@param flags _ImGuiDragDropFlags_Name[]
---@return ImGui.DragDropFlags
function ImGui.DragDropFlags(flags) end

--
-- Flags for Shortcut(), SetNextItemShortcut(),
-- (and for upcoming extended versions of IsKeyPressed(), IsMouseClicked(), Shortcut(), SetKeyOwner(), SetItemKeyOwner() that are still in imgui_internal.h)
-- Don't mistake with ImGuiInputTextFlags! (which is for ImGui::InputText() function)
--
---@class ImGui.InputFlags

---@alias _ImGuiInputFlags_Name
---| "None"
---| "Repeat"               #  Enable repeat. Return true on successive repeats. Default for legacy IsKeyPressed(). NOT Default for legacy IsMouseClicked(). MUST BE == 1.
---| "RouteActive"          #  Route to active item only.
---| "RouteFocused"         #  Route to windows in the focus stack (DEFAULT). Deep-most focused window takes inputs. Active item takes inputs over deep-most focused window.
---| "RouteGlobal"          #  Global route (unless a focused window or active item registered the route).
---| "RouteAlways"          #  Do not register route, poll keys directly.
---| "RouteOverFocused"     #  Option: global route: higher priority than focused route (unless active item in focused route).
---| "RouteOverActive"      #  Option: global route: higher priority than active item. Unlikely you need to use that: will interfere with every active items, e.g. CTRL+A registered by InputText will be overridden by this. May not be fully honored as user/internal code is likely to always assume they can access keys when active.
---| "RouteUnlessBgFocused" #  Option: global route: will not be applied if underlying background/void is focused (== no Dear ImGui windows are focused). Useful for overlay applications.
---| "RouteFromRootWindow"  #  Option: route evaluated from the point of view of root window rather than current window.
---| "Tooltip"              #  Automatically display a tooltip when hovering item [BETA] Unsure of right api (opt-in/opt-out)

---@param flags _ImGuiInputFlags_Name[]
---@return ImGui.InputFlags
function ImGui.InputFlags(flags) end

--
-- Configuration flags stored in io.ConfigFlags. Set by user/application.
--
---@class ImGui.ConfigFlags

---@alias _ImGuiConfigFlags_Name
---| "None"
---| "NavEnableKeyboard"       #  Master keyboard navigation enable flag. Enable full Tabbing + directional arrows + space/enter to activate.
---| "NavEnableGamepad"        #  Master gamepad navigation enable flag. Backend also needs to set ImGuiBackendFlags_HasGamepad.
---| "NavEnableSetMousePos"    #  Instruct navigation to move the mouse cursor. May be useful on TV/console systems where moving a virtual mouse is awkward. Will update io.MousePos and set io.WantSetMousePos=true. If enabled you MUST honor io.WantSetMousePos requests in your backend, otherwise ImGui will react as if the mouse is jumping around back and forth.
---| "NavNoCaptureKeyboard"    #  Instruct navigation to not set the io.WantCaptureKeyboard flag when io.NavActive is set.
---| "NoMouse"                 #  Instruct imgui to clear mouse position/buttons in NewFrame(). This allows ignoring the mouse information set by the backend.
---| "NoMouseCursorChange"     #  Instruct backend to not alter mouse cursor shape and visibility. Use if the backend cursor changes are interfering with yours and you don't want to use SetMouseCursor() to change mouse cursor. You may want to honor requests from imgui by reading GetMouseCursor() yourself instead.
---| "DockingEnable"           #  Docking enable flags.
---| "ViewportsEnable"         #  Viewport enable flags (require both ImGuiBackendFlags_PlatformHasViewports + ImGuiBackendFlags_RendererHasViewports set by the respective backends)
---| "DpiEnableScaleViewports" #  [BETA: Don't use] FIXME-DPI: Reposition and resize imgui windows when the DpiScale of a viewport changed (mostly useful for the main viewport hosting other window). Note that resizing the main window itself is up to your application.
---| "DpiEnableScaleFonts"     #  [BETA: Don't use] FIXME-DPI: Request bitmap-scaled fonts to match DpiScale. This is a very low-quality workaround. The correct way to handle DPI is _currently_ to replace the atlas and/or fonts in the Platform_OnChangedViewport callback, but this is all early work in progress.
---| "IsSRGB"                  #  Application is SRGB-aware.
---| "IsTouchScreen"           #  Application is using a touch screen instead of a mouse.

---@param flags _ImGuiConfigFlags_Name[]
---@return ImGui.ConfigFlags
function ImGui.ConfigFlags(flags) end

--
-- Backend capabilities flags stored in io.BackendFlags. Set by imgui_impl_xxx or custom backend.
--
---@class ImGui.BackendFlags

---@alias _ImGuiBackendFlags_Name
---| "None"
---| "HasGamepad"              #  Backend Platform supports gamepad and currently has one connected.
---| "HasMouseCursors"         #  Backend Platform supports honoring GetMouseCursor() value to change the OS cursor shape.
---| "HasSetMousePos"          #  Backend Platform supports io.WantSetMousePos requests to reposition the OS mouse position (only used if ImGuiConfigFlags_NavEnableSetMousePos is set).
---| "RendererHasVtxOffset"    #  Backend Renderer supports ImDrawCmd::VtxOffset. This enables output of large meshes (64K+ vertices) while still using 16-bit indices.
---| "PlatformHasViewports"    #  Backend Platform supports multiple viewports.
---| "HasMouseHoveredViewport" #  Backend Platform supports calling io.AddMouseViewportEvent() with the viewport under the mouse. IF POSSIBLE, ignore viewports with the ImGuiViewportFlags_NoInputs flag (Win32 backend, GLFW 3.30+ backend can do this, SDL backend cannot). If this cannot be done, Dear ImGui needs to use a flawed heuristic to find the viewport under.
---| "RendererHasViewports"    #  Backend Renderer supports multiple viewports.

---@param flags _ImGuiBackendFlags_Name[]
---@return ImGui.BackendFlags
function ImGui.BackendFlags(flags) end

--
-- Flags for InvisibleButton() [extended in imgui_internal.h]
--
---@class ImGui.ButtonFlags

---@alias _ImGuiButtonFlags_Name
---| "None"
---| "MouseButtonLeft"   #  React on left mouse button (default)
---| "MouseButtonRight"  #  React on right mouse button
---| "MouseButtonMiddle" #  React on center mouse button

---@param flags _ImGuiButtonFlags_Name[]
---@return ImGui.ButtonFlags
function ImGui.ButtonFlags(flags) end

--
-- Flags for ColorEdit3() / ColorEdit4() / ColorPicker3() / ColorPicker4() / ColorButton()
--
---@class ImGui.ColorEditFlags

---@alias _ImGuiColorEditFlags_Name
---| "None"
---| "NoAlpha"          #               // ColorEdit, ColorPicker, ColorButton: ignore Alpha component (will only read 3 components from the input pointer).
---| "NoPicker"         #               // ColorEdit: disable picker when clicking on color square.
---| "NoOptions"        #               // ColorEdit: disable toggling options menu when right-clicking on inputs/small preview.
---| "NoSmallPreview"   #               // ColorEdit, ColorPicker: disable color square preview next to the inputs. (e.g. to show only the inputs)
---| "NoInputs"         #               // ColorEdit, ColorPicker: disable inputs sliders/text widgets (e.g. to show only the small preview color square).
---| "NoTooltip"        #               // ColorEdit, ColorPicker, ColorButton: disable tooltip when hovering the preview.
---| "NoLabel"          #               // ColorEdit, ColorPicker: disable display of inline text label (the label is still forwarded to the tooltip and picker).
---| "NoSidePreview"    #               // ColorPicker: disable bigger color preview on right side of the picker, use small color square preview instead.
---| "NoDragDrop"       #               // ColorEdit: disable drag and drop target. ColorButton: disable drag and drop source.
---| "NoBorder"         #               // ColorButton: disable border (which is enforced by default)
---| "AlphaBar"         #               // ColorEdit, ColorPicker: show vertical alpha bar/gradient in picker.
---| "AlphaPreview"     #               // ColorEdit, ColorPicker, ColorButton: display preview as a transparent color over a checkerboard, instead of opaque.
---| "AlphaPreviewHalf" #               // ColorEdit, ColorPicker, ColorButton: display half opaque / half checkerboard, instead of opaque.
---| "HDR"              #               // (WIP) ColorEdit: Currently only disable 0.0f..1.0f limits in RGBA edition (note: you probably want to use ImGuiColorEditFlags_Float flag as well).
---| "DisplayRGB"       #  [Display]    // ColorEdit: override _display_ type among RGB/HSV/Hex. ColorPicker: select any combination using one or more of RGB/HSV/Hex.
---| "DisplayHSV"       #  [Display]    // "
---| "DisplayHex"       #  [Display]    // "
---| "Uint8"            #  [DataType]   // ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0..255.
---| "Float"            #  [DataType]   // ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0.0f..1.0f floats instead of 0..255 integers. No round-trip of value via integers.
---| "PickerHueBar"     #  [Picker]     // ColorPicker: bar for Hue, rectangle for Sat/Value.
---| "PickerHueWheel"   #  [Picker]     // ColorPicker: wheel for Hue, triangle for Sat/Value.
---| "InputRGB"         #  [Input]      // ColorEdit, ColorPicker: input and output data in RGB format.
---| "InputHSV"         #  [Input]      // ColorEdit, ColorPicker: input and output data in HSV format.

---@param flags _ImGuiColorEditFlags_Name[]
---@return ImGui.ColorEditFlags
function ImGui.ColorEditFlags(flags) end

--
-- Flags for DragFloat(), DragInt(), SliderFloat(), SliderInt() etc.
-- We use the same sets of flags for DragXXX() and SliderXXX() functions as the features are the same and it makes it easier to swap them.
-- (Those are per-item flags. There are shared flags in ImGuiIO: io.ConfigDragClickToInputText)
--
---@class ImGui.SliderFlags

---@alias _ImGuiSliderFlags_Name
---| "None"
---| "AlwaysClamp"     #  Clamp value to min/max bounds when input manually with CTRL+Click. By default CTRL+Click allows going out of bounds.
---| "Logarithmic"     #  Make the widget logarithmic (linear otherwise). Consider using ImGuiSliderFlags_NoRoundToFormat with this if using a format-string with small amount of digits.
---| "NoRoundToFormat" #  Disable rounding underlying value to match precision of the display format string (e.g. %.3f values are rounded to those 3 digits)
---| "NoInput"         #  Disable CTRL+Click or Enter key allowing to input text directly into the widget

---@param flags _ImGuiSliderFlags_Name[]
---@return ImGui.SliderFlags
function ImGui.SliderFlags(flags) end

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
---@class ImGui.TableFlags

---@alias _ImGuiTableFlags_Name
---| "None"
---| "Resizable"                  #  Enable resizing columns.
---| "Reorderable"                #  Enable reordering columns in header row (need calling TableSetupColumn() + TableHeadersRow() to display headers)
---| "Hideable"                   #  Enable hiding/disabling columns in context menu.
---| "Sortable"                   #  Enable sorting. Call TableGetSortSpecs() to obtain sort specs. Also see ImGuiTableFlags_SortMulti and ImGuiTableFlags_SortTristate.
---| "NoSavedSettings"            #  Disable persisting columns order, width and sort settings in the .ini file.
---| "ContextMenuInBody"          #  Right-click on columns body/contents will display table context menu. By default it is available in TableHeadersRow().
---| "RowBg"                      #  Set each RowBg color with ImGuiCol_TableRowBg or ImGuiCol_TableRowBgAlt (equivalent of calling TableSetBgColor with ImGuiTableBgFlags_RowBg0 on each row manually)
---| "BordersInnerH"              #  Draw horizontal borders between rows.
---| "BordersOuterH"              #  Draw horizontal borders at the top and bottom.
---| "BordersInnerV"              #  Draw vertical borders between columns.
---| "BordersOuterV"              #  Draw vertical borders on the left and right sides.
---| "BordersH"                   #  Draw horizontal borders.
---| "BordersV"                   #  Draw vertical borders.
---| "BordersInner"               #  Draw inner borders.
---| "BordersOuter"               #  Draw outer borders.
---| "Borders"                    #  Draw all borders.
---| "NoBordersInBody"            #  [ALPHA] Disable vertical borders in columns Body (borders will always appear in Headers). -> May move to style
---| "NoBordersInBodyUntilResize" #  [ALPHA] Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers). -> May move to style
---| "SizingFixedFit"             #  Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching contents width.
---| "SizingFixedSame"            #  Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching the maximum contents width of all columns. Implicitly enable ImGuiTableFlags_NoKeepColumnsVisible.
---| "SizingStretchProp"          #  Columns default to _WidthStretch with default weights proportional to each columns contents widths.
---| "SizingStretchSame"          #  Columns default to _WidthStretch with default weights all equal, unless overridden by TableSetupColumn().
---| "NoHostExtendX"              #  Make outer width auto-fit to columns, overriding outer_size.x value. Only available when ScrollX/ScrollY are disabled and Stretch columns are not used.
---| "NoHostExtendY"              #  Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit). Only available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.
---| "NoKeepColumnsVisible"       #  Disable keeping column always minimally visible when ScrollX is off and table gets too small. Not recommended if columns are resizable.
---| "PreciseWidths"              #  Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.
---| "NoClip"                     #  Disable clipping rectangle for every individual columns (reduce draw command count, items will be able to overflow into other columns). Generally incompatible with TableSetupScrollFreeze().
---| "PadOuterX"                  #  Default if BordersOuterV is on. Enable outermost padding. Generally desirable if you have headers.
---| "NoPadOuterX"                #  Default if BordersOuterV is off. Disable outermost padding.
---| "NoPadInnerX"                #  Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off).
---| "ScrollX"                    #  Enable horizontal scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size. Changes default sizing policy. Because this creates a child window, ScrollY is currently generally recommended when using ScrollX.
---| "ScrollY"                    #  Enable vertical scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size.
---| "SortMulti"                  #  Hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).
---| "SortTristate"               #  Allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).
---| "HighlightHoveredColumn"     #  Highlight column headers when hovered (may evolve into a fuller highlight)

---@param flags _ImGuiTableFlags_Name[]
---@return ImGui.TableFlags
function ImGui.TableFlags(flags) end

--
-- Flags for ImGui::TableSetupColumn()
--
---@class ImGui.TableColumnFlags

---@alias _ImGuiTableColumnFlags_Name
---| "None"
---| "Disabled"             #  Overriding/master disable flag: hide column, won't show in context menu (unlike calling TableSetColumnEnabled() which manipulates the user accessible state)
---| "DefaultHide"          #  Default as a hidden/disabled column.
---| "DefaultSort"          #  Default as a sorting column.
---| "WidthStretch"         #  Column will stretch. Preferable with horizontal scrolling disabled (default if table sizing policy is _SizingStretchSame or _SizingStretchProp).
---| "WidthFixed"           #  Column will not stretch. Preferable with horizontal scrolling enabled (default if table sizing policy is _SizingFixedFit and table is resizable).
---| "NoResize"             #  Disable manual resizing.
---| "NoReorder"            #  Disable manual reordering this column, this will also prevent other columns from crossing over this column.
---| "NoHide"               #  Disable ability to hide/disable this column.
---| "NoClip"               #  Disable clipping for this column (all NoClip columns will render in a same draw command).
---| "NoSort"               #  Disable ability to sort on this field (even if ImGuiTableFlags_Sortable is set on the table).
---| "NoSortAscending"      #  Disable ability to sort in the ascending direction.
---| "NoSortDescending"     #  Disable ability to sort in the descending direction.
---| "NoHeaderLabel"        #  TableHeadersRow() will not submit horizontal label for this column. Convenient for some small columns. Name will still appear in context menu or in angled headers.
---| "NoHeaderWidth"        #  Disable header text width contribution to automatic column width.
---| "PreferSortAscending"  #  Make the initial sort direction Ascending when first sorting on this column (default).
---| "PreferSortDescending" #  Make the initial sort direction Descending when first sorting on this column.
---| "IndentEnable"         #  Use current Indent value when entering cell (default for column 0).
---| "IndentDisable"        #  Ignore current Indent value when entering cell (default for columns > 0). Indentation changes _within_ the cell will still be honored.
---| "AngledHeader"         #  TableHeadersRow() will submit an angled header row for this column. Note this will add an extra row.
---| "IsEnabled"            #  Status: is enabled == not hidden by user/api (referred to as "Hide" in _DefaultHide and _NoHide) flags.
---| "IsVisible"            #  Status: is visible == is enabled AND not clipped by scrolling.
---| "IsSorted"             #  Status: is currently part of the sort specs
---| "IsHovered"            #  Status: is hovered by mouse

---@param flags _ImGuiTableColumnFlags_Name[]
---@return ImGui.TableColumnFlags
function ImGui.TableColumnFlags(flags) end

--
-- Flags for ImGui::TableNextRow()
--
---@class ImGui.TableRowFlags

---@alias _ImGuiTableRowFlags_Name
---| "None"
---| "Headers" #  Identify header row (set default background color + width of its contents accounted differently for auto column width)

---@param flags _ImGuiTableRowFlags_Name[]
---@return ImGui.TableRowFlags
function ImGui.TableRowFlags(flags) end

--
-- Flags for ImDrawList functions
-- (Legacy: bit 0 must always correspond to ImDrawFlags_Closed to be backward compatible with old API using a bool. Bits 1..3 must be unused)
--
---@class ImGui.DrawFlags

---@alias _ImDrawFlags_Name
---| "None"
---| "Closed"                  #  PathStroke(), AddPolyline(): specify that shape should be closed (Important: this is always == 1 for legacy reason)
---| "RoundCornersTopLeft"     #  AddRect(), AddRectFilled(), PathRect(): enable rounding top-left corner only (when rounding > 0.0f, we default to all corners). Was 0x01.
---| "RoundCornersTopRight"    #  AddRect(), AddRectFilled(), PathRect(): enable rounding top-right corner only (when rounding > 0.0f, we default to all corners). Was 0x02.
---| "RoundCornersBottomLeft"  #  AddRect(), AddRectFilled(), PathRect(): enable rounding bottom-left corner only (when rounding > 0.0f, we default to all corners). Was 0x04.
---| "RoundCornersBottomRight" #  AddRect(), AddRectFilled(), PathRect(): enable rounding bottom-right corner only (when rounding > 0.0f, we default to all corners). Wax 0x08.
---| "RoundCornersNone"        #  AddRect(), AddRectFilled(), PathRect(): disable rounding on all corners (when rounding > 0.0f). This is NOT zero, NOT an implicit flag!
---| "RoundCornersTop"
---| "RoundCornersBottom"
---| "RoundCornersLeft"
---| "RoundCornersRight"
---| "RoundCornersAll"

---@param flags _ImDrawFlags_Name[]
---@return ImGui.DrawFlags
function ImGui.DrawFlags(flags) end

--
-- Flags for ImDrawList instance. Those are set automatically by ImGui:: functions from ImGuiIO settings, and generally not manipulated directly.
-- It is however possible to temporarily alter flags between calls to ImDrawList:: functions.
--
---@class ImGui.DrawListFlags

---@alias _ImDrawListFlags_Name
---| "None"
---| "AntiAliasedLines"       #  Enable anti-aliased lines/borders (*2 the number of triangles for 1.0f wide line or lines thin enough to be drawn using textures, otherwise *3 the number of triangles)
---| "AntiAliasedLinesUseTex" #  Enable anti-aliased lines/borders using textures when possible. Require backend to render with bilinear filtering (NOT point/nearest filtering).
---| "AntiAliasedFill"        #  Enable anti-aliased edge around filled shapes (rounded rectangles, circles).
---| "AllowVtxOffset"         #  Can emit 'VtxOffset > 0' to allow large meshes. Set when 'ImGuiBackendFlags_RendererHasVtxOffset' is enabled.

---@param flags _ImDrawListFlags_Name[]
---@return ImGui.DrawListFlags
function ImGui.DrawListFlags(flags) end

--
-- Flags for ImFontAtlas build
--
---@class ImGui.FontAtlasFlags

---@alias _ImFontAtlasFlags_Name
---| "None"
---| "NoPowerOfTwoHeight" #  Don't round the height to next power of two
---| "NoMouseCursors"     #  Don't build software mouse cursors into the atlas (save a little texture memory)
---| "NoBakedLines"       #  Don't build thick line textures into the atlas (save a little texture memory, allow support for point/nearest filtering). The AntiAliasedLinesUseTex features uses them, otherwise they will be rendered using polygons (more expensive for CPU/GPU).

---@param flags _ImFontAtlasFlags_Name[]
---@return ImGui.FontAtlasFlags
function ImGui.FontAtlasFlags(flags) end

--
-- Flags stored in ImGuiViewport::Flags, giving indications to the platform backends.
--
---@class ImGui.ViewportFlags

---@alias _ImGuiViewportFlags_Name
---| "None"
---| "IsPlatformWindow"    #  Represent a Platform Window
---| "IsPlatformMonitor"   #  Represent a Platform Monitor (unused yet)
---| "OwnedByApp"          #  Platform Window: Was created/managed by the user application? (rather than our backend)
---| "NoDecoration"        #  Platform Window: Disable platform decorations: title bar, borders, etc. (generally set all windows, but if ImGuiConfigFlags_ViewportsDecoration is set we only set this on popups/tooltips)
---| "NoTaskBarIcon"       #  Platform Window: Disable platform task bar icon (generally set on popups/tooltips, or all windows if ImGuiConfigFlags_ViewportsNoTaskBarIcon is set)
---| "NoFocusOnAppearing"  #  Platform Window: Don't take focus when created.
---| "NoFocusOnClick"      #  Platform Window: Don't take focus when clicked on.
---| "NoInputs"            #  Platform Window: Make mouse pass through so we can drag this window while peaking behind it.
---| "NoRendererClear"     #  Platform Window: Renderer doesn't need to clear the framebuffer ahead (because we will fill it entirely).
---| "NoAutoMerge"         #  Platform Window: Avoid merging this window into another host window. This can only be set via ImGuiWindowClass viewport flags override (because we need to now ahead if we are going to create a viewport in the first place!).
---| "TopMost"             #  Platform Window: Display on top (for tooltips only).
---| "CanHostOtherWindows" #  Viewport can host multiple imgui windows (secondary viewports are associated to a single window). // FIXME: In practice there's still probably code making the assumption that this is always and only on the MainViewport. Will fix once we add support for "no main viewport".
---| "IsMinimized"         #  Platform Window: Window is minimized, can skip render. When minimized we tend to avoid using the viewport pos/size for clipping window or testing if they are contained in the viewport.
---| "IsFocused"           #  Platform Window: Window is focused (last call to Platform_GetWindowFocus() returned true)

---@param flags _ImGuiViewportFlags_Name[]
---@return ImGui.ViewportFlags
function ImGui.ViewportFlags(flags) end

--
-- A primary data type
--
---@alias ImGui.DataType
---| `ImGui.DataType.S8`     #  signed char / char (with sensible compilers)
---| `ImGui.DataType.U8`     #  unsigned char
---| `ImGui.DataType.S16`    #  short
---| `ImGui.DataType.U16`    #  unsigned short
---| `ImGui.DataType.S32`    #  int
---| `ImGui.DataType.U32`    #  unsigned int
---| `ImGui.DataType.S64`    #  long long / __int64
---| `ImGui.DataType.U64`    #  unsigned long long / unsigned __int64
---| `ImGui.DataType.Float`  #  float
---| `ImGui.DataType.Double` #  double
ImGui.DataType = {}

--
-- A cardinal direction
--
--
-- Forward declared enum type ImGuiDir
--
---@alias ImGui.Dir
---| `ImGui.Dir.None`
---| `ImGui.Dir.Left`
---| `ImGui.Dir.Right`
---| `ImGui.Dir.Up`
---| `ImGui.Dir.Down`
ImGui.Dir = {}

--
-- A sorting direction
--
--
-- Forward declared enum type ImGuiSortDirection
--
---@alias ImGui.SortDirection
---| `ImGui.SortDirection.None`
---| `ImGui.SortDirection.Ascending`  #  Ascending = 0->9, A->Z etc.
---| `ImGui.SortDirection.Descending` #  Descending = 9->0, Z->A etc.
ImGui.SortDirection = {}

--
-- A key identifier (ImGuiKey_XXX or ImGuiMod_XXX value): can represent Keyboard, Mouse and Gamepad values.
-- All our named keys are >= 512. Keys value 0 to 511 are left unused as legacy native/opaque key values (< 1.87).
-- Since >= 1.89 we increased typing (went from int to enum), some legacy code may need a cast to ImGuiKey.
-- Read details about the 1.87 and 1.89 transition : https://github.com/ocornut/imgui/issues/4921
-- Note that "Keys" related to physical keys and are not the same concept as input "Characters", the later are submitted via io.AddInputCharacter().
-- The keyboard key enum values are named after the keys on a standard US keyboard, and on other keyboard types the keys reported may not match the keycaps.
--
--
-- Forward declared enum type ImGuiKey
--
---@alias ImGui.Key
---| `ImGui.Key.None`
---| `ImGui.Key.Tab`                #  == ImGuiKey_NamedKey_BEGIN
---| `ImGui.Key.LeftArrow`
---| `ImGui.Key.RightArrow`
---| `ImGui.Key.UpArrow`
---| `ImGui.Key.DownArrow`
---| `ImGui.Key.PageUp`
---| `ImGui.Key.PageDown`
---| `ImGui.Key.Home`
---| `ImGui.Key.End`
---| `ImGui.Key.Insert`
---| `ImGui.Key.Delete`
---| `ImGui.Key.Backspace`
---| `ImGui.Key.Space`
---| `ImGui.Key.Enter`
---| `ImGui.Key.Escape`
---| `ImGui.Key.LeftCtrl`
---| `ImGui.Key.LeftShift`
---| `ImGui.Key.LeftAlt`
---| `ImGui.Key.LeftSuper`
---| `ImGui.Key.RightCtrl`
---| `ImGui.Key.RightShift`
---| `ImGui.Key.RightAlt`
---| `ImGui.Key.RightSuper`
---| `ImGui.Key.Menu`
---| `ImGui.Key[0]`
---| `ImGui.Key[1]`
---| `ImGui.Key[2]`
---| `ImGui.Key[3]`
---| `ImGui.Key[4]`
---| `ImGui.Key[5]`
---| `ImGui.Key[6]`
---| `ImGui.Key[7]`
---| `ImGui.Key[8]`
---| `ImGui.Key[9]`
---| `ImGui.Key.A`
---| `ImGui.Key.B`
---| `ImGui.Key.C`
---| `ImGui.Key.D`
---| `ImGui.Key.E`
---| `ImGui.Key.F`
---| `ImGui.Key.G`
---| `ImGui.Key.H`
---| `ImGui.Key.I`
---| `ImGui.Key.J`
---| `ImGui.Key.K`
---| `ImGui.Key.L`
---| `ImGui.Key.M`
---| `ImGui.Key.N`
---| `ImGui.Key.O`
---| `ImGui.Key.P`
---| `ImGui.Key.Q`
---| `ImGui.Key.R`
---| `ImGui.Key.S`
---| `ImGui.Key.T`
---| `ImGui.Key.U`
---| `ImGui.Key.V`
---| `ImGui.Key.W`
---| `ImGui.Key.X`
---| `ImGui.Key.Y`
---| `ImGui.Key.Z`
---| `ImGui.Key.F1`
---| `ImGui.Key.F2`
---| `ImGui.Key.F3`
---| `ImGui.Key.F4`
---| `ImGui.Key.F5`
---| `ImGui.Key.F6`
---| `ImGui.Key.F7`
---| `ImGui.Key.F8`
---| `ImGui.Key.F9`
---| `ImGui.Key.F10`
---| `ImGui.Key.F11`
---| `ImGui.Key.F12`
---| `ImGui.Key.F13`
---| `ImGui.Key.F14`
---| `ImGui.Key.F15`
---| `ImGui.Key.F16`
---| `ImGui.Key.F17`
---| `ImGui.Key.F18`
---| `ImGui.Key.F19`
---| `ImGui.Key.F20`
---| `ImGui.Key.F21`
---| `ImGui.Key.F22`
---| `ImGui.Key.F23`
---| `ImGui.Key.F24`
---| `ImGui.Key.Apostrophe`         #  '
---| `ImGui.Key.Comma`              #  ,
---| `ImGui.Key.Minus`              #  -
---| `ImGui.Key.Period`             #  .
---| `ImGui.Key.Slash`              #  /
---| `ImGui.Key.Semicolon`          #  ;
---| `ImGui.Key.Equal`              #  =
---| `ImGui.Key.LeftBracket`        #  [
---| `ImGui.Key.Backslash`          #  \ (this text inhibit multiline comment caused by backslash)
---| `ImGui.Key.RightBracket`       #  ]
---| `ImGui.Key.GraveAccent`        #  `
---| `ImGui.Key.CapsLock`
---| `ImGui.Key.ScrollLock`
---| `ImGui.Key.NumLock`
---| `ImGui.Key.PrintScreen`
---| `ImGui.Key.Pause`
---| `ImGui.Key.Keypad0`
---| `ImGui.Key.Keypad1`
---| `ImGui.Key.Keypad2`
---| `ImGui.Key.Keypad3`
---| `ImGui.Key.Keypad4`
---| `ImGui.Key.Keypad5`
---| `ImGui.Key.Keypad6`
---| `ImGui.Key.Keypad7`
---| `ImGui.Key.Keypad8`
---| `ImGui.Key.Keypad9`
---| `ImGui.Key.KeypadDecimal`
---| `ImGui.Key.KeypadDivide`
---| `ImGui.Key.KeypadMultiply`
---| `ImGui.Key.KeypadSubtract`
---| `ImGui.Key.KeypadAdd`
---| `ImGui.Key.KeypadEnter`
---| `ImGui.Key.KeypadEqual`
---| `ImGui.Key.AppBack`            #  Available on some keyboard/mouses. Often referred as "Browser Back"
---| `ImGui.Key.AppForward`
---| `ImGui.Key.GamepadStart`       #  Menu (Xbox)      + (Switch)   Start/Options (PS)
---| `ImGui.Key.GamepadBack`        #  View (Xbox)      - (Switch)   Share (PS)
---| `ImGui.Key.GamepadFaceLeft`    #  X (Xbox)         Y (Switch)   Square (PS)        // Tap: Toggle Menu. Hold: Windowing mode (Focus/Move/Resize windows)
---| `ImGui.Key.GamepadFaceRight`   #  B (Xbox)         A (Switch)   Circle (PS)        // Cancel / Close / Exit
---| `ImGui.Key.GamepadFaceUp`      #  Y (Xbox)         X (Switch)   Triangle (PS)      // Text Input / On-screen Keyboard
---| `ImGui.Key.GamepadFaceDown`    #  A (Xbox)         B (Switch)   Cross (PS)         // Activate / Open / Toggle / Tweak
---| `ImGui.Key.GamepadDpadLeft`    #  D-pad Left                                       // Move / Tweak / Resize Window (in Windowing mode)
---| `ImGui.Key.GamepadDpadRight`   #  D-pad Right                                      // Move / Tweak / Resize Window (in Windowing mode)
---| `ImGui.Key.GamepadDpadUp`      #  D-pad Up                                         // Move / Tweak / Resize Window (in Windowing mode)
---| `ImGui.Key.GamepadDpadDown`    #  D-pad Down                                       // Move / Tweak / Resize Window (in Windowing mode)
---| `ImGui.Key.GamepadL1`          #  L Bumper (Xbox)  L (Switch)   L1 (PS)            // Tweak Slower / Focus Previous (in Windowing mode)
---| `ImGui.Key.GamepadR1`          #  R Bumper (Xbox)  R (Switch)   R1 (PS)            // Tweak Faster / Focus Next (in Windowing mode)
---| `ImGui.Key.GamepadL2`          #  L Trig. (Xbox)   ZL (Switch)  L2 (PS) [Analog]
---| `ImGui.Key.GamepadR2`          #  R Trig. (Xbox)   ZR (Switch)  R2 (PS) [Analog]
---| `ImGui.Key.GamepadL3`          #  L Stick (Xbox)   L3 (Switch)  L3 (PS)
---| `ImGui.Key.GamepadR3`          #  R Stick (Xbox)   R3 (Switch)  R3 (PS)
---| `ImGui.Key.GamepadLStickLeft`  #  [Analog]                                         // Move Window (in Windowing mode)
---| `ImGui.Key.GamepadLStickRight` #  [Analog]                                         // Move Window (in Windowing mode)
---| `ImGui.Key.GamepadLStickUp`    #  [Analog]                                         // Move Window (in Windowing mode)
---| `ImGui.Key.GamepadLStickDown`  #  [Analog]                                         // Move Window (in Windowing mode)
---| `ImGui.Key.GamepadRStickLeft`  #  [Analog]
---| `ImGui.Key.GamepadRStickRight` #  [Analog]
---| `ImGui.Key.GamepadRStickUp`    #  [Analog]
---| `ImGui.Key.GamepadRStickDown`  #  [Analog]
---| `ImGui.Key.MouseLeft`
---| `ImGui.Key.MouseRight`
---| `ImGui.Key.MouseMiddle`
---| `ImGui.Key.MouseX1`
---| `ImGui.Key.MouseX2`
---| `ImGui.Key.MouseWheelX`
---| `ImGui.Key.MouseWheelY`
ImGui.Key = {}

---@alias ImGui.Mod
---| `ImGui.Mod.None`
---| `ImGui.Mod.Ctrl`  #  Ctrl (non-macOS), Cmd (macOS)
---| `ImGui.Mod.Shift` #  Shift
---| `ImGui.Mod.Alt`   #  Option/Menu
---| `ImGui.Mod.Super` #  Windows/Super (non-macOS), Ctrl (macOS)
ImGui.Mod = {}

--
-- Enumeration for PushStyleColor() / PopStyleColor()
--
---@alias ImGui.Col
---| `ImGui.Col.Text`
---| `ImGui.Col.TextDisabled`
---| `ImGui.Col.WindowBg`              #  Background of normal windows
---| `ImGui.Col.ChildBg`               #  Background of child windows
---| `ImGui.Col.PopupBg`               #  Background of popups, menus, tooltips windows
---| `ImGui.Col.Border`
---| `ImGui.Col.BorderShadow`
---| `ImGui.Col.FrameBg`               #  Background of checkbox, radio button, plot, slider, text input
---| `ImGui.Col.FrameBgHovered`
---| `ImGui.Col.FrameBgActive`
---| `ImGui.Col.TitleBg`               #  Title bar
---| `ImGui.Col.TitleBgActive`         #  Title bar when focused
---| `ImGui.Col.TitleBgCollapsed`      #  Title bar when collapsed
---| `ImGui.Col.MenuBarBg`
---| `ImGui.Col.ScrollbarBg`
---| `ImGui.Col.ScrollbarGrab`
---| `ImGui.Col.ScrollbarGrabHovered`
---| `ImGui.Col.ScrollbarGrabActive`
---| `ImGui.Col.CheckMark`             #  Checkbox tick and RadioButton circle
---| `ImGui.Col.SliderGrab`
---| `ImGui.Col.SliderGrabActive`
---| `ImGui.Col.Button`
---| `ImGui.Col.ButtonHovered`
---| `ImGui.Col.ButtonActive`
---| `ImGui.Col.Header`                #  Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem
---| `ImGui.Col.HeaderHovered`
---| `ImGui.Col.HeaderActive`
---| `ImGui.Col.Separator`
---| `ImGui.Col.SeparatorHovered`
---| `ImGui.Col.SeparatorActive`
---| `ImGui.Col.ResizeGrip`            #  Resize grip in lower-right and lower-left corners of windows.
---| `ImGui.Col.ResizeGripHovered`
---| `ImGui.Col.ResizeGripActive`
---| `ImGui.Col.Tab`                   #  TabItem in a TabBar
---| `ImGui.Col.TabHovered`
---| `ImGui.Col.TabActive`
---| `ImGui.Col.TabUnfocused`
---| `ImGui.Col.TabUnfocusedActive`
---| `ImGui.Col.DockingPreview`        #  Preview overlay color when about to docking something
---| `ImGui.Col.DockingEmptyBg`        #  Background color for empty node (e.g. CentralNode with no window docked into it)
---| `ImGui.Col.PlotLines`
---| `ImGui.Col.PlotLinesHovered`
---| `ImGui.Col.PlotHistogram`
---| `ImGui.Col.PlotHistogramHovered`
---| `ImGui.Col.TableHeaderBg`         #  Table header background
---| `ImGui.Col.TableBorderStrong`     #  Table outer and header borders (prefer using Alpha=1.0 here)
---| `ImGui.Col.TableBorderLight`      #  Table inner borders (prefer using Alpha=1.0 here)
---| `ImGui.Col.TableRowBg`            #  Table row background (even rows)
---| `ImGui.Col.TableRowBgAlt`         #  Table row background (odd rows)
---| `ImGui.Col.TextSelectedBg`
---| `ImGui.Col.DragDropTarget`        #  Rectangle highlighting a drop target
---| `ImGui.Col.NavHighlight`          #  Gamepad/keyboard: current highlighted item
---| `ImGui.Col.NavWindowingHighlight` #  Highlight window when using CTRL+TAB
---| `ImGui.Col.NavWindowingDimBg`     #  Darken/colorize entire screen behind the CTRL+TAB window list, when active
---| `ImGui.Col.ModalWindowDimBg`      #  Darken/colorize entire screen behind a modal window, when one is active
ImGui.Col = {}

--
-- Enumeration for PushStyleVar() / PopStyleVar() to temporarily modify the ImGuiStyle structure.
-- - The enum only refers to fields of ImGuiStyle which makes sense to be pushed/popped inside UI code.
--   During initialization or between frames, feel free to just poke into ImGuiStyle directly.
-- - Tip: Use your programming IDE navigation facilities on the names in the _second column_ below to find the actual members and their description.
--   - In Visual Studio: CTRL+comma ("Edit.GoToAll") can follow symbols inside comments, whereas CTRL+F12 ("Edit.GoToImplementation") cannot.
--   - In Visual Studio w/ Visual Assist installed: ALT+G ("VAssistX.GoToImplementation") can also follow symbols inside comments.
--   - In VS Code, CLion, etc.: CTRL+click can follow symbols inside comments.
-- - When changing this enum, you need to update the associated internal table GStyleVarInfo[] accordingly. This is where we link enum values to members offset/type.
--
---@alias ImGui.StyleVar
---| `ImGui.StyleVar.Alpha`                       #  float     Alpha
---| `ImGui.StyleVar.DisabledAlpha`               #  float     DisabledAlpha
---| `ImGui.StyleVar.WindowPadding`               #  ImVec2    WindowPadding
---| `ImGui.StyleVar.WindowRounding`              #  float     WindowRounding
---| `ImGui.StyleVar.WindowBorderSize`            #  float     WindowBorderSize
---| `ImGui.StyleVar.WindowMinSize`               #  ImVec2    WindowMinSize
---| `ImGui.StyleVar.WindowTitleAlign`            #  ImVec2    WindowTitleAlign
---| `ImGui.StyleVar.ChildRounding`               #  float     ChildRounding
---| `ImGui.StyleVar.ChildBorderSize`             #  float     ChildBorderSize
---| `ImGui.StyleVar.PopupRounding`               #  float     PopupRounding
---| `ImGui.StyleVar.PopupBorderSize`             #  float     PopupBorderSize
---| `ImGui.StyleVar.FramePadding`                #  ImVec2    FramePadding
---| `ImGui.StyleVar.FrameRounding`               #  float     FrameRounding
---| `ImGui.StyleVar.FrameBorderSize`             #  float     FrameBorderSize
---| `ImGui.StyleVar.ItemSpacing`                 #  ImVec2    ItemSpacing
---| `ImGui.StyleVar.ItemInnerSpacing`            #  ImVec2    ItemInnerSpacing
---| `ImGui.StyleVar.IndentSpacing`               #  float     IndentSpacing
---| `ImGui.StyleVar.CellPadding`                 #  ImVec2    CellPadding
---| `ImGui.StyleVar.ScrollbarSize`               #  float     ScrollbarSize
---| `ImGui.StyleVar.ScrollbarRounding`           #  float     ScrollbarRounding
---| `ImGui.StyleVar.GrabMinSize`                 #  float     GrabMinSize
---| `ImGui.StyleVar.GrabRounding`                #  float     GrabRounding
---| `ImGui.StyleVar.TabRounding`                 #  float     TabRounding
---| `ImGui.StyleVar.TabBorderSize`               #  float     TabBorderSize
---| `ImGui.StyleVar.TabBarBorderSize`            #  float     TabBarBorderSize
---| `ImGui.StyleVar.TableAngledHeadersAngle`     #  float     TableAngledHeadersAngle
---| `ImGui.StyleVar.TableAngledHeadersTextAlign` #  ImVec2  TableAngledHeadersTextAlign
---| `ImGui.StyleVar.ButtonTextAlign`             #  ImVec2    ButtonTextAlign
---| `ImGui.StyleVar.SelectableTextAlign`         #  ImVec2    SelectableTextAlign
---| `ImGui.StyleVar.SeparatorTextBorderSize`     #  float     SeparatorTextBorderSize
---| `ImGui.StyleVar.SeparatorTextAlign`          #  ImVec2    SeparatorTextAlign
---| `ImGui.StyleVar.SeparatorTextPadding`        #  ImVec2    SeparatorTextPadding
---| `ImGui.StyleVar.DockingSeparatorSize`        #  float     DockingSeparatorSize
ImGui.StyleVar = {}

--
-- Identify a mouse button.
-- Those values are guaranteed to be stable and we frequently use 0/1 directly. Named enums provided for convenience.
--
---@alias ImGui.MouseButton
---| `ImGui.MouseButton.Left`
---| `ImGui.MouseButton.Right`
---| `ImGui.MouseButton.Middle`
ImGui.MouseButton = {}

--
-- Enumeration for GetMouseCursor()
-- User code may request backend to display given cursor by calling SetMouseCursor(), which is why we have some cursors that are marked unused here
--
---@alias ImGui.MouseCursor
---| `ImGui.MouseCursor.None`
---| `ImGui.MouseCursor.Arrow`
---| `ImGui.MouseCursor.TextInput`  #  When hovering over InputText, etc.
---| `ImGui.MouseCursor.ResizeAll`  #  (Unused by Dear ImGui functions)
---| `ImGui.MouseCursor.ResizeNS`   #  When hovering over a horizontal border
---| `ImGui.MouseCursor.ResizeEW`   #  When hovering over a vertical border or a column
---| `ImGui.MouseCursor.ResizeNESW` #  When hovering over the bottom-left corner of a window
---| `ImGui.MouseCursor.ResizeNWSE` #  When hovering over the bottom-right corner of a window
---| `ImGui.MouseCursor.Hand`       #  (Unused by Dear ImGui functions. Use for e.g. hyperlinks)
---| `ImGui.MouseCursor.NotAllowed` #  When hovering something with disallowed interaction. Usually a crossed circle.
ImGui.MouseCursor = {}

--
-- Enumeration for AddMouseSourceEvent() actual source of Mouse Input data.
-- Historically we use "Mouse" terminology everywhere to indicate pointer data, e.g. MousePos, IsMousePressed(), io.AddMousePosEvent()
-- But that "Mouse" data can come from different source which occasionally may be useful for application to know about.
-- You can submit a change of pointer type using io.AddMouseSourceEvent().
--
--
-- Forward declared enum type ImGuiMouseSource
--
---@alias ImGui.MouseSource
---| `ImGui.MouseSource.Mouse`       #  Input is coming from an actual mouse.
---| `ImGui.MouseSource.TouchScreen` #  Input is coming from a touch screen (no hovering prior to initial press, less precise initial press aiming, dual-axis wheeling possible).
---| `ImGui.MouseSource.Pen`         #  Input is coming from a pressure/magnetic pen (often used in conjunction with high-sampling rates).
ImGui.MouseSource = {}

--
-- Enumeration for ImGui::SetNextWindow***(), SetWindow***(), SetNextItem***() functions
-- Represent a condition.
-- Important: Treat as a regular enum! Do NOT combine multiple values using binary operators! All the functions above treat 0 as a shortcut to ImGuiCond_Always.
--
---@alias ImGui.Cond
---| `ImGui.Cond.None`         #  No condition (always set the variable), same as _Always
---| `ImGui.Cond.Always`       #  No condition (always set the variable), same as _None
---| `ImGui.Cond.Once`         #  Set the variable once per runtime session (only the first call will succeed)
---| `ImGui.Cond.FirstUseEver` #  Set the variable if the object/window has no persistently saved data (no entry in .ini file)
---| `ImGui.Cond.Appearing`    #  Set the variable if the object/window is appearing after being hidden/inactive (or the first time)
ImGui.Cond = {}

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
---@alias ImGui.TableBgTarget
---| `ImGui.TableBgTarget.None`
---| `ImGui.TableBgTarget.RowBg0` #  Set row background color 0 (generally used for background, automatically set when ImGuiTableFlags_RowBg is used)
---| `ImGui.TableBgTarget.RowBg1` #  Set row background color 1 (generally used for selection marking)
---| `ImGui.TableBgTarget.CellBg` #  Set cell background color (top-most color)
ImGui.TableBgTarget = {}


---@alias ImGuiKeyChord ImGui.Key | ImGui.Mod

---@alias ImTextureID integer

---@class ImFont

---@class ImFontRange

---@class ImStringBuf
local ImStringBuf = {}

---@param str string
function ImStringBuf:Assgin(str) end

---@param size integer
function ImStringBuf:Resize(size) end

---@class ImVec2
---@field x number
---@field y number

---@class ImGuiID

---@class ImS8

---@class ImU8

---@class ImS16

---@class ImU16

---@class ImS32

---@class ImU32

---@class ImS64

---@class ImU64

---@class ImDrawIdx

---@class ImWchar32

---@class ImWchar16

---@alias ImWchar ImWchar32

---@class ImGuiContext

---@class ImGuiIO
---@field ConfigFlags ImGui.ConfigFlags            #  = 0              // See ImGuiConfigFlags_ enum. Set by user/application. Gamepad/keyboard navigation options, etc.
---@field BackendFlags ImGui.BackendFlags          #  = 0              // See ImGuiBackendFlags_ enum. Set by backend (imgui_impl_xxx files or custom backend) to communicate features supported by the backend.
---@field DisplaySize ImVec2                       #  <unset>          // Main display size, in pixels (generally == GetMainViewport()->Size). May change every frame.
---@field DeltaTime number                         #  = 1.0f/60.0f     // Time elapsed since last frame, in seconds. May change every frame.
---@field IniSavingRate number                     #  = 5.0f           // Minimum time between saving positions/sizes to .ini file, in seconds.
---@field UserData lightuserdata                   #  = NULL           // Store your own data.
---@field Fonts ImFontAtlas                        #  <auto>           // Font atlas: load, rasterize and pack one or more fonts into a single texture.
---@field FontGlobalScale number                   #  = 1.0f           // Global scale all fonts
---@field FontAllowUserScaling boolean             #  = false          // Allow user scaling text of individual window with CTRL+Wheel.
---@field DisplayFramebufferScale ImVec2           #  = (1, 1)         // For retina display or other situations where window coordinates are different from framebuffer coordinates. This generally ends up in ImDrawData::FramebufferScale.
---@field ConfigDockingNoSplit boolean             #  = false          // Simplified docking mode: disable window splitting, so docking is limited to merging multiple windows together into tab-bars.
---@field ConfigDockingWithShift boolean           #  = false          // Enable docking with holding Shift key (reduce visual noise, allows dropping in wider space)
---@field ConfigDockingAlwaysTabBar boolean        #  = false          // [BETA] [FIXME: This currently creates regression with auto-sizing and general overhead] Make every single floating window display within a docking node.
---@field ConfigDockingTransparentPayload boolean  #  = false          // [BETA] Make window or viewport transparent when docking and only display docking boxes on the target viewport. Useful if rendering of multiple viewport cannot be synced. Best used with ConfigViewportsNoAutoMerge.
---@field ConfigViewportsNoAutoMerge boolean       #  = false;         // Set to make all floating imgui windows always create their own viewport. Otherwise, they are merged into the main host viewports when overlapping it. May also set ImGuiViewportFlags_NoAutoMerge on individual viewport.
---@field ConfigViewportsNoTaskBarIcon boolean     #  = false          // Disable default OS task bar icon flag for secondary viewports. When a viewport doesn't want a task bar icon, ImGuiViewportFlags_NoTaskBarIcon will be set on it.
---@field ConfigViewportsNoDecoration boolean      #  = true           // Disable default OS window decoration flag for secondary viewports. When a viewport doesn't want window decorations, ImGuiViewportFlags_NoDecoration will be set on it. Enabling decoration can create subsequent issues at OS levels (e.g. minimum window size).
---@field ConfigViewportsNoDefaultParent boolean   #  = false          // Disable default OS parenting to main viewport for secondary viewports. By default, viewports are marked with ParentViewportId = <main_viewport>, expecting the platform backend to setup a parent/child relationship between the OS windows (some backend may ignore this). Set to true if you want the default to be 0, then all viewports will be top-level OS windows.
---@field MouseDrawCursor boolean                  #  = false          // Request ImGui to draw a mouse cursor for you (if you are on a platform without a mouse cursor). Cannot be easily renamed to 'io.ConfigXXX' because this is frequently used by backend implementations.
---@field ConfigMacOSXBehaviors boolean            #  = defined(__APPLE__) // Swap Cmd<>Ctrl keys + OS X style text editing cursor movement using Alt instead of Ctrl, Shortcuts using Cmd/Super instead of Ctrl, Line/Text Start and End using Cmd+Arrows instead of Home/End, Double click selects by word instead of selecting whole text, Multi-selection in lists uses Cmd/Super instead of Ctrl.
---@field ConfigInputTrickleEventQueue boolean     #  = true           // Enable input queue trickling: some types of events submitted during the same frame (e.g. button down + up) will be spread over multiple frames, improving interactions with low framerates.
---@field ConfigInputTextCursorBlink boolean       #  = true           // Enable blinking cursor (optional as some users consider it to be distracting).
---@field ConfigInputTextEnterKeepActive boolean   #  = false          // [BETA] Pressing Enter will keep item active and select contents (single-line only).
---@field ConfigDragClickToInputText boolean       #  = false          // [BETA] Enable turning DragXXX widgets into text input with a simple mouse click-release (without moving). Not desirable on devices without a keyboard.
---@field ConfigWindowsResizeFromEdges boolean     #  = true           // Enable resizing of windows from their edges and from the lower-left corner. This requires (io.BackendFlags & ImGuiBackendFlags_HasMouseCursors) because it needs mouse cursor feedback. (This used to be a per-window ImGuiWindowFlags_ResizeFromAnySide flag)
---@field ConfigWindowsMoveFromTitleBarOnly boolean#  = false       // Enable allowing to move windows only when clicking on their title bar. Does not apply to windows without a title bar.
---@field ConfigMemoryCompactTimer number          #  = 60.0f          // Timer (in seconds) to free transient windows/tables memory buffers when unused. Set to -1.0f to disable.
---@field MouseDoubleClickTime number              #  = 0.30f          // Time for a double-click, in seconds.
---@field MouseDoubleClickMaxDist number           #  = 6.0f           // Distance threshold to stay in to validate a double-click, in pixels.
---@field MouseDragThreshold number                #  = 6.0f           // Distance threshold before considering we are dragging.
---@field KeyRepeatDelay number                    #  = 0.275f         // When holding a key/button, time before it starts repeating, in seconds (for buttons in Repeat mode, etc.).
---@field KeyRepeatRate number                     #  = 0.050f         // When holding a key/button, rate at which it repeats, in seconds.
---@field ConfigDebugIsDebuggerPresent boolean     #  = false          // Enable various tools calling IM_DEBUG_BREAK().
---@field ConfigDebugBeginReturnValueOnce boolean  #  = false          // First-time calls to Begin()/BeginChild() will return false. NEEDS TO BE SET AT APPLICATION BOOT TIME if you don't want to miss windows.
---@field ConfigDebugBeginReturnValueLoop boolean  #  = false          // Some calls to Begin()/BeginChild() will return false. Will cycle through window depths then repeat. Suggested use: add "io.ConfigDebugBeginReturnValue = io.KeyShift" in your main loop then occasionally press SHIFT. Windows should be flickering while running.
---@field ConfigDebugIgnoreFocusLoss boolean       #  = false          // Ignore io.AddFocusEvent(false), consequently not calling io.ClearInputKeys() in input processing.
---@field ConfigDebugIniSettings boolean           #  = false          // Save .ini data with extra comments (particularly helpful for Docking, but makes saving slower)
---@field BackendPlatformUserData lightuserdata    #  = NULL           // User data for platform backend
---@field BackendRendererUserData lightuserdata    #  = NULL           // User data for renderer backend
---@field BackendLanguageUserData lightuserdata    #  = NULL           // User data for non C++ programming language backend
---@field ClipboardUserData lightuserdata
---@field PlatformLocaleDecimalPoint ImWchar       #  '.'              // [Experimental] Configure decimal point e.g. '.' or ',' useful for some languages (e.g. German), generally pulled from *localeconv()->decimal_point
---@field WantCaptureMouse boolean                 #  Set when Dear ImGui will use mouse inputs, in this case do not dispatch them to your main game/application (either way, always pass on mouse inputs to imgui). (e.g. unclicked mouse is hovering over an imgui window, widget is active, mouse was clicked over an imgui window, etc.).
---@field WantCaptureKeyboard boolean              #  Set when Dear ImGui will use keyboard inputs, in this case do not dispatch them to your main game/application (either way, always pass keyboard inputs to imgui). (e.g. InputText active, or an imgui window is focused and navigation is enabled, etc.).
---@field WantTextInput boolean                    #  Mobile/console: when set, you may display an on-screen keyboard. This is set by Dear ImGui when it wants textual keyboard input to happen (e.g. when a InputText widget is active).
---@field WantSetMousePos boolean                  #  MousePos has been altered, backend should reposition mouse on next frame. Rarely used! Set only when ImGuiConfigFlags_NavEnableSetMousePos flag is enabled.
---@field WantSaveIniSettings boolean              #  When manual .ini load/save is active (io.IniFilename == NULL), this will be set to notify your application that you can call SaveIniSettingsToMemory() and save yourself. Important: clear io.WantSaveIniSettings yourself after saving!
---@field NavActive boolean                        #  Keyboard/Gamepad navigation is currently allowed (will handle ImGuiKey_NavXXX events) = a window is focused and it doesn't use the ImGuiWindowFlags_NoNavInputs flag.
---@field NavVisible boolean                       #  Keyboard/Gamepad navigation is visible and allowed (will handle ImGuiKey_NavXXX events).
---@field Framerate number                         #  Estimate of application framerate (rolling average over 60 frames, based on io.DeltaTime), in frame per second. Solely for convenience. Slow applications may not want to use a moving average or may want to reset underlying buffers occasionally.
---@field MetricsRenderVertices integer            #  Vertices output during last call to Render()
---@field MetricsRenderIndices integer             #  Indices output during last call to Render() = number of triangles * 3
---@field MetricsRenderWindows integer             #  Number of visible windows
---@field MetricsActiveWindows integer             #  Number of active windows
---@field MouseDelta ImVec2                        #  Mouse delta. Note that this is zero if either current or previous position are invalid (-FLT_MAX,-FLT_MAX), so a disappearing/reappearing mouse won't have a huge delta.
---@field Ctx ImGuiContext                         #  Parent UI context (needs to be set explicitly by parent).
---@field MousePos ImVec2                          #  Mouse position, in pixels. Set to ImVec2(-FLT_MAX, -FLT_MAX) if mouse is unavailable (on another screen, etc.)
---@field MouseWheel number                        #  Mouse wheel Vertical: 1 unit scrolls about 5 lines text. >0 scrolls Up, <0 scrolls Down. Hold SHIFT to turn vertical scroll into horizontal scroll.
---@field MouseWheelH number                       #  Mouse wheel Horizontal. >0 scrolls Left, <0 scrolls Right. Most users don't have a mouse with a horizontal wheel, may not be filled by all backends.
---@field MouseSource ImGui.MouseSource            #  Mouse actual input peripheral (Mouse/TouchScreen/Pen).
---@field MouseHoveredViewport ImGuiID             #  (Optional) Modify using io.AddMouseViewportEvent(). With multi-viewports: viewport the OS mouse is hovering. If possible _IGNORING_ viewports with the ImGuiViewportFlags_NoInputs flag is much better (few backends can handle that). Set io.BackendFlags |= ImGuiBackendFlags_HasMouseHoveredViewport if you can provide this info. If you don't imgui will infer the value using the rectangles and last focused time of the viewports it knows about (ignoring other OS windows).
---@field KeyCtrl boolean                          #  Keyboard modifier down: Control
---@field KeyShift boolean                         #  Keyboard modifier down: Shift
---@field KeyAlt boolean                           #  Keyboard modifier down: Alt
---@field KeySuper boolean                         #  Keyboard modifier down: Cmd/Super/Windows
---@field KeyMods ImGuiKeyChord                    #  Key mods flags (any of ImGuiMod_Ctrl/ImGuiMod_Shift/ImGuiMod_Alt/ImGuiMod_Super flags, same as io.KeyCtrl/KeyShift/KeyAlt/KeySuper but merged into flags. Read-only, updated by NewFrame()
---@field WantCaptureMouseUnlessPopupClose boolean #  Alternative to WantCaptureMouse: (WantCaptureMouse == true && WantCaptureMouseUnlessPopupClose == false) when a click over void is expected to close a popup.
---@field MousePosPrev ImVec2                      #  Previous mouse position (note that MouseDelta is not necessary == MousePos-MousePosPrev, in case either position is invalid)
---@field MouseWheelRequestAxisSwap boolean        #  On a non-Mac system, holding SHIFT requests WheelY to perform the equivalent of a WheelX event. On a Mac system this is already enforced by the system.
---@field MouseCtrlLeftAsRightClick boolean        #  (OSX) Set to true when the current click was a ctrl-click that spawned a simulated right click
---@field PenPressure number                       #  Touch/Pen pressure (0.0f to 1.0f, should be >0.0f only when MouseDown[0] == true). Helper storage currently unused by Dear ImGui.
---@field AppFocusLost boolean                     #  Only modify via AddFocusEvent()
---@field AppAcceptingEvents boolean               #  Only modify via SetAppAcceptingEvents()
---@field BackendUsingLegacyKeyArrays ImS8         #  -1: unknown, 0: using AddKeyEvent(), 1: using legacy io.KeysDown[]
---@field BackendUsingLegacyNavInputArray boolean  #  0: using AddKeyAnalogEvent(), 1: writing to legacy io.NavInputs[] directly
---@field InputQueueSurrogate ImWchar16            #  For AddInputCharacterUTF16()
local ImGuiIO = {}
--
-- Input Functions
--
--
-- Queue a new key down/up event. Key should be "translated" (as in, generally ImGuiKey_A matches the key end-user would use to emit an 'A' character)
--
---@param key ImGui.Key
---@param down boolean
function ImGuiIO.AddKeyEvent(key, down) end

--
-- Queue a new key down/up event for analog values (e.g. ImGuiKey_Gamepad_ values). Dead-zones should be handled by the backend.
--
---@param key ImGui.Key
---@param down boolean
---@param v number
function ImGuiIO.AddKeyAnalogEvent(key, down, v) end

--
-- Queue a mouse position update. Use -FLT_MAX,-FLT_MAX to signify no mouse (e.g. app not focused and not hovered)
--
---@param x number
---@param y number
function ImGuiIO.AddMousePosEvent(x, y) end

--
-- Queue a mouse button change
--
---@param button integer
---@param down boolean
function ImGuiIO.AddMouseButtonEvent(button, down) end

--
-- Queue a mouse wheel update. wheel_y<0: scroll down, wheel_y>0: scroll up, wheel_x<0: scroll right, wheel_x>0: scroll left.
--
---@param wheel_x number
---@param wheel_y number
function ImGuiIO.AddMouseWheelEvent(wheel_x, wheel_y) end

--
-- Queue a mouse source change (Mouse/TouchScreen/Pen)
--
---@param source ImGui.MouseSource
function ImGuiIO.AddMouseSourceEvent(source) end

--
-- Queue a mouse hovered viewport. Requires backend to set ImGuiBackendFlags_HasMouseHoveredViewport to call this (for multi-viewport support).
--
---@param id ImGuiID
function ImGuiIO.AddMouseViewportEvent(id) end

--
-- Queue a gain/loss of focus for the application (generally based on OS/platform focus of your window)
--
---@param focused boolean
function ImGuiIO.AddFocusEvent(focused) end

--
-- Queue a new character input
--
---@param c integer
function ImGuiIO.AddInputCharacter(c) end

--
-- Queue a new character input from a UTF-16 character, it can be a surrogate
--
---@param c ImWchar16
function ImGuiIO.AddInputCharacterUTF16(c) end

--
-- Queue a new characters input from a UTF-8 string
--
---@param str string
function ImGuiIO.AddInputCharactersUTF8(str) end

--
-- Implied native_legacy_index = -1
--
---@param key ImGui.Key
---@param native_keycode integer
---@param native_scancode integer
function ImGuiIO.SetKeyEventNativeData(key, native_keycode, native_scancode) end

--
-- [Optional] Specify index for legacy <1.87 IsKeyXXX() functions with native indices + specify native keycode, scancode.
--
---@param key ImGui.Key
---@param native_keycode integer
---@param native_scancode integer
---@param native_legacy_index? integer | `-1`
function ImGuiIO.SetKeyEventNativeDataEx(key, native_keycode, native_scancode, native_legacy_index) end

--
-- Set master flag for accepting key/mouse/text events (default to true). Useful if you have native dialog boxes that are interrupting your application loop/refresh, and you want to disable events being queued while your app is frozen.
--
---@param accepting_events boolean
function ImGuiIO.SetAppAcceptingEvents(accepting_events) end

--
-- Clear all incoming events.
--
function ImGuiIO.ClearEventsQueue() end

--
-- Clear current keyboard/mouse/gamepad state + current frame text input buffer. Equivalent to releasing all keys/buttons.
--
function ImGuiIO.ClearInputKeys() end


---@class ImGuiInputTextCallbackData
---@field Ctx ImGuiContext              #  Parent UI context
---@field EventFlag ImGui.InputTextFlags#  One ImGuiInputTextFlags_Callback*    // Read-only
---@field Flags ImGui.InputTextFlags    #  What user passed to InputText()      // Read-only
---@field UserData lightuserdata        #  What user passed to InputText()      // Read-only
---@field EventChar ImWchar             #  Character input                      // Read-write   // [CharFilter] Replace character with another one, or set to zero to drop. return 1 is equivalent to setting EventChar=0;
---@field EventKey ImGui.Key            #  Key pressed (Up/Down/TAB)            // Read-only    // [Completion,History]
---@field BufTextLen integer            #  Text length (in bytes)               // Read-write   // [Resize,Completion,History,Always] Exclude zero-terminator storage. In C land: == strlen(some_text), in C++ land: string.length()
---@field BufSize integer               #  Buffer size (in bytes) = capacity+1  // Read-only    // [Resize,Completion,History,Always] Include zero-terminator storage. In C land == ARRAYSIZE(my_char_array), in C++ land: string.capacity()+1
---@field BufDirty boolean              #  Set if you modify Buf/BufTextLen!    // Write        // [Completion,History,Always]
---@field CursorPos integer             #                                       // Read-write   // [Completion,History,Always]
---@field SelectionStart integer        #                                       // Read-write   // [Completion,History,Always] == to SelectionEnd when no selection)
---@field SelectionEnd integer          #                                       // Read-write   // [Completion,History,Always]
local ImGuiInputTextCallbackData = {}
---@param pos integer
---@param bytes_count integer
function ImGuiInputTextCallbackData.DeleteChars(pos, bytes_count) end

---@param pos integer
---@param text string
---@param text_end? string
function ImGuiInputTextCallbackData.InsertChars(pos, text, text_end) end

function ImGuiInputTextCallbackData.SelectAll() end

function ImGuiInputTextCallbackData.ClearSelection() end

---@return boolean
function ImGuiInputTextCallbackData.HasSelection() end


---@class ImGuiWindowClass
---@field ClassId ImGuiID                               #  User data. 0 = Default class (unclassed). Windows of different classes cannot be docked with each others.
---@field ParentViewportId ImGuiID                      #  Hint for the platform backend. -1: use default. 0: request platform backend to not parent the platform. != 0: request platform backend to create a parent<>child relationship between the platform windows. Not conforming backends are free to e.g. parent every viewport to the main viewport or not.
---@field FocusRouteParentWindowId ImGuiID              #  ID of parent window for shortcut focus route evaluation, e.g. Shortcut() call from Parent Window will succeed when this window is focused.
---@field ViewportFlagsOverrideSet ImGui.ViewportFlags  #  Viewport flags to set when a window of this class owns a viewport. This allows you to enforce OS decoration or task bar icon, override the defaults on a per-window basis.
---@field ViewportFlagsOverrideClear ImGui.ViewportFlags#  Viewport flags to clear when a window of this class owns a viewport. This allows you to enforce OS decoration or task bar icon, override the defaults on a per-window basis.
---@field TabItemFlagsOverrideSet ImGui.TabItemFlags    #  [EXPERIMENTAL] TabItem flags to set when a window of this class gets submitted into a dock node tab bar. May use with ImGuiTabItemFlags_Leading or ImGuiTabItemFlags_Trailing.
---@field DockNodeFlagsOverrideSet ImGui.DockNodeFlags  #  [EXPERIMENTAL] Dock node flags to set when a window of this class is hosted by a dock node (it doesn't have to be selected!)
---@field DockingAlwaysTabBar boolean                   #  Set to true to enforce single floating windows of this class always having their own docking node (equivalent of setting the global io.ConfigDockingAlwaysTabBar)
---@field DockingAllowUnclassed boolean                 #  Set to true to allow windows of this class to be docked/merged with an unclassed window. // FIXME-DOCK: Move to DockNodeFlags override?

---@class ImFontConfig
---@field FontData lightuserdata      #           // TTF/OTF data
---@field FontDataSize integer        #           // TTF/OTF data size
---@field FontDataOwnedByAtlas boolean#  true     // TTF/OTF data ownership taken by the container ImFontAtlas (will delete memory itself).
---@field FontNo integer              #  0        // Index of font within TTF/OTF file
---@field SizePixels number           #           // Size in pixels for rasterizer (more or less maps to the resulting font height).
---@field OversampleH integer         #  2        // Rasterize at higher quality for sub-pixel positioning. Note the difference between 2 and 3 is minimal. You can reduce this to 1 for large glyphs save memory. Read https://github.com/nothings/stb/blob/master/tests/oversample/README.md for details.
---@field OversampleV integer         #  1        // Rasterize at higher quality for sub-pixel positioning. This is not really useful as we don't use sub-pixel positions on the Y axis.
---@field PixelSnapH boolean          #  false    // Align every glyph to pixel boundary. Useful e.g. if you are merging a non-pixel aligned font with the default font. If enabled, you can set OversampleH/V to 1.
---@field GlyphExtraSpacing ImVec2    #  0, 0     // Extra spacing (in pixels) between glyphs. Only X axis is supported for now.
---@field GlyphOffset ImVec2          #  0, 0     // Offset all glyphs from this font input.
---@field GlyphRanges ImFontRange     #  NULL     // THE ARRAY DATA NEEDS TO PERSIST AS LONG AS THE FONT IS ALIVE. Pointer to a user-provided list of Unicode range (2 value per range, values are inclusive, zero-terminated list).
---@field GlyphMinAdvanceX number     #  0        // Minimum AdvanceX for glyphs, set Min to align font icons, set both Min/Max to enforce mono-space font
---@field GlyphMaxAdvanceX number     #  FLT_MAX  // Maximum AdvanceX for glyphs
---@field MergeMode boolean           #  false    // Merge into previous ImFont, so you can combine multiple inputs font into one ImFont (e.g. ASCII font + icons + Japanese glyphs). You may want to use GlyphOffset.y when merge font of different heights.
---@field FontBuilderFlags integer    #  0        // Settings for custom font builder. THIS IS BUILDER IMPLEMENTATION DEPENDENT. Leave as zero if unsure.
---@field RasterizerMultiply number   #  1.0f     // Linearly brighten (>1.0f) or darken (<1.0f) font output. Brightening small fonts may be a good workaround to make them more readable. This is a silly thing we may remove in the future.
---@field RasterizerDensity number    #  1.0f     // DPI scale for rasterization, not altering other font metrics: make it easy to swap between e.g. a 100% and a 400% fonts for a zooming display. IMPORTANT: If you increase this it is expected that you increase font scale accordingly, otherwise quality may look lowered.
---@field EllipsisChar ImWchar        #  -1       // Explicitly specify unicode codepoint of ellipsis character. When fonts are being merged first specified ellipsis will be used.

---@class ImFontAtlas
---@field Flags ImGui.FontAtlasFlags#  Build flags (see ImFontAtlasFlags_)
---@field TexID ImTextureID         #  User data to refer to the texture once it has been uploaded to user's graphic systems. It is passed back to you during rendering via the ImDrawCmd structure.
---@field TexDesiredWidth integer   #  Texture width desired by user before Build(). Must be a power-of-two. If have many glyphs your graphics API have texture size restrictions you may want to increase texture width to decrease height.
---@field TexGlyphPadding integer   #  Padding between glyphs within texture in pixels. Defaults to 1. If your rendering method doesn't rely on bilinear filtering you may set this to 0 (will also need to set AntiAliasedLinesUseTex = false).
---@field Locked boolean            #  Marked as Locked by ImGui::NewFrame() so attempt to modify the atlas will assert.
---@field UserData lightuserdata    #  Store your own atlas related user-data (if e.g. you have multiple font atlas).
local ImFontAtlas = {}
---@param font_cfg ImFontConfig
---@return ImFont
function ImFontAtlas.AddFont(font_cfg) end

---@param font_cfg? ImFontConfig
---@return ImFont
function ImFontAtlas.AddFontDefault(font_cfg) end

---@param filename string
---@param size_pixels number
---@param font_cfg? ImFontConfig
---@param glyph_ranges? ImFontRange
---@return ImFont
function ImFontAtlas.AddFontFromFileTTF(filename, size_pixels, font_cfg, glyph_ranges) end

--
-- Note: Transfer ownership of 'ttf_data' to ImFontAtlas! Will be deleted after destruction of the atlas. Set font_cfg->FontDataOwnedByAtlas=false to keep ownership of your data and it won't be freed.
--
---@param font_data lightuserdata
---@param font_data_size integer
---@param size_pixels number
---@param font_cfg? ImFontConfig
---@param glyph_ranges? ImFontRange
---@return ImFont
function ImFontAtlas.AddFontFromMemoryTTF(font_data, font_data_size, size_pixels, font_cfg, glyph_ranges) end

--
-- 'compressed_font_data' still owned by caller. Compress with binary_to_compressed_c.cpp.
--
---@param compressed_font_data lightuserdata
---@param compressed_font_data_size integer
---@param size_pixels number
---@param font_cfg? ImFontConfig
---@param glyph_ranges? ImFontRange
---@return ImFont
function ImFontAtlas.AddFontFromMemoryCompressedTTF(compressed_font_data, compressed_font_data_size, size_pixels, font_cfg, glyph_ranges) end

--
-- 'compressed_font_data_base85' still owned by caller. Compress with binary_to_compressed_c.cpp with -base85 parameter.
--
---@param compressed_font_data_base85 string
---@param size_pixels number
---@param font_cfg? ImFontConfig
---@param glyph_ranges? ImFontRange
---@return ImFont
function ImFontAtlas.AddFontFromMemoryCompressedBase85TTF(compressed_font_data_base85, size_pixels, font_cfg, glyph_ranges) end

--
-- Clear input data (all ImFontConfig structures including sizes, TTF data, glyph ranges, etc.) = all the data used to build the texture and fonts.
--
function ImFontAtlas.ClearInputData() end

--
-- Clear output texture data (CPU side). Saves RAM once the texture has been copied to graphics memory.
--
function ImFontAtlas.ClearTexData() end

--
-- Clear output font data (glyphs storage, UV coordinates).
--
function ImFontAtlas.ClearFonts() end

--
-- Clear all input and output.
--
function ImFontAtlas.Clear() end

--
-- Build atlas, retrieve pixel data.
-- User is in charge of copying the pixels into graphics memory (e.g. create a texture with your engine). Then store your texture handle with SetTexID().
-- The pitch is always = Width * BytesPerPixels (1 or 4)
-- Building in RGBA32 format is provided for convenience and compatibility, but note that unless you manually manipulate or copy color data into
-- the texture (e.g. when using the AddCustomRect*** api), then the RGB pixels emitted will always be white (~75% of memory/bandwidth waste.
--
--
-- Build pixels data. This is called automatically for you by the GetTexData*** functions.
--
---@return boolean
function ImFontAtlas.Build() end

--
-- Bit ambiguous: used to detect when user didn't build texture but effectively we should check TexID != 0 except that would be backend dependent...
--
---@return boolean
function ImFontAtlas.IsBuilt() end

---@param id ImTextureID
function ImFontAtlas.SetTexID(id) end

--
-- Helpers to retrieve list of common Unicode ranges (2 value per range, values are inclusive, zero-terminated list)
-- NB: Make sure that your string are UTF-8 and NOT in your local code page.
-- Read https://github.com/ocornut/imgui/blob/master/docs/FONTS.md/#about-utf-8-encoding for details.
-- NB: Consider using ImFontGlyphRangesBuilder to build glyph ranges from textual data.
--
--
-- Basic Latin, Extended Latin
--
---@return ImFontRange
function ImFontAtlas.GetGlyphRangesDefault() end

--
-- Default + Greek and Coptic
--
---@return ImFontRange
function ImFontAtlas.GetGlyphRangesGreek() end

--
-- Default + Korean characters
--
---@return ImFontRange
function ImFontAtlas.GetGlyphRangesKorean() end

--
-- Default + Hiragana, Katakana, Half-Width, Selection of 2999 Ideographs
--
---@return ImFontRange
function ImFontAtlas.GetGlyphRangesJapanese() end

--
-- Default + Half-Width + Japanese Hiragana/Katakana + full set of about 21000 CJK Unified Ideographs
--
---@return ImFontRange
function ImFontAtlas.GetGlyphRangesChineseFull() end

--
-- Default + Half-Width + Japanese Hiragana/Katakana + set of 2500 CJK Unified Ideographs for common simplified Chinese
--
---@return ImFontRange
function ImFontAtlas.GetGlyphRangesChineseSimplifiedCommon() end

--
-- Default + about 400 Cyrillic characters
--
---@return ImFontRange
function ImFontAtlas.GetGlyphRangesCyrillic() end

--
-- Default + Thai characters
--
---@return ImFontRange
function ImFontAtlas.GetGlyphRangesThai() end

--
-- Default + Vietnamese characters
--
---@return ImFontRange
function ImFontAtlas.GetGlyphRangesVietnamese() end

--
-- You can request arbitrary rectangles to be packed into the atlas, for your own purposes.
-- - After calling Build(), you can query the rectangle position and render your pixels.
-- - If you render colored output, set 'atlas->TexPixelsUseColors = true' as this may help some backends decide of preferred texture format.
-- - You can also request your rectangles to be mapped as font glyph (given a font + Unicode point),
--   so you can render e.g. custom colorful icons and use them as regular glyphs.
-- - Read docs/FONTS.md for more details about using colorful icons.
-- - Note: this API may be redesigned later in order to support multi-monitor varying DPI settings.
--
---@param width integer
---@param height integer
---@return integer
function ImFontAtlas.AddCustomRectRegular(width, height) end

---@param font ImFont
---@param id ImWchar
---@param width integer
---@param height integer
---@param advance_x number
---@param offset_x? number | `0`
---@param offset_y? number | `0`
---@return integer
function ImFontAtlas.AddCustomRectFontGlyph(font, id, width, height, advance_x, offset_x, offset_y) end


---@class ImGuiViewport
---@field ID ImGuiID                     #  Unique identifier for the viewport
---@field Flags ImGui.ViewportFlags      #  See ImGuiViewportFlags_
---@field Pos ImVec2                     #  Main Area: Position of the viewport (Dear ImGui coordinates are the same as OS desktop/native coordinates)
---@field Size ImVec2                    #  Main Area: Size of the viewport.
---@field WorkPos ImVec2                 #  Work Area: Position of the viewport minus task bars, menus bars, status bars (>= Pos)
---@field WorkSize ImVec2                #  Work Area: Size of the viewport minus task bars, menu bars, status bars (<= Size)
---@field DpiScale number                #  1.0f = 96 DPI = No extra scale.
---@field ParentViewportId ImGuiID       #  (Advanced) 0: no parent. Instruct the platform backend to setup a parent/child relationship between platform windows.
---@field RendererUserData lightuserdata #  void* to hold custom data structure for the renderer (e.g. swap chain, framebuffers etc.). generally set by your Renderer_CreateWindow function.
---@field PlatformUserData lightuserdata #  void* to hold custom data structure for the OS / platform (e.g. windowing info, render context). generally set by your Platform_CreateWindow function.
---@field PlatformHandle lightuserdata   #  void* for FindViewportByPlatformHandle(). (e.g. suggested to use natural platform handle such as HWND, GLFWWindow*, SDL_Window*)
---@field PlatformHandleRaw lightuserdata#  void* to hold lower-level, platform-native window handle (under Win32 this is expected to be a HWND, unused for other platforms), when using an abstraction layer like GLFW or SDL (where PlatformHandle would be a SDL_Window*)
---@field PlatformWindowCreated boolean  #  Platform window has been created (Platform_CreateWindow() has been called). This is false during the first frame where a viewport is being created.
---@field PlatformRequestMove boolean    #  Platform window requested move (e.g. window was moved by the OS / host window manager, authoritative position will be OS window position)
---@field PlatformRequestResize boolean  #  Platform window requested resize (e.g. window was resized by the OS / host window manager, authoritative size will be OS window size)
---@field PlatformRequestClose boolean   #  Platform window requested closure (e.g. window was moved by the OS / host window manager, e.g. pressing ALT-F4)
local ImGuiViewport = {}
--
-- Helpers
--
---@return number
---@return number
function ImGuiViewport.GetCenter() end

---@return number
---@return number
function ImGuiViewport.GetWorkCenter() end


---@return userdata
---@return ImGuiIO
function ImGui.IO() end

---@return userdata
---@return ImGuiInputTextCallbackData
function ImGui.InputTextCallbackData() end

---@return userdata
---@return ImGuiWindowClass
function ImGui.WindowClass() end

---@return userdata
---@return ImFontConfig
function ImGui.FontConfig() end

---@return userdata
---@return ImFontAtlas
function ImGui.FontAtlas() end

---@return userdata
---@return ImGuiViewport
function ImGui.Viewport() end

---@param str? string
---@return ImStringBuf
function ImGui.StringBuf(str) end

--
-- Context creation and access
-- - Each context create its own ImFontAtlas by default. You may instance one yourself and pass it to CreateContext() to share a font atlas between contexts.
-- - DLL users: heaps and globals are not shared across DLL boundaries! You will need to call SetCurrentContext() + SetAllocatorFunctions()
--   for each static/DLL boundary you are calling from. Read "Context and Memory Allocators" section of imgui.cpp for details.
--
---@param shared_font_atlas? ImFontAtlas
---@return ImGuiContext?
function ImGui.CreateContext(shared_font_atlas) end

--
-- NULL = destroy current context
--
---@param ctx? ImGuiContext
function ImGui.DestroyContext(ctx) end

---@return ImGuiContext?
function ImGui.GetCurrentContext() end

---@param ctx ImGuiContext
function ImGui.SetCurrentContext(ctx) end

--
-- Main
--
--
-- access the IO structure (mouse/keyboard/gamepad inputs, time, various configuration options/flags)
--
---@return ImGuiIO
function ImGui.GetIO() end

--
-- start a new Dear ImGui frame, you can submit any command from this point until Render()/EndFrame().
--
function ImGui.NewFrame() end

--
-- ends the Dear ImGui frame. automatically called by Render(). If you don't need to render data (skipping rendering) you may call EndFrame() without Render()... but you'll have wasted CPU already! If you don't need to render, better to not create any windows and not call NewFrame() at all!
--
function ImGui.EndFrame() end

--
-- ends the Dear ImGui frame, finalize the draw data. You can then get call GetDrawData().
--
function ImGui.Render() end

--
-- get the compiled version string e.g. "1.80 WIP" (essentially the value for IMGUI_VERSION from the compiled version of imgui.cpp)
--
---@return string
function ImGui.GetVersion() end

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
---@param flags? ImGui.WindowFlags | `ImGui.WindowFlags { "None" }`
---@return boolean
---@return boolean | nil p_open
function ImGui.Begin(name, p_open, flags) end

function ImGui.End() end

--
-- Child Windows
-- - Use child windows to begin into a self-contained independent scrolling/clipping regions within a host window. Child windows can embed their own child.
-- - Before 1.90 (November 2023), the "ImGuiChildFlags child_flags = 0" parameter was "bool border = false".
--   This API is backward compatible with old code, as we guarantee that ImGuiChildFlags_Border == true.
--   Consider updating your old code:
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
---@param child_flags? ImGui.ChildFlags | `ImGui.ChildFlags { "None" }`
---@param window_flags? ImGui.WindowFlags | `ImGui.WindowFlags { "None" }`
---@return boolean
function ImGui.BeginChild(str_id, size_x, size_y, child_flags, window_flags) end

---@param id ImGuiID
---@param size_x? number | `0`
---@param size_y? number | `0`
---@param child_flags? ImGui.ChildFlags | `ImGui.ChildFlags { "None" }`
---@param window_flags? ImGui.WindowFlags | `ImGui.WindowFlags { "None" }`
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
---@param flags? ImGui.FocusedFlags | `ImGui.FocusedFlags { "None" }`
---@return boolean
function ImGui.IsWindowFocused(flags) end

--
-- is current window hovered and hoverable (e.g. not blocked by a popup/modal)? See ImGuiHoveredFlags_ for options. IMPORTANT: If you are trying to check whether your mouse should be dispatched to Dear ImGui or to your underlying app, you should not use this function! Use the 'io.WantCaptureMouse' boolean for that! Refer to FAQ entry "How can I tell whether to dispatch mouse/keyboard to Dear ImGui or my application?" for details.
--
---@param flags? ImGui.HoveredFlags | `ImGui.HoveredFlags { "None" }`
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
-- get viewport currently associated to the current window.
--
---@return ImGuiViewport
function ImGui.GetWindowViewport() end

--
-- Window manipulation
-- - Prefer using SetNextXXX functions (before Begin) rather that SetXXX functions (after Begin).
--
--
-- Implied pivot = ImVec2(0, 0)
--
---@param pos_x number
---@param pos_y number
---@param cond? ImGui.Cond | `ImGui.Cond.None`
function ImGui.SetNextWindowPos(pos_x, pos_y, cond) end

--
-- set next window position. call before Begin(). use pivot=(0.5f,0.5f) to center on given point, etc.
--
---@param pos_x number
---@param pos_y number
---@param cond? ImGui.Cond | `ImGui.Cond.None`
---@param pivot_x? number | `0`
---@param pivot_y? number | `0`
function ImGui.SetNextWindowPosEx(pos_x, pos_y, cond, pivot_x, pivot_y) end

--
-- set next window size. set axis to 0.0f to force an auto-fit on this axis. call before Begin()
--
---@param size_x number
---@param size_y number
---@param cond? ImGui.Cond | `ImGui.Cond.None`
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
---@param cond? ImGui.Cond | `ImGui.Cond.None`
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
---@param viewport_id ImGuiID
function ImGui.SetNextWindowViewport(viewport_id) end

--
-- (not recommended) set current window position - call within Begin()/End(). prefer using SetNextWindowPos(), as this may incur tearing and side-effects.
--
---@param pos_x number
---@param pos_y number
---@param cond? ImGui.Cond | `ImGui.Cond.None`
function ImGui.SetWindowPos(pos_x, pos_y, cond) end

--
-- (not recommended) set current window size - call within Begin()/End(). set to ImVec2(0, 0) to force an auto-fit. prefer using SetNextWindowSize(), as this may incur tearing and minor side-effects.
--
---@param size_x number
---@param size_y number
---@param cond? ImGui.Cond | `ImGui.Cond.None`
function ImGui.SetWindowSize(size_x, size_y, cond) end

--
-- (not recommended) set current window collapsed state. prefer using SetNextWindowCollapsed().
--
---@param collapsed boolean
---@param cond? ImGui.Cond | `ImGui.Cond.None`
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
---@param cond? ImGui.Cond | `ImGui.Cond.None`
function ImGui.SetWindowPosStr(name, pos_x, pos_y, cond) end

--
-- set named window size. set axis to 0.0f to force an auto-fit on this axis.
--
---@param name string
---@param size_x number
---@param size_y number
---@param cond? ImGui.Cond | `ImGui.Cond.None`
function ImGui.SetWindowSizeStr(name, size_x, size_y, cond) end

--
-- set named window collapsed state
--
---@param name string
---@param collapsed boolean
---@param cond? ImGui.Cond | `ImGui.Cond.None`
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

--
-- Parameters stacks (shared)
--
--
-- use NULL as a shortcut to push default font
--
---@param font ImFont
function ImGui.PushFont(font) end

function ImGui.PopFont() end

--
-- modify a style color. always use this if you modify the style after NewFrame().
--
---@param idx ImGui.Col
---@param col ImU32
function ImGui.PushStyleColor(idx, col) end

---@param idx ImGui.Col
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
---@param idx ImGui.StyleVar
---@param val number
function ImGui.PushStyleVar(idx, val) end

--
-- modify a style ImVec2 variable. always use this if you modify the style after NewFrame().
--
---@param idx ImGui.StyleVar
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
-- Style read access
-- - Use the ShowStyleEditor() function to interactively see/edit the colors.
--
--
-- get current font
--
---@return ImFont
function ImGui.GetFont() end

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
---@param idx ImGui.Col
---@return ImU32
function ImGui.GetColorU32(idx) end

--
-- retrieve given style color with style alpha applied and optional extra alpha multiplier, packed as a 32-bit value suitable for ImDrawList
--
---@param idx ImGui.Col
---@param alpha_mul? number | `1.0`
---@return ImU32
function ImGui.GetColorU32Ex(idx, alpha_mul) end

--
-- retrieve given color with style alpha applied, packed as a 32-bit value suitable for ImDrawList
--
---@param col_x number
---@param col_y number
---@param col_z number
---@param col_w number
---@return ImU32
function ImGui.GetColorU32ImVec4(col_x, col_y, col_z, col_w) end

--
-- Implied alpha_mul = 1.0f
--
---@param col ImU32
---@return ImU32
function ImGui.GetColorU32ImU32(col) end

--
-- retrieve given color with style alpha applied, packed as a 32-bit value suitable for ImDrawList
--
---@param col ImU32
---@param alpha_mul? number | `1.0`
---@return ImU32
function ImGui.GetColorU32ImU32Ex(col, alpha_mul) end

--
-- retrieve style color as stored in ImGuiStyle structure. use to feed back into PushStyleColor(), otherwise use GetColorU32() to get style color with style alpha baked in.
--
---@param idx ImGui.Col
---@return number
---@return number
---@return number
---@return number
function ImGui.GetStyleColorVec4(idx) end

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
---@return ImGuiID
function ImGui.GetID(str_id) end

---@param str_id_begin string
---@param str_id_end string
---@return ImGuiID
function ImGui.GetIDStr(str_id_begin, str_id_end) end

---@param ptr_id lightuserdata
---@return ImGuiID
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
---@param flags? ImGui.ButtonFlags | `ImGui.ButtonFlags { "None" }`
---@return boolean
function ImGui.InvisibleButton(str_id, size_x, size_y, flags) end

--
-- square button with an arrow shape
--
---@param str_id string
---@param dir ImGui.Dir
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

---@param label string
---@param flags integer[]
---@param flags_value integer
---@return boolean
function ImGui.CheckboxFlagsUintPtr(label, flags, flags_value) end

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
-- - 'uv0' and 'uv1' are texture coordinates. Read about them from the same link above.
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
---@param flags? ImGui.ComboFlags | `ImGui.ComboFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
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
---@param flags? ImGui.SliderFlags | `ImGui.SliderFlags { "None" }`
---@return boolean
function ImGui.VSliderIntEx(label, size_x, size_y, v, v_min, v_max, format, flags) end

--
-- Widgets: Input with Keyboard
-- - If you want to use InputText() with std::string or any custom dynamic string type, see misc/cpp/imgui_stdlib.h and comments in imgui_demo.cpp.
-- - Most of the ImGuiInputTextFlags flags are only useful for InputText() and not for InputFloatX, InputIntX, InputDouble etc.
--
--
-- Implied callback = NULL, user_data = NULL
--
---@param label string
---@param buf ImStringBuf | ImStringBuf[] | string[]
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputText(label, buf, flags) end

---@param label string
---@param buf ImStringBuf | ImStringBuf[] | string[]
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@param user_data lightuserdata
---@return boolean
function ImGui.InputTextEx(label, buf, flags, user_data) end

--
-- Implied size = ImVec2(0, 0), flags = 0, callback = NULL, user_data = NULL
--
---@param label string
---@param buf ImStringBuf | ImStringBuf[] | string[]
---@return boolean
function ImGui.InputTextMultiline(label, buf) end

---@param label string
---@param buf ImStringBuf | ImStringBuf[] | string[]
---@param size_x? number | `0`
---@param size_y? number | `0`
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@param user_data lightuserdata
---@return boolean
function ImGui.InputTextMultilineEx(label, buf, size_x, size_y, flags, user_data) end

--
-- Implied callback = NULL, user_data = NULL
--
---@param label string
---@param hint string
---@param buf ImStringBuf | ImStringBuf[] | string[]
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputTextWithHint(label, hint, buf, flags) end

---@param label string
---@param hint string
---@param buf ImStringBuf | ImStringBuf[] | string[]
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@param user_data lightuserdata
---@return boolean
function ImGui.InputTextWithHintEx(label, hint, buf, flags, user_data) end

--
-- Implied step = 0.0f, step_fast = 0.0f, format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@return boolean
function ImGui.InputFloat(label, v) end

---@param label string
---@param v number[]
---@param step? number | `0.0`
---@param step_fast? number | `0.0`
---@param format? string | `"%.3f"`
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputFloatEx(label, v, step, step_fast, format, flags) end

--
-- Implied format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@return boolean
function ImGui.InputFloat2(label, v) end

---@param label string
---@param v number[]
---@param format? string | `"%.3f"`
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputFloat2Ex(label, v, format, flags) end

--
-- Implied format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@return boolean
function ImGui.InputFloat3(label, v) end

---@param label string
---@param v number[]
---@param format? string | `"%.3f"`
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputFloat3Ex(label, v, format, flags) end

--
-- Implied format = "%.3f", flags = 0
--
---@param label string
---@param v number[]
---@return boolean
function ImGui.InputFloat4(label, v) end

---@param label string
---@param v number[]
---@param format? string | `"%.3f"`
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputFloat4Ex(label, v, format, flags) end

--
-- Implied step = 1, step_fast = 100, flags = 0
--
---@param label string
---@param v integer[]
---@return boolean
function ImGui.InputInt(label, v) end

---@param label string
---@param v integer[]
---@param step? integer | `1`
---@param step_fast? integer | `100`
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputIntEx(label, v, step, step_fast, flags) end

---@param label string
---@param v integer[]
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputInt2(label, v, flags) end

---@param label string
---@param v integer[]
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputInt3(label, v, flags) end

---@param label string
---@param v integer[]
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputInt4(label, v, flags) end

--
-- Implied step = 0.0, step_fast = 0.0, format = "%.6f", flags = 0
--
---@param label string
---@param v number[]
---@return boolean
function ImGui.InputDouble(label, v) end

---@param label string
---@param v number[]
---@param step? number | `0.0`
---@param step_fast? number | `0.0`
---@param format? string | `"%.6f"`
---@param flags? ImGui.InputTextFlags | `ImGui.InputTextFlags { "None" }`
---@return boolean
function ImGui.InputDoubleEx(label, v, step, step_fast, format, flags) end

--
-- Widgets: Color Editor/Picker (tip: the ColorEdit* functions have a little color square that can be left-clicked to open a picker, and right-clicked to open an option menu.)
-- - Note that in C++ a 'float v[X]' function argument is the _same_ as 'float* v', the array syntax is just a way to document the number of elements that are expected to be accessible.
-- - You can pass the address of a first float element out of a contiguous structure, e.g. &myvector.x
--
---@param label string
---@param col number[]
---@param flags? ImGui.ColorEditFlags | `ImGui.ColorEditFlags { "None" }`
---@return boolean
function ImGui.ColorEdit3(label, col, flags) end

---@param label string
---@param col number[]
---@param flags? ImGui.ColorEditFlags | `ImGui.ColorEditFlags { "None" }`
---@return boolean
function ImGui.ColorEdit4(label, col, flags) end

---@param label string
---@param col number[]
---@param flags? ImGui.ColorEditFlags | `ImGui.ColorEditFlags { "None" }`
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
---@param flags? ImGui.ColorEditFlags | `ImGui.ColorEditFlags { "None" }`
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
---@param flags? ImGui.ColorEditFlags | `ImGui.ColorEditFlags { "None" }`
---@param size_x? number | `0`
---@param size_y? number | `0`
---@return boolean
function ImGui.ColorButtonEx(desc_id, col_x, col_y, col_z, col_w, flags, size_x, size_y) end

--
-- initialize current options (generally on application startup) if you want to select a default format, picker type, etc. User will be able to change many settings, unless you pass the _NoOptions flag to your calls.
--
---@param flags ImGui.ColorEditFlags
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
---@param flags? ImGui.TreeNodeFlags | `ImGui.TreeNodeFlags { "None" }`
---@return boolean
function ImGui.TreeNodeEx(label, flags) end

---@param str_id string
---@param flags ImGui.TreeNodeFlags
---@param fmt string
---@param ...  any
---@return boolean
function ImGui.TreeNodeExStr(str_id, flags, fmt, ...) end

---@param ptr_id lightuserdata
---@param flags ImGui.TreeNodeFlags
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
---@param flags? ImGui.TreeNodeFlags | `ImGui.TreeNodeFlags { "None" }`
---@return boolean
function ImGui.CollapsingHeader(label, flags) end

--
-- when 'p_visible != NULL': if '*p_visible==true' display an additional small close button on upper right of the header which will set the bool to false when clicked, if '*p_visible==false' don't display the header.
--
---@param label string
---@param p_visible boolean[]
---@param flags? ImGui.TreeNodeFlags | `ImGui.TreeNodeFlags { "None" }`
---@return boolean
---@return boolean p_visible
function ImGui.CollapsingHeaderBoolPtr(label, p_visible, flags) end

--
-- set next TreeNode/CollapsingHeader open state.
--
---@param is_open boolean
---@param cond? ImGui.Cond | `ImGui.Cond.None`
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
---@param flags? ImGui.SelectableFlags | `ImGui.SelectableFlags { "None" }`
---@param size_x? number | `0`
---@param size_y? number | `0`
---@return boolean
function ImGui.SelectableEx(label, selected, flags, size_x, size_y) end

--
-- Implied size = ImVec2(0, 0)
--
---@param label string
---@param p_selected boolean[]
---@param flags? ImGui.SelectableFlags | `ImGui.SelectableFlags { "None" }`
---@return boolean
---@return boolean p_selected
function ImGui.SelectableBoolPtr(label, p_selected, flags) end

--
-- "bool* p_selected" point to the selection state (read-write), as a convenient helper.
--
---@param label string
---@param p_selected boolean[]
---@param flags? ImGui.SelectableFlags | `ImGui.SelectableFlags { "None" }`
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
-- - A tooltip window can contain items of any types.
-- - SetTooltip() is more or less a shortcut for the 'if (BeginTooltip()) { Text(...); EndTooltip(); }' idiom (with a subtlety that it discard any previously submitted tooltip)
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
-- set a text-only tooltip if preceding item was hovered. override any previous call to SetTooltip().
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
---@param flags? ImGui.WindowFlags | `ImGui.WindowFlags { "None" }`
---@return boolean
function ImGui.BeginPopup(str_id, flags) end

--
-- return true if the modal is open, and you can start outputting to it.
--
---@param name string
---@param p_open true | nil
---@param flags? ImGui.WindowFlags | `ImGui.WindowFlags { "None" }`
---@return boolean
---@return boolean | nil p_open
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
---@param popup_flags? ImGui.PopupFlags | `ImGui.PopupFlags { "None" }`
function ImGui.OpenPopup(str_id, popup_flags) end

--
-- id overload to facilitate calling from nested stacks
--
---@param id ImGuiID
---@param popup_flags? ImGui.PopupFlags | `ImGui.PopupFlags { "None" }`
function ImGui.OpenPopupID(id, popup_flags) end

--
-- helper to open popup when clicked on last item. Default to ImGuiPopupFlags_MouseButtonRight == 1. (note: actually triggers on the mouse _released_ event to be consistent with popup behaviors)
--
---@param str_id? string
---@param popup_flags? ImGui.PopupFlags | `ImGui.PopupFlags { "MouseButtonRight" }`
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
---@param popup_flags? ImGui.PopupFlags | `ImGui.PopupFlags { "MouseButtonRight" }`
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
---@param popup_flags? ImGui.PopupFlags | `ImGui.PopupFlags { "MouseButtonRight" }`
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
---@param popup_flags? ImGui.PopupFlags | `ImGui.PopupFlags { "MouseButtonRight" }`
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
---@param flags? ImGui.PopupFlags | `ImGui.PopupFlags { "None" }`
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
---@param flags? ImGui.TableFlags | `ImGui.TableFlags { "None" }`
---@return boolean
function ImGui.BeginTable(str_id, column, flags) end

---@param str_id string
---@param column integer
---@param flags? ImGui.TableFlags | `ImGui.TableFlags { "None" }`
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
---@param row_flags? ImGui.TableRowFlags | `ImGui.TableRowFlags { "None" }`
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
---@param flags? ImGui.TableColumnFlags | `ImGui.TableColumnFlags { "None" }`
function ImGui.TableSetupColumn(label, flags) end

---@param label string
---@param flags? ImGui.TableColumnFlags | `ImGui.TableColumnFlags { "None" }`
---@param init_width_or_weight? number | `0.0`
---@param user_id? ImGuiID | `0`
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
---@return ImGui.TableColumnFlags
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
---@param target ImGui.TableBgTarget
---@param color ImU32
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
---@param flags? ImGui.TabBarFlags | `ImGui.TabBarFlags { "None" }`
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
---@param flags? ImGui.TabItemFlags | `ImGui.TabItemFlags { "None" }`
---@return boolean
---@return boolean | nil p_open
function ImGui.BeginTabItem(label, p_open, flags) end

--
-- only call EndTabItem() if BeginTabItem() returns true!
--
function ImGui.EndTabItem() end

--
-- create a Tab behaving like a button. return true when clicked. cannot be selected in the tab bar.
--
---@param label string
---@param flags? ImGui.TabItemFlags | `ImGui.TabItemFlags { "None" }`
---@return boolean
function ImGui.TabItemButton(label, flags) end

--
-- notify TabBar or Docking system of a closed tab/window ahead (useful to reduce visual flicker on reorderable tab bars). For tab-bar: call after BeginTabBar() and before Tab submissions. Otherwise call with a window name.
--
---@param tab_or_docked_window_label string
function ImGui.SetTabItemClosed(tab_or_docked_window_label) end

--
-- Docking
-- [BETA API] Enable with io.ConfigFlags |= ImGuiConfigFlags_DockingEnable.
-- Note: You can use most Docking facilities without calling any API. You DO NOT need to call DockSpace() to use Docking!
-- - Drag from window title bar or their tab to dock/undock. Hold SHIFT to disable docking.
-- - Drag from window menu button (upper-left button) to undock an entire node (all windows).
-- - When io.ConfigDockingWithShift == true, you instead need to hold SHIFT to enable docking.
-- About dockspaces:
-- - Use DockSpaceOverViewport() to create a window covering the screen or a specific viewport + a dockspace inside it.
--   This is often used with ImGuiDockNodeFlags_PassthruCentralNode to make it transparent.
-- - Use DockSpace() to create an explicit dock node _within_ an existing window. See Docking demo for details.
-- - Important: Dockspaces need to be submitted _before_ any window they can host. Submit it early in your frame!
-- - Important: Dockspaces need to be kept alive if hidden, otherwise windows docked into it will be undocked.
--   e.g. if you have multiple tabs with a dockspace inside each tab: submit the non-visible dockspaces with ImGuiDockNodeFlags_KeepAliveOnly.
--
--
-- Implied size = ImVec2(0, 0), flags = 0, window_class = NULL
--
---@param dockspace_id ImGuiID
---@return ImGuiID
function ImGui.DockSpace(dockspace_id) end

---@param dockspace_id ImGuiID
---@param size_x? number | `0`
---@param size_y? number | `0`
---@param flags? ImGui.DockNodeFlags | `ImGui.DockNodeFlags { "None" }`
---@param window_class? ImGuiWindowClass
---@return ImGuiID
function ImGui.DockSpaceEx(dockspace_id, size_x, size_y, flags, window_class) end

--
-- Implied dockspace_id = 0, viewport = NULL, flags = 0, window_class = NULL
--
---@return ImGuiID
function ImGui.DockSpaceOverViewport() end

--
-- set next window dock id
--
---@param dock_id ImGuiID
---@param cond? ImGui.Cond | `ImGui.Cond.None`
function ImGui.SetNextWindowDockID(dock_id, cond) end

--
-- set next window class (control docking compatibility + provide hints to platform backend via custom viewport flags and platform parent/child relationship)
--
---@param window_class ImGuiWindowClass
function ImGui.SetNextWindowClass(window_class) end

---@return ImGuiID
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
---@param flags? ImGui.DragDropFlags | `ImGui.DragDropFlags { "None" }`
---@return boolean
function ImGui.BeginDragDropSource(flags) end

--
-- type is a user defined string of maximum 32 characters. Strings starting with '_' are reserved for dear imgui internal types. Data is copied and held by imgui. Return true when payload has been accepted.
--
---@param type string
---@param data string
---@param cond? ImGui.Cond | `ImGui.Cond.None`
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
---@param flags? ImGui.DragDropFlags | `ImGui.DragDropFlags { "None" }`
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
---@param flags? ImGui.HoveredFlags | `ImGui.HoveredFlags { "None" }`
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
---@param mouse_button? ImGui.MouseButton | `ImGui.MouseButton.Left`
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
---@return ImGuiID
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
-- Viewports
-- - Currently represents the Platform Window created by the application which is hosting our Dear ImGui windows.
-- - In 'docking' branch with multi-viewport enabled, we extend this concept to have multiple active viewports.
-- - In the future we will extend this concept further to also represent Platform Monitor and support a "no main platform window" operation mode.
--
--
-- return primary/default viewport. This can never be NULL.
--
---@return ImGuiViewport
function ImGui.GetMainViewport() end

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
---@param idx ImGui.Col
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
---@param arg_in ImU32
---@return number
---@return number
---@return number
---@return number
function ImGui.ColorConvertU32ToFloat4(arg_in) end

---@param in_x number
---@param in_y number
---@param in_z number
---@param in_w number
---@return ImU32
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
---@param key ImGui.Key
---@return boolean
function ImGui.IsKeyDown(key) end

--
-- Implied repeat = true
--
---@param key ImGui.Key
---@return boolean
function ImGui.IsKeyPressed(key) end

--
-- was key pressed (went from !Down to Down)? if repeat=true, uses io.KeyRepeatDelay / KeyRepeatRate
--
---@param key ImGui.Key
---@param arg_repeat? boolean | `true`
---@return boolean
function ImGui.IsKeyPressedEx(key, arg_repeat) end

--
-- was key released (went from Down to !Down)?
--
---@param key ImGui.Key
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
---@param key ImGui.Key
---@param repeat_delay number
---@param rate number
---@return integer
function ImGui.GetKeyPressedAmount(key, repeat_delay, rate) end

--
-- [DEBUG] returns English name of the key. Those names a provided for debugging purpose and are not meant to be saved persistently not compared.
--
---@param key ImGui.Key
---@return string
function ImGui.GetKeyName(key) end

--
-- Override io.WantCaptureKeyboard flag next frame (said flag is left for your application to handle, typically when true it instructs your app to ignore inputs). e.g. force capture keyboard when your widget is being hovered. This is equivalent to setting "io.WantCaptureKeyboard = want_capture_keyboard"; after the next NewFrame() call.
--
---@param want_capture_keyboard boolean
function ImGui.SetNextFrameWantCaptureKeyboard(want_capture_keyboard) end

--
-- Inputs Utilities: Shortcut Testing & Routing [BETA]
-- - ImGuiKeyChord = a ImGuiKey + optional ImGuiMod_Alt/ImGuiMod_Ctrl/ImGuiMod_Shift/ImGuiMod_Super.
--       ImGuiKey_C                          // Accepted by functions taking ImGuiKey or ImGuiKeyChord arguments)
--       ImGuiMod_Ctrl | ImGuiKey_C          // Accepted by functions taking ImGuiKeyChord arguments)
--   only ImGuiMod_XXX values are legal to combine with an ImGuiKey. You CANNOT combine two ImGuiKey values.
-- - The general idea is that several callers may register interest in a shortcut, and only one owner gets it.
--      Parent   -> call Shortcut(Ctrl+S)    // When Parent is focused, Parent gets the shortcut.
--        Child1 -> call Shortcut(Ctrl+S)    // When Child1 is focused, Child1 gets the shortcut (Child1 overrides Parent shortcuts)
--        Child2 -> no call                  // When Child2 is focused, Parent gets the shortcut.
--   The whole system is order independent, so if Child1 makes its calls before Parent, results will be identical.
--   This is an important property as it facilitate working with foreign code or larger codebase.
-- - To understand the difference:
--   - IsKeyChordPressed() compares mods and call IsKeyPressed() -> function has no side-effect.
--   - Shortcut() submits a route, routes are resolved, if it currently can be routed it calls IsKeyChordPressed() -> function has (desirable) side-effects as it can prevents another call from getting the route.
-- - Visualize registered routes in 'Metrics/Debugger->Inputs'.
--
---@param key_chord ImGuiKeyChord
---@param flags? ImGui.InputFlags | `ImGui.InputFlags { "None" }`
---@return boolean
function ImGui.Shortcut(key_chord, flags) end

---@param key_chord ImGuiKeyChord
---@param flags? ImGui.InputFlags | `ImGui.InputFlags { "None" }`
function ImGui.SetNextItemShortcut(key_chord, flags) end

--
-- Inputs Utilities: Mouse specific
-- - To refer to a mouse button, you may use named enums in your code e.g. ImGuiMouseButton_Left, ImGuiMouseButton_Right.
-- - You can also use regular integer: it is forever guaranteed that 0=Left, 1=Right, 2=Middle.
-- - Dragging operations are only reported after mouse has moved a certain distance away from the initial clicking position (see 'lock_threshold' and 'io.MouseDraggingThreshold')
--
--
-- is mouse button held?
--
---@param button ImGui.MouseButton
---@return boolean
function ImGui.IsMouseDown(button) end

--
-- Implied repeat = false
--
---@param button ImGui.MouseButton
---@return boolean
function ImGui.IsMouseClicked(button) end

--
-- did mouse button clicked? (went from !Down to Down). Same as GetMouseClickedCount() == 1.
--
---@param button ImGui.MouseButton
---@param arg_repeat? boolean | `false`
---@return boolean
function ImGui.IsMouseClickedEx(button, arg_repeat) end

--
-- did mouse button released? (went from Down to !Down)
--
---@param button ImGui.MouseButton
---@return boolean
function ImGui.IsMouseReleased(button) end

--
-- did mouse button double-clicked? Same as GetMouseClickedCount() == 2. (note that a double-click will also report IsMouseClicked() == true)
--
---@param button ImGui.MouseButton
---@return boolean
function ImGui.IsMouseDoubleClicked(button) end

--
-- return the number of successive mouse-clicks at the time where a click happen (otherwise 0).
--
---@param button ImGui.MouseButton
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
-- is mouse dragging? (uses io.MouseDraggingThreshold if lock_threshold < 0.0f)
--
---@param button ImGui.MouseButton
---@param lock_threshold? number | `-1.0`
---@return boolean
function ImGui.IsMouseDragging(button, lock_threshold) end

--
-- return the delta from the initial clicking position while the mouse button is pressed or was just released. This is locked and return 0.0f until the mouse moves past a distance threshold at least once (uses io.MouseDraggingThreshold if lock_threshold < 0.0f)
--
---@param button? ImGui.MouseButton | `ImGui.MouseButton.Left`
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
---@param button? ImGui.MouseButton | `ImGui.MouseButton.Left`
function ImGui.ResetMouseDragDeltaEx(button) end

--
-- get desired mouse cursor shape. Important: reset in ImGui::NewFrame(), this is updated during the frame. valid before Render(). If you use software rendering by setting io.MouseDrawCursor ImGui will render those for you
--
---@return ImGui.MouseCursor
function ImGui.GetMouseCursor() end

--
-- set desired mouse cursor shape
--
---@param cursor_type ImGui.MouseCursor
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

--
-- call in main loop. will call CreateWindow/ResizeWindow/etc. platform functions for each secondary viewport, and DestroyWindow for each inactive viewport.
--
function ImGui.UpdatePlatformWindows() end

--
-- Implied platform_render_arg = NULL, renderer_render_arg = NULL
--
function ImGui.RenderPlatformWindowsDefault() end

--
-- call in main loop. will call RenderWindow/SwapBuffers platform functions for each secondary viewport which doesn't have the ImGuiViewportFlags_Minimized flag set. May be reimplemented by user for custom rendering needs.
--
---@param platform_render_arg lightuserdata?
---@param renderer_render_arg lightuserdata?
function ImGui.RenderPlatformWindowsDefaultEx(platform_render_arg, renderer_render_arg) end

--
-- call DestroyWindow platform functions for all viewports. call from backend Shutdown() if you need to close platform windows before imgui shutdown. otherwise will be called by DestroyContext().
--
function ImGui.DestroyPlatformWindows() end

--
-- this is a helper for backends.
--
---@param id ImGuiID
---@return ImGuiViewport
function ImGui.FindViewportByID(id) end

--
-- this is a helper for backends. the type platform_handle is decided by the backend (e.g. HWND, MyWindow*, GLFWwindow* etc.)
--
---@param platform_handle lightuserdata
---@return ImGuiViewport
function ImGui.FindViewportByPlatformHandle(platform_handle) end

return ImGui
