/**********************Mineral deposits**************************/

/turf/closed/mineral //wall piece
	name = "rock"
	icon = 'icons/turf/mining.dmi'
	icon_state = "rock"
	var/smooth_icon = 'icons/turf/smoothrocks.dmi'
	smooth = SMOOTH_MORE|SMOOTH_BORDER
	canSmoothWith = null
	baseturfs = /turf/open/floor/plating/asteroid/
	opacity = 1
	density = TRUE
	layer = EDGED_TURF_LAYER
	temperature = TCMB
	var/environment_type = "asteroid"
	var/turf/open/floor/plating/turf_type = /turf/open/floor/plating/asteroid/
	var/obj/item/stack/ore/mineralType = null
	var/mineralAmt = 3
	var/last_act = 0
	var/scan_state = "" //Holder for the image we display when we're pinged by a mining scanner
	var/defer_change = 0
	var/maxDamage = 10
	var/damage = null
	var/mutable_appearance/crack_overlay
	var/can_dig_here = 1
/turf/closed/mineral/Initialize()
	if (!canSmoothWith)
		canSmoothWith = list(/turf/closed/mineral, /turf/closed/indestructible)
	var/matrix/M = new
	damage = maxDamage
	M.Translate(-4, -4)
	transform = M
	icon = smooth_icon
	if(scan_state)
		overlays += scan_state
	. = ..()

/turf/closed/mineral/proc/Spread_Vein()
	var/spreadChance = initial(mineralType.spreadChance)
	if(spreadChance)
		for(var/dir in GLOB.cardinals)
			if(prob(spreadChance))
				var/turf/T = get_step(src, dir)
				var/turf/closed/mineral/random/M = T
				if(istype(M) && !M.mineralType)
					M.Change_Ore(mineralType)

/turf/closed/mineral/proc/Change_Ore(var/ore_type, random = 0)
	if(random)
		mineralAmt = rand(1, 5)
	if(ispath(ore_type, /obj/item/stack/ore)) //If it has a scan_state, switch to it
		var/obj/item/stack/ore/the_ore = ore_type
		scan_state = initial(the_ore.scan_state) // I SAID. SWITCH. TO. IT.
		mineralType = ore_type // Everything else assumes that this is typed correctly so don't set it to non-ores thanks.

/turf/closed/mineral/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	if(turf_type)
		underlay_appearance.icon = initial(turf_type.icon)
		underlay_appearance.icon_state = initial(turf_type.icon_state)
		return TRUE
	return ..()


/turf/closed/mineral/attackby(obj/item/I, mob/user, params)
	if (!user.IsAdvancedToolUser())
		to_chat(usr, "<span class='warning'>You don't have the dexterity to do this!</span>")
		return

	if(I.tool_behaviour == TOOL_MINING)
		var/turf/T = user.loc
		if (!isturf(T))
			return

		if(last_act + (2 * I.toolspeed) > world.time)//prevents message spam
			return
		last_act = world.time
		to_chat(user, "<span class='notice'>You start picking...</span>")

		if(I.use_tool(src, user, 2, volume=50))
			if(ismineralturf(src))
				to_chat(user, "<span class='notice'>You finish cutting into the rock.</span>")
				I.obj_integrity -= 0.1
				damage -= 1
				SSblackbox.record_feedback("tally", "pick_used_mining", 1, I.type)
				if(damage <= 1)
					gets_drilled(user, TRUE)
				else
					return attack_hand(user)
/turf/closed/mineral/update_overlays()
	. = ..()
	if(!QDELETED(src))

		var/ratio = damage / maxDamage
		ratio = CEILING(ratio*4, 1) * 25

		if(smooth)
			QUEUE_SMOOTH(src)

		cut_overlay(crack_overlay)
		if(ratio > 75)
			return
		crack_overlay = mutable_appearance('icons/obj/structures.dmi', "damage[ratio]", -(layer+0.1))
		. += crack_overlay

/turf/closed/mineral/proc/gets_drilled(user, give_exp = FALSE)
	if (mineralType && (mineralAmt > 0))
		new mineralType(src, mineralAmt)
		SSblackbox.record_feedback("tally", "ore_mined", mineralAmt, mineralType)
	if(ishuman(user))
		var/mob/living/carbon/human/H = user
		if(give_exp)
			if (mineralType && (mineralAmt > 0))
				H.mind.adjust_experience(/datum/skill/mining, initial(mineralType.mine_experience) * mineralAmt)
			else
				H.mind.adjust_experience(/datum/skill/mining, 4)

	for(var/obj/effect/temp_visual/mining_overlay/M in src)
		qdel(M)
	var/flags = NONE
	if(defer_change) // TODO: make the defer change var a var for any changeturf flag
		flags = CHANGETURF_DEFER_CHANGE
	ScrapeAway(null, flags)
	addtimer(CALLBACK(src, .proc/AfterChange), 1, TIMER_UNIQUE)
	playsound(src, 'sound/effects/break_stone.ogg', 50, TRUE) //beautiful destruction

