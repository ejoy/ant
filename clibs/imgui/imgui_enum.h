static struct enum_pair eWindowFlags[] = {
	ENUM(ImGuiWindowFlags, None),
	ENUM(ImGuiWindowFlags, NoTitleBar),
	ENUM(ImGuiWindowFlags, NoResize),
	ENUM(ImGuiWindowFlags, NoMove),
	ENUM(ImGuiWindowFlags, NoScrollbar),
	ENUM(ImGuiWindowFlags, NoScrollWithMouse),
	ENUM(ImGuiWindowFlags, NoCollapse),
	ENUM(ImGuiWindowFlags, AlwaysAutoResize),
	ENUM(ImGuiWindowFlags, NoBackground),
	ENUM(ImGuiWindowFlags, NoSavedSettings),
	ENUM(ImGuiWindowFlags, NoMouseInputs),
	ENUM(ImGuiWindowFlags, MenuBar),
	ENUM(ImGuiWindowFlags, HorizontalScrollbar),
	ENUM(ImGuiWindowFlags, NoFocusOnAppearing),
	ENUM(ImGuiWindowFlags, NoBringToFrontOnFocus),
	ENUM(ImGuiWindowFlags, AlwaysVerticalScrollbar),
	ENUM(ImGuiWindowFlags, AlwaysHorizontalScrollbar),
	ENUM(ImGuiWindowFlags, NoNavInputs),
	ENUM(ImGuiWindowFlags, NoNavFocus),
	ENUM(ImGuiWindowFlags, UnsavedDocument),
	ENUM(ImGuiWindowFlags, NoDocking),
	ENUM(ImGuiWindowFlags, NoNav),
	ENUM(ImGuiWindowFlags, NoDecoration),
	ENUM(ImGuiWindowFlags, NoInputs),
	{ "NoClosed", (lua_Integer)1 << 32 },
	{ NULL, 0 },
};

static struct enum_pair eChildFlags[] = {
	ENUM(ImGuiChildFlags, None),
	ENUM(ImGuiChildFlags, Border),
	ENUM(ImGuiChildFlags, AlwaysUseWindowPadding),
	ENUM(ImGuiChildFlags, ResizeX),
	ENUM(ImGuiChildFlags, ResizeY),
	ENUM(ImGuiChildFlags, AutoResizeX),
	ENUM(ImGuiChildFlags, AutoResizeY),
	ENUM(ImGuiChildFlags, AlwaysAutoResize),
	ENUM(ImGuiChildFlags, FrameStyle),
	{ NULL, 0 },
};

static struct enum_pair eInputTextFlags[] = {
	ENUM(ImGuiInputTextFlags, None),
	ENUM(ImGuiInputTextFlags, CharsDecimal),
	ENUM(ImGuiInputTextFlags, CharsHexadecimal),
	ENUM(ImGuiInputTextFlags, CharsUppercase),
	ENUM(ImGuiInputTextFlags, CharsNoBlank),
	ENUM(ImGuiInputTextFlags, AutoSelectAll),
	ENUM(ImGuiInputTextFlags, EnterReturnsTrue),
	ENUM(ImGuiInputTextFlags, CallbackCompletion),
	ENUM(ImGuiInputTextFlags, CallbackHistory),
	// Todo : support CallbackAlways
	//	ENUM(ImGuiInputTextFlags, CallbackAlways),
	ENUM(ImGuiInputTextFlags, CallbackCharFilter),
	ENUM(ImGuiInputTextFlags, AllowTabInput),
	ENUM(ImGuiInputTextFlags, CtrlEnterForNewLine),
	ENUM(ImGuiInputTextFlags, NoHorizontalScroll),
	ENUM(ImGuiInputTextFlags, AlwaysOverwrite),
	ENUM(ImGuiInputTextFlags, ReadOnly),
	ENUM(ImGuiInputTextFlags, Password),
	ENUM(ImGuiInputTextFlags, NoUndoRedo),
	ENUM(ImGuiInputTextFlags, CharsScientific),
	ENUM(ImGuiInputTextFlags, CallbackResize),
	ENUM(ImGuiInputTextFlags, CallbackEdit),
	ENUM(ImGuiInputTextFlags, EscapeClearsAll),
	{ NULL, 0 },
};

