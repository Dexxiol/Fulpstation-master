
/**********************road**************************/

/turf/open/floor/plating/road //floor piece
	gender = PLURAL
	name = "road sand"
	baseturfs = /turf/open/floor/plating/road
	icon = 'icons/superpizza/pavement.dmi'
	icon_state = "pavement"
	icon_plating = "pavement"
	postdig_icon_change = FALSE
	/// Environment type for the turf
	var/environment_type = "road"
	/// Base turf type to be created by the tunnel
	var/turf_type = /turf/open/floor/plating/road
	/// Probability floor has a different icon state
	var/floor_variance = 0
	attachment_holes = FALSE
	/// Itemstack to drop when dug by a shovel
	var/obj/item/stack/digResult = ""
	/// Whether the turf has been dug or not
	var/dug
	planetary_atmos = TRUE
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
/turf/open/floor/plating/road/Initialize()
	var/proper_name = name
	. = ..()
	name = proper_name
	if(prob(floor_variance))
		icon_state = "[environment_type][rand(0,12)]"

/// Drops itemstack when dug and changes icon
/turf/open/floor/plating/road/proc/getDug()
	new digResult(src, 5)
	if(postdig_icon_change)
		if(!postdig_icon)
			icon_plating = "[environment_type]_dug"
			icon_state = "[environment_type]_dug"
	dug = TRUE

/// If the user can dig the turf
/turf/open/floor/plating/road/proc/can_dig(mob/user)
	if(!dug)
		return TRUE
	if(user)
		to_chat(user, "<span class='warning'>Looks like someone has dug here already!</span>")

/turf/open/floor/plating/road/try_replace_tile(obj/item/stack/tile/T, mob/user, params)
	return

/turf/open/floor/plating/road/burn_tile()
	return

/turf/open/floor/plating/road/MakeSlippery(wet_setting, min_wet_time, wet_time_to_add, max_wet_time, permanent)
	return

/turf/open/floor/plating/road/MakeDry()
	return

/turf/open/floor/plating/road/crush()
	return

/turf/open/floor/plating/road/attackby(obj/item/W, mob/user, params)
	. = ..()
	if(!.)
		if(W.tool_behaviour == TOOL_SHOVEL || W.tool_behaviour == TOOL_MINING)
			if(!can_dig(user))
				return TRUE

			if(!isturf(user.loc))
				return

			to_chat(user, "<span class='notice'>You start digging...</span>")

			if(W.use_tool(src, user, 40, volume=50))
				if(!can_dig(user))
					return TRUE
				to_chat(user, "<span class='notice'>You dig a hole.</span>")
				getDug()
				SSblackbox.record_feedback("tally", "pick_used_mining", 1, W.type)
				return TRUE
		else if(istype(W, /obj/item/storage/bag/ore))
			for(var/obj/item/stack/ore/O in src)
				SEND_SIGNAL(W, COMSIG_PARENT_ATTACKBY, O)

/turf/open/floor/plating/road/ex_act(severity, target)
	. = SEND_SIGNAL(src, COMSIG_ATOM_EX_ACT, severity, target)
	contents_explosion(severity, target)

/turf/open/floor/plating/lavaland_baseturf
	baseturfs = /turf/open/floor/plating/road/basalt/lava_land_surface

/turf/open/floor/plating/road/basalt
	name = "volcanic floor"
	baseturfs = /turf/open/floor/plating/road/basalt
	icon = 'icons/turf/floors.dmi'
	icon_state = "basalt"
	icon_plating = "basalt"
	environment_type = "basalt"
	floor_variance = 15
	digResult = /obj/item/stack/ore/glass/basalt

/turf/open/floor/plating/road/basalt/lava //lava underneath
	baseturfs = /turf/open/lava/smooth

/turf/open/floor/plating/road/basalt/airless
	initial_gas_mix = AIRLESS_ATMOS

/turf/open/floor/plating/road/basalt/Initialize()
	. = ..()
	set_basalt_light(src)

/turf/open/floor/plating/road/getDug()
	set_light(0)
	return ..()

///////Surface. The surface is warm, but survivable without a suit. Internals are required. The floors break to chasms, which drop you into the underground.

/turf/open/floor/plating/road/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/lava/smooth/lava_land_surface