/turf/closed/mineral/attack_animal(mob/living/simple_animal/user)
	if((user.environment_smash & ENVIRONMENT_SMASH_WALLS) || (user.environment_smash & ENVIRONMENT_SMASH_RWALLS))
		gets_drilled(user)
	..()

/turf/closed/mineral/attack_alien(mob/living/carbon/alien/M)
	to_chat(M, "<span class='notice'>You start digging into the rock...</span>")
	playsound(src, 'sound/effects/break_stone.ogg', 50, TRUE)
	if(do_after(M, 40, target = src))
		to_chat(M, "<span class='notice'>You tunnel into the rock.</span>")
		gets_drilled(M)

/turf/closed/mineral/attack_hulk(mob/living/carbon/human/H)
	..()
	if(do_after(H, 50, target = src))
		playsound(src, 'sound/effects/meteorimpact.ogg', 100, TRUE)
		H.say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!" ), forced = "hulk")
		gets_drilled(H)
	return TRUE

/turf/closed/mineral/Bumped(atom/movable/AM)
	..()
	if(ishuman(AM))
		var/mob/living/carbon/human/H = AM
		var/obj/item/I = H.is_holding_tool_quality(TOOL_MINING)
		if(I)
			attackby(I, H)
		return
	else if(iscyborg(AM))
		var/mob/living/silicon/robot/R = AM
		if(R.module_active && R.module_active.tool_behaviour == TOOL_MINING)
			attackby(R.module_active, R)
			return
	else
		return

/turf/closed/mineral/acid_melt()
	ScrapeAway()

/turf/closed/mineral/ex_act(severity, target)
	..()
	switch(severity)
		if(3)
			if (prob(75))
				gets_drilled(null, FALSE)
		if(2)
			if (prob(90))
				gets_drilled(null, FALSE)
		if(1)
			gets_drilled(null, FALSE)
	return






/turf/closed/mineral/dirt
	name = "dirt"
	icon = 'icons/turf/mining.dmi'
	icon_state = "dirt"
	smooth = null
	canSmoothWith = null
	baseturfs = /turf/open/floor/plating/asteroid/
	smooth_icon = 'icons/turf/smoothdirt.dmi'
/turf/closed/mineral/dirt/attackby(obj/item/I, mob/user, params)
	if (!user.IsAdvancedToolUser())
		to_chat(usr, "<span class='warning'>You don't have the dexterity to do this!</span>")
		return

	if(I.tool_behaviour == TOOL_SHOVEL)
		var/turf/T = user.loc
		if (!isturf(T))
			return

		if(last_act + (2 * I.toolspeed) > world.time)//prevents message spam
			return
		last_act = world.time
		to_chat(user, "<span class='notice'>You start picking...</span>")

		if(I.use_tool(src, user, 2, volume=50))
			if(ismineralturf(src))
				to_chat(user, "<span class='notice'>You finish cutting into the rock.</span>")
				I.obj_integrity -= 0.1
				damage -= 1
				SSblackbox.record_feedback("tally", "pick_used_mining", 1, I.type)
				if(damage <= 1)
					gets_drilled(user, TRUE)
				else
					return attack_hand(user)
	else
		return attack_hand(user)
/turf/closed/mineral/dirt/Bumped(atom/movable/AM)
	..()
	if(ishuman(AM))
		var/mob/living/carbon/human/H = AM
		var/obj/item/I = H.is_holding_tool_quality(TOOL_SHOVEL || TOOL_MINING)
		if(I)
			attackby(I, H)
		return
	else if(iscyborg(AM))
		var/mob/living/silicon/robot/R = AM
		if(R.module_active && R.module_active.tool_behaviour == TOOL_MINING || R.module_active && R.module_active.tool_behaviour == TOOL_SHOVEL)
			attackby(R.module_active, R)
			return
	else
		return




