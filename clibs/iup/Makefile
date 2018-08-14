include common.mk

INCLUDES = include src
INCLUDES += src/win

# Windows XP minimum
WIN32VER = 0x0501

DEFINES = _WIN32_WINNT=$(WIN32VER) _WIN32_IE=0x600 WINVER=$(WIN32VER) UNICODE IUP_DLL

all : iup.exe | scintilla.dll iupluaimglib.dll iupluacontrols.dll

SRCIUP = iup_array.c iup_callback.c iup_dlglist.c iup_attrib.c iup_focus.c iup_font.c \
      iup_globalattrib.c iup_object.c iup_key.c iup_layout.c iup_ledlex.c iup_names.c \
      iup_ledparse.c iup_predialogs.c iup_register.c iup_scanf.c iup_show.c iup_str.c \
      iup_func.c iup_childtree.c iup.c iup_classattrib.c iup_dialog.c iup_assert.c \
      iup_messagedlg.c iup_timer.c iup_image.c iup_label.c iup_fill.c iup_zbox.c \
      iup_colordlg.c iup_fontdlg.c iup_filedlg.c iup_strmessage.c iup_menu.c iup_frame.c \
      iup_user.c iup_button.c iup_radio.c iup_toggle.c iup_progressbar.c iup_text.c iup_val.c \
      iup_box.c iup_hbox.c iup_vbox.c iup_cbox.c iup_class.c iup_classbase.c iup_maskmatch.c \
      iup_mask.c iup_maskparse.c iup_tabs.c iup_spin.c iup_list.c iup_getparam.c iup_link.c \
      iup_sbox.c iup_scrollbox.c iup_normalizer.c iup_tree.c iup_split.c iup_layoutdlg.c \
      iup_recplay.c iup_progressdlg.c iup_expander.c iup_open.c iup_table.c iup_canvas.c \
      iup_gridbox.c iup_detachbox.c iup_backgroundbox.c iup_linefile.c iup_config.c \
      iup_flatbutton.c iup_animatedlabel.c iup_draw.c iup_flatframe.c iup_flattabs.c \
      iup_flatscrollbar.c iup_flatscrollbox.c iup_dial.c iup_gauge.c iup_colorbar.c \
      iup_colorbrowser.c iup_colorhsi.c iup_flatlabel.c iup_flatseparator.c iup_flattoggle.c \
      iup_dropbutton.c iup_space.c iup_multibox.c

SRCWIN += iupwin_common.c iupwin_brush.c iupwin_focus.c iupwin_font.c \
      iupwin_globalattrib.c iupwin_handle.c iupwin_key.c iupwin_str.c \
      iupwin_loop.c iupwin_open.c iupwin_tips.c iupwin_info.c \
      iupwin_dialog.c iupwin_messagedlg.c iupwin_timer.c \
      iupwin_image.c iupwin_label.c iupwin_canvas.c iupwin_frame.c \
      iupwin_fontdlg.c iupwin_filedlg.c iupwin_dragdrop.c \
      iupwin_button.c iupwin_draw.c iupwin_toggle.c iupwin_clipboard.c \
      iupwin_progressbar.c iupwin_text.c iupwin_val.c iupwin_touch.c \
      iupwin_tabs.c iupwin_menu.c iupwin_list.c iupwin_tree.c \
      iupwin_calendar.c iupwin_datepick.c iupwin_draw_gdi.c
 
SRCWIN += iupwindows_main.c iupwindows_help.c iupwindows_info.c

OBJIUP := $(patsubst %.c,$(ODIR)/%.o,$(SRCIUP))
OBJWIN := $(patsubst %.c,$(ODIR)/%.o,$(SRCWIN))

COMPILE = $(CC) -c -o $@ $< $(CFLAGS) $(addprefix -I$(IUPSRC)/,$(INCLUDES)) $(addprefix -D,$(DEFINES))

# IUP lua warpper

