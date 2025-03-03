---------------------------------------------------
--          Z O N E S        M O D U L E         --
---------------------------------------------------

root("Zones", m(DRAGON_ISLES, bubbleDownSelf({ ["timeline"] = ADDED_DFREL }, {
	m(VALDRAKKEN, {
		n(PROFESSIONS, {
			prof(ALCHEMY, bubbleDownSelf({ ["requireSkill"] = ALCHEMY }, {
				n(185545, {	-- Conflago <Alchemy Trainer>
					["coord"] = { 36.6, 72.6, VALDRAKKEN },
					["g"] = {
						r(366261),	-- Dragon Isles Alchemy
						r(370547),	-- Aerated Mana Potion
						r(370746),	-- Basic Phial Experimentation
						r(370743),	-- Basic Potion Experimentation
						r(370551),	-- Elemental Potion of Power
						r(370722),	-- Omnium Draconis
						r(370465),	-- Phial of Tepid Versatility
						r(370717),	-- Primal Convergent
						r(370748),	-- Reclaim Concoctions
						r(389190),	-- Recraft Equipment
						r(370539),	-- Refreshing Healing Potion
						r(370711),	-- Transmute: Awakened Air
						r(370731),	-- Writhefire Oil
					},
				}),
			})),
			prof(BLACKSMITHING, bubbleDownSelf({ ["requireSkill"] = BLACKSMITHING }, {
				n(185546, {	-- Metalshaper Kuroko <Blacksmithing Trainer>
					["coord"] = { 37.2, 47.8, VALDRAKKEN },
					["g"] = {
						r(365677),	-- Dragon Isles Blacksmithing
						r(367600),	-- Draconium Axe
						r(371344),	-- Draconium Blacksmith's Hammer
						r(371364),	-- Draconium Blacksmith's Toolbox
						r(393404),	-- Draconium Defender
						r(367596),	-- Draconium Dirk
						r(393416),	-- Draconium Great Axe
						r(367598),	-- Draconium Great Mace
						r(367595),	-- Draconium Knuckles
						r(371338),	-- Draconium Leatherworker's Knife
						r(371360),	-- Draconium Leatherworker's Toolset
						r(371302),	-- Draconium Needle Set
						r(371309),	-- Draconium Pickaxe
						r(371343),	-- Draconium Sickle
						r(371304),	-- Draconium Skinning Knife
						r(367597),	-- Draconium Stiletto
						r(367599),	-- Draconium Sword
						r(367611),	-- Explorer's Expert Clasp
						r(395879),	-- Explorer's Expert Gauntlets
						r(395881),	-- Explorer's Expert Greaves
						r(395883),	-- Explorer's Expert Helm
						r(395880),	-- Explorer's Expert Spaulders
						r(367610),	-- Explorer's Plate Boots
						r(367609),	-- Explorer's Plate Bracers
						r(395886),	-- Explorer's Plate Chestguard
						r(367712),	-- Frostfire Alloy
						r(365735),	-- Primal Molten Alloy
						r(371674),	-- Primal Weightstone
						r(371650),	-- Primal Whetstone
						r(385304),	-- Recraft Equipment
						r(371395),	-- Serevite Repair Hammer
						r(371394),	-- Serevite Skeleton Key
					},
				}),
			})),
			prof(ENGINEERING, bubbleDownSelf({ ["requireSkill"] = ENGINEERING }, {
				n(185548, {	-- Clinkyclick Shatterboom <Engineering Trainer>
					["coord"] = { 42.2, 48.8, VALDRAKKEN },
					["g"] = {
						r(366254),	-- Dragon Isles Engineering
						r(382379),	-- Arclight Capacitor
						r(382391),	-- Battle-Ready Binoculars
						r(382393),	-- Bottomless Stonecrust Ore Satchel
						r(384314),	-- Bronze Fireflight
						r(382330),	-- Creature Combustion Canister
						r(382385),	-- Deadline Deadeyes
						r(382398),	-- Draconium Brainwave Amplifier
						r(382392),	-- Draconium Delver's Helmet
						r(382397),	-- Draconium Encased Samophlange
						r(382394),	-- Draconium Fisherfriend
						r(382377),	-- Everburning Blasting Powder
						r(382378),	-- Greased-Up Gears
						r(382402),	-- Gyroscopic Kaleidoscope
						r(382375),	-- Handful of Tyrivite Bolts
						r(382346),	-- Haphazardly Tethered Wires
						r(382395),	-- Lapidary's Draconium Clamps
						r(382388),	-- Lightweight Ocular Lenses
						r(382384),	-- Milestone Magnifiers
						r(382407),	-- Neural Silencer Mk3
						r(382390),	-- Oscillating Wilderness Opticals
						r(382348),	-- Overcharged Overclocker
						r(382387),	-- P.E.W. x2
						r(382389),	-- Peripheral Vision Projectors
						r(382383),	-- Quality-Assured Optics
						r(389192),	-- Recraft Equipment
						r(382380),	-- Reinforced Machine Chassis
						r(382386),	-- Sentry's Stabilized Specs
						r(382376),	-- Shock-Spring Coil
						r(382396),	-- Spring-Loaded Draconium Fabric Cutters
						r(382401),	-- Tinker: Plane Displacer
						r(382360),	-- Tinker Removal Kit
					},
				}),
			})),
			prof(FISHING, bubbleDownSelf({ ["requireSkill"] = FISHING }, {
				n(185359, {	-- Toklo <Fishing Trainer>
					["coord"] = { 44.6, 74.6, VALDRAKKEN },
					["g"] = {
						r(366253),	-- Dragon Isles Fishing
						r(393061),	-- Aileron Seamoth School
						r(393060),	-- Cerulean Spinefish School
						r(393064),	-- Islefin Dorado Pool
						r(393067),	-- Magma Thresher Pool
						r(393068),	-- Prismatic Leaper School
						r(393066),	-- Rimefin Tuna Pool
						r(393063),	-- Scalebelly Mackerel
						r(393065),	-- Shimmering Treasure Pool
						r(393062),	-- Temporal Dragonhead School
						r(393059),	-- Thousandbite Pirahna Swarm
					},
				}),
			})),
			prof(LEATHERWORKING, bubbleDownSelf({ ["requireSkill"] = LEATHERWORKING }, {
				n(185551, {	-- Hideshaper Koruz <Leatherworking Trainer>
					["coord"] = { 28.8, 61.6, VALDRAKKEN },
					["g"] = {
						r(366249),	-- Dragon Isles Leatherworking
						r(375188),	-- Alchemist's Hat
						r(375102),	-- Bonewrought Crossbow
						r(375182),	-- Durable Pack
						r(375178),	-- Earthshine Scales
						r(375168),	-- Feral Hide Drums
						r(375181),	-- Floral Basket
						r(375179),	-- Frostbite Scales
						r(375184),	-- Jeweler's Cover
						r(375174),	-- Mireslush Hide
						r(375103),	-- Pioneer's Leather Boots
						r(375104),	-- Pioneer's Leather Wristguards
						r(375105),	-- Pioneer's Leather Tunic
						r(395863),	-- Pioneer's Practiced Belt
						r(395864),	-- Pioneer's Practiced Cowl
						r(395865),	-- Pioneer's Practiced Gloves
						r(395867),	-- Pioneer's Practiced Leggings
						r(395868),	-- Pioneer's Practiced Shoulderpads
						r(375185),	-- Protective Gloves
						r(389195),	-- Recraft Equipment
						r(375164),	-- Reinforced Armor Kit
						r(375186),	-- Resilient Smock
						r(375183),	-- Skinner's Cap
						r(375187),	-- Smithing Apron
						r(375173),	-- Stonecrust Hide
						r(375106),	-- Trailblazer's Scale Boots
						r(375107),	-- Trailblazer's Scale Bracers
						r(375108),	-- Trailblazer's Scale Vest
						r(395839),	-- Trailblazer's Toughened Coif
						r(395844),	-- Trailblazer's Toughened Chainbelt
						r(395845),	-- Trailblazer's Toughened Grips
						r(395847),	-- Trailblazer's Toughened Legguards
						r(395851),	-- Trailblazer's Toughened Spikes
					},
				}),
			})),
			prof(JEWELCRAFTING, bubbleDownSelf({ ["requireSkill"] = JEWELCRAFTING }, {
				n(190094, {	-- Tuluradormi <Jewelcrafting Trainer>
					["coord"] = { 40.6, 61.2, VALDRAKKEN },
					["g"] = {
						r(366250),	-- Dragon Isles Jewelcrafting
						r(374627),	-- Dragon Isles Prospecting
						r(395696),	-- Dragon Isles Crushing
						r(376233),	-- Band of New Beginnings
						r(374530),	-- Bold-Print Bifocals
						r(374537),	-- Chromatic Focus
						r(374437),	-- Crafty Queen's Ruby
						r(374477),	-- Draconic Vial
						r(374553),	-- Elemental Harmony
						r(374439),	-- Energized Vibrant Emerald
						r(374461),	-- Forceful Nozdorite
						r(374478),	-- Frameless Lens
						r(374480),	-- Glossy Stone
						r(374460),	-- Jagged Nozdorite
						r(374531),	-- Left-Handed Magnifying Glass
						r(374494),	-- Pendant of Impending Perils
						r(374462),	-- Puissant Nozdorite
						r(389194),	-- Recraft Equipment
						r(374506),	-- Revitalizing Red Carving
						r(374440),	-- Sensei's Sundered Onyx
						r(374475),	-- Shimmering Clasp
						r(374441),	-- Solid Eternity Amber
						r(374463),	-- Steady Nozdorite
						r(374532),	-- Sundered Onyx Loupes
						r(374550),	-- Timewatcher's Patience
						r(374438),	-- Zen Mystic Sapphire
					},
				}),
			})),
			--[[
			prof(MINING, bubbleDownSelf({ ["requireSkill"] = MINING }, {
				n(, {	--
					["coord"] = { X, Y VALDRAKKEN },
					["g"] = {
						r(366264),	-- Dragon Isles Mining
						r(366260),	-- Mining
						r(396169),	-- Elementally-Charged Stone
						r(395269),	-- Iridescent Ore
						r(396162),	-- Khaz'gorite
						r(384692),	-- Serevite Deposit
					},
				}),
			}),
			prof(SKINNING, bubbleDownSelf({ ["requireSkill"] = SKINNING }, {
				n(, {	--
					["coord"] = { X, Y VALDRAKKEN },
					["g"] = {
						r(366259),	-- Skinning
						r(395282),	-- Curious Hide
						r(395706),	-- Dense Hide
						r(392440),	-- Leather Skinning
						r(395700),	-- Lustrous Scaled Hide
						r(396173),	-- Saturated Bone
						r(392445),	-- Scale Skinning
					},
				}),
			}),
			--]]
			prof(TAILORING, bubbleDownSelf({ ["requireSkill"] = TAILORING }, {
				n(193649, {	-- Threadfinder Fulafong <Tailoring Trainer>
					["coord"] = { 31.8, 68.2, VALDRAKKEN },
					["g"] = {
						r(376533),	-- Abrasive Polishing Cloth
						r(376535),	-- Blazing Embroidery Thread
						r(392396),	-- Dragon Isles Cloth Scavenging
						r(366258),	-- Dragon Isles Tailoring
						r(376562),	-- Dragon Isles Unravelling
						r(376699),	-- Illustrious Insight
						r(376509),	-- Surveyor's Cloth Bands
						r(376507),	-- Surveyor's Cloth Robe
						r(376508),	-- Surveyor's Cloth Treads
						r(376506),	-- Surveyor's Tailored Cloak
						r(389196),	-- Recraft Equipment
						r(376560),	-- Simply Stitched Reagent Bag
						r(395809),	-- Surveyor's Seasoned Cord
						r(395813),	-- Surveyor's Seasoned Gloves
						r(395814),	-- Surveyor's Seasoned Pants
						r(395807),	-- Surveyor's Seasoned Hood
						r(395815),	-- Surveyor's Seasoned Shoulders
						r(376538),	-- Vibrant Spellthread
						r(376558),	-- Vibrant Wildercloth Bolt
						r(376543),	-- Wildercloth Alchemist's Robe
						r(376528),	-- Wildercloth Bag
						r(376530),	-- Wildercloth Bandage
						r(376555),	-- Wildercloth Bolt
						r(376547),	-- Wildercloth Chef's Hat
						r(376549),	-- Wildercloth Enchanter's Hat
						r(376551),	-- Wildercloth Fishing Cap
						r(376553),	-- Wildercloth Gardening Hat
						r(376545),	-- Wildercloth Tailor's Coat
					},
				}),
			})),
		}),
	}),
})));