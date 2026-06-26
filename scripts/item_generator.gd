class_name ItemGenerator
extends RefCounted

# Procedural generator for pro-shop clubs and balls. All output is plain JSON-serialisable
# dicts (colours as [r,g,b] arrays) matching the schema in data/clubs.json + data/balls.json,
# plus the extra visual / ball-stat fields the shop introduces. Pure static logic -- no state
# beyond the monotonic id counter it bumps on SaveManager.

const RARITIES := ["common", "uncommon", "rare", "legendary"]

# Rarity roll weights, indexed like RARITIES. The mystery box deliberately skews rarer so the
# gamble is worth its flat price.
const STANDARD_WEIGHTS := [55, 30, 12, 3]
const BOX_WEIGHTS       := [25, 35, 28, 12]

const PRICES := {"common": 250, "uncommon": 750, "rare": 2500, "legendary": 8000}
const BOX_PRICE := 1500

# Per-rarity "quality" window. q in [0,1] biases power up toward the per-type cap and tightens
# spread. The windows OVERLAP on purpose: a lucky common can out-roll a poor uncommon (e.g. an
# iron that flirts with driver power), but can never reach a legendary's ceiling. "mythic" is the
# tournament-only top tier (see the MYTHIC_* boost below); it never rolls in the shop.
const QUALITY := {
	"common":    [0.00, 0.45],
	"uncommon":  [0.25, 0.65],
	"rare":      [0.50, 0.85],
	"legendary": [0.75, 1.00],
	"mythic":    [1.00, 1.00],
}

# Tournament-only "Mythic" tier, awarded for winning a tournament and never sold. Its key stats
# are forced past the per-type legendary ceiling so a Mythic always out-rolls anything the shop
# can offer.
const MYTHIC_POWER_MULT  := 1.15   # club power, as a multiple of the type's hard cap
const MYTHIC_SPREAD_MULT := 0.6    # club spread, tighter than the tightest legendary

# Club type pick weights (putters are mostly functional, so they show up less). The no-putter
# variant is used for Mythic prizes so the headline reward always swings for distance.
const CLUB_TYPE_WEIGHTS           := {"driver": 28, "iron": 30, "wedge": 30, "putter": 12}
const CLUB_TYPE_WEIGHTS_NO_PUTTER := {"driver": 28, "iron": 30, "wedge": 30}

# Per-type stat baselines. power: [lo, hi] base roll, lifted toward `cap` by quality -- `cap`
# is the hard ceiling (a wedge can never reach driver power; a lucky iron can graze it).
# spread: [loose, tight] -- quality interpolates toward the tight (accurate) end.
const CLUB_BASE := {
	"driver": {"power": [55.0, 70.0], "cap": 88.0, "spread": [13.0, 5.0], "launch": [18.0, 24.0], "spin": [0.05, 0.30], "backspin": [0.0, 0.0]},
	"iron":   {"power": [38.0, 48.0], "cap": 62.0, "spread": [6.0, 1.5],  "launch": [35.0, 40.0], "spin": [0.25, 0.50], "backspin": [0.0, 6.0]},
	"wedge":  {"power": [22.0, 30.0], "cap": 34.0, "spread": [4.0, 2.0],  "launch": [40.0, 48.0], "spin": [0.50, 0.85], "backspin": [14.0, 28.0]},
	"putter": {"power": [19.0, 22.0], "cap": 22.0, "spread": [0.8, 0.4],  "launch": [0.0, 0.0],   "spin": [0.0, 0.0],   "backspin": [0.0, 0.0]},
}

const CLUB_NOUNS := {"driver": "Driver", "iron": "Iron", "wedge": "Wedge", "putter": "Putter"}

const CLUB_ADJ := {
	"common":    ["Standard", "Range", "Worn", "Basic", "Trusty"],
	"uncommon":  ["Tuned", "Balanced", "Crafted", "Swift", "Keen"],
	"rare":      ["Blazing", "Precision", "Tour", "Vortex", "Eclipse"],
	"legendary": ["Mythic", "Ascendant", "Celestial", "Phoenix", "Sovereign"],
	"mythic":    ["Excalibur", "Worldbreaker", "Olympian", "Apex", "Zenith"],
}

