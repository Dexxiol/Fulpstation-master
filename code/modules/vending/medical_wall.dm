/obj/machinery/vending/wallmed
	name = "\improper NanoMed"
	desc = "Wall-mounted Medical Equipment dispenser."
	icon_state = "wallmed"
	icon_deny = "wallmed-deny"
	density = FALSE
	products = list(/obj/item/reagent_containers/syringe = 3,
		            /obj/item/reagent_containers/pill/patch/libital = 5,
					/obj/item/reagent_containers/pill/patch/aiuri = 5,
					/obj/item/reagent_containers/pill/multiver = 2,
					/obj/item/reagent_containers/medigel/libital = 2,
					/obj/item/reagent_containers/medigel/aiuri = 2,
					/obj/item/reagent_containers/pill/patch/stypticpowder = 5,	//FULP
					/obj/item/reagent_containers/pill/patch/silversulfadiazine = 5,	//FULP
					/obj/item/reagent_containers/medigel/sterilizine = 1,
					/obj/item/reagent_containers/medigel/sterilizine = 1,
					/obj/item/healthanalyzer/wound = 2,
					/obj/item/stack/medical/bone_gel = 2)
	contraband = list(/obj/item/reagent_containers/pill/tox = 2,
	                  /obj/item/reagent_containers/pill/morphine = 2,
	                  /obj/item/storage/box/gum/happiness = 1)
	armor = list("melee" = 100, "bullet" = 100, "laser" = 100, "energy" = 100, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 100, "acid" = 50, "stab" = 1, "slash" = 1, "crush" = 1)
	resistance_flags = FIRE_PROOF
	refill_canister = /obj/item/vending_refill/wallmed
	default_price = 250
	extra_price = 500
	payment_department = ACCOUNT_MED
	tiltable = FALSE
	light_mask = "wallmed-light-mask"

/obj/item/vending_refill/wallmed
	machine_name = "NanoMed"
	icon_state = "refill_medical"

/obj/machinery/vending/wallmed/pubby
	products = list(/obj/item/reagent_containers/syringe = 3,
					/obj/item/reagent_containers/pill/patch/libital = 1,
					/obj/item/reagent_containers/pill/patch/aiuri = 1,
					/obj/item/reagent_containers/pill/patch/stypticpowder = 2,	//FULP
					/obj/item/reagent_containers/pill/patch/silversulfadiazine = 2,	//FULP
					/obj/item/reagent_containers/medigel/sterilizine = 1)