static struct enum_pair eTreeNodeFlags[] = {
	ENUM(ImGuiTreeNodeFlags, None),
	ENUM(ImGuiTreeNodeFlags, Selected),
	ENUM(ImGuiTreeNodeFlags, Framed),
	ENUM(ImGuiTreeNodeFlags, AllowOverlap),
	ENUM(ImGuiTreeNodeFlags, NoTreePushOnOpen),
	ENUM(ImGuiTreeNodeFlags, NoAutoOpenOnLog),
	ENUM(ImGuiTreeNodeFlags, DefaultOpen),
	ENUM(ImGuiTreeNodeFlags, OpenOnDoubleClick),
	ENUM(ImGuiTreeNodeFlags, OpenOnArrow),
	ENUM(ImGuiTreeNodeFlags, Leaf),
	ENUM(ImGuiTreeNodeFlags, Bullet),
	ENUM(ImGuiTreeNodeFlags, FramePadding),
	ENUM(ImGuiTreeNodeFlags, SpanAvailWidth),
	ENUM(ImGuiTreeNodeFlags, SpanFullWidth),
	ENUM(ImGuiTreeNodeFlags, SpanAllColumns),
	ENUM(ImGuiTreeNodeFlags, NavLeftJumpsBackHere),
	ENUM(ImGuiTreeNodeFlags, CollapsingHeader),
	{ NULL, 0 },
};

static struct enum_pair ePopupFlags[] = {
	ENUM(ImGuiPopupFlags, None),
	ENUM(ImGuiPopupFlags, MouseButtonLeft),
	ENUM(ImGuiPopupFlags, MouseButtonRight),
	ENUM(ImGuiPopupFlags, MouseButtonMiddle),
	ENUM(ImGuiPopupFlags, NoOpenOverExistingPopup),
	ENUM(ImGuiPopupFlags, NoOpenOverItems),
	ENUM(ImGuiPopupFlags, AnyPopupId),
	ENUM(ImGuiPopupFlags, AnyPopupLevel),
	ENUM(ImGuiPopupFlags, AnyPopup),
	{ NULL, 0 },
};

static struct enum_pair eSelectableFlags[] = {
	ENUM(ImGuiSelectableFlags, None),
	ENUM(ImGuiSelectableFlags, DontClosePopups),
	ENUM(ImGuiSelectableFlags, SpanAllColumns),
	ENUM(ImGuiSelectableFlags, AllowDoubleClick),
	ENUM(ImGuiSelectableFlags, AllowOverlap),
	// Use boolean(disabled) in Selectable(_,_, disabled)
	//	ENUM(ImGuiSelectableFlags, Disabled),
	{ NULL, 0 },
};

static struct enum_pair eComboFlags[] = {
	ENUM(ImGuiComboFlags, None),
	ENUM(ImGuiComboFlags, PopupAlignLeft),
	ENUM(ImGuiComboFlags, HeightSmall),
	ENUM(ImGuiComboFlags, HeightRegular),
	ENUM(ImGuiComboFlags, HeightLarge),
	ENUM(ImGuiComboFlags, HeightLargest),
	ENUM(ImGuiComboFlags, NoArrowButton),
	ENUM(ImGuiComboFlags, NoPreview),
	ENUM(ImGuiComboFlags, WidthFitPreview),
	{ NULL, 0 },
};

static struct enum_pair eTabBarFlags[] = {
	ENUM(ImGuiTabBarFlags, None),
	ENUM(ImGuiTabBarFlags, Reorderable),
	ENUM(ImGuiTabBarFlags, AutoSelectNewTabs),
	ENUM(ImGuiTabBarFlags, TabListPopupButton),
	ENUM(ImGuiTabBarFlags, NoCloseWithMiddleMouseButton),
	ENUM(ImGuiTabBarFlags, NoTabListScrollingButtons),
	ENUM(ImGuiTabBarFlags, NoTooltip),
	ENUM(ImGuiTabBarFlags, FittingPolicyResizeDown),
	ENUM(ImGuiTabBarFlags, FittingPolicyScroll),
	{ "NoClosed", (lua_Integer)1 << 32 },
	{ NULL, 0 },
};

//ImGuiTabItemFlags

static struct enum_pair eTableFlags[] = {
	ENUM(ImGuiTableFlags, None),
	ENUM(ImGuiTableFlags, Resizable),
	ENUM(ImGuiTableFlags, Reorderable),
	ENUM(ImGuiTableFlags, Hideable),
	ENUM(ImGuiTableFlags, Sortable),
	ENUM(ImGuiTableFlags, NoSavedSettings),
	ENUM(ImGuiTableFlags, ContextMenuInBody),
	ENUM(ImGuiTableFlags, RowBg),
	ENUM(ImGuiTableFlags, BordersInnerH),
	ENUM(ImGuiTableFlags, BordersOuterH),
	ENUM(ImGuiTableFlags, BordersInnerV),
	ENUM(ImGuiTableFlags, BordersOuterV),
	ENUM(ImGuiTableFlags, BordersH),
	ENUM(ImGuiTableFlags, BordersV),
	ENUM(ImGuiTableFlags, BordersInner),
	ENUM(ImGuiTableFlags, BordersOuter),
	ENUM(ImGuiTableFlags, Borders),
	ENUM(ImGuiTableFlags, NoBordersInBody),
	ENUM(ImGuiTableFlags, NoBordersInBodyUntilResize),
	ENUM(ImGuiTableFlags, SizingFixedFit),
	ENUM(ImGuiTableFlags, SizingFixedSame),
	ENUM(ImGuiTableFlags, SizingStretchProp),
	ENUM(ImGuiTableFlags, SizingStretchSame),
	ENUM(ImGuiTableFlags, NoHostExtendX),
	ENUM(ImGuiTableFlags, NoHostExtendY),
	ENUM(ImGuiTableFlags, NoKeepColumnsVisible),
	ENUM(ImGuiTableFlags, PreciseWidths),
	ENUM(ImGuiTableFlags, NoClip),
	ENUM(ImGuiTableFlags, PadOuterX),
	ENUM(ImGuiTableFlags, NoPadOuterX),
	ENUM(ImGuiTableFlags, NoPadInnerX),
	ENUM(ImGuiTableFlags, ScrollX),
	ENUM(ImGuiTableFlags, ScrollY),
	ENUM(ImGuiTableFlags, SortMulti),
	ENUM(ImGuiTableFlags, SortTristate),
	ENUM(ImGuiTableFlags, HighlightHoveredColumn),
	{ NULL, 0 },
};