/turf/closed/mineral/random
	var/list/mineralSpawnChanceList = list(
	/turf/closed/mineral/dirt= 1000,
	/obj/item/stack/ore/fake/stone = 400,
	/obj/item/stack/ore/iron = 120,
	/obj/item/stack/ore/fake/coal = 100,
	/obj/item/stack/ore/aluminum = 84,
	/obj/item/stack/ore/sulphur = 54,
	/obj/item/stack/ore/fake/salt = 44,
	/obj/item/stack/ore/garnierite = 43,
	/obj/item/stack/ore/cassiterite = 37,
	/obj/item/stack/ore/malachite = 34,
	/obj/item/stack/ore/sphalerite = 32,
	/obj/item/stack/ore/plasma = 20,
	/obj/item/stack/ore/titanium = 11,
	/obj/item/stack/ore/amethyst = 6,
	/obj/item/stack/ore/topaz = 5,
	/obj/item/stack/ore/uranium = 5,
	/obj/item/stack/ore/sapphire = 4,
	/obj/item/stack/ore/emerald = 3,
	/obj/item/stack/ore/silver = 2,
	/obj/item/stack/ore/ruby = 2,
	/obj/item/stack/ore/gold = 1,
	/obj/item/stack/ore/diamond = 0.7,
	/obj/item/stack/ore/bluespace_crystal = 0.5,

	/turf/open/floor/plating/asteroid/airless/cave = 10,
	/obj/item/stack/ore/fake/trash = 1,
	/turf/closed/mineral/gibtonite = 4, )
	var/mineralChance = 100

/turf/closed/mineral/random/Sedimentary
	maxDamage = 5
	smooth_icon = 'icons/turf/smoothsandstone.dmi'
	mineralSpawnChanceList = list(
	/obj/item/stack/ore/fake/stone 	= 200,
	/turf/closed/mineral/dirt		= 300,
	/obj/item/stack/ore/hematite	= 120,
	/obj/item/stack/ore/limonite	= 120,
	/obj/item/stack/ore/fake/coal	= 500,
	/obj/item/stack/ore/fake/niter	= 100,
	/obj/item/stack/ore/magnetite 	= 84,
	/obj/item/stack/ore/sulphur 	= 54,
	/obj/item/stack/ore/fake/salt 	= 44,
	/obj/item/stack/ore/fake/trash 	= 3,
	/obj/item/stack/ore/fake/sandstone = 500,
	/turf/open/floor/plating/asteroid/airless/cave = 1)
	mineralChance = 60

/turf/closed/mineral/random/IgneousExtrusive
	maxDamage = 10
	smooth_icon = 'icons/turf/smoothandestite.dmi'
	mineralSpawnChanceList = list(
	/obj/item/stack/ore/tetrahedrite	= 75,
	/obj/item/stack/ore/garnierite		= 32,
	/obj/item/stack/ore/galena			= 54,
	/obj/item/stack/ore/cassiterite		= 12,
	/obj/item/stack/ore/andestite 		= 50,
	/turf/open/floor/plating/asteroid/airless/cave = 10,
	/obj/item/stack/ore/fake/trash = 1,
	/turf/closed/mineral/gibtonite = 4, )
	mineralChance = 100

/turf/closed/mineral/random/Metamorphic
	turf_type = /turf/open/floor/plating/asteroid/granite
	maxDamage = 15
	smooth_icon = 'icons/turf/smoothmarble.dmi'
	mineralSpawnChanceList = list(
	/obj/item/stack/ore/marble = 120,
	/obj/item/stack/ore/sphalerite = 42,
	/obj/item/stack/ore/galena = 25,
	/turf/open/floor/plating/asteroid/airless/cave = 10,
	/obj/item/stack/ore/fake/trash = 1,
	/turf/closed/mineral/gibtonite = 4, )
	mineralChance = 50
	turf_type = /turf/open/floor/plating/asteroid/granite
/turf/closed/mineral/random/Igneousintrusive
	smooth_icon = 'icons/turf/smoothgranite.dmi'
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/tetrahedrite = 120,
		/obj/item/stack/ore/iron = 120,
		/obj/item/stack/ore/gold = 23,
		/obj/item/stack/ore/granite = 200,
		/turf/open/floor/plating/asteroid/airless/cave = 1,)
	mineralChance = 60
	maxDamage = 20