CTRLUA = button.lua canvas.lua dialog.lua colordlg.lua clipboard.lua \
       filedlg.lua fill.lua frame.lua hbox.lua normalizer.lua gridbox.lua \
       item.lua image.lua imagergb.lua imagergba.lua label.lua expander.lua \
       link.lua menu.lua multiline.lua list.lua separator.lua user.lua \
       submenu.lua text.lua toggle.lua vbox.lua zbox.lua timer.lua \
       sbox.lua scrollbox.lua split.lua spin.lua spinbox.lua cbox.lua \
       radio.lua val.lua tabs.lua fontdlg.lua tree.lua progressbar.lua \
       messagedlg.lua progressdlg.lua backgroundbox.lua flatbutton.lua \
       animatedlabel.lua calendar.lua datepick.lua param.lua parambox.lua \
       detachbox.lua flatframe.lua flattabs.lua flatscrollbox.lua \
       dial.lua gauge.lua colorbar.lua colorbrowser.lua flatlabel.lua \
       flatseparator.lua flattoggle.lua dropbutton.lua space.lua multibox.lua

SRCLUA = iuplua.lua constants.lua iup_config.lua

GC := $(patsubst %.lua,$(ODIR)/il_%.c,$(CTRLUA))

$(GC) : $(ODIR)/il_%.c : $(IUPSRC)/srclua5/elem/%.lua iupgen.lua
	$(LUABIN) iupgen.lua $< $@

LH := $(patsubst %.lua,$(ODIR)/%.lh,$(SRCLUA))

$(LH) : $(ODIR)/%.lh : $(IUPSRC)/srclua5/%.lua bin2c.lua
	$(LUABIN) bin2c.lua $< > $@

IUPLUASRC = iuplua.c iuplua_api.c iuplua_draw.c iuplua_tree_aux.c iuplua_scanf.c \
      iuplua_getparam.c iuplua_getcolor.c iuplua_config.c

OBJIUPLUA := $(patsubst %.c,$(ODIR)/%.o,$(IUPLUASRC))
OBJCTRL := $(patsubst %.lua,$(ODIR)/il_%.o,$(CTRLUA))

$(OBJIUPLUA) : $(ODIR)/%.o : $(IUPSRC)/srclua5/%.c $(LH)  | $(ODIR)
	$(CC) $(CFLAGS) -c -o $@ $< -DIUPLUA_USELH -I$(IUPSRC)/include -I$(IUPSRC)/src -I$(ODIR) -I$(IUPSRC)/srclua5 $(LUAINC)

$(OBJCTRL) : %.o : %.c  | $(ODIR)
	$(CC) $(CFLAGS) -c -o $@ $< -I$(IUPSRC)/include -I$(IUPSRC)/srclua5 $(LUAINC)						

# all

$(ODIR) :
	mkdir $@

$(OBJIUP): $(ODIR)/%.o: $(IUPSRC)/src/%.c | $(ODIR)
	$(COMPILE)

$(OBJWIN): $(ODIR)/%.o: $(IUPSRC)/src/win/%.c | $(ODIR)
	$(COMPILE)

$(ODIR)/libiup.a : $(OBJIUP) $(OBJWIN) $(OBJIUPLUA) $(OBJCTRL)
	$(AR) $@ $^

scintilla.dll : luaiup.dll
	$(MAKE) -f Makefile.scintilla

iupluaimglib.dll : luaiup.dll
	$(MAKE) -f Makefile.imglib

iupluacontrols.dll : luaiup.dll
	$(MAKE) -f Makefile.controls

luaiup.dll : $(OBJIUP) $(OBJWIN) $(OBJIUPLUA) $(OBJCTRL) 
	$(CC) --shared -o $@ $^ -lgdi32 -lcomdlg32 -lcomctl32 -lole32 -luuid $(LUALIB)

iup.exe : iupmain.c | luaiup.dll
	gcc $(CFLAGS) -o $@ $^ -I$(IUPSRC)/include $(LUAINC) $(LUALIB) -L. -lluaiup -mwindows

clean :
	rm -rf $(ODIR) && rm -f *.exe && rm -f *.dll