static struct enum_pair eTableColumnFlags[] = {
	ENUM(ImGuiTableColumnFlags, None),
	ENUM(ImGuiTableColumnFlags, Disabled),
	ENUM(ImGuiTableColumnFlags, DefaultHide),
	ENUM(ImGuiTableColumnFlags, DefaultSort),
	ENUM(ImGuiTableColumnFlags, WidthStretch),
	ENUM(ImGuiTableColumnFlags, WidthFixed),
	ENUM(ImGuiTableColumnFlags, NoResize),
	ENUM(ImGuiTableColumnFlags, NoReorder),
	ENUM(ImGuiTableColumnFlags, NoHide),
	ENUM(ImGuiTableColumnFlags, NoClip),
	ENUM(ImGuiTableColumnFlags, NoSort),
	ENUM(ImGuiTableColumnFlags, NoSortAscending),
	ENUM(ImGuiTableColumnFlags, NoSortDescending),
	ENUM(ImGuiTableColumnFlags, NoHeaderLabel),
	ENUM(ImGuiTableColumnFlags, NoHeaderWidth),
	ENUM(ImGuiTableColumnFlags, PreferSortAscending),
	ENUM(ImGuiTableColumnFlags, PreferSortDescending),
	ENUM(ImGuiTableColumnFlags, IndentEnable),
	ENUM(ImGuiTableColumnFlags, IndentDisable),
	ENUM(ImGuiTableColumnFlags, AngledHeader),
	ENUM(ImGuiTableColumnFlags, IsEnabled),
	ENUM(ImGuiTableColumnFlags, IsVisible),
	ENUM(ImGuiTableColumnFlags, IsSorted),
	ENUM(ImGuiTableColumnFlags, IsHovered),
	{ NULL, 0 },
};

static struct enum_pair eTableRowFlags[] = {
	ENUM(ImGuiTableRowFlags, None),
	ENUM(ImGuiTableRowFlags, Headers),
	{ NULL, 0 },
};

static struct enum_pair eTableBgTarget[] = {
	ENUM(ImGuiTableBgTarget, None),
	ENUM(ImGuiTableBgTarget, RowBg0),
	ENUM(ImGuiTableBgTarget, RowBg1),
	ENUM(ImGuiTableBgTarget, CellBg),
	{ NULL, 0 },
};

static struct enum_pair eFocusedFlags[] = {
	ENUM(ImGuiFocusedFlags, None),
	ENUM(ImGuiFocusedFlags, ChildWindows),
	ENUM(ImGuiFocusedFlags, RootWindow),
	ENUM(ImGuiFocusedFlags, AnyWindow),
	ENUM(ImGuiFocusedFlags, NoPopupHierarchy),
	ENUM(ImGuiFocusedFlags, DockHierarchy),
	ENUM(ImGuiFocusedFlags, RootAndChildWindows),
	{ NULL, 0 },
};

static struct enum_pair eHoveredFlags[] = {
	ENUM(ImGuiHoveredFlags, None),
	ENUM(ImGuiHoveredFlags, ChildWindows),
	ENUM(ImGuiHoveredFlags, RootWindow),
	ENUM(ImGuiHoveredFlags, AnyWindow),
	ENUM(ImGuiHoveredFlags, NoPopupHierarchy),
	ENUM(ImGuiHoveredFlags, DockHierarchy),
	ENUM(ImGuiHoveredFlags, AllowWhenBlockedByPopup),
	ENUM(ImGuiHoveredFlags, AllowWhenBlockedByActiveItem),
	ENUM(ImGuiHoveredFlags, AllowWhenOverlappedByItem),
	ENUM(ImGuiHoveredFlags, AllowWhenOverlappedByWindow),
	ENUM(ImGuiHoveredFlags, AllowWhenDisabled),
	ENUM(ImGuiHoveredFlags, NoNavOverride),
	ENUM(ImGuiHoveredFlags, AllowWhenOverlapped),
	ENUM(ImGuiHoveredFlags, RectOnly),
	ENUM(ImGuiHoveredFlags, RootAndChildWindows),
	ENUM(ImGuiHoveredFlags, ForTooltip),
	ENUM(ImGuiHoveredFlags, Stationary),
	ENUM(ImGuiHoveredFlags, DelayNone),
	ENUM(ImGuiHoveredFlags, DelayShort),
	ENUM(ImGuiHoveredFlags, DelayNormal),
	ENUM(ImGuiHoveredFlags, NoSharedDelay),
	{ NULL, 0 },
};