/turf/closed/mineral/random/Initialize()

	mineralSpawnChanceList = typelist("mineralSpawnChanceList", mineralSpawnChanceList)

	. = ..()
	if (prob(mineralChance))
		var/path = pickweight(mineralSpawnChanceList)
		if(ispath(path, /turf))
			var/stored_flags = 0
			if(flags_1 & NO_RUINS_1)
				stored_flags |= NO_RUINS_1
			var/turf/T = ChangeTurf(path,null,CHANGETURF_IGNORE_AIR)
			T.flags_1 |= stored_flags

			T.baseturfs = src.baseturfs
			if(ismineralturf(T))
				var/turf/closed/mineral/M = T
				M.turf_type = src.turf_type
				M.mineralAmt = rand(1, 5)
				M.environment_type = src.environment_type
				src = M
				M.levelupdate()
			else
				src = T
				T.levelupdate()

		else
			Change_Ore(path, 1)
			Spread_Vein(path)

/turf/closed/mineral/random/no_caves
	mineralSpawnChanceList = list(/obj/item/stack/ore/uranium = 5, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 10,
		/obj/item/stack/ore/silver = 12, /obj/item/stack/ore/plasma = 20, /obj/item/stack/ore/iron = 40, /obj/item/stack/ore/titanium = 11,
		/turf/closed/mineral/gibtonite = 4, /obj/item/stack/ore/bluespace_crystal = 1)

/turf/closed/mineral/random/more_caves
	mineralSpawnChanceList = list(/obj/item/stack/ore/uranium = 5, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 10,
		/obj/item/stack/ore/silver = 12, /obj/item/stack/ore/plasma = 20, /obj/item/stack/ore/iron = 40, /obj/item/stack/ore/titanium = 11,
		/turf/closed/mineral/gibtonite = 4, /turf/open/floor/plating/asteroid/airless/cave = 15, /obj/item/stack/ore/bluespace_crystal = 1)

/turf/closed/mineral/random/high_chance
	icon_state = "rock_highchance"
	mineralChance = 25
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 35, /obj/item/stack/ore/diamond = 30, /obj/item/stack/ore/gold = 45, /obj/item/stack/ore/titanium = 45,
		/obj/item/stack/ore/silver = 50, /obj/item/stack/ore/plasma = 50, /obj/item/stack/ore/bluespace_crystal = 20)

/turf/closed/mineral/random/high_chance/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 35, /obj/item/stack/ore/diamond = 30, /obj/item/stack/ore/gold = 45, /obj/item/stack/ore/titanium = 45,
		/obj/item/stack/ore/silver = 50, /obj/item/stack/ore/plasma = 50, /obj/item/stack/ore/bluespace_crystal)

/turf/closed/mineral/random/low_chance
	icon_state = "rock_lowchance"
	mineralChance = 6
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 2, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 4, /obj/item/stack/ore/titanium = 4,
		/obj/item/stack/ore/silver = 6, /obj/item/stack/ore/plasma = 15, /obj/item/stack/ore/iron = 40,
		/turf/closed/mineral/gibtonite = 2, /obj/item/stack/ore/bluespace_crystal = 1)

/turf/closed/mineral/random/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

	mineralChance = 10
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 5, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 10, /obj/item/stack/ore/titanium = 11,
		/obj/item/stack/ore/silver = 12, /obj/item/stack/ore/plasma = 20, /obj/item/stack/ore/iron = 40,
		/turf/closed/mineral/gibtonite/volcanic = 4, /turf/open/floor/plating/asteroid/airless/cave/volcanic = 1, /obj/item/stack/ore/bluespace_crystal = 1)

/turf/closed/mineral/random/volcanic/more_caves
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 5, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 10, /obj/item/stack/ore/titanium = 11,
		/obj/item/stack/ore/silver = 12, /obj/item/stack/ore/plasma = 20, /obj/item/stack/ore/iron = 40,
		/turf/closed/mineral/gibtonite/volcanic = 4, /turf/open/floor/plating/asteroid/airless/cave/volcanic = 15, /obj/item/stack/ore/bluespace_crystal = 1)

/turf/closed/mineral/random/volcanic/no_caves
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 5, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 10, /obj/item/stack/ore/titanium = 11,
		/obj/item/stack/ore/silver = 12, /obj/item/stack/ore/plasma = 20, /obj/item/stack/ore/iron = 40,
		/turf/closed/mineral/gibtonite/volcanic = 4, /obj/item/stack/ore/bluespace_crystal = 1)

