---------------------------------------------------
--          Z O N E S        M O D U L E         --
---------------------------------------------------
local BLOOD_FOR_BLOOD_GROUPS = applyclassicphase(TBC_PHASE_ONE, {
	i(30809),	-- Mark of Sargeras
	i(30810),	-- Sunfury Signet
});
-- The following recipes and gems go through a lot of changes between TBC and Cata.
local JEWELCRAFTING_PATTERNS = {
	i(23131),	-- Design: Bold Blood Garnet (Both)
	-- #if BEFORE CATA
	i(28596),	-- Design: Bright Blood Garnet [TBC] / Design: Delicate Blood Garnet [Cata+]
	-- #endif
	-- #if BEFORE CATA
	i(23130),	-- Design: Brilliant Blood Garnet [Cata+] / Design: Teardrop Blood Garnet (TBC)
	-- #endif
	-- #if AFTER CATA
	i(23148),	-- Design: Brilliant Blood Garnet [Cata+] / Design: Brilliant Golden Draenite [TBC]
	-- #endif
	-- #if BEFORE CATA
	i(23148),	-- Design: Brilliant Golden Draenite [TBC] / Design: Brilliant Blood Garnet [Cata+]
	-- #endif
	-- #if AFTER CATA
	i(28596),	-- Design: Delicate Blood Garnet [Cata+] / Design: Bright Blood Garnet [TBC]
	-- #endif
	i(23137),	-- Design: Glinting Flame Spessarite [TBC] / Design: Glinting Shadow Draenite [CATA+]
	-- #if BEFORE CATA
	i(23144),	-- Design: Glowing Shadow Draenite [TBC] / Design: Timeless Shadow Draenite [Cata+]
	-- #endif
	i(23135),	-- Design: Inscribed Flame Spessarite (Both)
	i(23141),	-- Design: Jagged Deep Peridot (Both)
	i(23140),	-- Design: Radiant Deep Peridot (Both)
	i(23151),	-- Design: Rigid Azure Moonstone [Cata+] / Design: Rigid Golden Draenite [TBC]
	i(28291),	-- Design: Smooth Golden Draenite (Both)
	i(23152),	-- Design: Solid Azure Moonstone (Both)
	i(23147),	-- Design: Sovereign Shadow Draenite (Both)
	i(23153),	-- Design: Sparkling Azure Moonstone (Both)
	-- #if AFTER CATA
	i(23130),	-- Design: Teardrop Blood Garnet [TBC] / Design: Brilliant Blood Garnet [Cata+]
	-- #endif
	-- #if AFTER CATA
	i(23144),	-- Design: Timeless Shadow Draenite [Cata+] / Design: Glowing Shadow Draenite [TBC]
	-- #endif
};
local VENDOR_GEMS = {
	i(28458),	-- Bold Tourmaline (Both)
	i(28462, {	-- Bright Tourmaline (TBC) / Delicate Tourmaline (Cata+)
		["timeline"] = { "removed 4.0.1.10000" },
	}),
	i(28459),	-- Delicate Tourmaline (Both)
	i(28461),	-- Runed Tourmaline (TBC) / Brilliant Tourmaline (Cata+)
	i(28460, {	-- Teardrop Tourmaline (TBC) / Brilliant Tourmaline (Cata+)
		["timeline"] = { "removed 4.0.1.10000" },
	}),
	i(28465, {	-- Lustrous Zircon (TBC) / Sparkling Zircon (Cata+)
		["timeline"] = { "removed 4.0.1.10000" },
	}),
	i(28463),	-- Solid Zircon (Both)
	i(28464),	-- Sparkling Zircon (Both)
	i(28466, {	-- Brilliant Amber (TBC) / Brilliant Tourmaline (Cata+)
		["timeline"] = { "removed 4.0.1.10000" },
	}),
	i(28469, {	-- Gleaming Amber (TBC) / Smooth Amber (Cata+)
		["timeline"] = { "removed 4.0.1.10000" },
	}),
	i(28468),	-- Rigid Amber (Both)
	i(28467),	-- Smooth Amber (Both)
	i(28470),	-- Thick Amber (TBC) / Subtle Amber (Cata+)
};
local FELANNIA_JOHAN_GROUPS = {};
-- #if AFTER WRATH
-- All of these were removed and the associated recipes are now available through trainers now.
bubbleDown({ ["spellID"] = 0, ["u"] = REMOVED_FROM_GAME }, JEWELCRAFTING_PATTERNS);
-- #endif
root("Zones", {
	m(OUTLAND, applyclassicphase(TBC_PHASE_ONE, {
		m(HELLFIRE_PENINSULA, bubbleDownSelf({ ["timeline"] = { "added 2.0.1" } }, {
			["lore"] = "Hellfire Peninsula is intended to be the first questing zone players hit after passing through The Dark Portal. It is a scorched zone, the site of many former battles and the massacre of the Draenei. Players are introduced early on to the threat of the Burning Legion at The Legion Front, further learning about Magtheridon's creation of the corrupted Fel Orcs and the sacrifices made in past battles on Draenor. Players also begin to learn about Draenic and Orcish culture in quest hubs in the western peninsula.",
			-- #if AFTER WRATH
			["icon"] = "Interface\\Icons\\achievement_zone_hellfirepeninsula_01",
			-- #endif
			["groups"] = {
				n(ACHIEVEMENTS, {
					petbattle(ach(9069, {	-- An Awfully Big Adventure
						["timeline"] = { "added 6.0.2" },
						["collectible"] = false,
						["filterID"] = BATTLE_PETS,
						["groups"] = {
							crit(28, {	-- Nicki Tinytech
								["coord"] = { 64.4, 49.2, HELLFIRE_PENINSULA },
								["cr"] = 66550,	-- Nicki Tinytech <Master Pet Tamer>
							}),
						},
					})),
					explorationAch(862, {	-- Explore Hellfire Peninsula
						-- #if BEFORE WRATH
						["description"] = "Explore Hellfire Peninsula, revealing the covered areas of the world map.",
						-- #endif
					}),
					classicAch(1189, {	-- To Hellfire and Back [Alliance Version]
						["races"] = ALLIANCE_ONLY,
						-- #if ANYCLASSIC
						-- #if AFTER CATA
						["sourceQuests"] = {
							-- Disrupt the Burning Legion
							10397,	-- Invasion Point: Annihilator

							-- Overthrow the Overlord
							10400,	-- Overlord
							10399,	-- The Heart of Darkness

							-- In Search of Sedai
							9545,	-- The Seer's Relic

							-- The Exorcism of Colonel Jules
							10935,	-- The Exorcism of Colonel Jules

							-- Drill the Drillmaster
							10937,	-- Drill the Drillmaster

							-- Temple of Telhamat
							9383,	-- An Ambitious Plan
							9490,	-- The Rock Flayer Matriarch
							-- all quests below need to be confirmed
							9427,	-- Cleaning the Waters
							9398,	-- Deadly Predators

							-- Green, But Not Orcs
							10630,	-- Beneath Thrallmar
							9356,	-- Smooth as Butter
							9351,	-- Voidwalkers Gone Wild

							-- Cenarion Post
							10351,	-- Natural Remedies
							10255,	-- Testing the Antidote
						},
						-- #else
						-- #if BEFORE WRATH
						["description"] = "Complete 80 quests in Hellfire Peninsula.",
						-- #endif
						["OnClick"] = [[_.CommonAchievementHandlers.LOREMASTER_OnClick]],
						["OnTooltip"] = [[_.CommonAchievementHandlers.LOREMASTER_OnTooltip]],
						["OnUpdate"] = [[function(t) return _.CommonAchievementHandlers.LOREMASTER_OnUpdate(t, 9587, 9575, 9607, 9589, 10754, 10762, 10763, 10764, 9492, 9493, 9494, 11002); end]],
						["rank"] = 80,
						-- #endif
						-- #else
						["groups"] = {
							crit(1, {	-- Disrupt the Burning Legion
								["sourceQuest"] = 10397,	-- Invasion Point: Annihilator
							}),
							crit(2, {	-- Overthrow the Overlord
								["sourceQuests"] = {
									10400,	-- Overlord
									10399,	-- The Heart of Darkness
								},
							}),
							crit(3, {	-- In Search of Sedai
								["sourceQuest"] = 9545,	-- The Seer's Relic
							}),
							crit(4, {	-- The Exorcism of Colonel Jules
								["sourceQuest"] = 10935,	-- The Exorcism of Colonel Jules
							}),
							crit(5, {	-- Drill the Drillmaster
								["sourceQuest"] = 10937,	-- Drill the Drillmaster
							}),
							crit(6, {	-- Temple of Telhamat
								["sourceQuests"] = {
									9383,	-- An Ambitious Plan
									9490,	-- The Rock Flayer Matriarch
									-- all quests below need to be confirmed
									9427,	-- Cleaning the Waters
									9398,	-- Deadly Predators
								},
							}),
							crit(7, {	-- Green, But Not Orcs
								["sourceQuests"] = {
									10630,	-- Beneath Thrallmar
									9356,	-- Smooth as Butter
									9351,	-- Voidwalkers Gone Wild
								},
							}),
							crit(8, {	-- Cenarion Post
								["sourceQuests"] = {
									10351,	-- Natural Remedies
									10255,	-- Testing the Antidote
								},
							}),
						},
						-- #endif
					}),
					classicAch(1271, {	-- To Hellfire and Back [Horde Version]
						["races"] = HORDE_ONLY,
						-- #if ANYCLASSIC
						-- #if AFTER CATA
						["sourceQuests"] = {
							-- Disrupt the Burning Legion
							10388,	-- Return to Thrallmar

							-- Cruel's Intentions
							10136,	-- Cruel's Intentions
							10389,	-- The Agony and the Darkness
							10393,	-- Vile Plans

							-- The Hand of Kargath
							10876,	-- The Foot of the Citadel

							-- Spinebreaker Post
							10295,	-- From the Abyss
							10834,	-- Grillok "Darkeye"
							10258,	-- Honor the Fallen (probably)
							10220,	-- Make Them listen
							9345,	-- Preparing the Salve

							-- The Mag'har
							9406,	-- The Mag'har

							-- Falcon Watch
							9397,	-- Birds of a Feather
							9370,	-- The Cleansing Must Be Stopped
							-- all quests below need to be confirmed
							9472,	-- Arelion's Mistress
							9391,	-- Marking the Path
							9387,	-- Source of the Corruption

							-- Green, But Not Orcs
							10630,	-- Beneath Thrallmar
							9356,	-- Smooth as Butter
							9351,	-- Voidwalkers Gone Wild

							-- Cenarion Post
							10351,	-- Natural Remedies
							10255,	-- Testing the Antidote
						},
						-- #else
						-- #if BEFORE WRATH
						["description"] = "Complete 90 quests in Hellfire Peninsula.",
						-- #endif
						["OnClick"] = [[_.CommonAchievementHandlers.LOREMASTER_OnClick]],
						["OnTooltip"] = [[_.CommonAchievementHandlers.LOREMASTER_OnTooltip]],
						["OnUpdate"] = [[function(t) return _.CommonAchievementHandlers.LOREMASTER_OnUpdate(t, 9588, 9572, 9608, 9590, 10755, 10756, 10757, 10758, 9495, 9496, 11003); end]],
						["rank"] = 90,
						-- #endif
						-- #else
						["groups"] = {
							crit(1, {	-- Disrupt the Burning Legion
								["sourceQuest"] = 10388,	-- Return to Thrallmar
							}),
							crit(2, {	-- Cruel's Intentions
								["sourceQuests"] = {
									10136,	-- Cruel's Intentions
									10389,	-- The Agony and the Darkness
									10393,	-- Vile Plans
								},
							}),
							crit(3, {	-- The Hand of Kargath
								["sourceQuest"] = 10876,	-- The Foot of the Citadel
							}),
							crit(4, {	-- Spinebreaker Post
								["sourceQuests"] = {
									10295,	-- From the Abyss
									10834,	-- Grillok "Darkeye"
									10258,	-- Honor the Fallen (probably)
									10220,	-- Make Them listen
									9345,	-- Preparing the Salve
								},
							}),
							crit(5, {	-- The Mag'har
								["sourceQuest"] = 9406,	-- The Mag'har
							}),
							crit(6, {	-- Falcon Watch
								["sourceQuests"] = {
									9397,	-- Birds of a Feather
									9370,	-- The Cleansing Must Be Stopped
									-- all quests below need to be confirmed
									9472,	-- Arelion's Mistress
									9391,	-- Marking the Path
									9387,	-- Source of the Corruption
								},
							}),
							crit(7, {	-- Green, But Not Orcs
								["sourceQuests"] = {
									10630,	-- Beneath Thrallmar
									9356,	-- Smooth as Butter
									9351,	-- Voidwalkers Gone Wild
								},
							}),
							crit(8, {	-- Cenarion Post
								["sourceQuests"] = {
									10351,	-- Natural Remedies
									10255,	-- Testing the Antidote
								},
							}),
						},
						-- #endif
					}),
				}),
				-- #if AFTER MOP
				petbattle(filter(BATTLE_PETS, {
					p(635, {	-- Adder
						["cr"] = 61325,	-- Adder
					}),
					p(414, {	-- Scorpid
						["cr"] = 61326,	-- Scorpid
					}),
				})),
				-- #endif
				-- #if ANYCLASSIC
				n(EXPLORATION, {
					exploration(3556, "256:256:182:412"),	-- Den of Haal'esh
					exploration(3546, "512:255:261:413"),	-- Expedition Armory
					exploration(3554, "512:342:183:326"),	-- Falcon Watch
					exploration(3797, "256:256:34:142"),	-- Fallen Sky Ridge
					exploration(3541, "512:512:478:25"),	-- Forge Camp: Mageddon
					exploration(3545, "256:458:338:210"),	-- Hellfire Citadel
					exploration(3538, "256:256:469:298"),	-- Honor Hold
					exploration(3555, "256:256:206:110"),	-- Mag'har Post
					exploration(3553, "256:512:326:45"),	-- Pools of Aggonar
					exploration(3551, "256:378:25:290"),	-- Ruins of Sha'naar
					exploration(3552, "512:512:38:152"),	-- Temple of Telhamat
					exploration(3804, "256:512:579:128"),	-- The Legion Front
					exploration(3539, "256:512:737:156"),	-- The Stair of Destiny
					exploration(3796, "256:260:308:408"),	-- The Warp Fields
					exploration(3536, "256:256:467:154"),	-- Thrallmar
					exploration(3547, "512:256:477:6"),		-- Throne of Kil'jaeden
					exploration(3802, "256:256:705:368"),	-- Void Ridge
					exploration(3582, "422:238:580:430"),	-- Zeth'Gor
				}),
				-- #endif
				n(FACTIONS, {
					faction(946, {	-- Honor Hold
						["maps"] = { HELLFIRE_CITADEL_BLOOD_FURNACE, HELLFIRE_CITADEL_RAMPARTS, HELLFIRE_CITADEL_SHATTERED_HALLS },
						["races"] = ALLIANCE_ONLY,
					}),
					faction(947, {	-- Thrallmar
						["maps"] = { HELLFIRE_CITADEL_BLOOD_FURNACE, HELLFIRE_CITADEL_RAMPARTS, HELLFIRE_CITADEL_SHATTERED_HALLS },
						["races"] = HORDE_ONLY,
					}),
				}),
				n(FLIGHT_PATHS, {
					fp(102, {	-- Falcon Watch, Hellfire Peninsula
						["cr"] = 18942,	-- Innalia <Wind Rider Master>
						["coord"] = { 27.8, 60.0, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
					}),
					fp(129, {	-- Hellfire Peninsula, The Dark Portal, Alliance
						["cr"] = 18931,	-- Amish Wildhammer <Gryphon Master>
						["coord"] = { 87.4, 52.4, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
					}),
					fp(130, {	-- Hellfire Peninsula, The Dark Portal, Horde
						["cr"] = 18930,	-- Vlagga Freyfeather <Wind Rider Master>
						["coord"] = { 87.4, 48.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
					}),
					fp(100, {	-- Honor Hold, Hellfire Peninsula
						["cr"] = 16822,	-- Flightmaster Krill Bitterhue <Gryphon Master>
						["coord"] = { 54.6, 62.4, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
					}),
					-- #if ANYCLASSIC
					fp(149, {	-- Shatter Point, Hellfire Peninsula
						["cr"] = 20234,	-- Runetog Wildhammer <Gryphon Master>
						["coord"] = { 78.4, 34.9, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
					}),
					-- #endif
					fp(141, {	-- Spinebreaker Ridge, Hellfire Peninsula
						["cr"] = 19558,	-- Amilya Airheart <Wind Rider Master>
						["coord"] = { 61.6, 81.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
					}),
					fp(101, {	-- Temple of Telhamat, Hellfire Peninsula
						["cr"] = 18785,	-- Kuma <Hippogryph Master>
						["coord"] = { 25.2, 37.2, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
					}),
					fp(99, {	-- Thrallmar, Hellfire Peninsula
						["cr"] = 16587,	-- Barley <Wind Rider Master>
						["coord"] = { 56.2, 36.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
					}),
				}),
				n(PROFESSIONS, {
					prof(BLACKSMITHING, {
						["crs"] = {
							16823,	-- Humphry <Blacksmithing Trainer> (A)
							16583,	-- Rohok <Blacksmithing Trainer> (H)
						},
						["coords"] = {
							{ 56.8, 63.8, HELLFIRE_PENINSULA },
							{ 53.2, 38.2, HELLFIRE_PENINSULA },
						},
						["g"] = TBC_BLACKSMITHING,
					}),
					prof(FISHING, {
						i(34867),	-- Monstrous Felblood Snapper
					}),
					prof(ENCHANTING, {
						["crs"] = {
							18773,	-- Johan Barnes <Enchanting Trainer> (A)
							18753,	-- Felannia <Enchanting Trainer> (H)
						},
						["coords"] = {
							{ 53.6, 66.0, HELLFIRE_PENINSULA },
							{ 52.5, 36.0, HELLFIRE_PENINSULA },
						},
						["g"] = TBC_ENCHANTING,
					}),
				}),
				n(QUESTS, {
					q(10864, {	-- A Burden of Souls
						["qg"] = 16588,	-- Apothecary Antonivich
						["sourceQuest"] = 10835,	-- Apothecary Antonivich
						["coord"] = { 52.2, 36.4, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9442, {	-- A Debilitating Sickness
						["qg"] = 17123,	-- Earthcaller Ryga
						["sourceQuest"] = 9441,	-- Envoy to the Mag'har
						["timeline"] = { "removed 4.0.3.10000" },
						["cost"] = {
							{ "i", 23753, 1 },	-- Drycap Mushroom
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/1 Drycap Mushroom
								["provider"] = { "i", 23753 },
								["coord"] = { 33.5, 64.1, HELLFIRE_PENINSULA },
							}),
						},
					}),
					q(9355, {	-- A Job for an Intelligent Man
						["qg"] = 16837,	-- Foreman Biggums
						["sourceQuest"] = 10143,	-- Expedition Point
						["coord"] = { 52.0, 62.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/15 Marauding Crust Burster slain
								["cr"] = 16857,	-- Marauding Crust Burster
							}),
							i(25785),	-- Adept's Band
							i(25784),	-- Imbued Chain
						},
					}),
					q(9376, {	-- A Pilgrim's Plight
						["qg"] = 17015,
						["sourceQuest"] = 9375,	-- The Road to Falcon Watch
						["coord"] = { 27.1, 61.9, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 23343, 1 },	-- Torn Pilgrim's Pack
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(61, 10, 61),
						["groups"] = {
							objective(1, {	-- 0/1 Torn Pilgrim's Pack
								["provider"] = { "i", 23343 },	-- Torn Pilgrim's Pack
								["coord"] = { 22.1, 68.5, HELLFIRE_PENINSULA }
							}),
							i(25783),	-- Pilgrim's Cover
							i(25781),	-- Segmented Breastplate
							i(25782),	-- Sunstrider Legguards
						},
					}),
					q(9410, {	-- A Spirit Guide
						["qg"] = 17015,	-- Far Seer Regulkut <Eyes of the Warchief>
						["sourceQuest"] = 9405,	-- The Warchief's Mandate
						["coord"] = { 54.2, 37.8, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							i(23669, {	-- Ancestral Spirit Wolf Totem
								["cr"] = 17062,	-- Krun Spinebreaker
								["coord"] = { 33.6, 43.6, HELLFIRE_PENINSULA },
							}),
						},
					}),
					q(9401, {	-- A Strange Weapon
						["qg"] = 17062,	-- Fel Orc Corpse
						["sourceQuest"] = 9400,	-- The Assassin
						["coord"] = { 33.6, 43.5, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 23550, 1 },	-- Heavy Stone Axe
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10367, {	-- A Traitor Among Us
						["qg"] = 19361,	-- Naladu
						["sourceQuest"] = 10403,	-- Naladu
						["coord"] = { 16.2, 65.0, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 29501, 1 },	-- Sha'naar Key
						},
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/1 Sha'naar Key
								["provider"] = { "i", 29501 },	-- Sha'naar Key
								["coord"] = { 14.3, 63.5, HELLFIRE_PENINSULA }
							}),
						},
					}),
					q(9447, bubbleDown({ ["timeline"] = { "removed 4.0.3.10000" } }, {	-- Administering the Salve
						["qg"] = 17123,	-- Earthcaller Ryga
						["sourceQuest"] = 9442,	-- A Debilitating Sickness
						["coord"] = { 32.1, 28.4, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/10 Debilitated Grunts Healed
								["provider"] = { "i", 23394 },	-- Healing Salve
								["cr"] = 16847,	-- Debilitated Mag'har Grunt
							}),
							i(25492),	-- Earthcaller's Mace
							i(25496),	-- Mag'har Bow
							i(25494),	-- Totemic Staff
							i(25495),	-- Wolfrider's Dagger
							-- #if BEFORE MOP
							i(29212),	-- Balanced Stone Dirk
							-- #endif
						},
					})),
					q(9383, {	-- An Ambitious Plan
						["qg"] = 17006,	-- Elsaana
						["coord"] = { 23.2, 36.6, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 23442, 1 },	-- Glowing Sanctified Crystal
						},
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(61, 10, 61),
						["groups"] = {
							objective(1, {	-- 0/1 Glowing Sanctified Crystal
								["provider"] = { "i", 23417 },	-- Sanctified Crystal
								["coord"] = { 48.0, 84.4, HELLFIRE_PENINSULA },
								["cr"] = 16975,	-- Uncontrolled Voidwalker
							}),
						},
					}),
					q(10058, {	-- An Old Gift
						["qg"] = 16825,	-- Father Malgor Devidicus
						["sourceQuest"] = 10143,	-- Expedition Point
						["coord"] = { 54.2, 63.5, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 25938, 1 },	-- Mysteries of the Light
						},
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Mysteries of the Light
								["provider"] = { "i", 25938 },	-- Mysteries of the Light
								["coord"] = { 55.0, 86.8, HELLFIRE_PENINSULA },
							}),
						},
					}),
					q(10835, {	-- Apothecary Antonivich
						["qg"] = 21279,	-- Apothecary Albreck
						["sourceQuest"] = 10538,	-- Boiling Blood
						["coord"] = { 61.1, 81.7, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 31550, 1 },	-- Albreck's Findings
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10449, {	-- Apothecary Zelana
						["qg"] = 21256,	-- Vurtok Axebreaker
						["sourceQuest"] = 10450,	-- Bonechewer Blood
						["coord"] = { 55.1, 36.3, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 30326, 1 },	-- Bonechewer Blood Samples
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9374, {	-- Arelion's Journal
						["qg"] = 16793,	-- Magistrix Carinda
						["coord"] = { 26.3, 60.3, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/1 Arelion's Journal
								["provider"] = { "i", 23339 },	-- Arelion's Journal
								["coord"] = { 40.1, 37.2, HELLFIRE_PENINSULA },
								["crs"] = {
									16903,	-- Blistering Oozeling
									20158,	-- Slime-Covered Corpse
								},
							}),
						},
					}),
					q(9472, {	-- Arelion's Mistress
						["qg"] = 16793,	-- Magistrix Carinda
						["sourceQuests"] = {
							9483,	-- Life's Finer Pleasures
							10287,	-- The Mistress Revealed
						},
						["coord"] = { 26.3, 60.3, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							i(25505),	-- Carinda's Wedding Band
						},
					}),
					q(10286, {	-- Arelion's Secret
						["qg"] = 16793,	-- Magistrix Carinda
						["sourceQuest"] = 9374,	-- Arelion's Journal
						["coord"] = { 26.3, 60.3, HELLFIRE_PENINSULA },
						["cr"] = 20159,	-- Magister Aledis
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10288, {	-- Arrival in Outland [Alliance]
						["qg"] = 19229,	-- Commander Duron
						["sourceQuests"] = {
							10119,	-- Through the Dark Portal [Alliance]
							-- #if AFTER 4.0.3.13277
							28708,	-- Hero's Call: Outland! [Breadcrumb]
							-- #endif
							-- #if AFTER 7.3.5.25600
							49862,	-- To Outland [Breadcrumb]
							-- #endif
							-- #if AFTER 9.0.1.36230
							60959,	-- Burning Crusade: Onward to Adventure in Outland [Alliance]
							-- #endif
						},
						["coord"] = { 87.3, 50.7, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 28105, 1 },	-- Duron's Report
						},
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10120, {	-- Arrival in Outland [Horde]
						["qg"] = 19253,	-- Lieutenant General Orion
						["sourceQuests"] = {
							9407,	-- Through the Dark Portal [Horde]
							-- #if AFTER 4.0.3.13277
							28705,	-- Warchief's Command: Outland! [Breadcrumb]
							-- #endif
							-- #if AFTER 7.3.5.25600
							49816,	-- To Outland [Breadcrumb]
							-- #endif
							-- #if AFTER 9.0.1.36230
							60961,	-- Burning Crusade: Onward to Adventure in Outland [Horde]
							-- #endif
						},
						["coord"] = { 87.3, 49.8, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 28024, 1 },	-- Orion's Report
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10369, {	-- Arzeth's Demise
						["qg"] = 19361,	-- Naladu
						["sourceQuest"] = 10368,	-- The Dreghood Elders
						["coord"] = { 16.2, 65.0, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/1 Arzeth the Powerless slain
								["crs"] = {
									19354,	-- Arzeth the Merciless <Servant of the Betrayer>
									20680,	-- Arzeth the Powerless <Servant of the Betrayer>
								},
								["coord"] = { 14.3, 58.8, HELLFIRE_PENINSULA },
								["cost"] = {
									{ "i", 29513, 1 },	-- Staff of the Dreghood Elders
								},
							}),
						},
					}),
					q(9543, {	-- Atonement
						["qg"] = 16834,	-- Anchorite Obadei
						["sourceQuest"] = 9424,	-- Makuru's Vengeance
						["coord"] = { 23.0, 40.3, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(9418, {	-- Avruu's Orb
						["provider"] = { "i", 23580 },	-- Avruu's Orb
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							i(25489),	-- Windtalker's Cloak
							i(25487),	-- Wind Dancer's Pendant
							i(25488),	-- Signet of Aeranas
						},
					}),
					q(10630, {	-- Beneath Thrallmar
						["qg"] = 16915,	-- Foreman Razelcraz
						["sourceQuest"] = 10629,	-- Shizz Work
						["coord"] = { 51.3, 30.5, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Urga'zz slain
								["cr"] = 18976,	-- Urga'zz
								["coord"] = { 53.7, 31.5, HELLFIRE_PENINSULA },
							}),
							i(30857),	-- Deep Core Lantern
							i(30855),	-- Shatterstone Pick
							i(30856),	-- Underworld Helm
						},
					}),
					q(9397, {	-- Birds of a Feather
						["qg"] = 16790,	-- Falconer Drenna Riverwind
						["coord"] = { 27.7, 60.3, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 23486, 1 },	-- Caged Female Kaliri Hatchling
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/1 Caged Female Kaliri Hatchling
								["provider"] = { "i", 23485 },	-- Empty Birdcage
								["coord"] = { 29, 81, HELLFIRE_PENINSULA },
								["cr"] = 17034,	-- Female Kaliri Hatchling
							}),
						},
					}),
					applyclassicphase(TBC_PHASE_FIVE, q(11516, {	-- Blast the Gateway
						["qg"] = 24937,	-- Magistrix Seyla
						["sourceQuest"] = 11526,	-- The Missing Magistrix
						["maxReputation"] = { 1077, EXALTED },	-- Shattered Sun Offensive, Exalted.
						["coord"] = { 58.2, 17.6, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(70, 25, 70),
						["isDaily"] = true,
						["groups"] = {
							objective(1, {	-- 0/1 Legion Gateway Destroyed
								["provider"] = { "i", 34253 },	-- Sizzling Embers
								["crs"] = {
									24916,	-- Living Flare
									24958,	-- Unstable Living Flare
								},
							}),
							i(35232),	-- Shattered Sun Supplies
						},
					})),
					applyclassicphase(TBC_PHASE_FIVE, q(11515, {	-- Blood for Blood
						["qg"] = 24937,	-- Magistrix Seyla
						["sourceQuest"] = 11526,	-- The Missing Magistrix
						["maxReputation"] = { 1077, EXALTED },	-- Shattered Sun Offensive, Exalted.
						["coord"] = { 58.2, 17.6, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(70, 25, 70),
						["isDaily"] = true,
						["groups"] = appendGroups(BLOOD_FOR_BLOOD_GROUPS, {
							objective(1, {	-- 0/1 Emaciated Felblood slain
								["provider"] = { "i", 34257 },	-- Fel Siphon
								["crs"] = {
									24918,	-- Felblood Initiate
									24955,	-- Emaciated Felblood
								},
							}),
						}),
					})),
					q(10250, {	-- Bloody Vengeance
						["qg"] = 19736,	-- Althen the Historian
						["sourceQuest"] = 10230,	-- The Battle Horn
						["coord"] = { 61.7, 81.7, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Urtrak slain
								["provider"] = { "i", 28651 },	-- Unyielding Battle Horn
								["coord"] = { 63.4, 77.2, HELLFIRE_PENINSULA },
								["cr"] = 19862,	-- Urtrak
							}),
						},
					}),
					q(10538, {	-- Boiling Blood
						["qg"] = 21279,	-- Apothecary Albreck
						["sourceQuest"] = 10242,	-- Spinebreaker Post
						["coord"] = { 61.1, 81.7, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 30430, 12 },	-- Boiled Blood
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/12 Boiled Blood
								["provider"] = { "i", 30425 },	-- Bleeding Hollow Blood
								["coord"] = { 65.2, 71.2, HELLFIRE_PENINSULA },
							}),
						},
					}),
					q(10450, {	-- Bonechewer Blood
						["qg"] = 21256,	-- Vurtok Axebreaker
						["coord"] = { 55.1, 36.3, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/12 Bonechewer Blood
								["provider"] = { "i", 30327 },	-- Bonechewer Blood
								["crs"] = {
									19701,	-- Bonechewer Evoker
									16876,	-- Bonechewer Mutant
									16925,	-- Bonechewer Raider
									18952,	-- Bonechewer Scavenger
								},
							}),
							i(29919),	-- Adamantine Kite Shield
							i(29915),	-- Desolation Rod
							i(29914),	-- Hellfire Skiver
							i(29916),	-- Ironstar Repeater
							i(29917),	-- Landslide Buckler
						},
					}),
					q(10087, {	-- Burn It Up... For the Horde!
						["qg"] = 21283,	-- Megzeg Nukklebust
						["sourceQuest"] = 10086,	-- I Work... For the Horde!
						["coord"] = { 55.1, 38.7, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Eastern Cannon Burned
								["provider"] = { "i", 27479 },	-- Flaming Torch
								["coord"] = { 60.6, 51.7, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- 0/1 Western Cannon Burned
								["provider"] = { "i", 27479 },	-- Flaming Torch
								["coord"] = { 54.7, 53.3, HELLFIRE_PENINSULA },
							}),
							i(29934),	-- Helm of Affinity
							i(29930),	-- Nature-Stitched Kilt
							i(29941),	-- Scale Brand Breastplate
							i(29928),	-- Wanderer's Stitched Trousers
						},
					}),
					q(10391, {	-- Cannons of Rage
						["qg"] = 3230,	-- Nazgrel
						["sourceQuest"] = 10390,	-- Forge Camp: Mageddon
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/3 Fel Cannon MKI slain
								["cr"] = 22461,	-- Fel Cannon MKI
							}),
						},
					}),
					q(9427, {	-- Cleansing the Waters
						["qg"] = 16796,	-- Amaan the Wise
						["sourceQuest"] = 9426,	-- The Pools of Aggonar
						["coord"] = { 23.4, 36.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- Aggonar's Presence Cleansed
								["provider"] = { "i", 23361 },	-- Cleansing Vial
								["coord"] = { 40.2, 30.8, HELLFIRE_PENINSULA },
								["cr"] = 17000,	-- Aggonis
							}),
							i(25485),	-- Amaan's Signet
							i(25486),	-- Demonslayer's Wristguards
							i(25484),	-- Telhamat Pendant
						},
					}),
					q(10132, {	-- Colossal Menace
						["qg"] = 19293,	-- Tola'thion
						["coord"] = { 15.6, 52.0, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(61, 10, 61),
						["groups"] = {
							objective(1, {	-- 0/5 Raging Colossus slain
								["cr"] = 19188,	-- Raging Colossus
							}),
							i(28062),	-- Expedition Repeater
							i(28063),	-- Survivalist's Wand
							-- #if BEFORE MOP
							i(28064, {	-- Idol of the Wild
								["timeline"] = { "removed 5.0.4.10000" },
							}),
							i(28065, {	-- Libram of Wracking
								["timeline"] = { "removed 5.0.4.10000" },
							}),
							i(28066, {	-- Totem of Lightning
								["timeline"] = { "removed 5.0.4.10000" },
							}),
							-- #endif
						},
					}),
					q(10134, {	-- Crimson Crystal Clue
						["provider"] = { "i", 29476 },	-- Crimson Crystal Shard
						["lvl"] = lvlsquish(61, 10, 61),
					}),
					q(9399, {	-- Cruel Taskmasters
						["qg"] = 16799,	-- Ikan
						["coord"] = { 23.0, 40.2, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/4 Illidari Taskmaster slain
								["cr"] = 17058,	-- Illidari Taskmaster
							}),
						},
					}),
					q(10136, {	-- Cruel's Intentions
						["qg"] = 3230,	-- Nazgrel
						["sourceQuest"] = 10392,	-- Doorway to the Abyss
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Arazzius the Cruel slain
								["coord"] = { 43.8, 31.6, HELLFIRE_PENINSULA },
								["cr"] = 19191,	-- Arazzius the Cruel
							}),
							i(28041),	-- Bladefist's Breadth
							i(28042),	-- Regal Protectorate
							i(28040),	-- Vengeance of the Illidari
						},
					}),
					q(10484, {	-- Cursed Talismans
						["qg"] = 21133,	-- Corporal Ironridge
						["sourceQuest"] = 10483,	-- Ill Omens
						["coord"] = { 70.9, 63.3, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/12 Cursed Talisman
								["provider"] = { "i", 30157 },	-- Cursed Talisman
								["crs"] = {
									16873,	-- Bleeding Hollow Dark Shaman
									16871,	-- Bleeding Hollow Grunt
									19422,	-- Bleeding Hollow Necrolyte
									16907,	-- Bleeding Hollow Peon
									19424,	-- Bleeding Hollow Tormentor
									19457,	-- Grillok "Darkeye"
									19442,	-- Worg Master Kruush
								},
							}),
						},
					}),
					q(9398, {	-- Deadly Predators
						["qg"] = 16797,	-- Scout Vanura
						["coord"] = { 23.3, 38.1, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/4 Stonescythe Alpha slain
								["cr"] = 16929,	-- Stonescythe Alpha
							}),
							objective(2, {	-- 0/8 Stonescythe Whelp slain
								["cr"] = 16927,	-- Stonescythe Whelp
							}),
						},
					}),
					q(10229, {	-- Decipher the Tome
						["provider"] = { "i", 28552 },	-- A Mysterious Tome
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9372, {	-- Demonic Contamination
						["qg"] = 16991,	-- Thiah Redmane
						["sourceQuests"] = {
							10443,	-- Helping the Cenarion Post [Alliance]
							10442,	-- Helping the Cenarion Post [Horde]
						},
						["coord"] = { 15.6, 52.0, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(61, 10, 61),
						["groups"] = {
							objective(1, {	-- 0/6 Helboar Blood Sample
								["provider"] = { "i", 23336 },	-- Helboar Blood Sample
								["crs"] = {
									16992,	-- Dreadtusk
									16880,	-- Hulking Helboar
								},
							}),
						},
					}),
					q(10916, {	-- Digging for Prayer Beads
						["qg"] = 22430,	-- Assistant Klatu
						["sourceQuest"] = 10903,	-- Return to Honor Hold
						["coord"] = { 54.3, 63.6, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 31795, 1 },	-- Draenei Prayer Beads
						},
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10144, {	-- Disrupt Their Reinforcements [Alliance]
						["qg"] = 19310,	-- Forward Commander Kingston
						["sourceQuest"] = 10143,	-- Expedition Point
						["coord"] = { 71.3, 62.7, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Disrupt Portal Grimh
								["provider"] = { "i", 28106 },	-- Kingston's Primers
								["coord"] = { 71.5, 55.2, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Disrupt Portal Kaalez
								["provider"] = { "i", 28106 },	-- Kingston's Primers
								["coord"] = { 72.7, 59.0, HELLFIRE_PENINSULA },
							}),
							i(29932),	-- Arcane Ringed Tunic
							i(29939),	-- Flayer-Hide Leggings
							i(29935),	-- Fore Scarred Breastplate
							i(29946),	-- Invader's Greathelm
							i(29927),	-- Shadowbrim Travel Hat
						},
					}),
					q(10208, {	-- Disrupt Their Reinforcements [Horde]
						["qg"] = 19273,	-- Forward Commander To'arch
						["sourceQuest"] = 10124,	-- Forward Base: Reaver's Fall
						["coord"] = { 65.8, 43.5, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Disrupt Portal Grimh
								["provider"] = { "i", 28478 },	-- To'arch's Primers
								["coord"] = { 71.5, 55.2, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Disrupt Portal Kaalez
								["provider"] = { "i", 28478 },	-- To'arch's Primers
								["coord"] = { 72.7, 59.0, HELLFIRE_PENINSULA },
							}),
							i(29932),	-- Arcane Ringed Tunic
							i(29939),	-- Flayer-Hide Leggings
							i(29935),	-- Fore Scarred Breastplate
							i(29946),	-- Invader's Greathelm
							i(29927),	-- Shadowbrim Travel Hat
						},
					}),
					q(10394, {	-- Disruption - Forge Camp: Mageddon
						["qg"] = 20793,	-- Field Marshal Brock
						["sourceQuest"] = 10382,	-- Go to the Front
						["coord"] = { 68.2, 28.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/10 Gan'arg Servant slain
								["cr"] = 16947,	-- Gan'arg Servant
							}),
							objective(2, {	-- 0/1 Razorsaw slain
								["coord"] = { 64.3, 30.9, HELLFIRE_PENINSULA },
								["cr"] = 20798,	-- Razorsaw
							}),
						},
					}),
					q(10392, {	-- Doorway to the Abyss
						["qg"] = 3230,	-- Nazgrel
						["sourceQuest"] = 10391,	-- Cannons of Rage
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Warbringer Arix'Amal
								["coord"] = { 53.1, 26.5, HELLFIRE_PENINSULA },
								["cr"] = 19298,	-- Warbringer Arix'Amal
							}),
							objective(2, {	-- 0/1 Close Burning Legion Gate
								["provider"] = { "i", 29795 },	-- Burning Legion Gate Key
								["coord"] = { 53.0, 27.7, HELLFIRE_PENINSULA },
							}),
						},
					}),
					q(10937, {	-- Drill the Drillmaster
						["qg"] = 16819,	-- Force Commander Danath Trollbane
						["sourceQuest"] = 10936,	-- Trollbane is Looking for You
						["coord"] = { 56.6, 66.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Drillmaster Zurok slain
								["coord"] = { 48.0, 56.3, HELLFIRE_PENINSULA },
								["cr"] = 19312,	-- Drillmaster Zurok
							}),
							i(31720),	-- Battlemaster's Breastplate
							i(31718),	-- Darkstorm Tunic
							i(31717),	-- Shadowcast Tunic
							i(31719),	-- Stormstrike Vest
						},
					}),
					q(10396, {	-- Enemy of my Enemy...
						["qg"] = 20793,	-- Field Marshal Brock
						["sourceQuest"] = 10394,	-- Disruption - Forge Camp: Mageddon
						["coord"] = { 68.2, 28.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/3 Fel Cannon MKI slain
								["cr"] = 22461,	-- Fel Cannon MKI
							}),
						},
					}),
					q(9441, {	-- Envoy to the Mag'har
						["qg"] = 4949,	-- Thrall
						["sourceQuest"] = 9438,	-- Messenger to Thrall
						["coord"] = { 31.6, 37.8, ORGRIMMAR },
						["timeline"] = { "removed 4.0.3.10000" },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						-- #if BEFORE 4.0.3.10000
						["groups"] = {
							i(25510),	-- Ceremonial Robes
							i(25512),	-- Tribal Hauberk
							i(25511),	-- Thunderforge Leggings
							i(25513),	-- Clefthoof Hide Mask
						},
						-- #endif
					}),
					q(10121, {	-- Eradicate the Burning Legion
						["qg"] = 3230,	-- Nazgrel
						["sourceQuest"] = 10291,	-- Report to Nazgrel
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10143, {	-- Expedition Point
						["qg"] = 19309,	-- Sergeant Altumus
						["sourceQuest"] = 10142,	-- The Path of Anguish
						["coord"] = { 61.7, 60.9, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9498, {	-- Falcon Watch [Non-Blood Elf]
						["qg"] = 16577,	-- Martik Tor'seldori
						["sourceQuest"] = 10124,	-- Forward Base: Reaver's Fall
						["coord"] = { 55.1, 39.1, HELLFIRE_PENINSULA },
						["races"] = exclude(BLOODELF, HORDE_ONLY),
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(9499, {	-- Falcon Watch [Blood Elf]
						["qg"] = 16577,	-- Martik Tor'seldori
						["sourceQuest"] = 10124,	-- Forward Base: Reaver's Fall
						["coord"] = { 55.1, 39.1, HELLFIRE_PENINSULA },
						["races"] = { BLOODELF },
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10919, {	-- Fei Fei's Treat
						["qg"] = 20206,	-- Fei Fei
						["sourceQuest"] = 10903,	-- Return to Honor Hold
						-- #if BEFORE WRATH
						["description"] = "In order to finish this, you need to talk to the Warrant Officer. After the dialog You're given the option to buy a 'Fei Fei Doggy Treat' for:\nSparkling Zircon: Gem vendor in the Inn\nMaiden's Anguish: Grand Master Alchemist or Reagent vendor in the tower.\nSilken Thread: Upstairs in the inn from the Grand Master Tailor",
						-- #else
						["description"] = "In order to finish this, you need to talk to the Warrant Officer. After the dialog You're given the option to buy a 'Fei Fei Doggy Treat' for a Silken Thread.\n\nSilken Thread can be found upstairs in the inn from the Grand Master Tailor.",
						-- #endif
						["coord"] = { 56.4, 62.9, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["cost"] = {
							{ "i", 31799, 1 },	-- Fei Fei Doggy Treat
						},
						["repeatable"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							i(31795),	-- Draenei Prayer Beads
						},
					}),
					q(10482, {	-- Fel Orc Scavengers
						["qg"] = 16820,	-- Lieutenant Amadi
						["sourceQuest"] = 10160,	-- Know Your Enemy
						["coord"] = { 50.9, 60.1, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/20 Bonechewer Orc slain
								["cr"] = 21161,	-- Bonechewer Orc
							}),
							i(29919),	-- Adamantine Kite Shield
							i(29915),	-- Desolation Rod
							i(29914),	-- Hellfire Skiver
							i(29916),	-- Ironstar Repeater
							i(29917),	-- Landslide Buckler
						},
					}),
					q(10909, {	-- Fel Spirits
						["qg"] = 22430,	-- Assistant Klatu
						["sourceQuest"] = 10903,	-- Return to Honor Hold
						["coord"] = { 54.3, 63.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/10 Fel Spirit slain
								["provider"] = { "i", 31772 },	-- Anchorite Relic
								["coord"] = { 44.5, 74.2, HELLFIRE_PENINSULA },
								["crs"] = {
									22454,	-- Fel Spirit
									16878,	-- Shattered Hand Berserker
								},
							}),
						},
					}),
					q(10123, {	-- Felspark Ravine
						["qg"] = 19256,	-- Sergeant Shatterskull
						["sourceQuest"] = 10121,	-- Eradicate the Burning Legion
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Dreadcaller slain
								["cr"] = 19434,	-- Dreadcaller
							}),
							objective(2, {	-- 0/4 Flamewaker Imp slain
								["cr"] = 19136,	-- Flamewaker Imp
							}),
							objective(3, {	-- 0/6 Infernal Warbringer slain
								["cr"] = 19261,	-- Infernal Warbringer
							}),
							i(29911),	-- Agamaggan's Quill
							i(29913),	-- Foe Reaver
							i(29908),	-- Rage Reaver
							i(29909),	-- Screaming Dagger
							i(29910),	-- The Staff of Twin Worlds
						},
					}),
					q(10254, {	-- Force Commander Danath
						["qg"] = 19308,	-- Marshal Isildor
						["sourceQuest"] = 10140,	-- Journey to Honor Hold
						["coord"] = { 54.6, 62.7, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10390, {	-- Forge Camp: Mageddon
						["qg"] = 3230,	-- Nazgrel
						["sourceQuest"] = 10388,	-- Return to Thrallmar
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 29586, 1 },	-- Head of Forgefiend Razorsaw
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/10 Gan'arg Servant slain
								["cr"] = 16947,	-- Gan'arg Servant
							}),
							objective(2, {	-- 0/1 Head of Forgefiend Razorsaw
								["provider"] = { "i", 29586 },	-- Head of Forgefiend Razorsaw
								["coord"] = { 64.3, 30.9, HELLFIRE_PENINSULA },
								["cr"] = 20798,	-- Razorsaw
							}),
							i(29934),	-- Helm of Affinity
							i(29930),	-- Nature-Stitched Kilt
							i(29941),	-- Scale Brand Breastplate
							i(29928),	-- Wanderer's Stitched Trousers
						},
					}),
					q(10124, {	-- Forward Base: Reaver's Fall
						["qg"] = 19256,	-- Sergeeant Shatterskull
						["sourceQuest"] = 10123,	-- Felspark Ravine
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10295, {	-- From the Abyss
						["qg"] = 19683,	-- Ogath the Mad
						["sourceQuest"] = 10294,	-- Void Ridge
						["coord"] = { 61.8, 81.5, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 29162, 1 },	-- Galaxis Soul Shard
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Galaxis Soul Shard
								["provider"] = { "i", 29226 },	-- Warp Rift Generator
								["coord"] = { 81, 78.8, HELLFIRE_PENINSULA },
								["cr"] = 16939,	-- Void Baron Galaxis
							}),
							i(29400),	-- Abyssal Shroud
							i(29398),	-- Circle of Banishing
							i(29399),	-- Rod of the Void Caller
						},
					}),
					q(9563, {	-- Gaining Mirren's Trust
						["qg"] = 16851,	-- Mirren Longbeard
						["coord"] = { 23.9, 72.3, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 23848, 1 },	-- Nethergarde Bitter
						},
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10382, {	-- Go to the Front
						["qg"] = 20232,	-- Wing Commander Gryphongar
						["sourceQuest"] = 10163,	-- Mission: The Abyssal Shelf
						["coord"] = { 79.3, 33.8, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10834, {	-- Grillok "Darkeye"
						["qg"] = 22231,	-- Zezzak
						["sourceQuest"] = 10813,	-- The Eyes of Grillok
						["coord"] = { 61.6, 81.8, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Grillok's Eyepatch
								["provider"] = { "i", 31529 },	-- Grillok's Eyepatch
								["coord"] = { 66.7, 71.5, HELLFIRE_PENINSULA },
								["cr"] = 19457,	-- Grillok "Darkeye"
							}),
							i(28057),	-- Bonechewer Berserker's Vest
							i(28055),	-- Gilded Crimson Chestplate
							i(28052),	-- Goldweave Tunic
							i(28051),	-- Jerkin of the Untamed Spirit
							i(28050),	-- Sacred Feather Vest
						},
					}),
					q(9361, {	-- Helboar, the Other White Meat
						["qg"] = 19344,	-- Legassi
						["sourceQuest"] = 9349,	-- Ravager Egg Roundup
						["coord"] = { 49.2, 74.8, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/8 Purified Helboar Meat
								["provider"] = { "i", 23248 },	-- Purified Helboar Meat
								["cost"] = {
									{ "i", 23268, 1 },	-- Purification Mixture
									{ "i", 23270, 1 },	-- Tainted Helboar Meat
								},
								["crs"] = {
									16863,	-- Deranged Helboar
									16992,	-- Dreadtusk
									16880,	-- Hulking Helboar
									16879,	-- Starving Helboar
								},
							}),
							i(29292),	-- Helboar Bacon
						},
					}),
					q(10106, {	-- Hellfire Fortifications [Alliance]
						["qg"] = 18266,	-- Warrant Officer Tracy Proudwell
						-- #if AFTER WRATH
						["sourceQuests"] = {
							13408,	-- Hellfire Fortifications [Alliance, Non-Death Knights]
							13410,	-- Hellfire Fortifications [Alliance, Death Knight Only]
						},
						-- #endif
						["coord"] = { 56.3, 62.8, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["isDaily"] = true,
						-- #if AFTER WRATH
						["lvl"] = lvlsquish(55, 10, 55),
						-- #else
						["lvl"] = lvlsquish(58, 10, 58),
						-- #endif
						["groups"] = {
							objective(1, {	-- Capture The Overlook
								["coord"] = { 39.9, 48.4, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Capture the Stadium
								["coord"] = { 35.6, 51.4, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Capture Broken Hill
								["coord"] = { 40.4, 56.7, HELLFIRE_PENINSULA },
							}),
							i(24579),	-- Mark of Honor Hold x3
						},
					}),
					q(13408, {	-- Hellfire Fortifications [Alliance, Non-Death Knights]
						["qg"] = 18266,	-- Warrant Officer Tracy Proudwell
						["sourceQuest"] = 10143,	-- Expedition Point
						["coord"] = { 56.3, 62.8, HELLFIRE_PENINSULA },
						["timeline"] = { "added 3.3.0.10958" },
						["classes"] = exclude(DEATHKNIGHT, ALL_CLASSES),
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(55, 10, 55),
						["groups"] = {
							objective(1, {	-- Capture The Overlook
								["coord"] = { 39.9, 48.4, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Capture the Stadium
								["coord"] = { 35.6, 51.4, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Capture Broken Hill
								["coord"] = { 40.4, 56.7, HELLFIRE_PENINSULA },
							}),
							i(40476),	-- Insignia of the Alliance
							i(24579),	-- Mark of Honor Hold x3
						},
					}),
					q(13410, {	-- Hellfire Fortifications [Alliance, Death Knight Only]
						["qg"] = 18266,	-- Warrant Officer Tracy Proudwell
						["sourceQuest"] = 10143,	-- Expedition Point
						["coord"] = { 56.3, 62.8, HELLFIRE_PENINSULA },
						["timeline"] = { "added 3.3.0.10958" },
						["classes"] = { DEATHKNIGHT },
						["races"] = ALLIANCE_ONLY,
						["isDaily"] = true,
						["lvl"] = lvlsquish(55, 10, 55),
						["groups"] = {
							objective(1, {	-- Capture The Overlook
								["coord"] = { 39.9, 48.4, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Capture the Stadium
								["coord"] = { 35.6, 51.4, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Capture Broken Hill
								["coord"] = { 40.4, 56.7, HELLFIRE_PENINSULA },
							}),
							i(24579),	-- Mark of Honor Hold x3
						},
					}),
					q(10110, {	-- Hellfire Fortifications [Horde]
						["qg"] = 18267,	-- Battlecryer Blackeye
						-- #if AFTER WRATH
						["sourceQuests"] = {
							13409,	-- Hellfire Fortifications [Horde, Non-Death Knights]
							13411,	-- Hellfire Fortifications [Horde, Death Knight Only]
						},
						-- #endif
						["coord"] = { 55.9, 39.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["isDaily"] = true,
						-- #if AFTER WRATH
						["lvl"] = lvlsquish(55, 10, 55),
						-- #else
						["lvl"] = lvlsquish(58, 10, 58),
						-- #endif
						["groups"] = {
							objective(1, {	-- Capture The Overlook
								["coord"] = { 39.9, 48.4, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Capture the Stadium
								["coord"] = { 35.6, 51.4, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Capture Broken Hill
								["coord"] = { 40.4, 56.7, HELLFIRE_PENINSULA },
							}),
							i(24581),	-- Mark of Thrallmar x3
						},
					}),
					q(13409, {	-- Hellfire Fortifications [Horde, Non-Death Knights]
						["qg"] = 18267,	-- Battlecryer Blackeye
						["sourceQuest"] = 10124,	-- Forward Base: Reaver's Fall
						["coord"] = { 55.9, 39.2, HELLFIRE_PENINSULA },
						["timeline"] = { "added 3.3.0.10958" },
						["classes"] = exclude(DEATHKNIGHT, ALL_CLASSES),
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(55, 10, 55),
						["groups"] = {
							objective(1, {	-- Capture The Overlook
								["coord"] = { 39.9, 48.4, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Capture the Stadium
								["coord"] = { 35.6, 51.4, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Capture Broken Hill
								["coord"] = { 40.4, 56.7, HELLFIRE_PENINSULA },
							}),
							i(40477),	-- Insignia of the Horde
							i(24581),	-- Mark of Thrallmar x3
						},
					}),
					q(13411, {	-- Hellfire Fortifications [Horde, Death Knight Only]
						["qg"] = 18267,	-- Battlecryer Blackeye
						["coord"] = { 55.9, 39.2, HELLFIRE_PENINSULA },
						["timeline"] = { "added 3.3.0.10958" },
						["classes"] = { DEATHKNIGHT },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(55, 10, 55),
						["groups"] = {
							objective(1, {	-- Capture The Overlook
								["coord"] = { 39.9, 48.4, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Capture the Stadium
								["coord"] = { 35.6, 51.4, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Capture Broken Hill
								["coord"] = { 40.4, 56.7, HELLFIRE_PENINSULA },
							}),
							i(24581),	-- Mark of Thrallmar x3
						},
					}),
					q(10443, {	-- Helping the Cenarion Post [Alliance]
						["qg"] = 16796,	-- Amaan the Wise
						["coord"] = { 23.4, 36.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(61, 10, 61),
					}),
					q(10442, {	-- Helping the Cenarion Post [Horde]
						["qg"] = 16790,	-- Falconer Drenna Riverwind
						["coord"] = { 27.7, 60.3, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(61, 10, 61),
					}),
					q(10258, {	-- Honor the Fallen
						["qg"] = 19736,	-- Althen the Historian
						["sourceQuest"] = 10250,	-- Bloody Vengeance
						["coord"] = { 61.7, 81.7, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							i(29108),	-- Blade of the Unyielding
							i(29109),	-- Rod of the Unyielding
						},
					}),
					q(10238, {	-- How to Serve Goblins
						["qg"] = 16915,	-- Foreman Razelcraz
						["sourceQuest"] = 10236,	-- Outland Sucks!
						["coord"] = { 51.3, 30.5, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Manni Saved
								["coord"] = { 45.1, 41.1, HELLFIRE_PENINSULA },
								["cr"] = 19763,	-- Manni
							}),
							objective(2, {	-- Moh Saved
								["coord"] = { 46.4, 45.2, HELLFIRE_PENINSULA },
								["cr"] = 19764,	-- Moh
							}),
							objective(3, {	-- Jakk Saved
								["coord"] = { 47.5, 46.6, HELLFIRE_PENINSULA },
								["cr"] = 19766,	-- Jakk
							}),
							i(30858),	-- Peon Sleep Potion
						},
					}),
					q(10086, {	-- I Work... For the Horde!
						["qg"] = 21283,	-- Megzeg Nukklebust
						["coord"] = { 55.1, 38.7, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 25912, 8 },	-- Salvaged Metal
							{ "i", 25911, 8 },	-- Salvaged Wood
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							i(29938),	-- Battle Seeker Chesguard
							i(29943),	-- Legionnaire's Studded Helm
							i(29945),	-- Magistrate's Greaves
							i(29931),	-- Phantasmal Headdress
						},
					}),
					q(10483, {	-- Ill Omens
						["qg"] = 16820,	-- Lieutenant Amadi
						["sourceQuest"] = 10482,	-- Fel Orc Scavengers
						["coord"] = { 50.9, 60.1, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 30157, 1 },	-- Cursed Talisman
						},
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10161, {	-- In Case of Emergency...
						["qg"] = 19367,	-- "Screaming" Screed Luckheed <Zeppelin Pilot>
						["coord"] = { 49.1, 74.8, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/30 Zeppelin Debris
								["provider"] = { "i", 28116 },	-- Zeppelin Debris
							}),
							i(25980),	-- Aerodynamic Scaled Vest
							i(25981),	-- Dirigible Crash Helmet
							i(25979),	-- Flintlocke's Piloting Pants
						},
					}),
					q(9366, {	-- In Need of Felblood
						["qg"] = 16791,	-- Ryathen the Somber
						["coord"] = { 26.9, 59.5, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/6 Felblood Sample
								["provider"] = { "i", 23269 },	-- Felblood Sample
								["cr"] = 16951,	-- Terrorfiend
							}),
						},
					}),
					q(9390, {	-- In Search of Sedai
						["qg"] = 16834,	-- Anchorite Obadei
						["coord"] = { 23.0, 40.3, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10397, {	-- Invasion Point: Annihilator
						["qg"] = 20793,	-- Field Marshal Brock
						["sourceQuest"] = 10396,	-- Enemy of my Enemy...
						["coord"] = { 68.2, 28.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Warbringer Arix'Amal
								["coord"] = { 53.1, 26.5, HELLFIRE_PENINSULA },
								["cr"] = 19298,	-- Warbringer Arix'Amal
							}),
							objective(2, {	-- 0/1 Close Burning Legion Gate
								["provider"] = { "i", 29795 },	-- Burning Legion Gate Key
								["coord"] = { 53.0, 27.7, HELLFIRE_PENINSULA },
							}),
						},
					}),
					q(10213, {	-- Investigate the Crash
						["qg"] = 16858,	-- Grelag
						["sourceQuest"] = 9345,	-- Preparing the Salve
						["coord"] = { 60.9, 81.6, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10140, {	-- Journey to Honor Hold
						["qg"] = 18931,	-- Amish Wildhammer
						["sourceQuest"] = 10288,	-- Arrival in Outland
						["coord"] = { 87.3, 52.4, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 28105, 1 },	-- Duron's Report
						},
						["isBreadcrumb"] = true,
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10289, {	-- Journey to Thrallmar
						["qg"] = 18930,	-- Vlagga Freyfeather
						["sourceQuest"] = 10120,	-- Arrival in Outland
						["coord"] = { 87.3, 48.1, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 28024, 1 },	-- Orion's Report
						},
						["isBreadcrumb"] = true,
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10159, {	-- Keep Thornfang Hill Clear!
						["qg"] = 16888,	-- Mahuram Stouthoof
						["coord"] = { 15.9, 52.1, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(61, 10, 61),
						["groups"] = {
							objective(1, {	-- 0/8 Thornfang Ravager slain
								["cr"] = 19349,	-- Thornfang Ravager
							}),
							objective(2, {	-- 0/8 Thornfang Venomspitter slain
								["cr"] = 19350,	-- Thornfang Venomspitter
							}),
						},
					}),
					q(10160, {	-- Know Your Enemy
						["qg"] = 16819,	-- Force Commander Danath Trollbane
						["coord"] = { 56.6, 66.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10078, {	-- Laying Waste to the Unwanted
						["qg"] = 21209,	-- Dumphry
						["sourceQuest"] = 10055,	-- Waste Not, Want Not
						["coord"] = { 51.2, 60.3, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Eastern Thrower Burned
								["provider"] = { "i", 26002 },	-- Flaming Torch
								["coord"] = { 58.5, 47.7, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Central Eastern Thrower Burned
								["provider"] = { "i", 26002 },	-- Flaming Torch
								["coord"] = { 55.7, 47.7, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Central Western Thrower Burned
								["provider"] = { "i", 26002 },	-- Flaming Torch
								["coord"] = { 53.6, 48.4, HELLFIRE_PENINSULA },
							}),
							objective(4, {	-- Western Thrower Burned
								["provider"] = { "i", 26002 },	-- Flaming Torch
								["coord"] = { 52.6, 47.9, HELLFIRE_PENINSULA },
							}),
							i(29934),	-- Helm of Affinity
							i(29930),	-- Nature-Stitched Kilt
							i(29941),	-- Scale Brand Breastplate
							i(29928),	-- Wanderer's Stitched Trousers
						},
					}),
					q(9483, {	-- Life's Finer Pleasures
						["qg"] = 17226,	-- Viera Sunwhisper
						["coord"] = { 27.2, 62.0, HELLFIRE_PENINSULA },
						["description"] = "Only available during |cFFFFD700Arelion's Mistress|r.",
						["cost"] = {
							{ "i", 29112, 1 },	-- Cenarion Spirits
						},
						["races"] = HORDE_ONLY,
						["repeatable"] = true,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- Carinda's Scroll of Retribution used
								["questID"] = 9472,	-- Arelion's Mistress
								["provider"] = { "i", 23693 },	-- Carinda's Scroll of Retribution
								["coord"] = { 27.1, 62.1, HELLFIRE_PENINSULA },
								["cr"] = 17226,	-- Viera Sunwhisper
							}),
						},
					}),
					q(10057, {	-- Looking to the Leadership
						["qg"] = 16827,	-- Honor Guard Wesilow
						["sourceQuest"] = 10050,	-- Unyielding Souls
						["coord"] = { 50.8, 60.3, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Arch Mage Xintor slain
								["coord"] = { 53.7, 81.1, HELLFIRE_PENINSULA },
								["cr"] = 16977,	-- Arch Mage Xintor
							}),
							objective(2, {	-- Lieutenant Commander Thalvos slain
								["coord"] = { 54.8, 83.5, HELLFIRE_PENINSULA },
								["cr"] = 16978,	-- Lieutenant Commander Thalvos
							}),
							i(25989),	-- Draenethyst Chaplet
							i(25992),	-- Enforcer's Chain
							i(25993),	-- Finely Wrought Chain
						},
					}),
					q(9396, {	-- Magic of the Arakkoa
						["qg"] = 16792,	-- Arcanist Calesthris Dawnstar
						["coord"] = { 27.0, 59.7, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/4 Haal'eshi Scroll
								["provider"] = { "i", 23483 },	-- Haal'eshi Scroll
								["crs"] = {
									17084,	-- Avruu
									16967,	-- Haal'eshi Talonguard
									16966,	-- Haal'eshi Windwalker
								},
							}),
						},
					}),
					q(10220, {	-- Make Them Listen
						["qg"] = 19682,	-- Emissary Mordiba
						["coord"] = { 61.7, 81.7, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/12 Unyielding Footman slain
								["cr"] = 16904,	-- Unyielding Footman
							}),
							objective(2, {	-- 0/8 Unyielding Knight slain
								["cr"] = 16906,	-- Unyielding Knight
							}),
							objective(3, {	-- 0/6 Unyielding Sorcerer slain
								["cr"] = 16905,	-- Unyielding Sorcerer
							}),
						},
					}),
					q(9424, {	-- Makuru's Vengeance
						["qg"] = 16833,	-- Makuru
						["sourceQuest"] = 9423,	-- Return to Obadei
						["coord"] = { 23.1, 40.1, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/10 Mag'har Ancestral Beads
								["provider"] = { "i", 23589 },	-- Mag'har Ancestral Beads
								["crs"] = {
									16847,	-- Debilitated Mag'har Grunt
									16846,	-- Mag'har Grunt
								},
							}),
							i(25920),	-- Sedai's Blade
							i(25919),	-- Sedai's Necklace
							i(25921),	-- Sedai's Ring
						},
					}),
					q(9391, {	-- Marking the Path
						["qg"] = 16789,	-- Ranger Captain Venn'ren
						["sourceQuest"] = 9340,	-- The Great Fissure
						["coord"] = { 28.4, 60.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- Western Beacon
								["provider"] = { "i", 23480 },	-- Lit Torch
								["coord"] = { 30.0, 60.6, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Central Beacon
								["provider"] = { "i", 23480 },	-- Lit Torch
								["coord"] = { 34.1, 60.0, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Southern Beacon
								["provider"] = { "i", 23480 },	-- Lit Torch
								["coord"] = { 36.1, 65.4, HELLFIRE_PENINSULA },
							}),
							i(25503),	-- Flamehandler's Gloves
							i(25502),	-- Lightbearer's Gauntlets
							i(25504),	-- Pilgrim's Belt
						},
					}),
					q(10906, {	-- Master of Elixirs (1/2)
						["qgs"] = {
							16588,	-- Apothecary Antonivich <Master Alchemy Trainer>
							18802,	-- Alchemist Gribble <Alchemy Trainer>
						},
						["coords"] = {
							{ 52.2, 36.4, HELLFIRE_PENINSULA },	-- Apothecary Antonivich <Master Alchemy Trainer>
							{ 53.8, 65.8, HELLFIRE_PENINSULA },	-- Alchemist Gribble <Alchemy Trainer>
						},
						["timeline"] = { "added 2.0.3", "removed 4.3.0" },
						["requireSkill"] = ALCHEMY,
						["altQuests"] = {
							--10906,	-- Master of Elixirs (1/2)
							10905,	-- Master of Potions (1/2)
							10907,	-- Master of Transmutation (1/2)
						},
						["isBreadcrumb"] = true,
						["lvl"] = 68,
					}),
					q(10905, {	-- Master of Potions (1/2)
						["qgs"] = {
							16588,	-- Apothecary Antonivich <Master Alchemy Trainer>
							18802,	-- Alchemist Gribble <Alchemy Trainer>
						},
						["coords"] = {
							{ 52.2, 36.4, HELLFIRE_PENINSULA },	-- Apothecary Antonivich <Master Alchemy Trainer>
							{ 53.8, 65.8, HELLFIRE_PENINSULA },	-- Alchemist Gribble <Alchemy Trainer>
						},
						["timeline"] = { "added 2.0.3", "removed 4.3.0" },
						["requireSkill"] = ALCHEMY,
						["altQuests"] = {
							10906,	-- Master of Elixirs (1/2)
							--10905,	-- Master of Potions (1/2)
							10907,	-- Master of Transmutation (1/2)
						},
						["isBreadcrumb"] = true,
						["lvl"] = 68,
					}),
					q(10907, {	-- Master of Transmutation (1/2)
						["qgs"] = {
							16588,	-- Apothecary Antonivich <Master Alchemy Trainer>
							18802,	-- Alchemist Gribble <Alchemy Trainer>
						},
						["coords"] = {
							{ 52.2, 36.4, HELLFIRE_PENINSULA },	-- Apothecary Antonivich <Master Alchemy Trainer>
							{ 53.8, 65.8, HELLFIRE_PENINSULA },	-- Alchemist Gribble <Alchemy Trainer>
						},
						["timeline"] = { "added 2.0.3", "removed 4.3.0" },
						["requireSkill"] = ALCHEMY,
						["altQuests"] = {
							10906,	-- Master of Elixirs (1/2)
							10905,	-- Master of Potions (1/2)
							--10907,	-- Master of Transmutation (1/2)
						},
						["isBreadcrumb"] = true,
						["lvl"] = 68,
					}),
					q(9438, {	-- Messenger to Thrall
						["qg"] = 3230,	-- Nazgrel
						["sourceQuest"] = 9406,	-- The Mag'har
						["coord"] = { 55.0, 36.0, HELLFIRE_PENINSULA },
						["timeline"] = { "removed 4.0.3.10000" },
						["cost"] = {
							{ "i", 23662, 1 },	-- Letter from Nazgrel
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(9373, {	-- Missing Missive
						["provider"] = { "i", 23338 },	-- Eroded Leather Case
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10146, {	-- Mission: Gateways Murketh and Shaadraz [Alliance]
						["qg"] = 19310,	-- Forward Commander Kingston
						["sourceQuest"] = 10144,	-- Disrupt Their Reinforcements [Alliance]
						["coord"] = { 71.3, 62.7, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Gateway Murketh Destroyed
								["provider"] = { "i", 28038 },	-- Seaforium PU-36 Explosive Nether Modulator
								["coord"] = { 78.0, 47.2, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Gateway Shaadraz Destroyed
								["provider"] = { "i", 28038 },	-- Seaforium PU-36 Explosive Nether Modulator
								["coord"] = { 77.7, 51.9, HELLFIRE_PENINSULA },
							}),
							i(29942),	-- Battle Scarred Leggings
							i(29937),	-- Helm of Infinite Visions
							i(29944),	-- Protectorate Breastplate
							i(29929),	-- Raging Spirit Harness
						},
					}),
					q(10129, {	-- Mission: Gateways Murketh and Shaadraz [Horde]
						["qg"] = 19273,	-- Forwarad Commander To'arch
						["sourceQuest"] = 10208,	-- Disrupt Their Reinforcements [Horde]
						["coord"] = { 65.8, 43.5, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Gateway Murketh Destroyed
								["provider"] = { "i", 28038 },	-- Seaforium PU-36 Explosive Nether Modulator
								["coord"] = { 78.0, 47.2, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Gateway Shaadraz Destroyed
								["provider"] = { "i", 28038 },	-- Seaforium PU-36 Explosive Nether Modulator
								["coord"] = { 77.7, 51.9, HELLFIRE_PENINSULA },
							}),
							i(29942),	-- Battle Scarred Leggings
							i(29937),	-- Helm of Infinite Visions
							i(29944),	-- Protectorate Breastplate
							i(29929),	-- Raging Spirit Harness
						},
					}),
					q(10163, {	-- Mission: The Abyssal Shelf [Alliance]
						["qg"] = 20232,	-- Wing Commander Gryphongar
						["sourceQuest"] = 10344,	-- Wing Commander Gryphongar
						["coord"] = { 79.3, 33.8, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/20 Gan'arg Peon slain
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19398,	-- Gan'arg Peon
							}),
							objective(2, {	-- 0/5 Mo'arg Overseer slain
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19397,	-- Mo'arg Overseer
							}),
							objective(3, {	-- 0/5 Fel Cannon Destroyed
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19399,	-- Fel Cannon
							}),
							i(29933),	-- Arcane Ringed Greaves
							i(29936),	-- Skyfire Greaves
							i(29940),	-- Veteran's Skullcap
							i(29926),	-- Whispering Tunic
						},
					}),
					q(10162, {	-- Mission: The Abyssal Shelf [Horde]
						["qg"] = 19273,	-- Forwarad Commander To'arch
						["sourceQuest"] = 10129,	-- Mission: Gateways Murketh and Shaadraz [Horde]
						["coord"] = { 65.8, 43.5, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/20 Gan'arg Peon slain
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19398,	-- Gan'arg Peon
							}),
							objective(2, {	-- 0/5 Mo'arg Overseer slain
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19397,	-- Mo'arg Overseer
							}),
							objective(3, {	-- 0/5 Fel Cannon Destroyed
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19399,	-- Fel Cannon
							}),
							i(29933),	-- Arcane Ringed Greaves
							i(29936),	-- Skyfire Greaves
							i(29940),	-- Veteran's Skullcap
							i(29926),	-- Whispering Tunic
						},
					}),
					q(10403, {	-- Naladu
						["qgs"] = {
							20678,	-- Akoru the Firecaller
							20679,	-- Aylaan the Waterwaker
							20677,	-- Morod the Windstirrer
						},
						["coords"] = {
							{ 15.5, 58.7, HELLFIRE_PENINSULA },	-- Akoru the Firecaller
							{ 13.0, 58.4, HELLFIRE_PENINSULA },	-- Aylaan the Waterwaker
							{ 13.1, 61.0, HELLFIRE_PENINSULA },	-- Morod the Windstirrer
						},
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10351, {	-- Natural Remedies
						["qg"] = 19294,	-- Earthbinder Galandria Nightbreeze
						["sourceQuest"] = 10349,	-- The Earthbinder
						["coord"] = { 15.9, 51.5, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(61, 10, 61),
						["groups"] = {
							objective(1, {	-- Fallen Sky Ridge Revitalized
								["provider"] = { "i", 29478 },	-- Seed of Revitalization
								["coord"] = { 13.6, 39, HELLFIRE_PENINSULA },
								["cr"] = 19305,	-- Goliathon <King of the Colossi>
							}),
							i(28075),	-- Destroyer's Mantle
							i(28069),	-- Golden Cenarion Greaves
							i(28074),	-- Studded Green Anklewraps
							i(28070),	-- Verdant Handwraps
						},
					}),
					q(10236, {	-- Outland Sucks!
						["qg"] = 16915,	-- Foreman Razelcraz
						["coord"] = { 51.3, 30.5, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 28554, 6 },	-- Shredder Spare Parts
						},
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							i(23424),	-- Fel Iron Ore
						},
					}),
					q(10400, {	-- Overlord
						["qg"] = 16819,	-- Force Commander Danath Trollbane
						["sourceQuest"] = 10395,	-- The Dark Missive
						["coord"] = { 56.6, 66.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Arazzius the Cruel slain
								["coord"] = { 43.8, 31.6, HELLFIRE_PENINSULA },
								["cr"] = 19191,	-- Arazzius the Cruel
							}),
							i(28041),	-- Bladefist's Breadth
							i(28042),	-- Regal Protectorate
							i(28040),	-- Vengeance of the Illidari
						},
					}),
					q(9345, {	-- Preparing the Salve
						["qg"] = 16858,	-- Grelag
						["coord"] = { 60.9, 81.6, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 23205, 12 },	-- Hellfire Spineleaf
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9385, {	-- Rampaging Ravagers
						["qg"] = 16850,	-- Gremni Longbeard
						["coord"] = { 23.8, 72.1, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/10 Quillfang Ravager slain
								["cr"] = 16934,	-- Quillfang Ravager
							}),
						},
					}),
					q(9349, {	-- Ravager Egg Roundup
						["qg"] = 19344,	-- Legassi
						["coord"] = { 49.2, 74.8, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/12 Ravager Egg
								["provider"] = { "i", 23217 },	-- Ravager Egg
								["crs"] = {
									16933,	-- Razorfang Ravager
									16934,	-- Quillfang Ravager
								},
							}),
							i(28501),	-- Ravager Egg Omelet
						},
					}),
					q(10291, {	-- Report to Nazgrel
						["qg"] = 19255,	-- General Krakork
						["sourceQuest"] = 10289,	-- Journey to Thrallmar
						["coord"] = { 55.8, 36.8, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(55, 10, 55),
					}),
					q(10875, {	-- Report to Nazgrel
						["qg"] = 16588,	-- Apothecary Antonivich
						["sourceQuest"] = 10838,	-- The Demonaic Scryer
						["coord"] = { 52.2, 36.4, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10103, {	-- Report to Zurai
						["qg"] = 16789,	-- Ranger Captain Venn'ren
						["coord"] = { 28.4, 60.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(61, 10, 61),
					}),
					q(10903, {	-- Return to Honor Hold
						["qg"] = 21133,	-- Corporal Ironridge
						["sourceQuest"] = 10485,	-- Warlord of the Bleeding Hollow
						["coord"] = { 70.9, 63.3, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9423, {	-- Return to Obadei
						["qg"] = 16852,	-- Sedai's Corpse
						["sourceQuest"] = 9390,	-- In Search of Sedai
						["coord"] = { 26.8, 37.4, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10346, {	-- Return to the Abyssal Shelf [Alliance]
						["qg"] = 20235,	-- Gryphoneer Windbellow
						["sourceQuest"] = 10163,	-- Mission: The Abyssal Shelf
						["coord"] = { 78.2, 34.4, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["repeatable"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/20 Gan'arg Peon slain
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19398,	-- Gan'arg Peon
							}),
							objective(2, {	-- 0/5 Mo'arg Overseer slain
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19397,	-- Mo'arg Overseer
							}),
							objective(3, {	-- 0/5 Fel Cannon Destroyed
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19399,	-- Fel Cannon
							}),
						},
					}),
					q(10347, {	-- Return to the Abyssal Shelf [Horde]
						["qg"] = 19401,	-- Wing Commander Brack
						["sourceQuest"] = 10162,	-- Mission: The Abyssal Shelf
						["coord"] = { 66.0, 43.7, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["repeatable"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/20 Gan'arg Peon slain
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19398,	-- Gan'arg Peon
							}),
							objective(2, {	-- 0/5 Mo'arg Overseer slain
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19397,	-- Mo'arg Overseer
							}),
							objective(3, {	-- 0/5 Fel Cannon Destroyed
								["provider"] = { "i", 28132 },	-- Area 52 Special
								["cr"] = 19399,	-- Fel Cannon
							}),
						},
					}),
					q(10388, {	-- Return to Thrallmar
						["qgs"] = {
							19273,	-- Forwarad Commander To'arch
							16576,	-- Overlord Hun Maimfist
						},
						["sourceQuest"] = 10129,	-- Mission: Gateways Murketh and Shaadraz [Horde]
						["coords"] = {
							{ 65.8, 43.5, HELLFIRE_PENINSULA },	-- Forwarad Commander To'arch
							{ 65.0, 44.2, HELLFIRE_PENINSULA },	-- Overlord Hun Maimfist
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9430, {	-- Sha'naar Relics
						["qg"] = 16796,	-- Amaan the Wise
						["sourceQuest"] = 9543,	-- Atonement
						["coord"] = { 23.4, 36.5, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 23642, 10 },	-- Sha'naar Relic
						},
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10340, {	-- Shatter Point
						["qg"] = 19310,	-- Forward Commander Kingston
						["sourceQuest"] = 10146,	-- Mission: Gateways Murketh and Shaadraz [Alliance]
						["coord"] = { 71.3, 62.7, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10629, {	-- Shizz Work
						["qg"] = 16915,	-- Foreman Razelcraz
						["sourceQuest"] = 10238,	-- How to Serve Goblins
						["coord"] = { 51.3, 30.5, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Shredder Keys
								["provider"] = { "i", 30794 },	-- Shredder Keys
								["coord"] = { 51.2, 30.6, HELLFIRE_PENINSULA },
								["cr"] = 21847,	-- Fel Guard Hound
								["cost"] = {
									{ "i", 30803, 1 },	-- Felhound Whistle
								},
							}),
							i(18588),	-- Ez-Thro Dynamite II
						},
					}),
					q(9356, {	-- Smooth as Butter
						["qg"] = 19344,	-- Legassi
						["sourceQuest"] = 9361,	-- Helboar, the Other White Meat
						["coord"] = { 49.2, 74.8, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/12 Plump Buzzard Wing
								["provider"] = { "i", 23239 },	-- Plump Buzzard Wing
								["coord"] = { 62.9, 66.6, HELLFIRE_PENINSULA },
								["cr"] = 16972,	-- Bonestripper Buzzard
							}),
							i(27684),	-- Recipe: Buzzard Bites
							i(27651),	-- Buzzard Bites x5
						},
					}),
					q(9387, {	-- Source of the Corruption
						["qg"] = 16794,	-- Apothecary Azethen
						["coord"] = { 26.7, 59.7, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/5 Demonic Essence
								["provider"] = { "i", 29113 },	-- Demonic Essence
								["coord"] = { 14.3, 59.5, HELLFIRE_PENINSULA },
								["cr"] = 17058,	-- Illidari Taskmaster
							}),
							i(25914),	-- Broken Choker
							i(25915),	-- Fallen Vindicator's Blade
							i(25913),	-- Ring of the Slain Anchorite
						},
					}),
					q(10242, {	-- Spinebreaker Post
						["qg"] = 21257,	-- Apothecary Zelana
						["sourceQuest"] = 10449,	-- Apothecary Zelana
						["coord"] = { 66.1, 41.9, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 30404, 1 },	-- Bleeding Hollow Blood Sample
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10255, {	-- Testing the Antidote
						["qg"] = 16991,	-- Thiah Redmane
						["sourceQuest"] = 9372,	-- Demonic Contamination
						["coord"] = { 15.6, 52.0, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(61, 10, 61),
						["groups"] = {
							objective(1, {	-- Administer Antidote
								["provider"] = { "i", 23337 },	-- Cenarion Antidote
								["cr"] = 16992,	-- Dreadtusk
							}),
							i(25985),	-- Cenarion Naturalist's Staff
							i(25986),	-- Dreadtusk's Fury
							i(25987),	-- Helboar Carving Blade
						},
					}),
					q(10389, {	-- The Agony and the Darkness
						["qg"] = 21175,	-- Magister Bloodhawk
						["sourceQuest"] = 10392,	-- Doorway to the Abyss
						["coord"] = { 55.1, 36.0, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/10 Terrorfiend slain
								["cr"] = 16951,	-- Terrorfiend slain
							}),
						},
					}),
					q(9417, {	-- The Arakkoa Threat
						["qg"] = 16850,	-- Gremni Longbeard
						["sourceQuest"] = 9558,	-- The Longbeards
						["coord"] = { 23.8, 72.1, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/4 Haal'eshi Windwalker slain
								["cr"] = 16966,	-- Haal'eshi Windwalker slain
							}),
							objective(2, {	-- 0/6 Haal'eshi Talonguard slain
								["cr"] = 16967,	-- Haal'eshi Talonguard slain
							}),
						},
					}),
					q(9400, {	-- The Assassin
						["qg"] = 3230,	-- Nazgrel
						["sourceQuest"] = 10124,	-- Forward Base: Reaver's Fall
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10230, {	-- The Battle Horn
						["qg"] = 19736,	-- Althen the Historian
						["sourceQuest"] = 10229,	-- Decipher the Tome
						["coord"] = { 61.7, 81.7, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 28562, 1 },	-- Unyielding Battle Horn
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9370, {	-- The Cleansing Must Be Stopped
						["qg"] = 16791,	-- Ryathen the Somber
						["sourceQuest"] = 9366,	-- In Need of Felblood
						["coord"] = { 26.9, 59.5, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- Draenei Anchorite slain
								["provider"] = { "i", 23358 },	-- Signaling Gem
								["coord"] = { 39, 40, HELLFIRE_PENINSULA },
								["cr"] = 16994,	-- Draenei Anchorite
							}),
							i(25499),	-- Felblood Band
							i(25500),	-- Felforce Medallion
							i(25501),	-- Lost Anchorite's Cloak
						},
					}),
					q(10395, {	-- The Dark Missive
						["provider"] = { "i", 29588 },	-- Burning Legion Missive
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10838, {	-- The Demonaic Scryer
						["qg"] = 16588,	-- Apothecary Antonivichk
						["sourceQuest"] = 10864,	-- A Burden of Souls
						["coord"] = { 52.2, 36.4, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Demoniac Scryer Reading
								["provider"] = { "i", 31607 },	-- Demoniac Scryer Reading
								["coord"] = { 44, 51, HELLFIRE_PENINSULA },
								["cost"] = {
									{ "i", 31606, 1 },	-- Demoniac Scryer
								},
							}),
							i(31715),	-- Demoniac Soul Prison
						},
					}),
					q(10368, {	-- The Dreghood Elders
						["qg"] = 19361,	-- Naladu
						["sourceQuest"] = 10367,	-- A Traitor Among Us
						["coord"] = { 16.2, 65.0, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/1 Morod the Windstirrer Freed
								["provider"] = { "i", 29501 },	-- Sha'naar Key
								["coord"] = { 13.0, 61.0, HELLFIRE_PENINSULA },
								["cr"] = 20677,	-- Morod the Windstirrer
							}),
							objective(2, {	-- 0/1 Akoru the Firecaller Freed
								["provider"] = { "i", 29501 },	-- Sha'naar Key
								["coord"] = { 15.6, 58.6, HELLFIRE_PENINSULA },
								["cr"] = 20678,	-- Akoru the Firecaller
							}),
							objective(3, {	-- 0/1 Aylaan the Waterwaker Freed
								["provider"] = { "i", 29501 },	-- Sha'naar Key
								["coord"] = { 13.0, 58.6, HELLFIRE_PENINSULA },
								["cr"] = 20679,	-- Aylaan the Waterwaker
							}),
						},
					}),
					q(10349, {	-- The Earthbinder
						["qg"] = 19293,	-- Tola'thion
						["sourceQuest"] = 10134,	-- Crimson Crystal Clue
						["coord"] = { 15.6, 52.0, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 29477, 1 },	-- Crimson Crystal Shard
						},
						["lvl"] = lvlsquish(61, 10, 61),
					}),
					q(10935, {	-- The Exorcism of Colonel Jules
						["qg"] = 22430,	-- Assistant Klatu
						["sourceQuests"] = {
							10916,	-- Digging for Prayer Beads
							10909,	-- Fel Spirits
						},
						["coord"] = { 54.3, 63.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Colonel Jules Saved
								["provider"] = { "i", 31828 },	-- Ritual Prayer Beads
								["coord"] = { 53.9, 63.6, HELLFIRE_PENINSULA },
								["cr"] = 22432,	-- Colonel Jules
							}),
						},
					}),
					q(10813, {	-- The Eyes of Grillok
						["qg"] = 22231,	-- Zezzak
						["sourceQuest"] = 10792,	-- Zeth'Gor Must Burn!
						["coord"] = { 61.6, 81.8, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Eye of Grillok Returned
								["provider"] = { "i", 31463 },	-- Zezzak's Shard
								["coord"] = { 67.3, 72.1, HELLFIRE_PENINSULA },
								["cr"] = 19440,	-- Eye of Grillok
							}),
						},
					}),
					q(9420, {	-- The Finest Down
						["qg"] = 16851,	-- Mirren Longbeard
						["sourceQuest"] = 9563,	-- Gaining Mirren's Trust
						["coord"] = { 23.9, 72.3, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/8 Kaliri Feather
								["provider"] = { "i", 23588 },	-- Kaliri Feather
								["crs"] = {
									17034,	-- Female Kaliri Hatchling
									17035,	-- Kaliri Matriarch
									17053,	-- Kaliri Swooper
									17039,	-- Male Kaliri Hatchling
								},
							}),
							i(23587),	-- Mirren's Drinking Hat
						},
					}),
					q(10876, {	-- The Foot of the Citadel
						["qg"] = 3230,	-- Nazgrel
						["sourceQuest"] = 10875,	-- Report to Nazgrel
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 The Head of the Hand of Kargath
								["provider"] = { "i", 31706 },	-- The Head of the Hand of Kargath
								["coord"] = { 47.6, 49.8, HELLFIRE_PENINSULA },
								["cost"] = {
									{ "i", 31702, 1 },	-- Challenge from the Horde
								},
								["crs"] = {
									19264,	-- Force Commander Gorax
									22374,	-- Hand of Kargath
								},
							}),
							i(31720),	-- Battlemaster's Breastplate
							i(31718),	-- Darkstorm Tunic
							i(31717),	-- Shadowcast Tunic
							i(31719),	-- Stormstrike Vest
						},
					}),
					q(9340, {	-- The Great Fissure
						["qg"] = 16789,	-- Ranger Captain Venn'ren
						["sourceQuests"] = {
							9498,	-- Falcon Watch [Non-Blood Elf]
							9499,	-- Falcon Watch [Blood Elf]
						},
						["coord"] = { 28.4, 60.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/8 Stonescythe Whelp slain
								["cr"] = 16927,	-- Stonescythe Whelp
							}),
							objective(2, {	-- 0/3 Stonescythe Alpha slain
								["cr"] = 16929,	-- Stonescythe Alpha
							}),
						},
					}),
					q(10399, {	-- The Heart of Darkness
						["qg"] = 16839,	-- Warp-Scryer Kryv
						["sourceQuest"] = 10395,	-- The Dark Missive
						["coord"] = { 56.6, 66.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/10 Terrorfiend slain
								["cr"] = 16951,	-- Terrorfiend
							}),
						},
					}),
					q(10141, {	-- The Legion Reborn
						["qg"] = 16819,	-- Force Commander Danath Trollbane
						["coord"] = { 56.6, 66.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9558, {	-- The Longbeards
						["qg"] = 16826,	-- Sid Limbardi
						["sourceQuest"] = 10143,	-- Expedition Point
						["coord"] = { 54.2, 63.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(9406, {	-- The Mag'har
						["qg"] = 16845,	-- Gorkan Bloodfish
						["sourceQuest"] = 9410,	-- A Spirit Guide
						["coord"] = { 31.9, 27.7, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 23569, 1 },	-- Letter from the Mag'har
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						-- #if AFTER 4.0.3.10000
						["groups"] = {
							i(25510),	-- Ceremonial Robes
							i(25512),	-- Tribal Hauberk
							i(25511),	-- Thunderforge Leggings
							i(25513),	-- Clefthoof Hide Mask
						},
						-- #endif
					}),
					q(10099, {	-- The Mastermind
						["qg"] = 16837,	-- Foreman Biggums
						["sourceQuest"] = 10079,	-- When This Mine's a-Rockin'
						["coord"] = { 52.0, 62.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Z'kral slain
								["coord"] = { 56.3, 61.4, HELLFIRE_PENINSULA },
								["cr"] = 18974,	-- Z'kral
							}),
							i(25982),	-- Foreman's Sash
							i(25983),	-- Heavy Miner's Belt
							i(25984),	-- Miner's Brace
						},
					}),
					q(10287, {	-- The Mistress Revealed
						["qg"] = 20159,	-- Megister Aledis
						["sourceQuest"] = 10286,	-- Arelion's Secret
						["coords"] = {
							{ 10.3, 50.3, HELLFIRE_PENINSULA },
							{ 15.7, 50.0, HELLFIRE_PENINSULA },
							{ 20.0, 50.0, HELLFIRE_PENINSULA },
							{ 24.8, 49.3, HELLFIRE_PENINSULA },
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10142, {	-- The Path of Anguish
						["qg"] = 19309,	-- Sergeant Altumus
						["sourceQuest"] = 10141,	-- The Legion Reborn
						["coord"] = { 61.6, 60.7, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Dreadcaller slain
								["cr"] = 19434,	-- Dreadcaller
							}),
							objective(2, {	-- 0/4 Flamewaker Imp slain
								["cr"] = 19136,	-- Flamewaker Imp
							}),
							objective(3, {	-- 0/6 Infernal Warbringer slain
								["cr"] = 19261,	-- Infernal Warbringer
							}),
							i(29911),	-- Agamaggan's Quill
							i(29913),	-- Foe Reaver
							i(29908),	-- Rage Reaver
							i(29909),	-- Screaming Dagger
							i(29910),	-- The Staff of Twin Worlds
						},
					}),
					q(10047, {	-- The Path of Glory
						["qg"] = 16839,	-- Warp-Scryer Kryv
						["sourceQuest"] = 10143,	-- Expedition Point
						["coord"] = { 56.6, 66.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/8 Cleanse Trampled Skeleton
								["provider"] = { "i", 25889 },	-- Draenei Holy Water
							}),
						},
					}),
					q(9426, {	-- The Pools of Aggonar
						["qg"] = 16796,	-- Amaan the Wise
						["coord"] = { 23.4, 36.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/6 Terrorfiend slain
								["cr"] = 16951,	-- Terrorfiend
							}),
							objective(2, {	-- 0/6 Blistering Rot slain
								["cr"] = 16901,	-- Blistering Rot
							}),
						},
					}),
					q(9375, {	-- The Road to Falcon Watch
						["qg"] = 16993,	-- Wounded Blood Elf Pilgrim
						["coord"] = { 24.5, 76.0, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(61, 10, 61),
						["groups"] = {
							objective(1, {	-- Escort Wounded Blood Elf Pilgrim to Falcon Watch
								["coord"] = { 26.4, 61.8, HELLFIRE_PENINSULA },
							}),
						},
					}),
					q(9490, {	-- The Rock Flayer Matriarch
						["qg"] = 16799,	-- Ikan
						["coord"] = { 23.0, 40.2, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- 0/1 Blacktalon's Claws
								["provider"] = { "i", 23687 },	-- Blacktalon's Claws
								["coord"] = { 33.4, 65.1, HELLFIRE_PENINSULA },
								["cr"] = 17057,	-- Blacktalon the Savage
							}),
							i(25479),	-- Boots of the Earthcaller
							i(25478),	-- Defender's Gauntlets
							i(25480),	-- Wastewalker's Sash
						},
					}),
					q(9545, {	-- The Seer's Relic
						["qg"] = 16796,	-- Amaan the Wise
						["sourceQuest"] = 9430,	-- Sha'naar Relics
						["coord"] = { 23.4, 36.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
						["groups"] = {
							objective(1, {	-- Vision Granted
								["provider"] = { "i", 23645 },	-- Seer's Relic
								["coord"] = { 26.9, 37.4, HELLFIRE_PENINSULA },
								["cr"] = 16852,	-- Sedai's Corpse
							}),
							i(25507),	-- Leggings of Telhamat
							i(25508),	-- Omenai Vest
							i(25506),	-- Vindicator's Chain Helm
						},
					}),
					q(10093, {	-- The Temple of Telhamat
						["qg"] = 16839,	-- Warp-Scryer Kryv
						["sourceQuest"] = 10047,	-- The Path of Glory
						["coord"] = { 56.6, 66.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9405, {	-- The Warchief's Mandate
						["qg"] = 3230,	-- Nazgrel
						["sourceQuest"] = 9401,	-- A Strange Weapon
						["coord"] = { 55.0, 35.9, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 23550, 1 },	-- Heavy Stone Axe
						},
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(60, 10, 60),
					}),
					q(10278, {	-- The Warp Rifts
						["qg"] = 19683,	-- Ogath the Mad
						["coord"] = { 61.8, 81.5, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/3 Warp Nether
								["provider"] = { "i", 29051 },	-- Warp Nether
								["coord"] = { 52, 84, HELLFIRE_PENINSULA },
								["cost"] = {
									{ "i", 29027, 1 },	-- Unstable Warp Rift Generator
								},
								["cr"] = 20145,	-- Unstable Voidwalker
							}),
						},
					}),
					q(10119, {	-- Through the Dark Portal [Alliance]
						["qg"] = 16841,	-- Watch Commander Relthorn Netherwane
						["coord"] = { 54.7, 50.5, BLASTED_LANDS },
						["timeline"] = { "removed 6.0.3.10000" },
						["races"] = ALLIANCE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9407, {	-- Through the Dark Portal [Horde]
						["qg"] = 19254,	-- Warlord Dar'toon
						["coord"] = { 54.4, 50.5, BLASTED_LANDS },
						["timeline"] = { "removed 6.0.3.10000" },
						["races"] = HORDE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(49862, {	-- To Outland! [Alliance]
						["description"] = "Breadcrumb quest when you first step in Outland. You will not be able to get it if you visited Outland before this quest was implemented.",
						["timeline"] = { "added 7.3.5.25600", "removed 9.0" },
						["races"] = ALLIANCE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(49816, {	-- To Outland! [Horde]
						["description"] = "Breadcrumb quest when you first step in Outland. You will not be able to get it if you visited Outland before this quest was implemented.",
						["timeline"] = { "added 7.3.5.25600", "removed 9.0" },
						["races"] = HORDE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10936, {	-- Trollbane is Looking for You
						["qg"] = 22430,	-- Assistant Klatu
						["sourceQuest"] = 10935,	-- The Exorcism of Colonel Jules
						["coord"] = { 54.3, 63.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(9381, {	-- Trueflight Arrows
						["qg"] = 16790,	-- Falconer Drenna Riverwind
						["coord"] = { 27.7, 60.3, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(61, 10, 61),
						["groups"] = {
							objective(1, {	-- 0/8 Bonestripper Tail Feather
								["provider"] = { "i", 23387 },	-- Bonestripper Tail Feather
								["coord"] = { 28.8, 54.1, HELLFIRE_PENINSULA },
								["cr"] = 16973,	-- Bonestripper Vulture
							}),
						},
					}),
					q(10050, {	-- Unyielding Souls
						["qg"] = 16827,	-- Honor Guard Wesilow
						["sourceQuest"] = 10143,	-- Expedition Point
						["coord"] = { 50.8, 60.3, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/12 Unyielding Footman slain
								["cr"] = 16904,	-- Unyielding Footman
							}),
							objective(2, {	-- 0/10 Unyielding Sorcerer slain
								["cr"] = 16905,	-- Unyielding Sorcerer
							}),
							objective(3, {	-- 0/5 Unyielding Knight slain
								["cr"] = 16906,	-- Unyielding Knight
							}),
						},
					}),
					q(10393, {	-- Vile Plans
						["provider"] = { "i", 29590 },	-- Burning Legion Missive
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10294, {	-- Void Ridge
						["qg"] = 19683,	-- Ogath the Mad
						["sourceQuest"] = 10278,	-- The Warp Rifts
						["coord"] = { 61.8, 81.5, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/40 Void Ridge Soul Shard
								["provider"] = { "i", 29161 },	-- Void Ridge Soul Shard
								["crs"] = {
									17014,	-- Collapsing Voidwalker
									19527,	-- Vacillating Voidcaller
								},
							}),
						},
					}),
					q(9351, {	-- Voidwalkers Gone Wild
						["qg"] = 19367,	-- "Screaming" Screed Luckheed <Zeppelin Pilot>
						["sourceQuest"] = 10161,	-- In Case of Emergency...
						["coord"] = { 49.1, 74.8, HELLFIRE_PENINSULA },
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/10 Condensed Voidwalker Essence
								["provider"] = { "i", 23218 },	-- Condensed Voidwalker Essence
								["crs"] = {
									16974,	-- Rogue Voidwalker
									16975,	-- Uncontrolled Voidwalker
								},
							}),
							i(25787),	-- Charm of Alacrity
							i(25786),	-- Hypnotist's Watch
						},
					}),
					q(9466, {	-- Wanted: Blacktalon the Savage
						["provider"] = { "o", 181638 },
						["coord"] = { 28.0, 60.3, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Blacktalon's Claws
								["provider"] = { "i", 23687 },	-- Blacktalon's Claws
								["coord"] = { 33.4, 65.1, HELLFIRE_PENINSULA },
								["cr"] = 17057,	-- Blacktalon the Savage
							}),
							i(25483),	-- Fine Sash
							i(25482),	-- Venn'ren's Boots
							i(25481),	-- Sunstrider's Gauntlets
						},
					}),
					q(10809, {	-- Wanted: Worg Master Kruush
						["provider"] = { "o", 185166 },	-- Wanted Poster
						["sourceQuest"] = 10449,	-- Apothecary Zelana (TODO:: verify this. It isn't always available, but first seen while on "Spinebreaker Post")
						["coord"] = { 61.2, 80.5, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Worg Master's Head
								["provider"] = { "i", 31374 },	-- Worg Master's Head
								["coord"] = { 68.3, 73.5, HELLFIRE_PENINSULA },
								["cr"] = 19442,	-- Worg Master Kruush
							}),
						},
					}),
					q(10485, {	-- Warlord of the Bleeding Hollow
						["qg"] = 21133,	-- Corporal Ironridge
						["sourceQuest"] = 10484,	-- Cursed Talismans
						["coord"] = { 70.9, 63.3, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/1 Morkh's Shattered Armor
								["provider"] = { "i", 30158 },	-- Morkh's Shattered Armor
								["coord"] = { 70.1, 77.1, HELLFIRE_PENINSULA },
								["cr"] = 16964,	-- Warlord Morkh
							}),
						},
					}),
					q(10055, {	-- Waste Not, Want Not
						["qg"] = 21209,	-- Dumphry
						["coord"] = { 51.2, 60.3, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 25912, 8 },	-- Salvaged Metal
							{ "i", 25911, 8 },	-- Salvaged Wood
						},
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							i(29938),	-- Battle Seeker Chesguard
							i(29943),	-- Legionnaire's Studded Helm
							i(29945),	-- Magistrate's Greaves
							i(29931),	-- Phantasmal Headdress
						},
					}),
					q(10079, {	-- When This Mine's a-Rockin'
						["qg"] = 16837,	-- Foreman Biggums
						["sourceQuest"] = 10143,	-- Expedition Point
						["coord"] = { 52.0, 62.5, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- 0/12 Gan'arg Sapper slain
								["cr"] = 18827,	-- Gan'arg Sapper
							}),
						},
					}),
					q(10344, {	-- Wing Commander Gryphongar
						["qg"] = 20234,	-- Runetog Wildhammer
						["sourceQuest"] = 10340,	-- Shatter Point
						["coord"] = { 78.4, 34.9, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["isBreadcrumb"] = true,
						["lvl"] = lvlsquish(58, 10, 58),
					}),
					q(10895, {	-- Zeth'Gor Must Burn! [Alliance]
						["qg"] = 19409,	-- Wing Commander Dabir'ee
						["coord"] = { 71.4, 62.4, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Northern Tower Marked
								["provider"] = { "i", 31739 },	-- Smoke Beacon
								["coord"] = { 68.0, 66.7, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Southern Tower Marked
								["provider"] = { "i", 31739 },	-- Smoke Beacon
								["coord"] = { 66.6, 76.5, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Forge Tower Marked
								["provider"] = { "i", 31739 },	-- Smoke Beacon
								["coord"] = { 70.1, 69.2, HELLFIRE_PENINSULA },
							}),
							objective(4, {	-- Foothill Tower Marked
								["provider"] = { "i", 31739 },	-- Smoke Beacon
								["coord"] = { 70.8, 71.5, HELLFIRE_PENINSULA },
							}),
							i(28057),	-- Bonechewer Berserker's Vest
							i(28055),	-- Gilded Crimson Chestplate
							i(28052),	-- Goldweave Tunic
							i(28051),	-- Jerkin of the Untamed Spirit
							i(28050),	-- Sacred Feather Vest
						},
					}),
					q(10792, {	-- Zeth'Gor Must Burn! [Horde]
						["qg"] = 22107,	-- Captain Darkhowl
						["sourceQuest"] = 10809,	-- WANTED: Worg Master Kruush
						["coord"] = { 61.2, 81.3, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["lvl"] = lvlsquish(58, 10, 58),
						["groups"] = {
							objective(1, {	-- Barracks Burned
								["provider"] = { "i", 31346 },	-- Burning Bleeding Hollow Torch
								["coord"] = { 69.5, 76.0, HELLFIRE_PENINSULA },
							}),
							objective(2, {	-- Eastern Hovel Burned
								["provider"] = { "i", 31346 },	-- Burning Bleeding Hollow Torch
								["coord"] = { 69.9, 70.0, HELLFIRE_PENINSULA },
							}),
							objective(3, {	-- Western Hovel Burned
								["provider"] = { "i", 31346 },	-- Burning Bleeding Hollow Torch
								["coord"] = { 67.3, 76.3, HELLFIRE_PENINSULA },
							}),
							objective(4, {	-- Stable Burned
								["provider"] = { "i", 31346 },	-- Burning Bleeding Hollow Torch
								["coord"] = { 68.5, 73.3, HELLFIRE_PENINSULA },
							}),
							i(27732),	-- Infiltrator's Cloak
							i(27731),	-- Vindicator's Cloak
						},
					}),
				}),
				n(RARES, {
					n(18678, {	-- Fulgorge
						["description"] = "This rare cannot be manually targeted, and you may not be able to see it if you're flying too high.  Search along its three possible paths and be on the lookout for red rumbling rocks.",
						["coords"] = {
							{ 23.8, 63.0, HELLFIRE_PENINSULA },	-- west path, bottom
							{ 24.8, 48.0, HELLFIRE_PENINSULA },	-- west path, mid
							{ 30.8, 37.0, HELLFIRE_PENINSULA },	-- west path, top
							{ 28.6, 65.8, HELLFIRE_PENINSULA },	-- central path, bottom
							{ 37.2, 52.8, HELLFIRE_PENINSULA },	-- central path, mid
							{ 45.0, 48.8, HELLFIRE_PENINSULA },	-- central path, top
							{ 41.4, 71.8, HELLFIRE_PENINSULA },	-- east path, bottom
							{ 49.4, 70.6, HELLFIRE_PENINSULA },	-- east path, mid
							{ 56.6, 71.8, HELLFIRE_PENINSULA },	-- east path, top
						},
						["groups"] = {
							i(31181),	-- Rockwurm Handwraps
							i(31179),	-- Rockwurm Hide Gloves
							i(31177),	-- Rockwurm Scale Gauntlets
							i(31176),	-- Rockwurm Plate Handguards
						},
					}),
					n(18677, {	-- Mekthorg the Wild
						["coords"] = {
							{ 41.6, 71.2, HELLFIRE_PENINSULA },
							{ 47.0, 58.4, HELLFIRE_PENINSULA },
							{ 49.2, 50.8, HELLFIRE_PENINSULA },
							{ 44.8, 40.2, HELLFIRE_PENINSULA },
							{ 55.6, 50.4, HELLFIRE_PENINSULA },
							{ 69.8, 68.2, HELLFIRE_PENINSULA },
							{ 64.8, 72.4, HELLFIRE_PENINSULA },
							{ 67.8, 76.8, HELLFIRE_PENINSULA },
						},
						["groups"] = {
							i(31174),	-- Demonweave Raiment
							i(31172),	-- Demon-Cured Tunic
							i(31170),	-- Demon-Forged Hauberk
							i(31168),	-- Demon-Forged Chestguard
						},
					}),
					n(18679, {	-- Vorakem Doomspeaker <Herald of Doom Lord Kazzak>
						["coords"] = {
							{ 74.0, 36.9, HELLFIRE_PENINSULA },
							{ 71.4, 56.0, HELLFIRE_PENINSULA },
						},
						["groups"] = {
							i(31185),	-- Legion Crown
							i(31184),	-- Legion Headguard
							i(31183),	-- Legion Coif
							i(31182),	-- Legion Helm
						},
					}),
				}),
				n(VENDORS, {
					n(18802, {	-- Alchemist Gribble <Alchemy Trainer>
						["coord"] = { 53.8, 65.8, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = {
							i(22900, {	-- Recipe: Elixir of Camouflage
								["isLimited"] = true,
							}),
						},
					}),
					n(16588, {	-- Apothecary Antonivich <Alchemy Trainer>
						["coord"] = { 52.2, 36.4, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(22900, {	-- Recipe: Elixir of Camouflage
								["isLimited"] = true,
							}),
						},
					}),
					n(18991, {	-- Aresella <Medic>
						["coord"] = { 26.2, 62.0, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = sharedData({["timeline"] = { "added 2.2.0.7272", "removed 8.0"}},{
							i(21993),	-- Manual: Heavy Netherweave Bandage
							i(21992),	-- Manual: Netherweave Bandage
							i(22012),	-- Master First Aid - Doctor in the House
						}),
					}),
					n(18267, {	-- Battlecryer Blackeye
						["coord"] = { 55.9, 39.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = pvp({
							i(27832, {	-- Band of the Victor
								["cost"] = { { "i", 24581, 15 }, },	-- 15x Mark of Thrallmar
							}),
							i(63697, {	-- Bold Blood Garnet
								["cost"] = { { "i", 24581, 10 }, },	-- 10x Mark of Thrallmar
								["timeline"] = { "added 4.0.1.12941" },
							}),
							i(27777, {	-- Brilliant Blood Garnet (Cata+) / Stark Blood Garnet (TBC)
								["cost"] = { { "i", 24581, 10 }, },	-- 10x Mark of Thrallmar
							}),
							i(27830, {	-- Circlet of the Victor
								["cost"] = { { "i", 24581, 15 }, },	-- 15x Mark of Thrallmar
							}),
							i(28360, {	-- Delicate Blood Garnet (Cata+) / Mighty Blood Garnet (TBC)
								["cost"] = { { "i", 24581, 10 }, },	-- 10x Mark of Thrallmar
							}),
							i(27786, {	-- Jagged Deep Peridot (Cata+) / Barbed Deep Peridot (TBC)
								["cost"] = { { "i", 24581, 10 }, },	-- 10x Mark of Thrallmar
							}),
							i(24522, {	-- Thrallmar Favor
								["cost"] = { { "i", 24581, 5 }, },	-- 5x Mark of Thrallmar
							}),
						}),
					}),
					-- #if AFTER WRATH
					n(35099, {	-- Bana Wildmane <Wind Rider Keeper>
						["coord"] = { 54.2, 41.6, HELLFIRE_PENINSULA },
						["timeline"] = { "added 3.2.0.10192" },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(25475),	-- Blue Wind Rider (MOUNT!)
							i(25476),	-- Green Wind Rider (MOUNT!)
							i(25531),	-- Swift Green Wind Rider (MOUNT!)
							i(25533),	-- Swift Purple Wind Rider (MOUNT!)
							i(25477),	-- Swift Red Wind Rider (MOUNT!)
							i(25532),	-- Swift Yellow Wind Rider (MOUNT!)
							i(25474),	-- Tawny Wind Rider (MOUNT!)
						},
					}),
					-- #endif
					n(18988, {	-- Baxter <Chef>
						["coord"] = { 56.8, 37.4, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(27736, {	-- Master Cookbook
								["timeline"] = { "removed 3.1.0" },
								["rank"] = 5,
							}),
						},
					}),
					n(18990, {	-- Burko <Medic>
						["coord"] = { 22.4, 39.4, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = sharedData({["timeline"] = { "added 2.2.0.7272", "removed 8.0"}},{
							i(21993),	-- Manual: Heavy Netherweave Bandage
							i(21992),	-- Manual: Netherweave Bandage
							i(22012),	-- Master First Aid - Doctor in the House
						}),
					}),
					n(16585, {	-- Cookie One-Eye <Food & Drink>
						["coord"] = { 54.6, 41.0, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(27688),	-- Recipe: Ravager Dog
						},
					}),
					n(18997, {	-- Fallesh Sunfallow <Weapon Merchant>
						["coord"] = { 26.4, 60.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(30755, {	-- Mag'hari Fighting Claw
								["isLimited"] = true,
							}),
							i(30753, {	-- Warphorn Spear
								["isLimited"] = true,
							}),
						},
					}),
					n(18753, {	-- Felannia <Enchanting Trainer>
						["coord"] = { 52.2, 36.0, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = FELANNIA_JOHAN_GROUPS,
					}),
					n(16602, {	-- Floyd Pinkus <Innkeeper>
						["coord"] = { 56.7, 37.5, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(30748, {	-- Enchanter's Satchel
								["isLimited"] = true,
							}),
							i(30747, {	-- Gem Pouch
								["isLimited"] = true,
							}),
							i(30746, {	-- Mining Sack
								["isLimited"] = true,
							}),
							i(30745, {	-- Heavy Toolbox
								["isLimited"] = true,
							}),
						},
					}),
					n(18987, {	-- Gaston <Chef>
						["coord"] = { 54.0, 63.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = {
							i(27736, {	-- Master Cookbook
								["timeline"] = { "removed 3.1.0" },
								["rank"] = 5,
							}),
						},
					}),
					-- #if AFTER WRATH
					n(35101, {	-- Grunda Bronzewing <Gryphon Keeper>
						["coord"] = { 54.2, 62.6, HELLFIRE_PENINSULA },
						["timeline"] = { "added 3.2.0.10192" },
						["races"] = ALLIANCE_ONLY,
						["groups"] = {
							i(25471),	-- Ebon Gryphon (MOUNT!)
							i(25470),	-- Golden Gryphon (MOUNT!)
							i(25472),	-- Snowy Gryphon (MOUNT!)
							i(25473),	-- Swift Blue Gryphon (MOUNT!)
							i(25528),	-- Swift Green Gryphon (MOUNT!)
							i(25529),	-- Swift Purple Gryphon (MOUNT!)
							i(25527),	-- Swift Red Gryphon (MOUNT!)
						},
					}),
					-- #endif
					-- #if BEFORE 4.0.1
					n(30734, {	-- Jezebel Bican <Inscription Supplies>
						["coord"] = { 54.0, 65.6, NORTHREND_DALARAN },
						["races"] = ALLIANCE_ONLY,
						["groups"] = {
							i(50166, {	-- Technique: Glyph of Eternal Water
								["timeline"] = { "deleted 4.0.1" },
							}),
						},
					}),
					-- #endif
					n(18773, {	-- Johan Barnes <Enchanting Trainer>
						["coord"] = { 53.6, 66.0, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = FELANNIA_JOHAN_GROUPS,
					}),
					n(18751, {	-- Kalaen <Jewelcrafting Trainer>
						["coord"] = { 56.78, 37.79, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = JEWELCRAFTING_PATTERNS,
					}),
					-- #if BEFORE 4.0.1
					n(30735, {	-- Kul Inkspiller <Inscription Supplies>
						["coord"] = { 52.4, 36.0, NORTHREND_DALARAN },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(50166, {	-- Technique: Glyph of Eternal Water
								["timeline"] = { "deleted 4.0.1" },
							}),
						},
					}),
					-- #endif
					n(18775, {	-- Lebowski <Engineering Trainer>
						["coord"] = { 55.6, 65.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = {
							i(23803, {	-- Schematic: Cogspinner Goggles
								["isLimited"] = true,
							}),
							i(23805, {	-- Schematic: Ultra-Spectropic Detection Goggles
								["isLimited"] = true,
							}),
						},
					}),
					n(17657, {	-- Logistics Officer Ulrike <Honor Hold Quartermaster>
						["coord"] = { 56.6, 62.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = {
							i(23999),	-- Honor Hold Tabard
							i(30622, {	-- Flamewrought Key
								["timeline"] = { "removed 4.2.0.10000" },
								["races"] = ALLIANCE_ONLY,
								-- #if BEFORE 4.2.0
								-- #if ANYCLASSIC
								-- Blizzard added "Honored" versions of this key for TBC Classic... BLIZZARD.
								["OnTooltip"] = [[function(t)
									local tooltip = _.ShowItemCompareTooltips(t.otherItemID);
									if ATTClassicSettings.Unobtainables[]] .. TBC_PHASE_FOUR .. [[] then
										tooltip:AddLine("This is now available at Honored reputation.", 0.4, 0.8, 1, 1);
									else
										tooltip:AddLine("This will be available at Honored reputation after TBC Phase 4.", 0.4, 0.8, 1, 1);
									end
									tooltip:Show();
								end]],
								["OnUpdate"] = [[function(t)
									if not t.otherItemID then
										t.otherItemID = 185687;
										_.CacheField(t, "itemID", t.otherItemID);
										t.GetItemCount = function(t) return GetItemCount(t.itemID, true) + GetItemCount(t.otherItemID, true); end
										t.OnUpdate = nil;
									end
								end]],
								-- #endif
								-- #endif
							}),
							i(32883, {	-- Felbane Slugs
								["timeline"] = { "removed 4.0.1.10000" },
							}),
							i(29196, {	-- Glyph of Fire Warding
								["timeline"] = { "removed 5.0.4" },
							}),
							i(29189, {	-- Glyph of Renewal
								["timeline"] = { "removed 5.0.4" },
							}),
							i(29153),	-- Blade of the Archmage
							applyclassicphase(TBC_PHASE_TWO, i(35476)),	-- Crusader's Ornamented Spaulders
							applyclassicphase(TBC_PHASE_TWO, i(35477)),	-- Crusader's Scaled Gauntlets
							i(24180),	-- Design: Dawnstone Crab
							i(23142),	-- Design: Regal Deep Peridot (Cata+) / Design: Enduring Deep Peridot (TBC)
							applyclassicphase(TBC_PHASE_TWO, i(35469)),	-- Dragonhide Robe
							applyclassicphase(TBC_PHASE_TWO, i(35464)),	-- Dreadweave Robe
							applyclassicphase(TBC_PHASE_TWO, i(35465)),	-- Evoker's Silk Amice
							i(25825),	-- Footman's Longsword
							i(22531),	-- Formula: Enchant Bracer - Superior Healing (RECIPE!)
							i(22547),	-- Formula: Enchant Chest - Exceptional Stats (RECIPE!)
							i(33150, {["timeline"]={"added 2.2.0"}}),	-- Formula: Enchant Cloak - Subtlety (RECIPE!)
							i(29166),	-- Hellforged Halberd
							i(29156),	-- Honor's Call
							applyclassicphase(TBC_PHASE_TWO, i(35470)),	-- Kodohide Spaulders
							applyclassicphase(TBC_PHASE_TWO, i(35467)),	-- Mooncloth Vestments
							applyclassicphase(TBC_PHASE_TWO, i(35468)),	-- Opportunist's Leather Gloves
							i(29719, {	-- Pattern: Cobrahide Leg Armor
								["spellID"] = 35549,	-- Cobrahide Leg Armor
								["requireSkill"] = LEATHERWORKING,
							}),
							i(29213, {	-- Pattern: Felstalker Belt
								["spellID"] = 32498,	-- Felstalker Belt
								["requireSkill"] = LEATHERWORKING,
							}),
							i(29214, {	-- Pattern: Felstalker Bracers
								["spellID"] = 32499,	-- Felstalker Bracers
								["requireSkill"] = LEATHERWORKING,
							}),
							i(29215, {	-- Pattern: Felstalker Breastplate
								["spellID"] = 32500,	-- Felstalker Breastplate
								["requireSkill"] = LEATHERWORKING,
							}),
							i(29722, {	-- Pattern: Nethercobra Leg Armor
								["spellID"] = 35554,	-- Nethercobra Leg Armor
								["requireSkill"] = LEATHERWORKING,
							}),
							applyclassicphase(TBC_PHASE_THREE, i(34218, {	-- Pattern: Netherscale Ammo Pouch
								["timeline"] = { "removed 4.0.1.10000" },
							})),
							i(23619),	-- Plans: Felsteel Shield Spike (RECIPE!)
							i(22905),	-- Recipe: Elixir of Major Agility
							i(25870),	-- Recipe: Transmute Skyfire Diamond
							i(29169),	-- Ring of Convalescence
							i(25826),	-- Sage's Band
							applyclassicphase(TBC_PHASE_TWO, i(35466)),	-- Satin Hood
							applyclassicphase(TBC_PHASE_TWO, i(35478)),	-- Savage Plate Helm
							applyclassicphase(TBC_PHASE_TWO, i(35474)),	-- Seer's Linked Helm
							applyclassicphase(TBC_PHASE_TWO, i(35472)),	-- Seer's Mail Armor
							applyclassicphase(TBC_PHASE_TWO, i(35473)),	-- Seer's Ringmail Gloves
							applyclassicphase(TBC_PHASE_TWO, i(35475)),	-- Stalker's Chain Gauntlets
							i(29151),	-- Veteran's Musket
							applyclassicphase(TBC_PHASE_TWO, i(35471)),	-- Wyrmhide Gloves
							i(24008),	-- Dried Mushroom Rations
							i(24007),	-- Footman's Waterskin
						},
					}),
					n(22227, {	-- Markus Scylan <Gem Vendor>
						["coord"] = { 54.67, 63.57, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = VENDOR_GEMS,
					}),
					n(19836, {	-- Mixie Farshot <Gun Merchant>
						["coord"] = { 61.1, 81.4, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(23807, {	-- Schematic: Adamantite Scope
								["isLimited"] = true,
							}),
							i(23803, {	-- Schematic: Cogspinner Goggles
								["isLimited"] = true,
							}),
						},
					}),
					n(17585, {	-- Quartermaster Urgronn <Thrallmar Quartermaster>
						["coord"] = { 54.9, 37.8, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(24004),	-- Thrallmar Tabard
							i(30637, {	-- Flamewrought Key
								["timeline"] = { "removed 4.2.0.10000" },
								["races"] = HORDE_ONLY,
								-- #if BEFORE 4.2.0
								-- #if ANYCLASSIC
								-- Blizzard added "Honored" versions of this key for TBC Classic... BLIZZARD.
								["OnTooltip"] = [[function(t)
									local tooltip = _.ShowItemCompareTooltips(t.otherItemID);
									if ATTClassicSettings.Unobtainables[]] .. TBC_PHASE_FOUR .. [[] then
										tooltip:AddLine("This is now available at Honored reputation.", 0.4, 0.8, 1, 1);
									else
										tooltip:AddLine("This will be available at Honored reputation after TBC Phase 4.", 0.4, 0.8, 1, 1);
									end
									tooltip:Show();
								end]],
								["OnUpdate"] = [[function(t)
									if not t.otherItemID then
										t.otherItemID = 185686;
										_.CacheField(t, "itemID", t.otherItemID);
										t.GetItemCount = function(t) return GetItemCount(t.itemID, true) + GetItemCount(t.otherItemID, true); end
										t.OnUpdate = nil;
									end
								end]],
								-- #endif
								-- #endif
							}),
							i(29197, {	-- Glyph of Fire Warding
								["timeline"] = { "removed 5.0.4" },
							}),
							i(29190, {	-- Glyph of Renewal
								["timeline"] = { "removed 5.0.4" },
							}),
							i(32882, {	-- Hellfire Shot
								["timeline"] = { "removed 4.0.1.10000" },
							}),
							i(29168),	-- Ancestral Band
							i(29167),	-- Blackened Spear
							applyclassicphase(TBC_PHASE_TWO, i(35406)),	-- Crusader's Ornamented Spaulders
							applyclassicphase(TBC_PHASE_TWO, i(35413)),	-- Crusader's Scaled Gauntlets
							i(31358),	-- Design: Dawnstone Crab
							i(31359),	-- Design: Regal Deep Peridot (Cata+) / Design: Enduring Deep Peridot (TBC)
							applyclassicphase(TBC_PHASE_TWO, i(35360)),	-- Dragonhide Robe
							applyclassicphase(TBC_PHASE_TWO, i(35332)),	-- Dreadweave Robe
							applyclassicphase(TBC_PHASE_TWO, i(35343)),	-- Evoker's Silk Amice
							i(25824),	-- Farseer's Band
							i(24000),	-- Formula: Enchant Bracer - Superior Healing (RECIPE!)
							i(24003),	-- Formula: Enchant Chest - Exceptional Stats (RECIPE!)
							i(33151, {["timeline"]={"added 2.2.0"}}),	-- Formula: Enchant Cloak - Subtlety (RECIPE!)
							i(25823),	-- Grunt's Waraxe
							applyclassicphase(TBC_PHASE_TWO, i(35364)),	-- Kodohide Spaulders
							i(29152),	-- Marksman's Bow
							applyclassicphase(TBC_PHASE_TWO, i(35337)),	-- Mooncloth Vestments
							applyclassicphase(TBC_PHASE_TWO, i(35366)),	-- Opportunist's Leather Gloves
							i(31361, {	-- Pattern: Cobrahide Leg Armor
								["spellID"] = 35549,	-- Cobrahide Leg Armor
								["requireSkill"] = LEATHERWORKING,
							}),
							i(25738, {	-- Pattern: Felstalker Belt
								["spellID"] = 32498,	-- Felstalker Belt
								["requireSkill"] = LEATHERWORKING,
							}),
							i(25739, {	-- Pattern: Felstalker Bracers
								["spellID"] = 32499,	-- Felstalker Bracers
								["requireSkill"] = LEATHERWORKING,
							}),
							i(25740, {	-- Pattern: Felstalker Breastplate
								["spellID"] = 32500,	-- Felstalker Breastplate
								["requireSkill"] = LEATHERWORKING,
							}),
							i(31362, {	-- Pattern: Nethercobra Leg Armor
								["spellID"] = 35554,	-- Nethercobra Leg Armor
								["requireSkill"] = LEATHERWORKING,
							}),
							applyclassicphase(TBC_PHASE_THREE, i(34201, {	-- Pattern: Netherscale Ammo Pouch
								["timeline"] = { "removed 4.0.1.10000" },
							})),
							i(24002),	-- Plans: Felsteel Shield Spike (RECIPE!)
							i(24001),	-- Recipe: Elixir of Major Agility
							i(29232),	-- Recipe: Transmute Skyfire Diamond
							applyclassicphase(TBC_PHASE_TWO, i(35339)),	-- Satin Hood
							applyclassicphase(TBC_PHASE_TWO, i(35409)),	-- Savage Plate Helm
							applyclassicphase(TBC_PHASE_TWO, i(35383)),	-- Seer's Linked Helm
							applyclassicphase(TBC_PHASE_TWO, i(35386)),	-- Seer's Mail Armor
							applyclassicphase(TBC_PHASE_TWO, i(35392)),	-- Seer's Ringmail Gloves
							applyclassicphase(TBC_PHASE_TWO, i(35377)),	-- Stalker's Chain Gauntlets
							i(29155),	-- Stormcaller
							i(29165),	-- Warbringer
							applyclassicphase(TBC_PHASE_TWO, i(35371)),	-- Wyrmhide Gloves
							i(24009),	-- Dried Fruit Rations
							i(24006),	-- Grunt's Waterskin
						},
					}),
					n(22225, {	-- Reagan Mancuso <Gem Vendor>
						["coord"] = { 45.82, 37.79, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = VENDOR_GEMS,
					}),
					n(16583, {	-- Rohok <Master Blacksmithing Trainer>
						["coord"] = { 53.2, 38.2, HELLFIRE_PENINSULA },
						["races"] = HORDE_ONLY,
						["groups"] = {
							i(25847, {	-- Plans: Eternium Rod (RECIPE!)
								["timeline"] = { "added 2.0.1", "removed 5.0.4" },
							}),
							i(23638, {	-- Plans: Lesser Ward of Shielding (RECIPE!)
								["isLimited"] = true,
							}),
						},
					}),
					n(16826, {	-- Sid Limbardi <Innkeeper>
						["coord"] = { 54.2, 63.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = {
							i(27688),	-- Recipe: Ravager Dog
						},
					}),
					n(19001, {	-- Talaara <Weapon Merchant>
						["coord"] = { 23.2, 40.0, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = {
							i(30755, {	-- Mag'hari Fighting Claw
								["isLimited"] = true,
							}),
							i(30753, {	-- Warphorn Spear
								["isLimited"] = true,
							}),
						},
					}),
					n(18774, {	-- Tatiana <Jewelcrafting Trainer>
						["coord"] = { 54.6, 63.6, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = JEWELCRAFTING_PATTERNS,
					}),
					n(19004, {	-- Vodesiin <Reagents>
						["coord"] = { 24.4, 38.8, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = {
							i(25848, {	-- Formula: Runed Adamantite Rod (RECIPE!)
								["timeline"] = { "added 2.0.1", "removed 5.0.4" },
							}),
						},
					}),
					n(18266, {	-- Warrant Officer Tracy Proudwell
						["coord"] = { 56.4, 62.8, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
						["groups"] = pvp({
							i(27833, {	-- Band of the Victor
								["cost"] = { { "i", 24579, 15 }, },	-- 15x Mark of Honor Hold
							}),
							i(63696, {	-- Bold Blood Garnet
								["cost"] = { { "i", 24579, 10 }, },	-- 10x Mark of Honor Hold
								["timeline"] = { "added 4.0.1.12941" },
							}),
							i(27812, {	-- Brilliant Blood Garnet (Cata+) / Stark Blood Garnet (TBC)
								["cost"] = { { "i", 24579, 10 }, },	-- 10x Mark of Honor Hold
							}),
							i(27834, {	-- Circlet of the Victor
								["cost"] = { { "i", 24579, 15 }, },	-- 15x Mark of Honor Hold
							}),
							i(28361, {	-- Delicate Blood Garnet (Cata+) / Mighty Blood Garnet (TBC)
								["cost"] = { { "i", 24579, 10 }, },	-- 10x Mark of Honor Hold
							}),
							i(27809, {	-- Jagged Deep Peridot (Cata+) / Notched Deep Peridot (TBC)
								["cost"] = { { "i", 24579, 10 }, },	-- 10x Mark of Honor Hold
							}),
							i(24520, {	-- Honor Hold Favor
								["cost"] = { { "i", 24579, 5 }, },	-- 5x Mark of Honor Hold
							}),
							i(31799, {	-- Fei Fei Doggy Treat
								["cost"] = {
									-- #if BEFORE WRATH
									{ "i", 28464, 1 },	-- Sparkling Zircon
									{ "i", 2931, 1 },	-- Maiden's Anguish
									-- #endif
									{ "i", 4291, 1 },	-- Silken Thread
								},
							}),
						}),
					}),
				}),
				n(ZONE_DROPS, {
					i(28552, {	-- A Mysterious Tome
						["description"] = "Must have started or completed |cFFFFD700Make Them Listen|r for this item to become available.",
						["cr"] = 16906,	-- Unyielding Knight
						["races"] = HORDE_ONLY,
					}),
					i(23580, {	-- Avruu's Orb
						["cr"] = 17084,	-- Avruu
						["coords"] = {
							{ 25.57, 76.45, HELLFIRE_PENINSULA },
							{ 25.57, 76.33, HELLFIRE_PENINSULA },
							{ 25.53, 75.92, HELLFIRE_PENINSULA },
							{ 25.64, 75.25, HELLFIRE_PENINSULA },
						},
					}),
					i(31347, {	-- Bleeding Hollow Torch
						["cr"] = 16907,	-- Bleeding Hollow Peon
					}),
					i(31346, {	-- Burning Bleeding Hollow Torch
						["coord"] = { 69, 69, HELLFIRE_PENINSULA },
						["cost"] = {
							{ "i", 31347, 1 },	-- Bleeding Hollow Torch
						},
					}),
					i(29588, {	-- Burning Legion Missive [Alliance]
						["cr"] = 19298,	-- Warbringer Arix'Amal
						["coord"] = { 53.0, 26.7, HELLFIRE_PENINSULA },
						["races"] = ALLIANCE_ONLY,
					}),
					i(29590, {	-- Burning Legion Missive [Horde]
						["cr"] = 20798,	-- Razorsaw
						["races"] = HORDE_ONLY,
					}),
					i(29476, {	-- Crimson Crystal Shard
						["cr"] = 19188,	-- Raging Colossus
					}),
					i(23338, {	-- Eroded Leather Case
						["crs"] = {
							16857,	-- Marauding Crust Burster
							16968,	-- Tunneler
						},
					}),
				}),
			},
		})),
	})),
});

-- Add in the items that aren't locked by phase.
appendGroups({
	i(20753),	-- Formula: Lesser Wizard Oil (RECIPE!)
	i(20752),	-- Formula: Minor Mana Oil (RECIPE!)
	i(20758),	-- Formula: Minor Wizard Oil (RECIPE!)
	i(22307),	-- Pattern: Enchanted Mageweave Pouch
	-- #if BEFORE CATA
	i(6342),	-- Formula: Enchant Chest - Minor Mana
	-- #endif
}, FELANNIA_JOHAN_GROUPS);

-- #if AFTER TBC
-- These quests trigger after specific events occur in the zone.
root("HiddenQuestTriggers", {
	q(10061),	-- The Unyielding - completed with 10050 "Unyielding Souls"
	q(10062, { ["_drop"] = { "g" }, }),	-- Looking to the Leadership - completed with 10057 "Looking to the Leadership"
	q(10088),	-- When This Mine's a-Rockin' - completed with quest 10079
	q(10125),	-- Mission: Disrupt Communications - completed with quest 10144 & 10208
	q(10207),	-- Forward Base: Reaver's Fall REUSE - completed with quest 10124 & 10143
	q(10214),	-- When This Mine's a-Rockin' - completed with quest 10079
	q(10454),	-- Hellfire Peninsula - Flag: OFF THE RAILS. Triggered just after turning in quest 10124 & 10143
});

-- These quests never made it in.
root("NeverImplemented", bubbleDown({ ["u"] = NEVER_IMPLEMENTED }, {
	n(QUESTS, {
		q(9344),	-- BETA A Hasty Departure
		q(10084, {	-- BETA Assault on Mageddon
			i(25996),	-- Emblem of Perseverance
			i(25994),	-- Rune of Force
			i(25995),	-- Star of Sha'naar
		}),
		q(10092, {	-- BETA Assault on Mageddon
			i(25996),	-- Emblem of Perseverance
			i(25994),	-- Rune of Force
			i(25995),	-- Star of Sha'naar
		}),
		q(10056),	-- BETA Bleeding Hollow Supplies
		q(10158),	-- BETA Bleeding Hollow Supplies
		q(10059),	-- BETA Dealing With Zeth'Gor
		q(10053),	-- BETA Dealing with Zeth'Gor
		q(10139, {	-- BETA Dispatching the Commander [Alliance]
			--i(28057),	-- Bonechewer Berserker's Vest
			i(28054),	-- Fleshripper's Bladed Chestplate [Remained Unobtainable, other rewards moved to other quests.]
			--i(28055),	-- Gilded Crimson Chestplate
			--i(28052),	-- Goldweave Tunic
			--i(28051),	-- Jerkin of the Untamed Spirit
			--i(28050),	-- Sacred Feather Vest
		}),
		q(10157, {	-- BETA Dispatching the Commander [Horde]
			--i(28057),	-- Bonechewer Berserker's Vest
			i(28054),	-- Fleshripper's Bladed Chestplate [Remained Unobtainable, other rewards moved to other quests.]
			--i(28055),	-- Gilded Crimson Chestplate
			--i(28052),	-- Goldweave Tunic
			--i(28051),	-- Jerkin of the Untamed Spirit
			--i(28050),	-- Sacred Feather Vest
		}),
		q(10089),	-- BETA Forge Camps of the Legion
		q(9408),	-- BETA Forgotten Heroes
		q(10054),	-- BETA Impending Doom
		q(10060),	-- BETA Impending Doom
		q(9511),	-- BETA Kargath's Battle Plans
		q(9342, {	-- BETA Marauding Crust Bursters
			-- Items on the current version of the quest, these don't need to be marked removed (and shouldn't be)
			--i(25785),	-- Adept's Band
			--i(25784),	-- Imbued Chain
		}),
		q(10135),	-- BETA Mission: Be the Messenger [Horde]
		q(10148),	-- BETA Mission: Be the Messenger [Alliance]
		q(10133),	-- BETA Mission: Kill the Messenger
		q(10147),	-- BETA Mission: Kill the Messenger
		q(10127),	-- BETA Mission: Sever the Tie
		q(10145),	-- BETA Mission: Sever the Tie UNUSED
		q(10370),	-- BETA Nazgrel's Command
		q(10131),	-- BETA Planning the Escape
		q(10154),	-- BETA Planning the Escape
		q(10137, {	-- BETA Provoking the Warboss
			i(25988),	-- Glowing Alabaster Ring
			i(25991),	-- Seamless Stone Band
			i(25990),	-- Smooth Soapstone Band
		}),
		q(10155, {	-- BETA Provoking the Warboss
			i(25988),	-- Glowing Alabaster Ring
			i(25991),	-- Seamless Stone Band
			i(25990),	-- Smooth Soapstone Band
		}),
		q(10398),	-- BETA Return to Honor Hold
		q(10558),	-- BETA Revered Among Honor Hold
		q(10559),	-- BETA Revered Among Thrallmar
		q(10128),	-- BETA Saving Private Imarion
		q(10153),	-- BETA Saving Scout Makha
		q(10122),	-- BETA The Citadel's Reach
		q(10150),	-- BETA The Citadel's Reach
		q(9382, {	-- BETA The Fate of the Clefthoof
			-- Items on the current version of the quest, these don't need to be marked removed (and shouldn't be)
			--i(25787),	-- Charm of Alacrity
			--i(25786),	-- Hypnotist's Watch
		}),
		q(10100, {	-- BETA The Mastermind
			-- Items on the current version of the quest, these don't need to be marked removed (and shouldn't be)
			--i(25982),	-- Foreman's Sash
			--i(25983),	-- Heavy Miner's Belt
			--i(25984),	-- Miner's Brace
		}),
		q(10130),	-- BETA The Western Flank
		q(10152),	-- BETA The Western Flank
		q(9377),	-- BETA Thirsting For Power
		q(10046),	-- BETA Through the Dark Portal
		q(10138),	-- BETA Under Whose Orders?
		q(10156),	-- BETA Under Whose Orders?
		q(10126),	-- BETA Warboss Nekrogg's Orders
		q(10151),	-- BETA Warboss Nekrogg's Orders
		q(9346),	-- BETA When Helboars Fly
		q(10090),	-- [Not Used] BETA The Legion's Plans
		q(9510),	-- [Not Used] BETA Bristlehide Clefthoof Hides
		q(9380),	-- [Not Used] BETA Hounded for More
	}),
}));
-- #endif