static struct enum_pair eDockNodeFlags[] = {
	ENUM(ImGuiDockNodeFlags, None),
	ENUM(ImGuiDockNodeFlags, KeepAliveOnly),
	ENUM(ImGuiDockNodeFlags, NoDockingOverCentralNode),
	ENUM(ImGuiDockNodeFlags, PassthruCentralNode),
	ENUM(ImGuiDockNodeFlags, NoDockingSplit),
	ENUM(ImGuiDockNodeFlags, NoResize),
	ENUM(ImGuiDockNodeFlags, AutoHideTabBar),
	ENUM(ImGuiDockNodeFlags, NoUndocking),
	{ NULL, 0 },
};

static struct enum_pair eDragDropFlags[] = {
	ENUM(ImGuiDragDropFlags, None),
	ENUM(ImGuiDragDropFlags, SourceNoPreviewTooltip),
	ENUM(ImGuiDragDropFlags, SourceNoDisableHover),
	ENUM(ImGuiDragDropFlags, SourceNoHoldToOpenOthers),
	ENUM(ImGuiDragDropFlags, SourceAllowNullID),
	ENUM(ImGuiDragDropFlags, SourceExtern),
	ENUM(ImGuiDragDropFlags, SourceAutoExpirePayload),
	ENUM(ImGuiDragDropFlags, AcceptBeforeDelivery),
	ENUM(ImGuiDragDropFlags, AcceptNoDrawDefaultRect),
	ENUM(ImGuiDragDropFlags, AcceptNoPreviewTooltip),
	ENUM(ImGuiDragDropFlags, AcceptPeekOnly),
	{ NULL, 0 },
};

//ImGuiDataType

//ImGuiDir

static struct enum_pair eSortDirection[] = {
	ENUM(ImGuiSortDirection, None),
	ENUM(ImGuiSortDirection, Ascending),
	ENUM(ImGuiSortDirection, Descending),
	{ NULL, 0 },
};