# Ball archetypes -- each is a coherent playstyle. `sig` is the signature stat that rarity
# pushes toward its extreme (`sig_hi` = whether higher is the strong direction). hue is the
# base colour family. backspin_mod multiplies the club's backspin; backspin_add is flat bite
# applied on ANY club (so a Spinner ball still checks off a driver).
const BALL_ARCHETYPES := [
	{"name": "Power",    "weight": 25, "dist": [1.20, 1.60], "air": [0.015, 0.04], "roll": [2.4, 3.0], "bsmod": [0.8, 1.0], "bsadd": [0.0, 0.0],  "sig": "dist",  "hue": [0.00, 0.08], "sat": [0.7, 0.9], "adj": ["Rocket", "Cannon", "Bomber", "Boomstick"]},
	{"name": "Spinner",  "weight": 25, "dist": [0.90, 1.05], "air": [0.05, 0.08],  "roll": [2.8, 3.5], "bsmod": [1.3, 1.8], "bsadd": [6.0, 14.0], "sig": "spin",  "hue": [0.28, 0.42], "sat": [0.6, 0.85], "adj": ["Biter", "Gripper", "Backspin", "Zip"]},
	{"name": "Roller",   "weight": 25, "dist": [1.00, 1.15], "air": [0.03, 0.05],  "roll": [1.4, 2.0], "bsmod": [0.6, 0.9], "bsadd": [0.0, 0.0],  "sig": "roll",  "hue": [0.55, 0.66], "sat": [0.6, 0.85], "adj": ["Runner", "Glider", "Cruiser", "Roller"]},
	{"name": "Balanced", "weight": 25, "dist": [0.95, 1.10], "air": [0.04, 0.06],  "roll": [2.2, 2.8], "bsmod": [0.9, 1.1], "bsadd": [0.0, 0.0],  "sig": "dist",  "hue": [0.10, 0.16], "sat": [0.0, 0.12], "adj": ["Tour", "Classic", "Standard", "Pro"]},
]

const RARITY_PREFIX := {"rare": "Tour", "legendary": "Mythic", "mythic": "Mythic"}


# --- Public API -------------------------------------------------------------

# Tournament prizes. A Mythic is a notch above legendary on the stats that matter, and excludes
# putters so the reward always swings big.
static func generate_mythic_club() -> Dictionary:
	return generate_club("mythic", false)

static func generate_mythic_ball() -> Dictionary:
	return generate_ball("mythic")


static func roll_rarity(weights: Array) -> String:
	var total: int = 0
	for w in weights:
		total += int(w)
	var pick: int = randi() % maxi(total, 1)
	for i in range(RARITIES.size()):
		pick -= int(weights[i])
		if pick < 0:
			return RARITIES[i]
	return RARITIES[0]

static func price_for(rarity: String) -> int:
	return int(PRICES.get(rarity, 250))

static func next_id(prefix: String) -> String:
	var n: int = int(SaveManager.data.get("gen_counter", 0)) + 1
	SaveManager.data["gen_counter"] = n
	return "%s_%d" % [prefix, n]


static func generate_club(rarity: String, allow_putter: bool = true) -> Dictionary:
	var type: String = _weighted_key(CLUB_TYPE_WEIGHTS if allow_putter else CLUB_TYPE_WEIGHTS_NO_PUTTER)
	var base: Dictionary = CLUB_BASE[type]
	var q: float = _quality(rarity)

	# Power: blend a base random with quality, then map onto [lo .. cap].
	var pt: float = clampf(randf() * 0.6 + q * 0.6, 0.0, 1.0)
	var power: float = lerp(base["power"][0], base["cap"], pt)

	# Spread: quality tightens toward the accurate end.
	var st: float = clampf(randf() * 0.5 + q * 0.7, 0.0, 1.0)
	var spread: float = lerp(base["spread"][0], base["spread"][1], st)

	var spin: float = randf_range(base["spin"][0], base["spin"][1])
	var launch: float = randf_range(base["launch"][0], base["launch"][1])
	var bst: float = clampf(randf() * 0.6 + q * 0.5, 0.0, 1.0)
	var backspin: float = lerp(base["backspin"][0], base["backspin"][1], bst)

	# Mythic forces power past the type's hard cap and spread below the legendary band, so the
	# prize is unmistakably stronger than anything the shop sells.
	if rarity == "mythic":
		power = base["cap"] * MYTHIC_POWER_MULT
		spread = base["spread"][1] * MYTHIC_SPREAD_MULT
		backspin = base["backspin"][1]

	var colors: Dictionary = _club_colors()
	var def := {
		"id": next_id("gen_club"),
		"name": _club_name(type, rarity),
		"type": type,
		"rarity": rarity,
		"power": snappedf(power, 0.1),
		"spread": snappedf(spread, 0.1),
		"spin": snappedf(spin, 0.01),
		"launch_angle": snappedf(launch, 0.1),
		"backspin": snappedf(backspin, 0.1),
		"description": _club_desc(type, power, spread, backspin),
		"colors": colors["colors"],
		"pattern": colors["pattern"],
	}
	return def