/turf/open/floor/plating/road/lowpressure
	initial_gas_mix = OPENTURF_LOW_PRESSURE
	baseturfs = /turf/open/floor/plating/road/lowpressure
	turf_type = /turf/open/floor/plating/road/lowpressure

/turf/open/floor/plating/road/airless
	baseturfs = /turf/open/floor/plating/road/airless
	turf_type = /turf/open/floor/plating/road/airless


#define SPAWN_MEGAFAUNA "bluh bluh huge boss"
#define SPAWN_BUBBLEGUM 6
GLOBAL_LIST_INIT(shitboyspawns, list(/mob/living/simple_animal/hostile/space_dragon = 2, /mob/living/simple_animal/hostile/zombie = 2, /mob/living/simple_animal/hostile/megafauna/wendigo = 2, /mob/living/simple_animal/hostile/jungle/leaper = 3, /mob/living/simple_animal/hostile/megafauna/dragon = 4, /mob/living/simple_animal/hostile/megafauna/colossus = 2, /mob/living/simple_animal/hostile/megafauna/bubblegum = SPAWN_BUBBLEGUM))


/turf/open/floor/plating/road/airless/cave
	/// Length of the tunnel
	var/length = 100
	/// Mobs that can spawn in the tunnel, weighted list
	var/list/mob_spawn_list
	/// Megafauna that can spawn in the tunnel, weighted list
	var/list/shitboyspawns
	/// Flora that can spawn in the tunnel, weighted list
	var/list/flora_spawn_list
	/// Terrain that can spawn in the tunnel, weighted list
	var/list/terrain_spawn_list
	/// If the tunnel should keep being created
	var/sanity = 1
	/// Cave direction to move
	var/forward_cave_dir = 1
	/// Backwards cave direction for tracking
	var/backward_cave_dir = 2
	/// If the tunnel is moving backwards
	var/going_backwards = TRUE
	/// If this is a cave creating type
	var/has_data = FALSE
	/// The non-cave creating type
	var/data_having_type = /turf/open/floor/plating/road/airless/cave/has_data
	/// Option tunnel width, weighted list
	var/list/pick_tunnel_width
	/// Optional turf types instead of turf_type, weighted list
	var/list/choose_turf_type
	turf_type = /turf/open/floor/plating/road/airless

/turf/open/floor/plating/road/airless/cave/has_data //subtype for producing a tunnel with given data
	has_data = TRUE

/turf/open/floor/plating/road/airless/cave/volcanic
	mob_spawn_list = list(/mob/living/simple_animal/hostile/asteroid/goliath/beast/random = 50, /obj/structure/spawner/lavaland/goliath = 3, \
		/mob/living/simple_animal/hostile/asteroid/basilisk/watcher/random = 40, /obj/structure/spawner/lavaland = 2, \
		/mob/living/simple_animal/hostile/asteroid/hivelord/legion/random = 30, /obj/structure/spawner/lavaland/legion = 3, \
		SPAWN_MEGAFAUNA = 6, /mob/living/simple_animal/hostile/asteroid/goldgrub = 10, )

	data_having_type = /turf/open/floor/plating/road/airless/cave/volcanic/has_data
	turf_type = /turf/open/floor/plating/road/basalt/lava_land_surface
	icon_state = "basalt"
	icon_plating = "basalt"
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS

/turf/open/floor/plating/road/airless/cave/volcanic/has_data //subtype for producing a tunnel with given data
	has_data = TRUE