static struct enum_pair eKey[] = {
	ENUM(ImGuiKey, None),
	ENUM(ImGuiKey, Tab),
	ENUM(ImGuiKey, LeftArrow),
	ENUM(ImGuiKey, RightArrow),
	ENUM(ImGuiKey, UpArrow),
	ENUM(ImGuiKey, DownArrow),
	ENUM(ImGuiKey, PageUp),
	ENUM(ImGuiKey, PageDown),
	ENUM(ImGuiKey, Home),
	ENUM(ImGuiKey, End),
	ENUM(ImGuiKey, Insert),
	ENUM(ImGuiKey, Delete),
	ENUM(ImGuiKey, Backspace),
	ENUM(ImGuiKey, Space),
	ENUM(ImGuiKey, Enter),
	ENUM(ImGuiKey, Escape),
	ENUM(ImGuiKey, LeftCtrl),
	ENUM(ImGuiKey, LeftShift),
	ENUM(ImGuiKey, LeftAlt),
	ENUM(ImGuiKey, LeftSuper),
	ENUM(ImGuiKey, RightCtrl),
	ENUM(ImGuiKey, RightShift),
	ENUM(ImGuiKey, RightAlt),
	ENUM(ImGuiKey, RightSuper),
	ENUM(ImGuiKey, Menu),
	ENUM(ImGuiKey, 0),
	ENUM(ImGuiKey, 1),
	ENUM(ImGuiKey, 2),
	ENUM(ImGuiKey, 3),
	ENUM(ImGuiKey, 4),
	ENUM(ImGuiKey, 5),
	ENUM(ImGuiKey, 6),
	ENUM(ImGuiKey, 7),
	ENUM(ImGuiKey, 8),
	ENUM(ImGuiKey, 9),
	ENUM(ImGuiKey, A),
	ENUM(ImGuiKey, B),
	ENUM(ImGuiKey, C),
	ENUM(ImGuiKey, D),
	ENUM(ImGuiKey, E),
	ENUM(ImGuiKey, F),
	ENUM(ImGuiKey, G),
	ENUM(ImGuiKey, H),
	ENUM(ImGuiKey, I),
	ENUM(ImGuiKey, J),
	ENUM(ImGuiKey, K),
	ENUM(ImGuiKey, L),
	ENUM(ImGuiKey, M),
	ENUM(ImGuiKey, N),
	ENUM(ImGuiKey, O),
	ENUM(ImGuiKey, P),
	ENUM(ImGuiKey, Q),
	ENUM(ImGuiKey, R),
	ENUM(ImGuiKey, S),
	ENUM(ImGuiKey, T),
	ENUM(ImGuiKey, U),
	ENUM(ImGuiKey, V),
	ENUM(ImGuiKey, W),
	ENUM(ImGuiKey, X),
	ENUM(ImGuiKey, Y),
	ENUM(ImGuiKey, Z),
	ENUM(ImGuiKey, F1),
	ENUM(ImGuiKey, F2),
	ENUM(ImGuiKey, F3),
	ENUM(ImGuiKey, F4),
	ENUM(ImGuiKey, F5),
	ENUM(ImGuiKey, F6),
	ENUM(ImGuiKey, F7),
	ENUM(ImGuiKey, F8),
	ENUM(ImGuiKey, F9),
	ENUM(ImGuiKey, F10),
	ENUM(ImGuiKey, F11),
	ENUM(ImGuiKey, F12),
	ENUM(ImGuiKey, F13),
	ENUM(ImGuiKey, F14),
	ENUM(ImGuiKey, F15),
	ENUM(ImGuiKey, F16),
	ENUM(ImGuiKey, F17),
	ENUM(ImGuiKey, F18),
	ENUM(ImGuiKey, F19),
	ENUM(ImGuiKey, F20),
	ENUM(ImGuiKey, F21),
	ENUM(ImGuiKey, F22),
	ENUM(ImGuiKey, F23),
	ENUM(ImGuiKey, F24),
	ENUM(ImGuiKey, Apostrophe),
	ENUM(ImGuiKey, Comma),
	ENUM(ImGuiKey, Minus),
	ENUM(ImGuiKey, Period),
	ENUM(ImGuiKey, Slash),
	ENUM(ImGuiKey, Semicolon),
	ENUM(ImGuiKey, Equal),
	ENUM(ImGuiKey, LeftBracket),
	ENUM(ImGuiKey, Backslash),
	ENUM(ImGuiKey, RightBracket),
	ENUM(ImGuiKey, GraveAccent),
	ENUM(ImGuiKey, CapsLock),
	ENUM(ImGuiKey, ScrollLock),
	ENUM(ImGuiKey, NumLock),
	ENUM(ImGuiKey, PrintScreen),
	ENUM(ImGuiKey, Pause),
	ENUM(ImGuiKey, Keypad0),
	ENUM(ImGuiKey, Keypad1),
	ENUM(ImGuiKey, Keypad2),
	ENUM(ImGuiKey, Keypad3),
	ENUM(ImGuiKey, Keypad4),
	ENUM(ImGuiKey, Keypad5),
	ENUM(ImGuiKey, Keypad6),
	ENUM(ImGuiKey, Keypad7),
	ENUM(ImGuiKey, Keypad8),
	ENUM(ImGuiKey, Keypad9),
	ENUM(ImGuiKey, KeypadDecimal),
	ENUM(ImGuiKey, KeypadDivide),
	ENUM(ImGuiKey, KeypadMultiply),
	ENUM(ImGuiKey, KeypadSubtract),
	ENUM(ImGuiKey, KeypadAdd),
	ENUM(ImGuiKey, KeypadEnter),
	ENUM(ImGuiKey, KeypadEqual),
	ENUM(ImGuiKey, AppBack),
	ENUM(ImGuiKey, AppForward),
	ENUM(ImGuiKey, GamepadStart),
	ENUM(ImGuiKey, GamepadBack),
	ENUM(ImGuiKey, GamepadFaceLeft),
	ENUM(ImGuiKey, GamepadFaceRight),
	ENUM(ImGuiKey, GamepadFaceUp),
	ENUM(ImGuiKey, GamepadFaceDown),
	ENUM(ImGuiKey, GamepadDpadLeft),
	ENUM(ImGuiKey, GamepadDpadRight),
	ENUM(ImGuiKey, GamepadDpadUp),
	ENUM(ImGuiKey, GamepadDpadDown),
	ENUM(ImGuiKey, GamepadL1),
	ENUM(ImGuiKey, GamepadR1),
	ENUM(ImGuiKey, GamepadL2),
	ENUM(ImGuiKey, GamepadR2),
	ENUM(ImGuiKey, GamepadL3),
	ENUM(ImGuiKey, GamepadR3),
	ENUM(ImGuiKey, GamepadLStickLeft),
	ENUM(ImGuiKey, GamepadLStickRight),
	ENUM(ImGuiKey, GamepadLStickUp),
	ENUM(ImGuiKey, GamepadLStickDown),
	ENUM(ImGuiKey, GamepadRStickLeft),
	ENUM(ImGuiKey, GamepadRStickRight),
	ENUM(ImGuiKey, GamepadRStickUp),
	ENUM(ImGuiKey, GamepadRStickDown),
	ENUM(ImGuiKey, MouseLeft),
	ENUM(ImGuiKey, MouseRight),
	ENUM(ImGuiKey, MouseMiddle),
	ENUM(ImGuiKey, MouseX1),
	ENUM(ImGuiKey, MouseX2),
	ENUM(ImGuiKey, MouseWheelX),
	ENUM(ImGuiKey, MouseWheelY),
	{ NULL, 0 },
};