/turf/closed/mineral/random/snow
	name = "snowy mountainside"
	icon = 'icons/turf/mining.dmi'
	smooth_icon = 'icons/turf/walls/mountain_wall.dmi'
	icon_state = "mountainrock"
	smooth = SMOOTH_MORE|SMOOTH_BORDER
	canSmoothWith = list (/turf/closed)
	defer_change = TRUE
	environment_type = "snow_cavern"
	turf_type = /turf/open/floor/plating/asteroid/snow/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

	mineralChance = 10
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 5, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 10, /obj/item/stack/ore/titanium = 11,
		/obj/item/stack/ore/silver = 12, /obj/item/stack/ore/plasma = 20, /obj/item/stack/ore/iron = 40,
		/turf/closed/mineral/gibtonite/ice/icemoon = 4, /turf/open/floor/plating/asteroid/airless/cave/snow = 1, /obj/item/stack/ore/bluespace_crystal = 1)

/turf/closed/mineral/random/snow/Change_Ore(var/ore_type, random = 0)
	. = ..()
	if(mineralType)
		smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
		icon = 'icons/turf/walls/icerock_wall.dmi'

/turf/closed/mineral/random/snow/more_caves
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 5, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 10, /obj/item/stack/ore/titanium = 11,
		/obj/item/stack/ore/silver = 12, /obj/item/stack/ore/plasma = 20, /obj/item/stack/ore/iron = 40,
		/turf/closed/mineral/gibtonite/ice/icemoon = 4, /turf/open/floor/plating/asteroid/airless/cave/snow = 15, /obj/item/stack/ore/bluespace_crystal = 1)

/turf/closed/mineral/random/snow/no_caves
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 5, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 10, /obj/item/stack/ore/titanium = 11,
		/obj/item/stack/ore/silver = 12, /obj/item/stack/ore/plasma = 20, /obj/item/stack/ore/iron = 40,
		/turf/closed/mineral/gibtonite/ice/icemoon = 4, /obj/item/stack/ore/bluespace_crystal = 1)

/turf/closed/mineral/random/snow/underground
	// abundant ore and caves
	mineralChance = 20
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 10, /obj/item/stack/ore/diamond = 4, /obj/item/stack/ore/gold = 20, /obj/item/stack/ore/titanium = 22,
		/obj/item/stack/ore/silver = 24, /obj/item/stack/ore/plasma = 20, /obj/item/stack/ore/iron = 20, /obj/item/stack/ore/bananium = 1,
		/turf/closed/mineral/gibtonite/ice/icemoon = 8, /turf/open/floor/plating/asteroid/airless/cave/snow/underground = 2, /obj/item/stack/ore/bluespace_crystal = 2)

/turf/closed/mineral/random/snow/high_chance
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 35, /obj/item/stack/ore/diamond  = 30, /obj/item/stack/ore/gold = 45, /obj/item/stack/ore/titanium = 45,
		/obj/item/stack/ore/silver = 50, /obj/item/stack/ore/plasma = 50, /obj/item/stack/ore/bluespace_crystal = 20)

/turf/closed/mineral/random/labormineral
	icon_state = "rock_labor"
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 3, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 8, /obj/item/stack/ore/titanium = 8,
		/obj/item/stack/ore/silver = 20, /obj/item/stack/ore/plasma = 30, /obj/item/stack/ore/iron = 95,
		/turf/closed/mineral/gibtonite = 2)

/turf/closed/mineral/random/labormineral/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE
	mineralSpawnChanceList = list(
		/obj/item/stack/ore/uranium = 3, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 8, /obj/item/stack/ore/titanium = 8,
		/obj/item/stack/ore/silver = 20, /obj/item/stack/ore/plasma = 30, /obj/item/stack/ore/bluespace_crystal = 1, /turf/closed/mineral/gibtonite/volcanic = 2,
		/obj/item/stack/ore/iron = 95)

// Subtypes for mappers placing ores manually.
/turf/closed/mineral/random/labormineral/ice
	name = "snowy mountainside"
	icon = 'icons/turf/mining.dmi'
	smooth_icon = 'icons/turf/walls/mountain_wall.dmi'
	icon_state = "mountainrock"
	smooth = SMOOTH_MORE|SMOOTH_BORDER
	canSmoothWith = list (/turf/closed)
	defer_change = TRUE
	environment_type = "snow"
	turf_type = /turf/open/floor/plating/asteroid/snow/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

	defer_change = TRUE
	mineralSpawnChanceList = list(
		/turf/closed/mineral/uranium/ice/icemoon = 3, /turf/closed/mineral/diamond/ice/icemoon = 1, /turf/closed/mineral/gold/ice/icemoon = 8, /turf/closed/mineral/titanium/ice/icemoon = 8,
		/turf/closed/mineral/silver/ice/icemoon = 20, /turf/closed/mineral/plasma/ice/icemoon = 30, /turf/closed/mineral/bscrystal/ice/icemoon = 1, /turf/closed/mineral/gibtonite/ice/icemoon = 2,
		/turf/closed/mineral/iron/ice/icemoon = 95)