/turf/open/floor/plating/road/airless/cave/snow
	gender = PLURAL
	name = "snow"
	desc = "Looks cold."
	icon = 'icons/turf/snow.dmi'
	baseturfs = /turf/open/floor/plating/road/snow/icemoon
	icon_state = "snow"
	icon_plating = "snow"
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS
	slowdown = 0
	environment_type = "snow"
	flags_1 = NONE
	planetary_atmos = TRUE
	burnt_states = list("snow_dug")
	bullet_sizzle = TRUE
	bullet_bounce_sound = null
	digResult = /obj/item/stack/sheet/mineral/snow
	mob_spawn_list = list(/mob/living/simple_animal/hostile/asteroid/wolf = 50, /obj/structure/spawner/ice_moon = 3, \
						  /mob/living/simple_animal/hostile/asteroid/polarbear = 30, /obj/structure/spawner/ice_moon/polarbear = 3, \
						  /mob/living/simple_animal/hostile/asteroid/hivelord/legion/snow = 50, /mob/living/simple_animal/hostile/asteroid/goldgrub = 10)

	flora_spawn_list = list(/obj/structure/flora/tree/pine = 2, /obj/structure/flora/rock/icy = 2, /obj/structure/flora/rock/pile/icy = 2, /obj/structure/flora/grass/both = 12)
	terrain_spawn_list = list(/obj/structure/geyser/random = 1,
		/obj/machinery/atmospherics/miner/geyser/water = 1,
		/obj/machinery/atmospherics/miner/geyser/n2o = 1,
		/obj/machinery/atmospherics/miner/geyser/plasma = 1,
		/obj/machinery/atmospherics/miner/geyser/hydrogen = 1,)
	data_having_type = /turf/open/floor/plating/road/airless/cave/snow/has_data
	turf_type = /turf/open/floor/plating/road/snow/icemoon
	choose_turf_type = list(/turf/open/floor/plating/road/snow/icemoon = 19, /turf/open/floor/plating/ice/icemoon = 1)
	pick_tunnel_width = list("1" = 2, "2" = 2)

/turf/open/floor/plating/road/airless/cave/snow/underground
	mob_spawn_list = list(/mob/living/simple_animal/hostile/asteroid/ice_demon = 50, /obj/structure/spawner/ice_moon/demonic_portal = 3, \
						  /mob/living/simple_animal/hostile/asteroid/ice_whelp = 30, /obj/structure/spawner/ice_moon/demonic_portal/ice_whelp = 3, \
						  /mob/living/simple_animal/hostile/asteroid/hivelord/legion/snow = 50, /obj/structure/spawner/ice_moon/demonic_portal/snowlegion = 3)
	flora_spawn_list = list(/obj/structure/flora/rock/icy = 6, /obj/structure/flora/rock/pile/icy = 6)
	data_having_type = /turf/open/floor/plating/road/airless/cave/snow/underground/has_data
	choose_turf_type = null
	pick_tunnel_width = list("1" = 2, "2" = 2, "3" = 2)

/turf/open/floor/plating/road/airless/cave/snow/has_data //subtype for producing a tunnel with given data
	has_data = TRUE

/turf/open/floor/plating/road/airless/cave/snow/underground/has_data //subtype for producing a tunnel with given data
	has_data = TRUE

/turf/open/floor/plating/road/airless/cave/Initialize()
	if (!mob_spawn_list)
		mob_spawn_list = null //list(/mob/living/simple_animal/mouse = 5, /mob/living/simple_animal/chicken = 4, )
	if (!shitboyspawns)
		shitboyspawns = GLOB.shitboyspawns
	if (!flora_spawn_list)
		flora_spawn_list = list(/obj/structure/barrel/shit = 2, /obj/structure/flora/rock/pile = 2, /obj/effect/spawner/lootdrop/maintenance = 2)
	if(!terrain_spawn_list)
		terrain_spawn_list = list(/obj/structure/barrel/shit = 1,
		)
	. = ..()
	if(!has_data)
		produce_tunnel_from_data()

/// Sets the tunnel length and direction
/turf/open/floor/plating/road/airless/cave/proc/get_cave_data(set_length, exclude_dir = -1)
	// If set_length (arg1) isn't defined, get a random length; otherwise assign our length to the length arg.
	if(!set_length)
		length = rand(70, 90)
	else
		length = set_length

	// Get our directiosn
	forward_cave_dir = pick(GLOB.alldirs - exclude_dir)
	// Get the opposite direction of our facing direction
	backward_cave_dir = angle2dir(dir2angle(forward_cave_dir) + 180)

/// Gets the tunnel length and direction then makes the tunnel
/turf/open/floor/plating/road/airless/cave/proc/produce_tunnel_from_data(tunnel_length, excluded_dir = -1)
	get_cave_data(tunnel_length, excluded_dir)
	// Make our tunnels
	make_tunnel(forward_cave_dir)
	if(going_backwards)
		make_tunnel(backward_cave_dir)
	// Kill ourselves by replacing ourselves with a normal floor.
	SpawnFloor(src)

/**
  * Makes the tunnel and spawns things inside of it
  *
  * Picks a tunnel width for the tunnel and then starts spawning turfs in the direction it moves in
  * Can randomly change directions of the tunnel, stops if it hits the edge of the map, or a no tunnel area
  * Can randomly make new tunnels out of itself
  *
  */
