-----------------------------------------------------
--   D U N G E O N S  &  R A I D S  M O D U L E    --
-----------------------------------------------------
root("Instances", tier(TBC_TIER, applyclassicphase(TBC_PHASE_FIVE, {
	inst(752, {	-- Sunwell Plateau
		["lore"] = "Nearly seven thousand years ago, the Highborne were exiled from Kalimdor for refusing to give up arcane magic. Led by Dath'Remar Sunstrider, these elves founded their own kingdom of Quel'Thalas. For millennia the mystical pool of energy known as the Sunwell fueled the potent magic of the exiled high elves. Now, the remnants of this ancient fountain have become the Burning Legion's latest target as the demons prepare to summon their commander, Kil'jaeden, with the Sunwell's energy.",
		["coord"] = { 44.28, 45.71, ISLE_OF_QUELDANAS },	-- Sunwell Plateau, Isle of Quel'Danas
		["maps"] = {
			SUNWELL_PLATEAU,
			336,	-- Shrine of the Eclipse
		},
		["sharedLockout"] = 1,
		["isRaid"] = true,
		["lvl"] = lvlsquish(68, 30, 68),	-- Level 68s could zone in without any attunements. TODO: Check this.
		["groups"] = {
			n(ZONE_DROPS, bubbleDown({
			-- #IF AFTER 10.0
				["_drop"] = { "classes", "c" },
			-- #ENDIF
			},{
				i(35202),	-- Design: Amulet of Flowing Life
				i(35200),	-- Design: Hard Khorium Band
				i(35203),	-- Design: Hard Khorium Choker
				i(35198),	-- Design: Loop of Forged Power
				i(35201),	-- Design: Pendant of Sunfire
				i(35199),	-- Design: Ring of Flowing Life
				i(35218, {	-- Pattern: Carapace of Sun and Shadow
					["spellID"] = 46138,	-- Carapace of Sun and Shadow
					["requireSkill"] = LEATHERWORKING,
					["f"] = RECIPES,
				}),
				i(35217, {	-- Pattern: Embrace of the Phoenix
					["spellID"] = 46137,	-- Embrace of the Phoenix
					["requireSkill"] = LEATHERWORKING,
					["f"] = RECIPES,
				}),
				i(35213, {	-- Pattern: Fletcher's Gloves of the Phoenix
					["spellID"] = 46133,	-- Fletcher's Gloves of the Phoenix
					["requireSkill"] = LEATHERWORKING,
					["f"] = RECIPES,
				}),
				i(35214, {	-- Pattern: Gloves of Immortal Dusk
					["spellID"] = 46134,	-- Gloves of Immortal Dusk
					["requireSkill"] = LEATHERWORKING,
					["f"] = RECIPES,
				}),
				i(35205),	-- Pattern: Hands of Eternal Light
				i(35216, {	-- Pattern: Leather Chestguard of the Sun
					["spellID"] = 46136,	-- Leather Chestguard of the Sun
					["requireSkill"] = LEATHERWORKING,
					["f"] = RECIPES,
				}),
				i(35212, {	-- Pattern: Leather Gauntlets of the Sun
					["spellID"] = 46132,	-- Leather Gauntlets of the Sun
					["requireSkill"] = LEATHERWORKING,
					["f"] = RECIPES,
				}),
				i(35207),	-- Pattern: Robe of Eternal Light
				i(35219, {	-- Pattern: Sun-Drenched Scalee Chestguard
					["spellID"] = 46139,	-- Sun-Drenched Scalee Chestguard
					["requireSkill"] = LEATHERWORKING,
					["f"] = RECIPES,
				}),
				i(35215, {	-- Pattern: Sun-Drenched Scale Gloves
					["spellID"] = 46135,	-- Sun-Drenched Scale Gloves
					["requireSkill"] = LEATHERWORKING,
					["f"] = RECIPES,
				}),
				i(35204),	-- Pattern: Sunfire Handwraps
				i(35206),	-- Pattern: Sunfire Robe
				i(35209),	-- Plans: Hard Khorium Battlefists (RECIPE!)
				i(35211),	-- Plans: Hard Khorium Battleplate (RECIPE!)
				i(35210),	-- Plans: Sunblessed Breastplate (RECIPE!)
				i(35208),	-- Plans: Sunblessed Gauntlets (RECIPE!)
				i(35186),	-- Schematic: Annihilator Holo-Gogs
				i(35196),	-- Schematic: Hard Khorium Goggles
				i(35190),	-- Schematic: Hyper-Magnified Moon Specs
				i(35187),	-- Schematic: Justicebringer 3000 Specs
				i(35193),	-- Schematic: Lightning Etched Specs
				i(35195),	-- Schematic: Mayhem Projection Goggles
				i(35189),	-- Schematic: Powerheal 9000 Lens
				i(35192),	-- Schematic: Primal-Attuned Goggles
				i(35197),	-- Schematic: Quad Deathblow X44 Goggles
				i(35194),	-- Schematic: Surestrike Goggles v3.0
				i(35191),	-- Schematic: Wonderheal XT68 Shades
				i(35273),	-- Study of Advanced Smelting
				-- #if BEFORE MOP
				i(34349, {	-- Blade of Life's Inevitability
					["timeline"] = { "removed 5.0.4.10000" },
				}),
				-- #endif
				i(34350),	-- Gauntlets of the Ancient Shadowmoon
				i(34346),	-- Mounting Vengeance
				i(34183),	-- Shivering Felspine
				i(34351),	-- Tranquil Majesty Wraps
				i(34348),	-- Wand of Cleansing Light
				i(34347),	-- Wand of the Demonsoul
				i(35733),	-- Ring of Harmonic Beauty
				i(32227),	-- Crimson Spinel
				i(32228),	-- Empyrean Sapphire
				i(32229),	-- Lionseye
				i(32231),	-- Pyrestone
				i(32230),	-- Shadowsong Amethyst
				i(32249),	-- Seaspray Emerald
			})),
			n(COMMON_BOSS_DROPS, {
				i(34664, {	-- Sunmote
					["crs"] = {
						24850,	-- Kalecgos
						24892,	-- Sathrovarr the Corruptor
						24882,	-- Brutalus
						25038,	-- Felmyst
						25165,	-- Sacrolash
						25166,	-- Alythess
						25840,	-- Entropius
						25741,	-- M'uru
						25315,	-- Kil'jaeden
					},
				}),
			}),
			e(1591, {	-- Kalecgos
				["crs"] = {
					24850,	-- Kalecgos
					24892,	-- Sathrovarr the Corruptor
				},
				["groups"] = {
					i(34848),	-- Bracers of the Forgotten Conqueror
					i(34851),	-- Bracers of the Forgotten Protector
					i(34852),	-- Bracers of the Forgotten Vanquisher
					i(34164),	-- Dragonscale-Encrusted Longblade
					i(34165),	-- Fang of Kalecgos
					i(34169),	-- Breeches of Natural Aggression
					i(34167),	-- Legplates of the Holy Juggernaut
					i(34170),	-- Pantaloons of Calming Strife
					i(34168),	-- Starstalker Legguards
					i(34166),	-- Band of Lucent Beams
				},
			}),
			e(1592, {	-- Brutallus
				["creatureID"] = 24882,
				["groups"] = {
					i(122113, {	-- Sunblade Rune of Activation (PET!)
						["timeline"] = { "added 6.1.0.19445" },
					}),
					i(34853),	-- Belt of the Forgotten Conqueror
					i(34854),	-- Belt of the Forgotten Protector
					i(34855),	-- Belt of the Forgotten Vanquisher
					i(34176),	-- Reign of Misery
					i(34179),	-- Heart of the Pit
					i(34177),	-- Clutch of Demise
					i(34178),	-- Collar of the Pit Lord
					i(34180),	-- Felfury Legplates
					i(34181),	-- Leggings of Calamity
				},
			}),
			e(1593, {	-- Felmyst
				["creatureID"] = 25038,
				["groups"] = {
					i(34856),	-- Boots of the Forgotten Conqueror
					i(34857),	-- Boots of the Forgotten Protector
					i(34858),	-- Boots of the Forgotten Vanquisher
					i(34182),	-- Grand Magister's Staff of Torrents
					i(34185),	-- Sword Breaker's Bulwark
					i(34184),	-- Brooch of the Highborne
					i(34352),	-- Borderland Fortress Grips
					i(34186),	-- Chain Links of the Tumultuous Storm
					i(34188),	-- Leggings of the Immortal Night
				},
			}),
			e(1594, {	-- The Eredar Twins
				["crs"] = {
					25165,	-- Sacrolash
					25166,	-- Alythess
				},
				["groups"] = {
					i(122115, {	-- Servant's Bell (PET!)
						["timeline"] = { "added 6.1.0.19445" },
					}),
					i(34853),	-- Belt of the Forgotten Conqueror
					i(34854),	-- Belt of the Forgotten Protector
					i(34855),	-- Belt of the Forgotten Vanquisher
					i(34856),	-- Boots of the Forgotten Conqueror
					i(34857),	-- Boots of the Forgotten Protector
					i(34858),	-- Boots of the Forgotten Vanquisher
					i(34848),	-- Bracers of the Forgotten Conqueror
					i(34851),	-- Bracers of the Forgotten Protector
					i(34852),	-- Bracers of the Forgotten Vanquisher
					i(34198),	-- Stanchion of Primal Intellect
					i(34199),	-- Archon's Gavel
					i(34203),	-- Grip of Mannoroth
					i(34197),	-- Shiv of Exsanguination
					i(34196),	-- Golden Bow of Quel'Thalas
					i(34206),	-- Book of Highborne Hymns
					i(34204),	-- Amulet of Unfettered Magics
					i(35290),	-- Sin'dorei Pendant of Conquest
					i(35291),	-- Sin'dorei Pendant of Salvation
					i(35292),	-- Sin'dorei Pendant of Triumph
					i(34210),	-- Amice of the Convoker
					i(34208),	-- Equilibrium Epaulets
					i(34194),	-- Mantle of the Golden Forest
					i(34192),	-- Pauldrons of Perseverance
					i(34202),	-- Shawl of Wonderment
					i(34195),	-- Shoulderpads of Vehemence
					i(34209),	-- Spaulders of Reclamation
					i(34193),	-- Spaulders of the Thalassian Savior
					i(34190),	-- Crimson Paragon's Cover
					i(34205),	-- Shroud of Redeemed Souls
					i(34189),	-- Band of Ruinous Delight
				},
			}),
			e(1595, {	-- M'uru
				["crs"] = {
					25840,	-- Entropius
					25741,	-- M'uru
				},
				["groups"] = {
					i(175160, {	-- Holy Relic (Bag of Tricks addition)
						["races"] = { VULPERA },
						["questID"] = 59035,
						["timeline"] = { "added 8.3.0.33115" },
						["ignoreBonus"] = true,
					}),
					i(122114, {	-- Void Collar (PET!)
						["timeline"] = { "added 6.1.0.19445" },
					}),
					i(34214),	-- Muramasa
					i(34231),	-- Aegis of Angelic Fortune (MISSING IN ADVENTURE GUIDE)
					i(34232),	-- Fel Conqueror Raiments (MISSING IN ADVENTURE GUIDE)
					i(34229),	-- Garments of Serene Shores
					i(34211),	-- Harness of Carnal Instinct
					i(34216),	-- Heroic Judicator's Chestguard
					i(34233),	-- Robes of Faltered Light (MISSING IN ADVENTURE GUIDE)
					i(34212),	-- Sunglow Vest
					i(34228),	-- Vicious Hawkstrider Hauberk
					i(34215),	-- Warharness of Reckless Fury
					i(34240),	-- Gauntlets of the Soothed Soul (MISSING IN ADVENTURE GUIDE)
					i(34234),	-- Shadowed Gauntlets of Paroxysm (MISSING IN ADVENTURE GUIDE)
					i(34213),	-- Ring of Hardened Resolve
					i(34230),	-- Ring of Omnipotence
					i(35282),	-- Sin'dorei Band of Dominance
					i(35283),	-- Sin'dorei Band of Salvation
					i(35284),	-- Sin'dorei Band of Triumph
					i(34427),	-- Blackened Naaru Sliver
					i(34430),	-- Glimmering Naaru Sliver
					i(34429),	-- Shifting Naaru Sliver
					i(34428),	-- Steely Naaru Sliver
				},
			}),
			e(1596, {	-- Kil'jaeden
				["creatureID"] = 25315,
				["groups"] = {
					ach(698),	-- Sunwell Plateau
					classicAch(725, {	-- Thori'dal, the Stars' Fury
						["provider"] = { "i", 34334 },	-- Thori'dal, the Stars' Fury
						["classes"] = { WARRIOR, ROGUE, HUNTER },
						-- #if BEFORE WRATH
						["description"] = "Obtain Thori'dal, the Stars' Fury from Kil'jaeden in Sunwell Plateau.",
						["OnUpdate"] = [[_.CommonAchievementHandlers.ANY_ITEM_PROVIDER]],
						-- #else
						["description"] = "You must equip the bow to earn this achievement.",
						-- #endif
					}),
					i(34334),	-- Thori'dal, the Stars' Fury (LEGENDARY!)
					i(34247),	-- Apolyon, the Soul-Render
					i(34337),	-- Golden Staff of the Sin'dorei
					i(34329),	-- Crux of the Apocalypse
					i(34335),	-- Hammer of Sanctification
					i(34331),	-- Hand of the Deceiver
					i(34336),	-- Sunfire
					i(34333),	-- Coif of Alleria
					i(34245),	-- Cover of Ursol the Wise
					i(34332),	-- Cowl of Gul'dan
					i(34339),	-- Cowl of Light's Purity
					i(34345),	-- Crown of Anasterian
					i(34340),	-- Dark Conjuror's Collar
					i(34244),	-- Duplicitous Guise
					i(34243),	-- Helm of Burning Righteousness
					i(34241),	-- Cloak of Unforgivable Sin
					i(34242),	-- Tattered Cape of Antonidas
					i(34341),	-- Borderland Paingrips
					i(34344),	-- Handgrips of Defiled Worlds
					i(34342),	-- Handguards of the Dawn
					i(34343),	-- Thalassian Ranger Gauntlets
				},
			}),
		},
	}),
})));