/turf/closed/mineral/iron
	mineralType = /obj/item/stack/ore/iron/
	scan_state = "rock_Iron"

/turf/closed/mineral/coal
	mineralType = /obj/item/stack/ore/fake/coal
	scan_state = "rock_Coal"

/turf/closed/mineral/rocks
	mineralType = /obj/item/stack/ore/fake/stone
	scan_state = "stone"

/turf/closed/mineral/salt
	mineralType = /obj/item/stack/ore/fake/salt
	scan_state = "salt"
/turf/closed/mineral/tetrahedrite
	mineralType = /obj/item/stack/ore/tetrahedrite
	scan_state = "tetrahedrite"
/turf/closed/mineral/trash
	mineralType = /obj/item/stack/ore/fake/trash
	scan_state = "trash"
/turf/closed/mineral/malachite
	mineralType = /obj/item/stack/ore/malachite
	scan_state = "malachite"
/turf/closed/mineral/magnetite
	mineralType = /obj/item/stack/ore/magnetite
	scan_state = "magnetite"
/turf/closed/mineral/sphalerite
	mineralType = /obj/item/stack/ore/sphalerite
	scan_state = "sphalerite"
/turf/closed/mineral/galena
	mineralType = /obj/item/stack/ore/galena
	scan_state = "galena"
/turf/closed/mineral/cassiterite
	mineralType = /obj/item/stack/ore/cassiterite
	scan_state = "cassiterite"
/turf/closed/mineral/garnierite
	mineralType = /obj/item/stack/ore/garnierite
	scan_state = "garnierite"
/turf/closed/mineral/sulphur
	mineralType = /obj/item/stack/ore/sulphur
	scan_state = "sulphur"
/turf/closed/mineral/amethyst
	mineralType = /obj/item/stack/ore/amethyst
	scan_state = "amethyst"
/turf/closed/mineral/sapphire
	mineralType = /obj/item/stack/ore/sapphire
	scan_state = "sapphire"
/turf/closed/mineral/topaz
	mineralType = /obj/item/stack/ore/topaz
	scan_state = "topaz"
/turf/closed/mineral/emerald
	mineralType = /obj/item/stack/ore/emerald
	scan_state = "emerald"
/turf/closed/mineral/iron/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = 1

/turf/closed/mineral/iron/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_iron"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/iron/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/uranium
	mineralType = /obj/item/stack/ore/uranium
	scan_state = "rock_Uranium"

/turf/closed/mineral/uranium/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/turf/closed/mineral/uranium/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_Uranium"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/uranium/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/diamond
	mineralType = /obj/item/stack/ore/diamond
	scan_state = "rock_Diamond"

/turf/closed/mineral/diamond/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/turf/closed/mineral/diamond/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_diamond"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/diamond/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/gold
	mineralType = /obj/item/stack/ore/gold
	scan_state = "rock_Gold"

/turf/closed/mineral/gold/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/turf/closed/mineral/gold/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_gold"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/gold/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/silver
	mineralType = /obj/item/stack/ore/silver
	scan_state = "rock_Silver"

/turf/closed/mineral/rocks
	mineralType = /obj/effect/spawner/lootdrop/minnyral
	scan_state = "minerals"

/turf/closed/mineral/trash
	mineralType = /obj/effect/spawner/lootdrop/maintenance
	scan_state = "trash"

/turf/closed/mineral/silver/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/turf/closed/mineral/silver/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_silver"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/silver/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/titanium
	mineralType = /obj/item/stack/ore/titanium
	scan_state = "rock_Titanium"

/turf/closed/mineral/titanium/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/turf/closed/mineral/titanium/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_titanium"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/titanium/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/plasma
	mineralType = /obj/item/stack/ore/plasma
	scan_state = "rock_Plasma"

/turf/closed/mineral/plasma/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/turf/closed/mineral/plasma/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_plasma"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/plasma/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/bananium
	mineralType = /obj/item/stack/ore/bananium
	mineralAmt = 3
	scan_state = "rock_Bananium"

/turf/closed/mineral/bananium/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_Bananium"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/bananium/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/bscrystal
	mineralType = /obj/item/stack/ore/bluespace_crystal
	mineralAmt = 1
	scan_state = "rock_BScrystal"

