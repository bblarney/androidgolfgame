extends RefCounted
# Shared in-game UI design tokens + StyleBox factories for the broadcast-style HUD.
# Centralizes colours and the dark-translucent "card" look so the HUD labels, club rail,
# scorebug, aim indicator and tournament bug all read as one cohesive overlay rather than a
# scatter of independently-styled elements. Pull in with:  const UI := preload(".../ui_palette.gd")
# then reference UI.INK, UI.card_style(), etc. Reuses the StyleBoxFlat idiom already used by
# pro_shop.gd / clubhouse.gd.

# --- Typography -------------------------------------------------------------
# Oswald (SIL OFL) -- a condensed sports-broadcast face. _draw()-based UI passes this to
# draw_string() instead of ThemeDB.fallback_font so procedural text matches the node-based text
# that picks the same font up through the project default theme (assets/ui/theme.tres).
const FONT_PATH := "res://assets/fonts/Oswald-VariableFont_wght.ttf"
static var FONT : Font = load(FONT_PATH)

# --- Colour tokens ----------------------------------------------------------
const INK     := Color(0.95, 0.98, 0.85)        # primary cream text
const SUBINK  := Color(0.70, 0.80, 0.68)        # muted secondary text / labels
const PANEL   := Color(0.05, 0.10, 0.07, 0.82)  # translucent dark-green card fill
const BORDER  := Color(0.20, 0.32, 0.24, 0.90)  # subtle card edge
const ACCENT  := Color(1.00, 0.85, 0.25)        # broadcast gold
const ON_GOLD := Color(0.08, 0.11, 0.06)        # dark ink for text sitting on a gold fill
const DANGER  := Color(1.00, 0.55, 0.45)        # coral (cut line / penalty)
const HAZARD  := Color(0.55, 0.82, 1.00)        # water-hazard blue
const SHADOW  := Color(0.00, 0.00, 0.00, 0.35)

# Front-end screens (menu / shop / clubhouse / tournament / tutorial) sit on a solid background
# rather than over the 3D course, so they use opaque cards instead of the translucent HUD PANEL.
const PANEL_SOLID := Color(0.12, 0.20, 0.15)    # opaque card fill
const EDGE        := Color(0.20, 0.32, 0.24)    # opaque card border
const METER       := Color(0.55, 0.82, 0.45)    # stat-bar / progress fill

# Lie colours by surface -- single source of truth shared by the HUD info card (was inlined in
# hole_manager.gd) and any future UI that reports the lie.
const LIE_COLORS := {
	"tee":     Color(0.85, 0.95, 0.80),
	"green":   Color(0.55, 1.00, 0.55),
	"fairway": Color(0.70, 0.92, 0.55),
	"sand":    Color(0.95, 0.86, 0.55),
	"rough":   Color(0.55, 0.72, 0.38),
}

static func lie_color(surface: String) -> Color:
	return LIE_COLORS.get(surface, LIE_COLORS["rough"])

# --- StyleBox factories -----------------------------------------------------
# Rounded translucent panel with a soft drop shadow. When accent_left > 0 a gold bar runs down
# the left edge (the broadcast "lower third" look) and the content inset grows to clear it;
# otherwise a faint border traces all four sides.
static func card_style(accent_left: float = 0.0, radius: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16.0
	box.content_margin_right = 18.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 12.0
	box.shadow_color = SHADOW
	box.shadow_size = 6
	if accent_left > 0.0:
		# StyleBoxFlat has one border colour, so a gold left bar means no other borders.
		box.border_color = ACCENT
		box.border_width_left = int(accent_left)
		box.content_margin_left = 16.0 + accent_left
	else:
		box.border_color = BORDER
		box.set_border_width_all(1)
	return box

# Pill-shaped button fill. Active = solid gold (with dark ink), inactive = translucent card.
static func pill_button_style(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	box.set_border_width_all(1)
	if active:
		box.bg_color = ACCENT
		box.border_color = ACCENT.lightened(0.15)
	else:
		box.bg_color = PANEL
		box.border_color = BORDER
	return box

# Opaque card for front-end screens (menu/shop/clubhouse/tournament/tutorial), parameterised so
# each screen keeps its own border colour, corner radius and inner margin.
static func solid_card_style(border_col: Color = EDGE, radius: int = 10, margin: float = 16.0, border_w: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_SOLID
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border_w)
	box.border_color = border_col
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box

# Apply the full pill look (all states + font colours + font) to a Button in one call. Covers the
# normal/hover/pressed/disabled states so a styled button never falls back to Godot's grey default.
static func style_button(btn: Button, active: bool) -> void:
	btn.add_theme_stylebox_override("normal", pill_button_style(active))
	# Inactive buttons gain a gold edge on hover for feedback; active ones already read gold.
	var hover := pill_button_style(active)
	if not active:
		hover.border_color = ACCENT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pill_button_style(true))
	var disabled := pill_button_style(false)
	disabled.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, 0.35)
	disabled.border_color = Color(BORDER.r, BORDER.g, BORDER.b, 0.4)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink : Color = ON_GOLD if active else INK
	btn.add_theme_color_override("font_color", ink)
	btn.add_theme_color_override("font_hover_color", ink.lightened(0.1))
	btn.add_theme_color_override("font_pressed_color", ON_GOLD)
	btn.add_theme_color_override("font_disabled_color", SUBINK.darkened(0.25))
	btn.add_theme_font_override("font", FONT)