static struct enum_pair eConfigFlags[] = {
	ENUM(ImGuiConfigFlags, None),
	ENUM(ImGuiConfigFlags, NavEnableKeyboard),
	ENUM(ImGuiConfigFlags, NavEnableGamepad),
	ENUM(ImGuiConfigFlags, NavEnableSetMousePos),
	ENUM(ImGuiConfigFlags, NavNoCaptureKeyboard),
	ENUM(ImGuiConfigFlags, NoMouse),
	ENUM(ImGuiConfigFlags, NoMouseCursorChange),
	ENUM(ImGuiConfigFlags, DockingEnable),
	ENUM(ImGuiConfigFlags, ViewportsEnable),
	ENUM(ImGuiConfigFlags, DpiEnableScaleViewports),
	ENUM(ImGuiConfigFlags, DpiEnableScaleFonts),
	ENUM(ImGuiConfigFlags, IsSRGB),
	ENUM(ImGuiConfigFlags, IsTouchScreen),
	{ NULL, 0 },
};

//ImGuiBackendFlags

static struct enum_pair eCol[] = {
	ENUM(ImGuiCol, Text),
	ENUM(ImGuiCol, TextDisabled),
	ENUM(ImGuiCol, WindowBg),
	ENUM(ImGuiCol, ChildBg),
	ENUM(ImGuiCol, PopupBg),
	ENUM(ImGuiCol, Border),
	ENUM(ImGuiCol, BorderShadow),
	ENUM(ImGuiCol, FrameBg),
	ENUM(ImGuiCol, FrameBgHovered),
	ENUM(ImGuiCol, FrameBgActive),
	ENUM(ImGuiCol, TitleBg),
	ENUM(ImGuiCol, TitleBgActive),
	ENUM(ImGuiCol, TitleBgCollapsed),
	ENUM(ImGuiCol, MenuBarBg),
	ENUM(ImGuiCol, ScrollbarBg),
	ENUM(ImGuiCol, ScrollbarGrab),
	ENUM(ImGuiCol, ScrollbarGrabHovered),
	ENUM(ImGuiCol, ScrollbarGrabActive),
	ENUM(ImGuiCol, CheckMark),
	ENUM(ImGuiCol, SliderGrab),
	ENUM(ImGuiCol, SliderGrabActive),
	ENUM(ImGuiCol, Button),
	ENUM(ImGuiCol, ButtonHovered),
	ENUM(ImGuiCol, ButtonActive),
	ENUM(ImGuiCol, Header),
	ENUM(ImGuiCol, HeaderHovered),
	ENUM(ImGuiCol, HeaderActive),
	ENUM(ImGuiCol, Separator),
	ENUM(ImGuiCol, SeparatorHovered),
	ENUM(ImGuiCol, SeparatorActive),
	ENUM(ImGuiCol, ResizeGrip),
	ENUM(ImGuiCol, ResizeGripHovered),
	ENUM(ImGuiCol, ResizeGripActive),
	ENUM(ImGuiCol, Tab),
	ENUM(ImGuiCol, TabHovered),
	ENUM(ImGuiCol, TabActive),
	ENUM(ImGuiCol, TabUnfocused),
	ENUM(ImGuiCol, TabUnfocusedActive),
	ENUM(ImGuiCol, DockingPreview),
	ENUM(ImGuiCol, DockingEmptyBg),
	ENUM(ImGuiCol, PlotLines),
	ENUM(ImGuiCol, PlotLinesHovered),
	ENUM(ImGuiCol, PlotHistogram),
	ENUM(ImGuiCol, PlotHistogramHovered),
	ENUM(ImGuiCol, TableHeaderBg),
	ENUM(ImGuiCol, TableBorderStrong),
	ENUM(ImGuiCol, TableBorderLight),
	ENUM(ImGuiCol, TableRowBg),
	ENUM(ImGuiCol, TableRowBgAlt),
	ENUM(ImGuiCol, TextSelectedBg),
	ENUM(ImGuiCol, DragDropTarget),
	ENUM(ImGuiCol, NavHighlight),
	ENUM(ImGuiCol, NavWindowingHighlight),
	ENUM(ImGuiCol, NavWindowingDimBg),
	ENUM(ImGuiCol, ModalWindowDimBg),
	ENUM(ImGuiCol, COUNT),
	{ NULL, 0 },
};