/turf/closed/mineral/bscrystal/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/turf/closed/mineral/bscrystal/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_BScrystal"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/bscrystal/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt
	baseturfs = /turf/open/floor/plating/asteroid/basalt
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS

/turf/closed/mineral/volcanic/lava_land_surface
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	defer_change = TRUE

/turf/closed/mineral/ash_rock //wall piece
	name = "rock"
	icon = 'icons/turf/mining.dmi'
	smooth_icon = 'icons/turf/walls/rock_wall.dmi'
	icon_state = "rock2"
	smooth = SMOOTH_MORE|SMOOTH_BORDER
	canSmoothWith = list (/turf/closed)
	baseturfs = /turf/open/floor/plating/ashplanet/wateryrock
	initial_gas_mix = OPENTURF_LOW_PRESSURE
	environment_type = "waste"
	turf_type = /turf/open/floor/plating/ashplanet/rocky
	defer_change = TRUE

/turf/closed/mineral/snowmountain
	name = "snowy mountainside"
	icon = 'icons/turf/mining.dmi'
	smooth_icon = 'icons/turf/walls/mountain_wall.dmi'
	icon_state = "mountainrock"
	smooth = SMOOTH_MORE|SMOOTH_BORDER
	canSmoothWith = list (/turf/closed)
	baseturfs = /turf/open/floor/plating/asteroid/snow
	initial_gas_mix = FROZEN_ATMOS
	environment_type = "snow"
	turf_type = /turf/open/floor/plating/asteroid/snow
	defer_change = TRUE

/turf/closed/mineral/snowmountain/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/snowmountain/cavern
	name = "ice cavern rock"
	icon = 'icons/turf/mining.dmi'
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	icon_state = "icerock"
	smooth = SMOOTH_MORE|SMOOTH_BORDER
	canSmoothWith = list (/turf/closed)
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	environment_type = "snow_cavern"
	turf_type = /turf/open/floor/plating/asteroid/snow/ice

/turf/closed/mineral/snowmountain/cavern/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

//GIBTONITE

/turf/closed/mineral/gibtonite
	mineralAmt = 1
	scan_state = "rock_Gibtonite"
	var/det_time = 8 //Countdown till explosion, but also rewards the player for how close you were to detonation when you defuse it
	var/stage = GIBTONITE_UNSTRUCK //How far into the lifecycle of gibtonite we are
	var/activated_ckey = null //These are to track who triggered the gibtonite deposit for logging purposes
	var/activated_name = null
	var/mutable_appearance/activated_overlay

/turf/closed/mineral/gibtonite/Initialize()
	det_time = rand(8,10) //So you don't know exactly when the hot potato will explode
	. = ..()

/turf/closed/mineral/gibtonite/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/mining_scanner) || istype(I, /obj/item/t_scanner/adv_mining_scanner) && stage == 1)
		user.visible_message("<span class='notice'>[user] holds [I] to [src]...</span>", "<span class='notice'>You use [I] to locate where to cut off the chain reaction and attempt to stop it...</span>")
		defuse()
	..()

/turf/closed/mineral/gibtonite/proc/explosive_reaction(mob/user = null, triggered_by_explosion = 0)
	if(stage == GIBTONITE_UNSTRUCK)
		activated_overlay = mutable_appearance('icons/turf/smoothrocks.dmi', "rock_Gibtonite_active", ON_EDGED_TURF_LAYER)
		add_overlay(activated_overlay)
		name = "gibtonite deposit"
		desc = "An active gibtonite reserve. Run!"
		stage = GIBTONITE_ACTIVE
		visible_message("<span class='danger'>There's gibtonite inside! It's going to explode!</span>")

		var/notify_admins = 0
		if(z != 5)
			notify_admins = TRUE

		if(!triggered_by_explosion)
			log_bomber(user, "has trigged a gibtonite deposit reaction via", src, null, notify_admins)
		else
			log_bomber(null, "An explosion has triggered a gibtonite deposit reaction via", src, null, notify_admins)

		countdown(notify_admins)

/turf/closed/mineral/gibtonite/proc/countdown(notify_admins = 0)
	set waitfor = 0
	while(istype(src, /turf/closed/mineral/gibtonite) && stage == GIBTONITE_ACTIVE && det_time > 0 && mineralAmt >= 1)
		det_time--
		sleep(5)
	if(istype(src, /turf/closed/mineral/gibtonite))
		if(stage == GIBTONITE_ACTIVE && det_time <= 0 && mineralAmt >= 1)
			var/turf/bombturf = get_turf(src)
			mineralAmt = 0
			stage = GIBTONITE_DETONATE
			explosion(bombturf,1,3,5, adminlog = notify_admins)

