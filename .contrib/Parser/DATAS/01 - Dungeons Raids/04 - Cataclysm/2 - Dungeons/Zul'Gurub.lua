-----------------------------------------------------
--   D U N G E O N S  &  R A I D S  M O D U L E    --
-----------------------------------------------------

_.Instances = { tier(CATA_TIER, {
	inst(76, {	-- Zul'Gurub
		["mapID"] = ZULGURUB,
		["coord"] = { 72.0, 32.9, NORTHERN_STRANGLETHORN },	-- Zul'Gurub
		["g"] = {
			d(2, {	-- Heroic
				["lvl"] = 85,
				["g"] = {
					n(ACHIEVEMENTS, {
						ach(5744, {	-- Gurubashi Headhunter
							crit(1, {	-- Gub
								["_npcs"] = { 52440 },	-- Gub
							}),
							crit(2, {	-- Mortaxx
								["_npcs"] = { 52438 },	-- Mortaxx
							}),
							crit(3, {	-- Kaulema
								["_npcs"] = { 52422 },	-- Kaulema
							}),
							crit(4, {	-- Mor'Lek
								["_npcs"] = { 52405 },	-- Mor'Lek
							}),
							crit(5, {	-- Hive Queen
								["_npcs"] = { 52442 },	-- Florawing Hive Queen
							}),
							crit(6, {	-- Lost Offspring
								["_npcs"] = { 52418 },	-- Lost Offspring of Gahz'ranka
							}),
							crit(7, {	-- Gurubashi Master Chef
								["_npcs"] = { 52392 },	-- Gurubashi Master Chef
							}),
							crit(8, {	-- Tor-Tun
								["_npcs"] = { 52414 },	-- Tor-Tun
							}),
						}),
					}),
					n(ZONE_DROPS, {
						i(69803, {	-- Gurubashi Punisher
							["crs"] = {
								52348,	-- Berserking Boulder Roller
								52323,	-- Chosen of Hethiss
								52442,	-- Florawing Hive Queen
								52440,	-- Gub
								52077,	-- Gurubashi Berserker
								52325,	-- Gurubashi Blood Drinker
								52079,	-- Gurubashi Bloodrager
								52088,	-- Gurubashi Cauldron-Mixer
								52076,	-- Gurubashi Cauldron-Mixer
								52082,	-- Gurubashi Cauldron-Mixer
								52081,	-- Gurubashi Cauldron-Mixer
								52392,	-- Gurubashi Master Chef
								52436,	-- Gurubashi Refugee
								52327,	-- Gurubashi Shadow Hunter
								52598,	-- Gurubashi Soul-Eater
								52167,	-- Gurubashi Spirit Warrior
								52434,	-- Gurubashi Villager
								52606,	-- Gurubashi Warmonger
								52089,	-- Gurubashi Worker
								52086,	-- Hakkari Witch Doctor
								52422,	-- Kaulema the Mover
								52339,	-- Lesser Priest of Bethekk
								52418,	-- Lost Offspring of Gahz'ranka
								52405,	-- Mor'Lek the Dismantler
								52438,	-- Mortaxx
								52345,	-- Pride of Bethekk
								52085,	-- Razzashi Adder
								52417,	-- Shredtooth Frenzy
								52340,	-- Tiki Lord Mu'Loa
								52362,	-- Tiki Lord Zim'wae
								52380,	-- Venomancer Mauri
								52381,	-- Venomancer T'Kulu
								52311,	-- Venomguard Destroyer
								52379,	-- Venomtip Needler
								52322,	-- Witch Doctor Qu'in
								52962,	-- Zandalari Archon
								130241,	-- Zandalari Archon
								130243,	-- Zandalari Hierophant
								52958,	-- Zandalari Hierophant
								130245,	-- Zandalari Juggernaut
								52956,	-- Zandalari Juggernaut
								52413,	-- Zulian Gnasher
							},
						}),
						i(69800, {	-- Spiritguard Drape
							["crs"] = {
								52348,	-- Berserking Boulder Roller
								52323,	-- Chosen of Hethiss
								52442,	-- Florawing Hive Queen
								52377,	-- Florawing Needler
								52440,	-- Gub
								52077,	-- Gurubashi Berserker
								52325,	-- Gurubashi Blood Drinker
								52079,	-- Gurubashi Bloodrager
								52076,	-- Gurubashi Cauldron-Mixer
								52088,	-- Gurubashi Cauldron-Mixer
								52082,	-- Gurubashi Cauldron-Mixer
								52081,	-- Gurubashi Cauldron-Mixer
								52392,	-- Gurubashi Master Chef
								52436,	-- Gurubashi Refugee
								52327,	-- Gurubashi Shadow Hunter
								52598,	-- Gurubashi Soul-Eater
								52167,	-- Gurubashi Spirit Warrior
								52434,	-- Gurubashi Villager
								52435,	-- Gurubashi Villager
								52606,	-- Gurubashi Warmonger
								52089,	-- Gurubashi Worker
								52086,	-- Hakkari Witch Doctor
								52422,	-- Kaulema the Mover
								52339,	-- Lesser Priest of Bethekk
								52418,	-- Lost Offspring of Gahz'ranka
								52405,	-- Mor'Lek the Dismantler
								52438,	-- Mortaxx
								52345,	-- Pride of Bethekk
								52085,	-- Razzashi Adder
								52417,	-- Shredtooth Frenzy
								52340,	-- Tiki Lord Mu'Loa
								52362,	-- Tiki Lord Zim'wae
								52414,	-- Tor-Tun
								52380,	-- Venomancer Mauri
								52381,	-- Venomancer T'Kulu
								52311,	-- Venomguard Destroyer
								52379,	-- Venomtip Needler
								52322,	-- Witch Doctor Qu'in
								130241,	-- Zandalari Archon
								52962,	-- Zandalari Archon
								130243,	-- Zandalari Hierophant
								52958,	-- Zandalari Hierophant
								52956,	-- Zandalari Juggernaut
								130245,	-- Zandalari Juggernaut
								52413,	-- Zulian Gnasher
							},
						}),
						i(69796, {	-- Spiritcaller Cloak
							["crs"] = {
								52348,	-- Berserking Boulder Roller
								52323,	-- Chosen of Hethiss
								52442,	-- Florawing Hive Queen
								52440,	-- Gub
								52077,	-- Gurubashi Berserker
								52325,	-- Gurubashi Blood Drinker
								52079,	-- Gurubashi Bloodrager
								52076,	-- Gurubashi Cauldron-Mixer
								52088,	-- Gurubashi Cauldron-Mixer
								52082,	-- Gurubashi Cauldron-Mixer
								52081,	-- Gurubashi Cauldron-Mixer
								52392,	-- Gurubashi Master Chef
								52436,	-- Gurubashi Refugee
								52437,	-- Gurubashi Refugee
								52327,	-- Gurubashi Shadow Hunter
								52598,	-- Gurubashi Soul-Eater
								52167,	-- Gurubashi Spirit Warrior
								52435,	-- Gurubashi Villager
								52434,	-- Gurubashi Villager
								52606,	-- Gurubashi Warmonger
								52089,	-- Gurubashi Worker
								52086,	-- Hakkari Witch Doctor
								52422,	-- Kaulema the Mover
								52339,	-- Lesser Priest of Bethekk
								52418,	-- Lost Offspring of Gahz'ranka
								52405,	-- Mor'Lek the Dismantler
								52438,	-- Mortaxx
								52345,	-- Pride of Bethekk
								52085,	-- Razzashi Adder
								52417,	-- Shredtooth Frenzy
								52340,	-- Tiki Lord Mu'Loa
								52362,	-- Tiki Lord Zim'wae
								52414,	-- Tor-Tun
								52380,	-- Venomancer Mauri
								52381,	-- Venomancer T'Kulu
								52311,	-- Venomguard Destroyer
								52379,	-- Venomtip Needler
								52322,	-- Witch Doctor Qu'in
								52962,	-- Zandalari Archon
								52958,	-- Zandalari Hierophant
								130243,	-- Zandalari Hierophant
								52956,	-- Zandalari Juggernaut
								130245,	-- Zandalari Juggernaut
								52413,	-- Zulian Gnasher
							},
						}),
						i(69802, {	-- Band of the Gurubashi Berserker
							["crs"] = {
								52348,	-- Berserking Boulder Roller
								52323,	-- Chosen of Hethiss
								52442,	-- Florawing Hive Queen
								52440,	-- Gub
								52077,	-- Gurubashi Berserker
								52325,	-- Gurubashi Blood Drinker
								52079,	-- Gurubashi Bloodrager
								52088,	-- Gurubashi Cauldron-Mixer
								52076,	-- Gurubashi Cauldron-Mixer
								52082,	-- Gurubashi Cauldron-Mixer
								52081,	-- Gurubashi Cauldron-Mixer
								52392,	-- Gurubashi Master Chef
								52327,	-- Gurubashi Shadow Hunter
								52598,	-- Gurubashi Soul-Eater
								52167,	-- Gurubashi Spirit Warrior
								52434,	-- Gurubashi Villager
								52606,	-- Gurubashi Warmonger
								52089,	-- Gurubashi Worker
								52086,	-- Hakkari Witch Doctor
								52422,	-- Kaulema the Mover
								52339,	-- Lesser Priest of Bethekk
								52418,	-- Lost Offspring of Gahz'ranka
								52405,	-- Mor'Lek the Dismantler
								52438,	-- Mortaxx
								52345,	-- Pride of Bethekk
								52085,	-- Razzashi Adder
								52417,	-- Shredtooth Frenzy
								52340,	-- Tiki Lord Mu'Loa
								52362,	-- Tiki Lord Zim'wae
								52414,	-- Tor-Tun
								52380,	-- Venomancer Mauri
								52381,	-- Venomancer T'Kulu
								52311,	-- Venomguard Destroyer
								52379,	-- Venomtip Needler
								52322,	-- Witch Doctor Qu'in
								52962,	-- Zandalari Archon
								52958,	-- Zandalari Hierophant
								130245,	-- Zandalari Juggernaut
								52956,	-- Zandalari Juggernaut
								52413,	-- Zulian Gnasher
							},
						}),
					}),
					n(QUESTS, {
						q(29155, {	-- A Shiny Reward
							["races"] = ALLIANCE_ONLY,
							["sourceQuests"] = {
								29153,	-- Booty Bay's Interests
								29154,	-- Booty Bay's Interests
							},
							["providers"] = {
								{ "n", 2496 },	-- Baron Revilgaz
								{ "n", 53151 },	-- Overseer Blingbang
							},
							["g"] = {
								i(133997),	-- Black Ice (TOY!)
								i(69863, {	-- Golden Necklace
									["ignoreSource"] = true,	-- Yay, Blizzard gave these sourceIDs
								}),
								i(69865, {	-- Gem-Studded Bracelets
									["ignoreSource"] = true,	-- Yay, Blizzard gave these sourceIDs
								}),
								i(69864, {	-- Tarnished Crown
									["ignoreSource"] = true,	-- Yay, Blizzard gave these sourceIDs
								}),
							},
						}),
						q(29253, {	-- A Shiny Reward
							["races"] = HORDE_ONLY,
							["sourceQuests"] = {
								29251,	-- Booty Bay's Interests
								29252,	-- Booty Bay's Interests
							},
							["providers"] = {
								{ "n", 2496 },	-- Baron Revilgaz
								{ "n", 53151 },	-- Overseer Blingbang
							},
							["g"] = {
								i(133997),	-- Black Ice (TOY!)
								i(69863, {	-- Golden Necklace
									["ignoreSource"] = true,	-- Yay, Blizzard gave these sourceIDs
								}),
								i(69865, {	-- Gem-Studded Bracelets
									["ignoreSource"] = true,	-- Yay, Blizzard gave these sourceIDs
								}),
								i(69864, {	-- Tarnished Crown
									["ignoreSource"] = true,	-- Yay, Blizzard gave these sourceIDs
								}),
							},
						}),
						q(29208,  {	-- An Old Friend
							["sourceQuests"] = {
								26775,	-- Be Raptor [Alliance]
								26362,	-- Be Raptor [Horde]
							},
							["provider"] = { "n", 52877 },	-- Lashtail Hatchling
							["g"] = {
								i(69251),	-- Lashtail Hatchling
							},
						}),
						q(29154, {	-- Booty Bay's Interests
							["provider"] = { "n", 53151 },			-- Overseer Revilgaz
							["races"] = ALLIANCE_ONLY,
						}),
						q(29252, {	-- Booty Bay's Interests
							["provider"] = { "n", 53151 },			-- Overseer Revilgaz
							["races"] = HORDE_ONLY,
						}),
						q(29241,  {	-- Break the Godbreaker
							["provider"] = { "n", 53024 },			-- Bloodslayer Zala
						}),
						q(29174,  {	-- Break Their Spirits
							["u"] = NEVER_IMPLEMENTED,
						}),
						q(29175,  {	-- Break Their Spirits
							["provider"] = { "n", 53023 },			-- Bloodslayer T'ara
						}),
						q(29242,  {	-- Putting a Price on Priceless
							["provider"] = { "n", 53043 },			-- Briney Boltcutter
						}),
						q(29168,  {	-- Secondary Targets
							["u"] = NEVER_IMPLEMENTED,
						}),
						q(29173,  {	-- Secondary Targets
							["provider"] = { "n", 53023 },			-- Bloodslayer T'ara
						}),
						q(29169,  {	-- The Beasts Within
							["u"] = NEVER_IMPLEMENTED,
						}),
						q(29172,  {	-- The Beasts Within
							["provider"] = { "n", 53023 },			-- Bloodslayer T'ara
						}),
						q(29262,  {	-- Zul'Gurub Voodoo
							--["objectID"] = 208550,	-- Voodoo Pile
							["isDaily"] = true,
							["description"] = "You need 425 Archaeology and a Troll Tablet to activate the \"Call of the Raptor\" buff which summons raptor hatchlings to attack your enemies.",
						}),
					}),
					n(52442, {	-- Florawing Hive Queen
						["questID"] = 53809,	-- KillID
						["isDaily"] = true,
						["g"] = {
							i(69817),	-- Hive Queen's Honeycomb
						},
					}),
					n(52414),	-- Tor-Tun
					cr(52155, e(175, {	-- High Priest Venoxis
						ach(5743),	-- It's Not Easy Being Green
						i(69603),	-- Breastplate of Serenity
						i(69600),	-- Belt of Slithering Serpents
						i(69604),	-- Coils of Hate
						i(69601),	-- Serpentine Leggings
						i(69602),	-- Signet of Venoxis
					})),
					n(52422, {	-- Kaulema
						i(69818),	-- Giant Sack
					}),
					cr(52151, e(176, {	-- Bloodlord Mandokir
						ach(5762),	-- Ohganot So Fast!
						i(68823),	-- Armored Razzashi Raptor (MOUNT!)
						i(69609),	-- Bloodlord's Protector
						i(69607),	-- Touch of Discord
						i(69605),	-- Amulet of the Watcher
						i(69606),	-- Hakkari Loa Drape
						i(69608),	-- Deathcharged Wristguards
					})),
					n(52405, {	-- Mor'Lek
						i(69818),	-- Giant Sack
					}),
					n(-41,   {			-- Cache of Madness (Requires 225 Archeology)
						--[[ encounter IDs if we're ever able to use an array for them:
							177,	-- Gri'lek
							178,	-- Hazza'rah
							179,	-- Renataki
							180,	-- Wushoolay
						--]]
						["description"] = "Requires 225 Archaeology to spawn.",
						["g"] = {
							--[[ Using CRS // QGS doesn't apply the description.  Only applies to NPCID
							{	-- Summon Artifacts
								["npcID"] = 52446,	-- Ancient Dwarven Artifact
								["description"] = "This artifact is used in summoning the boss.",
								["providers"] = {
									{ "n", 52450 },	-- Ancient Elven Artifact
									{ "n", 52454 },	-- Ancient Fossil
									{ "n", 52452 },	-- Ancient Troll Artifact
								},
							},
							{	-- Ignored Artifacts
								["npcID"] = 52449,	-- Ancient Dwarven Artifact
								["description"] = "|CFFFF0000IGNORE!|r",
								["providers"] = {
									{ "n", 52451 },	-- Ancient Elven Artifact
									{ "n", 52455 },	-- Ancient Fossil
									{ "n", 52453 },	-- Ancient Troll Artifact
								},
							},
							--]]
							{	-- Ancient Dwarven Artifact
								["npcID"] = 52446,	-- Ancient Dwarven Artifact
								["description"] = "This artifact is used in summoning the boss.",
							},
							--[[
							{	-- Ancient Dwarven Artifact
								["npcID"] = 52449,	-- Ancient Dwarven Artifact
								["description"] = "|CFFFF0000IGNORE!|r",
							},
							--]]
							{	-- Ancient Elven Artifact
								["npcID"] = 52450,	-- Ancient Elven Artifact
								["description"] = "This artifact is used in summoning the boss.",
							},
							--[[
							{	-- Ancient Elven Artifact
								["npcID"] = 52451,	-- Ancient Elven Artifact
								["description"] = "|CFFFF0000IGNORE!|r",
							},
							--]]
							{	-- Ancient Fossil
								["npcID"] = 52454,	-- Ancient Fossil
								["description"] = "This artifact is used in summoning the boss.",
							},
							--[[
							{	-- Ancient Fossil
								["npcID"] = 52455,	-- Ancient Fossil
								["description"] = "|CFFFF0000IGNORE!|r",
							},
							--]]
							{	-- Ancient Troll Artifact
								["npcID"] = 52452,	-- Ancient Troll Artifact
								["description"] = "This artifact is used in summoning the boss.",
							},
							--[[
							{	-- Ancient Troll Artifact
								["npcID"] = 52453,	-- Ancient Troll Artifact
								["description"] = "|CFFFF0000IGNORE!|r",
							},
							--]]
							i(69638, {	-- Arlokk's Claws
								["crs"] = { 52269 },	-- Renataki
							}),
							i(69639, {	-- Renataki's Soul Slicer
								["crs"] = { 52269 },	-- Renataki
							}),
							i(69636, {	-- Thekal's Claws
								["crs"] = { 52271 },	-- Hazzarah
							}),
							i(69637, {	-- Gurubashi Destroyer
								["crs"] = { 52271 },	-- Hazzarah
							}),
							i(69631, {	-- Zulian Voodoo Stick
								["crs"] = {
									52258,	-- Gri'lek
									52271,	-- Hazzarah
									52269,	-- Renataki
									52286,	-- Wushoolay
								},
							}),
							i(69632, {	-- Lost Bag of Whammies
								["crs"] = {
									52258,	-- Gri'lek
									52271,	-- Hazzarah
									52269,	-- Renataki
									52286,	-- Wushoolay
								},
							}),
							i(69635, {	-- Amulet of Protection
								["crs"] = { 52258 },	-- Gri'lek
							}),
							i(69641, {	-- Troll Skull Chestplate
								["crs"] = { 52286 },	-- Wushoolay
							}),
							i(69630, {	-- Handguards of the Tormented
								["crs"] = {
									52258,	-- Gri'lek
									52271,	-- Hazzarah
									52269,	-- Renataki
									52286,	-- Wushoolay
								},
							}),
							i(69633, {	-- Plunderer's Gauntlets
								["crs"] = {
									52258,	-- Gri'lek
									52271,	-- Hazzarah
									52269,	-- Renataki
									52286,	-- Wushoolay
								},
							}),
							i(69640, {	-- Kilt of Forgotten Rites
								["crs"] = { 52286 },	-- Wushoolay
							}),
							i(69634, {	-- Fasc's Preserved Boots
								["crs"] = { 52258 },	-- Gri'lek
							}),
						},
					}),
					n(52438, {	-- Mortaxx
						i(52722),	-- Maelstrom Crystal
					}),
					n(52392, {	-- Gurubashi Master Chef
						i(69822),	-- Master Chef's Groceries
					}),
					cr(52059, e(181, {	-- High Priestess Kilnara
						ach(5765),	-- Here, Kitty Kitty...
						i(68824),	-- Swift Zulian Panther (MOUNT!)
						i(69614),	-- Roaring Mask of Bethekk
						i(69612),	-- Claw-Fringe Mantle
						i(69611),	-- Sash of Anguish
						i(69613),	-- Leggings of the Pride
						i(69610),	-- Arlokk's Signet
					})),
					cr(52053, e(184, {	-- Zanzil
						i(69618),	-- Zulian Slicer
						i(69617),	-- Plumed Medicine Helm
						i(69616),	-- Spiritbinder Spaulders
						i(69619),	-- Bone Plate Handguards
						i(69615),	-- Zombie Walker Legguards
					})),
					n(52440, {	-- Gub
						i(69823),	-- Gub's Catch
					}),
					n(52418, {	-- Lost Offspring of Gahz'ranka
						i(70719),	-- Water-Filled Gills
					}),
					cr(52148, e(185, {	-- Jin'do the Godbreaker
						ach(5768),	-- Heroic: Zul'Gurub
						ach(5759),	-- Spirit Twister
						i(69628),	-- Jeklik's Smasher
						i(69626),	-- Jin'do's Verdict
						i(69624),	-- Legacy of Arlokk
						i(69621),	-- Twinblade of the Hakkari
						i(69620),	-- Twinblade of the Hakkari
						i(69625),	-- Mandokir's Tribute
						i(69629),	-- Shield of the Blood God
						i(69627),	-- Zulian Ward
						i(69622),	-- The Hexxer's Mask
						i(69623),	-- Vestments of the Soulflayer
						h(i(122215)),	-- Music Roll: Zul'Gurub Voodoo
					})),
				},
			}),
		},
	}),
})};
root("HiddenQuestTriggers", {
	tier(WOD_TIER, {
		q(35411),	-- Zul'Gurub Reward Quest - Heroic completion
		q(35412),	-- Zul'Gurub Bonus Objective Reward Quest - kill Cache of Madness
	}),
});