static struct enum_pair eStyleVar[] = {
	ENUM(ImGuiStyleVar, Alpha),
	ENUM(ImGuiStyleVar, DisabledAlpha),
	ENUM(ImGuiStyleVar, WindowPadding),
	ENUM(ImGuiStyleVar, WindowRounding),
	ENUM(ImGuiStyleVar, WindowBorderSize),
	ENUM(ImGuiStyleVar, WindowMinSize),
	ENUM(ImGuiStyleVar, WindowTitleAlign),
	ENUM(ImGuiStyleVar, ChildRounding),
	ENUM(ImGuiStyleVar, ChildBorderSize),
	ENUM(ImGuiStyleVar, PopupRounding),
	ENUM(ImGuiStyleVar, PopupBorderSize),
	ENUM(ImGuiStyleVar, FramePadding),
	ENUM(ImGuiStyleVar, FrameRounding),
	ENUM(ImGuiStyleVar, FrameBorderSize),
	ENUM(ImGuiStyleVar, ItemSpacing),
	ENUM(ImGuiStyleVar, ItemInnerSpacing),
	ENUM(ImGuiStyleVar, IndentSpacing),
	ENUM(ImGuiStyleVar, CellPadding),
	ENUM(ImGuiStyleVar, ScrollbarSize),
	ENUM(ImGuiStyleVar, ScrollbarRounding),
	ENUM(ImGuiStyleVar, GrabMinSize),
	ENUM(ImGuiStyleVar, GrabRounding),
	ENUM(ImGuiStyleVar, TabRounding),
	ENUM(ImGuiStyleVar, TabBarBorderSize),
	ENUM(ImGuiStyleVar, ButtonTextAlign),
	ENUM(ImGuiStyleVar, SelectableTextAlign),
	ENUM(ImGuiStyleVar, SeparatorTextBorderSize),
	ENUM(ImGuiStyleVar, SeparatorTextAlign),
	ENUM(ImGuiStyleVar, SeparatorTextPadding),
	ENUM(ImGuiStyleVar, DockingSeparatorSize),
	ENUM(ImGuiStyleVar, COUNT),
	{ NULL, 0 },
};

//ImGuiButtonFlags

static struct enum_pair eColorEditFlags[] = {
	ENUM(ImGuiColorEditFlags, None),
	ENUM(ImGuiColorEditFlags, NoAlpha),
	ENUM(ImGuiColorEditFlags, NoPicker),
	ENUM(ImGuiColorEditFlags, NoOptions),
	ENUM(ImGuiColorEditFlags, NoSmallPreview),
	ENUM(ImGuiColorEditFlags, NoInputs),
	ENUM(ImGuiColorEditFlags, NoTooltip),
	ENUM(ImGuiColorEditFlags, NoLabel),
	ENUM(ImGuiColorEditFlags, NoSidePreview),
	ENUM(ImGuiColorEditFlags, NoDragDrop),
	ENUM(ImGuiColorEditFlags, NoBorder),
	ENUM(ImGuiColorEditFlags, AlphaBar),
	ENUM(ImGuiColorEditFlags, AlphaPreview),
	ENUM(ImGuiColorEditFlags, AlphaPreviewHalf),
	ENUM(ImGuiColorEditFlags, HDR),
	ENUM(ImGuiColorEditFlags, DisplayRGB),
	ENUM(ImGuiColorEditFlags, DisplayHSV),
	ENUM(ImGuiColorEditFlags, DisplayHex),
	ENUM(ImGuiColorEditFlags, Uint8),
	ENUM(ImGuiColorEditFlags, Float),
	ENUM(ImGuiColorEditFlags, PickerHueBar),
	ENUM(ImGuiColorEditFlags, PickerHueWheel),
	ENUM(ImGuiColorEditFlags, InputRGB),
	ENUM(ImGuiColorEditFlags, InputHSV),
	{ NULL, 0 },
};

static struct enum_pair eSliderFlags[] = {
	ENUM(ImGuiSliderFlags, None),
	ENUM(ImGuiSliderFlags, AlwaysClamp),
	ENUM(ImGuiSliderFlags, Logarithmic),
	ENUM(ImGuiSliderFlags, NoRoundToFormat),
	ENUM(ImGuiSliderFlags, NoInput),
	{ NULL, 0 },
};

static struct enum_pair eMouseButton[] = {
	ENUM(ImGuiMouseButton, Left),
	ENUM(ImGuiMouseButton, Right),
	ENUM(ImGuiMouseButton, Middle),
	ENUM(ImGuiMouseButton, COUNT),
	{ NULL, 0 },
};