static func generate_ball(rarity: String) -> Dictionary:
	var arch: Dictionary = _weighted_archetype()
	var q: float = _quality(rarity)

	var dist: float = randf_range(arch["dist"][0], arch["dist"][1])
	var air: float = randf_range(arch["air"][0], arch["air"][1])
	var roll: float = randf_range(arch["roll"][0], arch["roll"][1])
	var bsmod: float = randf_range(arch["bsmod"][0], arch["bsmod"][1])
	var bsadd: float = randf_range(arch["bsadd"][0], arch["bsadd"][1])

	# Rarity pushes the signature stat toward its strong extreme.
	match arch["sig"]:
		"dist":
			dist = lerp(dist, arch["dist"][1], q * 0.8)
			air = lerp(air, arch["air"][0], q * 0.6)
		"spin":
			bsmod = lerp(bsmod, arch["bsmod"][1], q * 0.8)
			bsadd = lerp(bsadd, arch["bsadd"][1], q * 0.8)
		"roll":
			roll = lerp(roll, arch["roll"][0], q * 0.8)

	# Mythic pushes every "good" direction past its archetype band: more carry, less drag, and a
	# touch more bite, so the prize plays a class above the shop's legendaries.
	if rarity == "mythic":
		dist = maxf(dist, arch["dist"][1]) * 1.08
		air = minf(air, arch["air"][0]) * 0.85
		bsmod = maxf(bsmod, arch["bsmod"][1])

	var hue: float = randf_range(arch["hue"][0], arch["hue"][1])
	var sat: float = randf_range(arch["sat"][0], arch["sat"][1])
	var col := Color.from_hsv(hue, sat, randf_range(0.85, 1.0))
	var col2 := Color.from_hsv(fmod(hue + 0.5, 1.0), clampf(sat + 0.2, 0.0, 1.0), randf_range(0.5, 0.85))
	var pattern: String = ["solid", "stripe", "spots", "two_tone"][randi() % 4]

	var def := {
		"id": next_id("gen_ball"),
		"name": _ball_name(arch, rarity),
		"rarity": rarity,
		"color": _rgb(col),
		"color2": _rgb(col2),
		"pattern": pattern,
		"distance_modifier": snappedf(dist, 0.01),
		"air_resistance": snappedf(air, 0.001),
		"roll_resistance": snappedf(roll, 0.01),
		"backspin_mod": snappedf(bsmod, 0.01),
		"backspin_add": snappedf(bsadd, 0.1),
		"description": _ball_desc(arch),
	}
	return def


# --- Internals --------------------------------------------------------------

static func _quality(rarity: String) -> float:
	var w: Array = QUALITY.get(rarity, [0.0, 0.45])
	return randf_range(w[0], w[1])

static func _weighted_key(weights: Dictionary) -> String:
	var total: int = 0
	for k in weights:
		total += int(weights[k])
	var pick: int = randi() % maxi(total, 1)
	for k in weights:
		pick -= int(weights[k])
		if pick < 0:
			return k
	return weights.keys()[0]

static func _weighted_archetype() -> Dictionary:
	var total: int = 0
	for a in BALL_ARCHETYPES:
		total += int(a["weight"])
	var pick: int = randi() % maxi(total, 1)
	for a in BALL_ARCHETYPES:
		pick -= int(a["weight"])
		if pick < 0:
			return a
	return BALL_ARCHETYPES[0]

static func _club_name(type: String, rarity: String) -> String:
	var adjs: Array = CLUB_ADJ.get(rarity, CLUB_ADJ["common"])
	var noun: String = CLUB_NOUNS.get(type, "Club")
	if type == "driver" and randf() < 0.35:
		noun = "Wood"
	return "%s %s" % [adjs[randi() % adjs.size()], noun]

static func _ball_name(arch: Dictionary, rarity: String) -> String:
	var adjs: Array = arch["adj"]
	var base: String = "%s Ball" % adjs[randi() % adjs.size()]
	if RARITY_PREFIX.has(rarity):
		return "%s %s" % [RARITY_PREFIX[rarity], base]
	return base

static func _club_desc(type: String, power: float, spread: float, backspin: float) -> String:
	if backspin > 16.0:
		return "Bites hard and stops on a dime."
	if type == "iron" and power > 52.0:
		return "An iron that swings like a driver."
	if spread < 3.0:
		return "Pinpoint accuracy on every swing."
	if power > 75.0:
		return "Absolutely bombs it off the tee."
	return "A dependable %s." % type

static func _ball_desc(arch: Dictionary) -> String:
	match arch["name"]:
		"Power":   return "Explosive carry on every shot."
		"Spinner": return "Heavy backspin -- checks up fast on the green."
		"Roller":  return "Low spin, runs out for miles."
		_:         return "A well-rounded, predictable ball."

# Randomised club palette. Head takes a saturated hue; shaft a tinted metal; grip dark; accent
# is a complementary hue. ~40% become a two-tone finish (accent band on the head).
static func _club_colors() -> Dictionary:
	var hue: float = randf()
	var head := Color.from_hsv(hue, randf_range(0.35, 0.8), randf_range(0.35, 0.7))
	var accent := Color.from_hsv(fmod(hue + 0.5, 1.0), randf_range(0.4, 0.85), randf_range(0.6, 0.95))
	var shaft := Color.from_hsv(hue, randf_range(0.0, 0.25), randf_range(0.55, 0.85))
	var two_tone: bool = randf() < 0.4
	var colors := {
		"shaft": _rgb(shaft),
		"grip": [0.08, 0.08, 0.08],
		"head": _rgb(head),
		"accent": _rgb(accent),
		"head_rough": snappedf(randf_range(0.2, 0.7), 0.01),
		"head_metal": snappedf(randf_range(0.2, 0.9), 0.01),
	}
	return {"colors": colors, "pattern": "two_tone" if two_tone else "solid"}

static func _rgb(c: Color) -> Array:
	return [snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001)]