/turf/open/floor/plating/road/airless/cave/proc/make_tunnel(dir)
	var/turf/open/floor/plating/asteroid/garbango/tunnel = src
	var/next_angle = pick(45, -45)

	var/tunnel_width = 1
	if(pick_tunnel_width)
		tunnel_width = text2num(pickweight(pick_tunnel_width))

	for(var/i = 0; i < length; i++)
		if(!sanity)
			break

		var/list/L = list(45)
		if(ISODD(dir2angle(dir))) // We're going at an angle and we want thick angled tunnels.
			L += -45

		// Expand the edges of our tunnel
		for(var/edge_angle in L)
			var/turf/open/floor/plating/asteroid/garbango/edge = tunnel
			for(var/current_tunnel_width = 1 to tunnel_width)
				if(!sanity)
					break
				edge = get_step(edge, angle2dir(dir2angle(dir) + edge_angle))
				if(istype(edge))
					SpawnFloor(edge)

		if(!sanity)
			break

		// Move our tunnel forward
		tunnel = get_step(tunnel, dir)

		if(istype(tunnel))
			// Small chance to have forks in our tunnel; otherwise dig our tunnel.
			if(i > 3 && prob(20))
				if(isarea(tunnel.loc))
					var/area/A = tunnel.loc
					if(!A.tunnel_allowed)
						sanity = 0
						break
				var/stored_flags = 0
				if(tunnel.flags_1 & NO_RUINS_1)
					stored_flags |= NO_RUINS_1
				var/turf/open/floor/plating/road/airless/cave/C = tunnel.ChangeTurf(data_having_type, null, CHANGETURF_IGNORE_AIR)
				C.flags_1 |= stored_flags
				C.going_backwards = FALSE
				C.produce_tunnel_from_data(rand(10, 15), dir)
			else
				SpawnFloor(tunnel)
		else //if(!istype(tunnel, parent)) // We hit space/normal/wall, stop our tunnel.
			break

		// Chance to change our direction left or right.
		if(i > 2 && prob(33))
			// We can't go a full loop though
			next_angle = -next_angle
			setDir(angle2dir(dir2angle(dir) )+ next_angle)


/// Spawns the floor of the tunnel and any type of structure or mob it can have
/turf/open/floor/plating/road/airless/cave/proc/SpawnFloor(turf/T)
	if(!T)
		sanity = 0
		return
	if(isarea(T.loc))
		var/area/A = T.loc
		if(!A.tunnel_allowed)
			sanity = 0
			return
	if(choose_turf_type)
		turf_type = pickweight(choose_turf_type)
	if(turf_type == initial(turf_type)) // Don't spawn different turf types under flora or terrain
		var/spawned_flora = FALSE
		var/spawned_terrain = FALSE
		if(is_outdoors(z))
			spawned_flora = SpawnFlora(T)	//No space mushrooms, cacti.
			spawned_terrain = SpawnTerrain(T)
		if(!spawned_flora && !spawned_terrain) // No rocks beneath mob spawners / mobs.
			SpawnMonster(T)
	var/stored_flags = 0
	if(T.flags_1 & NO_RUINS_1)
		stored_flags |= NO_RUINS_1
	T = T.ChangeTurf(turf_type, null, CHANGETURF_IGNORE_AIR)
	T.flags_1 |= stored_flags

/// Spawns a random mob or megafauna in the tunnel
/turf/open/floor/plating/road/airless/cave/proc/SpawnMonster(turf/T)
	if(!isarea(loc))
		return
	var/area/A = loc
	if(prob(1))
		if(!A.mob_spawn_allowed)
			return
		var/randumb = pickweight(mob_spawn_list)
		if(!randumb)
			return
		while(randumb == SPAWN_MEGAFAUNA)
			if(A.megafauna_spawn_allowed && shitboyspawns && shitboyspawns.len) //this is danger. it's boss time.
				var/maybe_boss = pickweight(shitboyspawns)
				if(shitboyspawns[maybe_boss])
					randumb = maybe_boss
			else //this is not danger, don't spawn a boss, spawn something else
				randumb = pickweight(mob_spawn_list)

		for(var/thing in urange(20, T)) //prevents mob clumps
			if(!ishostile(thing) && !istype(thing, /obj/structure/spawner))
				continue
			if((ispath(randumb, /mob/living/simple_animal/hostile/megafauna) || ismegafauna(thing)) && get_dist(src, thing) <= 7)
				return //if there's a megafauna within standard view don't spawn anything at all
			if(ispath(randumb, /mob/living/simple_animal/hostile/asteroid) || istype(thing, /mob/living/simple_animal/hostile/asteroid))
				return //if the random is a standard mob, avoid spawning if there's another one within 12 tiles
			if((ispath(randumb, /obj/structure/spawner/lavaland) || istype(thing, /obj/structure/spawner/lavaland)) && get_dist(src, thing) <= 2)
				return //prevents tendrils spawning in each other's collapse range

		if(ispath(randumb, /mob/living/simple_animal/hostile/megafauna/bubblegum)) //there can be only one bubblegum, so don't waste spawns on it
			shitboyspawns.Remove(randumb)

		new randumb(T)
		return TRUE