static struct enum_pair eMouseCursor[] = {
	ENUM(ImGuiMouseCursor, None),
	ENUM(ImGuiMouseCursor, Arrow),
	ENUM(ImGuiMouseCursor, TextInput),
	ENUM(ImGuiMouseCursor, ResizeAll),
	ENUM(ImGuiMouseCursor, ResizeNS),
	ENUM(ImGuiMouseCursor, ResizeEW),
	ENUM(ImGuiMouseCursor, ResizeNESW),
	ENUM(ImGuiMouseCursor, ResizeNWSE),
	ENUM(ImGuiMouseCursor, Hand),
	ENUM(ImGuiMouseCursor, NotAllowed),
	ENUM(ImGuiMouseCursor, COUNT),
	{ NULL, 0 },
};

static struct enum_pair eDrawFlags[] = {
	ENUM(ImDrawFlags, None),
	ENUM(ImDrawFlags, Closed),
	ENUM(ImDrawFlags, RoundCornersTopLeft),
	ENUM(ImDrawFlags, RoundCornersTopRight),
	ENUM(ImDrawFlags, RoundCornersBottomLeft),
	ENUM(ImDrawFlags, RoundCornersBottomRight),
	ENUM(ImDrawFlags, RoundCornersNone),
	ENUM(ImDrawFlags, RoundCornersTop),
	ENUM(ImDrawFlags, RoundCornersBottom),
	ENUM(ImDrawFlags, RoundCornersLeft),
	ENUM(ImDrawFlags, RoundCornersRight),
	ENUM(ImDrawFlags, RoundCornersAll),
	{ NULL, 0 },
};

static struct enum_pair eDrawListFlags[] = {
	ENUM(ImDrawListFlags, None),
	ENUM(ImDrawListFlags, AntiAliasedLines),
	ENUM(ImDrawListFlags, AntiAliasedLinesUseTex),
	ENUM(ImDrawListFlags, AntiAliasedFill),
	ENUM(ImDrawListFlags, AllowVtxOffset),
	{ NULL, 0 },
};

static struct enum_pair eButtonFlags[] = {
	ENUM(ImGuiButtonFlags, None),
	ENUM(ImGuiButtonFlags, MouseButtonLeft),
	ENUM(ImGuiButtonFlags, MouseButtonRight),
	ENUM(ImGuiButtonFlags, MouseButtonMiddle),
	{ NULL, 0 },
};

//ImGuiMouseSource

//ImGuiCond

//ImFontAtlasFlags

//ImGuiViewportFlags

static struct enum_pair eMod[] = {
	ENUM(ImGuiMod, None),
	ENUM(ImGuiMod, Ctrl),
	ENUM(ImGuiMod, Shift),
	ENUM(ImGuiMod, Alt),
	ENUM(ImGuiMod, Super),
	ENUM(ImGuiMod, Shortcut),
	{ NULL, 0 },
};

void imgui_enum_init(lua_State* L) {
	lua_newtable(L);
	flag_gen(L, "Window", eWindowFlags);
	flag_gen(L, "Child", eChildFlags);
	flag_gen(L, "InputText", eInputTextFlags);
	flag_gen(L, "TreeNode", eTreeNodeFlags);
	flag_gen(L, "Popup", ePopupFlags);
	flag_gen(L, "Selectable", eSelectableFlags);
	flag_gen(L, "Combo", eComboFlags);
	flag_gen(L, "TabBar", eTabBarFlags);
	flag_gen(L, "Table", eTableFlags);
	flag_gen(L, "TableColumn", eTableColumnFlags);
	flag_gen(L, "TableRow", eTableRowFlags);
	flag_gen(L, "Focused", eFocusedFlags);
	flag_gen(L, "Hovered", eHoveredFlags);
	flag_gen(L, "DockNode", eDockNodeFlags);
	flag_gen(L, "DragDrop", eDragDropFlags);
	flag_gen(L, "Config", eConfigFlags);
	flag_gen(L, "ColorEdit", eColorEditFlags);
	flag_gen(L, "Slider", eSliderFlags);
	flag_gen(L, "Draw", eDrawFlags);
	flag_gen(L, "DrawList", eDrawListFlags);
	flag_gen(L, "Button", eButtonFlags);
	lua_setfield(L, -2, "Flags");

	lua_newtable(L);
	enum_gen(L, "TableBgTarget", eTableBgTarget);
	enum_gen(L, "SortDirection", eSortDirection);
	enum_gen(L, "Key", eKey);
	enum_gen(L, "Col", eCol);
	enum_gen(L, "StyleVar", eStyleVar);
	enum_gen(L, "MouseButton", eMouseButton);
	enum_gen(L, "MouseCursor", eMouseCursor);
	enum_gen(L, "Mod", eMod);
	lua_setfield(L, -2, "Enum");
}