/turf/closed/mineral/gibtonite/proc/defuse()
	if(stage == GIBTONITE_ACTIVE)
		cut_overlay(activated_overlay)
		activated_overlay.icon_state = "rock_Gibtonite_inactive"
		add_overlay(activated_overlay)
		desc = "An inactive gibtonite reserve. The ore can be extracted."
		stage = GIBTONITE_STABLE
		if(det_time < 0)
			det_time = 0
		visible_message("<span class='notice'>The chain reaction stopped! The gibtonite had [det_time] reactions left till the explosion!</span>")

/turf/closed/mineral/gibtonite/gets_drilled(mob/user, triggered_by_explosion = 0)
	if(stage == GIBTONITE_UNSTRUCK && mineralAmt >= 1) //Gibtonite deposit is activated
		playsound(src,'sound/effects/hit_on_shattered_glass.ogg',50,TRUE)
		explosive_reaction(user, triggered_by_explosion)
		return
	if(stage == GIBTONITE_ACTIVE && mineralAmt >= 1) //Gibtonite deposit goes kaboom
		var/turf/bombturf = get_turf(src)
		mineralAmt = 0
		stage = GIBTONITE_DETONATE
		explosion(bombturf,1,2,5, adminlog = 0)
	if(stage == GIBTONITE_STABLE) //Gibtonite deposit is now benign and extractable. Depending on how close you were to it blowing up before defusing, you get better quality ore.
		var/obj/item/gibtonite/G = new (src)
		if(det_time <= 0)
			G.quality = 3
			G.icon_state = "Gibtonite ore 3"
		if(det_time >= 1 && det_time <= 2)
			G.quality = 2
			G.icon_state = "Gibtonite ore 2"

	var/flags = NONE
	if(defer_change)
		flags = CHANGETURF_DEFER_CHANGE
	ScrapeAway(null, flags)
	addtimer(CALLBACK(src, .proc/AfterChange), 1, TIMER_UNIQUE)


/turf/closed/mineral/gibtonite/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/turf/closed/mineral/gibtonite/ice
	environment_type = "snow_cavern"
	icon_state = "icerock_Gibtonite"
	smooth_icon = 'icons/turf/walls/icerock_wall.dmi'
	turf_type = /turf/open/floor/plating/asteroid/snow/ice
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE

/turf/closed/mineral/gibtonite/ice/icemoon
	turf_type = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/asteroid/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS

/turf/closed/mineral/strong
	name = "Very strong rock"
	desc = "Seems to be stronger than the other rocks in the area. Only a master of mining techniques could destroy this."
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = 1
	smooth_icon = 'icons/turf/walls/rock_wall.dmi'

/turf/closed/mineral/strong/attackby(obj/item/I, mob/user, params)
	if(!ishuman(user))
		to_chat(usr, "<span class='warning'>Only a more advanced species could break a rock such as this one!</span>")
		return FALSE
	var/mob/living/carbon/human/H = user
	if(H.mind.get_skill_level(/datum/skill/mining) >= SKILL_LEVEL_MASTER)
		. = ..()
	else
		to_chat(usr, "<span class='warning'>The rock seems to be too strong to destroy. Maybe I can break it once I become a master miner.</span>")


/turf/closed/mineral/strong/gets_drilled(mob/user)
	if(!ishuman(user))
		return // see attackby
	var/mob/living/carbon/human/H = user
	if(!(H.mind.get_skill_level(/datum/skill/mining) >= SKILL_LEVEL_MASTER))
		return
	drop_ores()
	H.client.give_award(/datum/award/achievement/skill/legendary_miner, H)
	var/flags = NONE
	if(defer_change) // TODO: make the defer change var a var for any changeturf flag
		flags = CHANGETURF_DEFER_CHANGE
	ScrapeAway(flags=flags)
	addtimer(CALLBACK(src, .proc/AfterChange), 1, TIMER_UNIQUE)
	playsound(src, 'sound/effects/break_stone.ogg', 50, TRUE) //beautiful destruction
	H.mind.adjust_experience(/datum/skill/mining, 100) //yay!

/turf/closed/mineral/strong/proc/drop_ores()
	if(prob(10))
		new /obj/item/stack/sheet/mineral/mythril(src, 5)
	else
		new /obj/item/stack/sheet/mineral/adamantine(src, 5)

/turf/closed/mineral/strong/acid_melt()
	return

/turf/closed/mineral/strong/ex_act(severity, target)
	return