#undef SPAWN_MEGAFAUNA
#undef SPAWN_BUBBLEGUM

/// Spawns a random flora in the tunnel, can spawn clumps of them
/turf/open/floor/plating/road/airless/cave/proc/SpawnFlora(turf/T)
	if(prob(3))
		if(isarea(loc))
			var/area/A = loc
			if(!A.flora_allowed)
				return
		var/randumb = pickweight(flora_spawn_list)
		if(!randumb)
			return
		for(var/obj/structure/flora/F in range(12, T)) //Allows for growing patches, but not ridiculous stacks of flora
			if(!istype(F, randumb))
				return
		new randumb(T)
		return TRUE

/// Spawns a random terrain object in the tunnel
/turf/open/floor/plating/road/airless/cave/proc/SpawnTerrain(turf/T)
	if(prob(1))
		if(isarea(loc))
			var/area/A = loc
			if(!A.flora_allowed)
				return
		var/randumb = pickweight(terrain_spawn_list)
		if(!randumb)
			return
		for(var/obj/structure/geyser/F in range(7, T))
			if(istype(F, randumb))
				return
		new randumb(T)
		return TRUE

/turf/open/floor/plating/road/snow
	gender = PLURAL
	name = "snow"
	desc = "Looks cold."
	icon = 'icons/turf/snow.dmi'
	baseturfs = /turf/open/floor/plating/road/snow
	icon_state = "snow"
	icon_plating = "snow"
	initial_gas_mix = FROZEN_ATMOS
	slowdown = 2
	environment_type = "snow"
	flags_1 = NONE
	planetary_atmos = TRUE
	broken_states = list("snow_dug")
	burnt_states = list("snow_dug")
	bullet_sizzle = TRUE
	bullet_bounce_sound = null
	digResult = /obj/item/stack/sheet/mineral/snow

/turf/open/floor/plating/road/snow/burn_tile()
	if(!burnt)
		visible_message("<span class='danger'>[src] melts away!.</span>")
		slowdown = 0
		burnt = TRUE
		icon_state = "snow_dug"
		return TRUE
	return FALSE

/turf/open/floor/plating/road/snow/icemoon
	baseturfs = /turf/open/floor/plating/road/snow/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS
	slowdown = 0

/turf/open/lava/plasma/ice_moon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS
	baseturfs = /turf/open/lava/plasma/ice_moon
	planetary_atmos = TRUE

/turf/open/floor/plating/road/snow/ice
	name = "icy snow"
	desc = "Looks colder."
	baseturfs = /turf/open/floor/plating/road/snow/ice
	initial_gas_mix = "o2=0;n2=82;plasma=24;TEMP=120"
	floor_variance = 0
	icon_state = "snow-ice"
	icon_plating = "snow-ice"
	environment_type = "snow_cavern"
	footstep = FOOTSTEP_FLOOR
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY


/turf/open/floor/plating/road/snow/ice/icemoon
	baseturfs = /turf/open/floor/plating/road/snow/ice/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS
	planetary_atmos = TRUE
	slowdown = 0

/turf/open/floor/plating/road/snow/ice/burn_tile()
	return FALSE

/turf/open/floor/plating/road/snow/airless
	initial_gas_mix = AIRLESS_ATMOS

/turf/open/floor/plating/road/snow/temperatre
	initial_gas_mix = "o2=22;n2=82;TEMP=255.37"

/turf/open/floor/plating/road/snow/atmosphere
	initial_gas_mix = FROZEN_ATMOS
	planetary_atmos = FALSE