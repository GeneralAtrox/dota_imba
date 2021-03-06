-- Copyright (C) 2018  The Dota IMBA Development Team
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

require('events/combat_events')
require('events/npc_spawned/on_hero_spawned')
require('events/npc_spawned/on_unit_spawned')
require('events/on_entity_killed/on_hero_killed')

function GameMode:OnGameRulesStateChange(keys)
	local newState = GameRules:State_Get()

	if IsMutationMap() then
		Mutation:OnGameRulesStateChange(keys)
	end

	if newState == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		InitItemIds()
		GameMode:OnSetGameMode() -- setup gamemode rules
		InitializeTeamSelection()
		GetPlayerInfoIXP() -- Add a class later
		Imbattlepass:Init() -- Initialize Battle Pass

		-- setup Player colors into hex for panorama
		local hex_colors = {}
		for i = 0, PlayerResource:GetPlayerCount() - 1 do
			table.insert(hex_colors, i, rgbToHex(PLAYER_COLORS[i]))
		end

		CustomNetTables:SetTableValue("game_options", "player_colors", hex_colors)
	elseif newState == DOTA_GAMERULES_STATE_HERO_SELECTION then
		HeroSelection:Init() -- init picking screen kv (this function is a bit heavy to run)
		api.imba.event(api.events.entered_hero_selection)
		Timers:CreateTimer(0.5, function()
			HeroSelection:StartSelection()
		end)
	elseif newState == DOTA_GAMERULES_STATE_PRE_GAME then
		api.imba.event(api.events.entered_pre_game)

		if api.imba.data.donators then
			CustomNetTables:SetTableValue("game_options", "donators", api.imba.get_donators())
		end
		if api.imba.data.developers then
			CustomNetTables:SetTableValue("game_options", "developers", api.imba.get_developers())
		end

		-- Create a timer to avoid lag spike entering pick screen
		Timers:CreateTimer(3.0, function()
			if USE_TEAM_COURIER == true then
				COURIER_TEAM = {}
				COURIER_TEAM[2] = CreateUnitByName("npc_dota_courier", Entities:FindByClassname(nil, "info_courier_spawn_radiant"):GetAbsOrigin(), true, nil, nil, 2)
				COURIER_TEAM[3] = CreateUnitByName("npc_dota_courier", Entities:FindByClassname(nil, "info_courier_spawn_dire"):GetAbsOrigin(), true, nil, nil, 3)
			end

			-- IMBA: Custom maximum level EXP tables adjustment
			local max_level = tonumber(CustomNetTables:GetTableValue("game_options", "max_level")["1"])
			if max_level and max_level > 25 then
				local j = 26
				Timers:CreateTimer(function()
					if j >= max_level then return end
					for i = j, j + 2 do
						XP_PER_LEVEL_TABLE[i] = XP_PER_LEVEL_TABLE[i-1] + 3500
						GameRules:GetGameModeEntity():SetCustomXPRequiredToReachNextLevel( XP_PER_LEVEL_TABLE )
					end
					j = j + 2
					return 1.0
				end)
			end

			-- Initialize IMBA Runes system
			ImbaRunes:Init()

			-- Initialize base shrines
			SetupShrines()

			-- Initialize gg panel
			GoodGame:Init()

			-- Setup topbar player colors
			CustomGameEventManager:Send_ServerToAllClients("override_top_bar_colors", {})
		end)
	elseif newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		api.imba.event(api.events.started_game)

		-- start rune timers
		if GetMapName() == Map1v1() then
			Setup1v1()
		else
			if IsMutationMap() then
				SpawnEasterEgg()
			end

			ImbaRunes:Spawn()
		end

		-- add abilities to all towers
		local towers = Entities:FindAllByClassname("npc_dota_tower")

		for _, tower in pairs(towers) do
			SetupTower(tower)
		end

		if IsMutationMap() then
			Timers:CreateTimer(function()
				Mutation:OnSlowThink()
				return 60.0
			end)
		end
	elseif newState == DOTA_GAMERULES_STATE_POST_GAME then
		api.imba.event(api.events.entered_post_game)
		api.imba.complete(function (error, players)
			local game_id = 0
			if api.imba.data ~= nil then
				game_id = api.imba.data.id or 0
			end

			CustomGameEventManager:Send_ServerToAllClients("end_game", {
				players = players,
				info = {
					winner = GAME_WINNER_TEAM,
					id = game_id,
					radiant_score = GetTeamHeroKills(2),
					dire_score = GetTeamHeroKills(3),
				},
			})
		end)
	end
end

dummy_created_count = 0

function GameMode:OnNPCSpawned(keys)
	GameMode:_OnNPCSpawned(keys)
	local npc = EntIndexToHScript(keys.entindex)

	if npc then
		-- UnitSpawned Api Event
		local player = "-1"

		if npc:IsRealHero() and npc:GetPlayerID() then
			player = PlayerResource:GetSteamID(npc:GetPlayerID())
		end

		api.imba.event(api.events.unit_spawned, {
			tostring(npc:GetUnitName()),
			tostring(player)
		})

		if npc:IsCourier() then
			if npc.first_spawn == true then
				CombatEvents("generic", "courier_respawn", npc)
			else
				npc:AddAbility("courier_movespeed"):SetLevel(1)
				npc.first_spawn = true
			end

			return
		elseif npc:IsRealHero() then
			if api.imba.is_donator(PlayerResource:GetSteamID(npc:GetPlayerOwnerID())) then
				npc:AddNewModifier(npc, nil, "modifier_imba_donator", {})
			end

			if npc.first_spawn ~= true then
				npc.first_spawn = true

				-- Need a frame time to detect illusions
				Timers:CreateTimer(FrameTime(), function()
					GameMode:OnHeroFirstSpawn(npc)
				end)

				return
			end

			GameMode:OnHeroSpawned(npc)

			return
		elseif string.find(npc:GetUnitName(), "tower") then
			print("Tower Spawned!")
			SetupTower(npc)
			return
		else
			if npc.first_spawn ~= true then
				npc.first_spawn = true
				GameMode:OnUnitFirstSpawn(npc)

				return
			end

			GameMode:OnUnitSpawned(npc)

			return
		end
	end
end

function GameMode:OnDisconnect(keys)
	-- GetConnectionState values:
	-- 0 - no connection
	-- 1 - bot connected
	-- 2 - player connected
	-- 3 - bot/player disconnected.

	-- Typical keys:
	-- PlayerID: 2
	-- name: Zimberzimber
	-- networkid: [U:1:95496383]
	-- reason: 2
	-- splitscreenplayer: -1
	-- userid: 7
	-- xuid: 76561198055762111

	-- IMBA: Player disconnect/abandon logic
	-- If the game hasn't started, or has already ended, do nothing
	if (GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME) or (GameRules:State_Get() < DOTA_GAMERULES_STATE_PRE_GAME) then
		return nil
			-- Else, start tracking player's reconnect/abandon state
	else
		-- Fetch player's player and hero information
		local player_id = keys.PlayerID
		local player_name = keys.name
		local hero = PlayerResource:GetPlayer(player_id):GetAssignedHero()
		local line_duration = 7

		-- Start tracking
--		log.info("started keeping track of player "..player_id.."'s connection state")
		api.imba.event(api.events.player_disconnected, { tostring(PlayerResource:GetSteamID(player_id)) })

		local disconnect_time = 0
		Timers:CreateTimer(1, function()
			-- Keep track of time disconnected
			disconnect_time = disconnect_time + 1

			-- If the player has abandoned the game, set his gold to zero and distribute passive gold towards its allies
			if disconnect_time >= ABANDON_TIME then
				-- Abandon message
				Notifications:BottomToAll({hero = hero:GetUnitName(), duration = line_duration})
				Notifications:BottomToAll({text = player_name.." ", duration = line_duration, continue = true})
				Notifications:BottomToAll({text = "#imba_player_abandon_message", duration = line_duration, style = {color = "DodgerBlue"}, continue = true})
				PlayerResource:SetHasAbandonedDueToLongDisconnect(player_id, true)
				log.info("player "..player_id.." has abandoned the game.")

				api.imba.event(api.events.player_abandoned, { tostring(PlayerResource:GetSteamID(player_id)) })

				-- Start redistributing this player's gold to its allies
				PlayerResource:StartAbandonGoldRedistribution(player_id)
				-- If the player has reconnected, stop tracking connection state every second
			elseif PlayerResource:GetConnectionState(player_id) == 2 then

			-- Else, keep tracking connection state
			else
--				log.info("tracking player "..player_id.."'s connection state, disconnected for "..disconnect_time.." seconds.")
				return 1
			end
		end)

		local table = {
			ID = player_id,
			team = PlayerResource:GetTeam(player_id),
			disconnect = 1
		}
		GoodGame:Call(table)
	end
end

-- An entity died
function GameMode:OnEntityKilled( keys )
	GameMode:_OnEntityKilled( keys )

	-- The Unit that was killed
	local killed_unit = EntIndexToHScript( keys.entindex_killed )

	-- The Killing entity
	local killer = nil

	if keys.entindex_attacker then
		killer = EntIndexToHScript( keys.entindex_attacker )
	end

	if killed_unit then
		------------------------------------------------
		-- Api Event Unit Killed
		------------------------------------------------

		killedUnitName = tostring(killed_unit:GetUnitName())

		if (killedUnitName ~= "") then
			killedPlayer = "-1"

			if killed_unit:IsRealHero() and killed_unit:GetPlayerID() then
				killedPlayerId = killed_unit:GetPlayerID()
				killedPlayer = PlayerResource:GetSteamID(killedPlayerId)
			end

			killerUnitName = "-1"
			killerPlayer = "-1"
			if (killer ~= nil) then
				killerUnitName = tostring(killer:GetUnitName())
				if (killer:IsRealHero() and killer:GetPlayerID()) then
					killerPlayerId = killer:GetPlayerID()
					killerPlayer = PlayerResource:GetSteamID(killerPlayerId)
				end
			end

			api.imba.event(api.events.unit_killed, {
				tostring(killerUnitName),
				tostring(killerPlayer),
				tostring(killedUnitName),
				tostring(killedPlayer)
			})
		end

		-------------------------------------------------------------------------------------------------
		-- IMBA: Ancient destruction detection
		-------------------------------------------------------------------------------------------------
		if killed_unit:GetUnitName() == "npc_dota_badguys_fort" then
			GAME_WINNER_TEAM = 2
			return
		elseif killed_unit:GetUnitName() == "npc_dota_goodguys_fort" then
			GAME_WINNER_TEAM = 3
			return
		end

		-- Check if the dying unit was a player-controlled hero
		if killed_unit:IsRealHero() and killed_unit:GetPlayerID() then
			if killer:GetTeamNumber() == 4 then
				CombatEvents("kill", "neutrals_kill_hero", killed_unit)
			end

			-- reset killstreak if not comitted suicide
			if killer ~= killed_unit then
				killed_unit.killstreak = 0
			end

			GameMode:OnHeroDeath(killer, killed_unit)

			if IsMutationMap() then
				Mutation:OnHeroDeath(killed_unit)
			end

			return
		elseif killed_unit:IsBuilding() then
			if string.find(killed_unit:GetUnitName(), "tower3") then
				local unit_name = "npc_dota_goodguys_healers"
				if killed_unit:GetTeamNumber() == 3 then
					unit_name = "npc_dota_badguys_healers"
				end

				local units = FindUnitsInRadius(killed_unit:GetTeamNumber(), Vector(0, 0, 0), nil, FIND_UNITS_EVERYWHERE, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_INVULNERABLE, FIND_ANY_ORDER, false)

				for _, building in pairs(units) do
					if building:GetUnitName() == unit_name or string.find(building:GetUnitName(), "npc_imba_donator_statue_") then
						if building:HasModifier("modifier_invulnerable") then
							building:RemoveModifierByName("modifier_invulnerable")
						end
					end
				end
			end

			if killer:IsRealHero() then
				print("Killer is a hero! (Building)")
				CombatEvents("kill", "hero_kill_tower", killed_unit, killer)
				if killer:GetTeam() ~= killed_unit:GetTeam() then
					if killed_unit:GetUnitName() == "npc_dota_goodguys_healers" or killed_unit:GetUnitName() == "npc_dota_badguys_healers" then
						SendOverheadEventMessage(killer:GetPlayerOwner(), OVERHEAD_ALERT_GOLD, killed_unit, 125, nil)
					else
						SendOverheadEventMessage(killer:GetPlayerOwner(), OVERHEAD_ALERT_GOLD, killed_unit, 200, nil)
					end
				end
			else
				print("Killer is not a hero! (Building)")
				CombatEvents("generic", "tower", killed_unit, killer)
			end

			if GetMapName() == Map1v1() then
				local winner = 2

				if killed_unit:GetTeamNumber() == 2 then
					winner = 3
				end

				GAME_WINNER_TEAM = winner
				GameRules:SetGameWinner(winner)
			end

			return
		elseif killed_unit:IsCourier() then
			CombatEvents("generic", "courier_dead", killed_unit)
			return
		else
			if IsMutationMap() then
				Mutation:OnUnitDeath(killed_unit)
			end
		end

		if killer:IsRealHero() then
			if killer:GetTeam() ~= killed_unit:GetTeam() and killed_unit:GetGoldBounty() > 0 then
--				local custom_gold_bonus = tonumber(CustomNetTables:GetTableValue("game_options", "bounty_multiplier")["1"]) or 100
--				local gold_bounty = killed_unit:GetGoldBounty()

--				local gold_reliable = true
--				local gold_reason = DOTA_ModifyGold_CreepKill

--				if killed_unit:IsRealHero() then
--					gold_reason = DOTA_ModifyGold_HeroKill
--					print(killed_unit:GetNumAttackers())
				if killed_unit:IsRoshan() then
--				elseif killed_unit:IsRoshan() then
--					gold_bounty = RandomInt(IMBA_ROSHAN_GOLD_KILL_MIN, IMBA_ROSHAN_GOLD_KILL_MAX) * custom_gold_bonus / 100
--					gold_bounty_assist = IMBA_ROSHAN_GOLD_ASSIST * custom_gold_bonus / 100
--					gold_reason = DOTA_ModifyGold_RoshanKill

--					for _, hero in pairs(HeroList:GetAllHeroes()) do
--						if hero:GetTeam() == killer:GetTeam() then
--							SendOverheadEventMessage(hero:GetPlayerOwner(), OVERHEAD_ALERT_GOLD, killed_unit, gold_bounty_assist, nil)
--							hero:ModifyGold(gold_bounty_assist, gold_reliable, gold_reason)

--							if hero == killer then
--								SendOverheadEventMessage(hero:GetPlayerOwner(), OVERHEAD_ALERT_GOLD, killed_unit, gold_bounty, nil)
--								hero:ModifyGold(gold_bounty, gold_reliable, gold_reason)
--							end
--						end
--					end

					-- Respawn time for Roshan
					local respawn_time = RandomInt(ROSHAN_RESPAWN_TIME_MIN, ROSHAN_RESPAWN_TIME_MAX) * 60
					Timers:CreateTimer(respawn_time, function()
						local roshan = CreateUnitByName("npc_dota_roshan", _G.ROSHAN_SPAWN_LOC, true, nil, nil, DOTA_TEAM_NEUTRALS)
						roshan:AddNewModifier(roshan, nil, "modifier_imba_roshan_ai", {})
					end)

					CombatEvents("kill", "roshan_dead", killed_unit, killer)

					return
--				elseif killed_unit:IsCourier() then
--					gold_bounty = gold_bounty * custom_gold_bonus / 100
--					gold_reason = DOTA_ModifyGold_CourierKill
--				else -- creeps + all other units
--					gold_bounty = gold_bounty * custom_gold_bonus / 100
--					gold_reliable = false
				end

--				SendOverheadEventMessage(killer:GetPlayerOwner(), OVERHEAD_ALERT_GOLD, killed_unit, gold_bounty, nil)
--				killer:ModifyGold(gold_bounty, gold_reliable, gold_reason)
			end

			if killer == killed_unit then
				CombatEvents("kill", "hero_suicide", killed_unit)
			elseif killed_unit:IsRealHero() and killer:GetTeamNumber() == killed_unit:GetTeamNumber() then
				CombatEvents("kill", "hero_deny_hero", killed_unit, killer)
			end
		end

--		if killer:GetOwnerEntity() then
--			SendOverheadEventMessage(killer:GetPlayerOwner(), OVERHEAD_ALERT_GOLD, killed_unit, killed_unit:GetGoldBounty(), nil)
--		end

		if killed_unit.pedestal then
			killed_unit.pedestal:ForceKill(false)
		end
	end
end

function GameMode:OnItemPickedUp(keys)
	local unitEntity = nil
	if keys.UnitEntitIndex then
		unitEntity = EntIndexToHScript(keys.UnitEntitIndex)
	elseif keys.HeroEntityIndex then
		unitEntity = EntIndexToHScript(keys.HeroEntityIndex)
	end

	local itemEntity = EntIndexToHScript(keys.ItemEntityIndex)
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local itemname = keys.itemname
end

function GameMode:OnPlayerReconnect(keys)
	
end

function GameMode:OnAbilityUsed(keys)
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local abilityname = keys.abilityname

end

function GameMode:OnPlayerLevelUp(keys)
	local player = EntIndexToHScript(keys.player)
	local hero = player:GetAssignedHero()
	local level = keys.level

	if hero:GetLevel() > 25 then
		if hero:GetUnitName() == "npc_dota_hero_meepo" then
			for _, hero in pairs(HeroList:GetAllHeroes()) do
				if hero:GetUnitName() == "npc_dota_hero_meepo" and hero:IsClone() then
					if not hero:HasModifier("modifier_imba_war_veteran_"..hero:GetPrimaryAttribute()) then
						hero:AddNewModifier(hero, nil, "modifier_imba_war_veteran_"..hero:GetCloneSource():GetPrimaryAttribute(), {}):SetStackCount(math.min(hero:GetCloneSource():GetLevel() -25, 17))
					else
						hero:FindModifierByName("modifier_imba_war_veteran_"..hero:GetCloneSource():GetPrimaryAttribute()):SetStackCount(math.min(hero:GetCloneSource():GetLevel() -25, 17))
					end
				end
			end
		end

		if not hero:HasModifier("modifier_imba_war_veteran_"..hero:GetPrimaryAttribute()) then
			hero:AddNewModifier(hero, nil, "modifier_imba_war_veteran_"..hero:GetPrimaryAttribute(), {}):SetStackCount(1)
		else
			hero:FindModifierByName("modifier_imba_war_veteran_"..hero:GetPrimaryAttribute()):SetStackCount(math.min(hero:GetLevel() -25, 17))
		end

		hero:SetAbilityPoints(hero:GetAbilityPoints() - 1)
	end
	
	if hero:GetUnitName() == "npc_dota_hero_invoker" then
		hero:FindAbilityByName("invoker_invoke"):SetLevel(min(math.floor(level/6 + 1), 4))
	end
end

function GameMode:OnPlayerLearnedAbility(keys)
	local player = EntIndexToHScript(keys.player)
	local hero = player:GetAssignedHero()
	local abilityname = keys.abilityname

	-- If it the ability is Homing Missiles, wait a bit and set count to 1
	if abilityname == "gyrocopter_homing_missile" then
		Timers:CreateTimer(1, function()
			-- Find homing missile modifier
			local modifier_charges = player:GetAssignedHero():FindModifierByName("modifier_gyrocopter_homing_missile_charge_counter")
			if modifier_charges then
				modifier_charges:SetStackCount(3)
			end
		end)
	elseif abilityname == "special_bonus_imba_mirana_5" then -- fix for mirana stand still talent not working
		hero:AddNewModifier(hero, nil, "modifier_imba_mirana_silence_stance", {})
		hero:AddNewModifier(hero, nil, "modifier_imba_mirana_silence_stance_visible", {})
	end

	-- initiate talent!
	if abilityname:find("special_bonus_imba_") == 1 then
		hero:AddNewModifier(hero, nil, "modifier_"..abilityname, {})
	end

	if abilityname == "lone_druid_savage_roar" and not hero.savage_roar then
		hero.savage_roar = true
	end

	if hero then
		api.imba.event(api.events.ability_learned, {
			tostring(abilityname),
			tostring(hero:GetUnitName()),
			tostring(PlayerResource:GetSteamID(player:GetPlayerID()))
		})
	end
end
--[[
function GameMode:PlayerConnect(keys)

end
--]]
-- This function is called once when the player fully connects and becomes "Ready" during Loading
function GameMode:OnConnectFull(keys)
	local entIndex = keys.index + 1
	local ply = EntIndexToHScript(entIndex)
	local playerID = ply:GetPlayerID()
	
	ReconnectPlayer(playerID)
	
	PlayerResource:InitPlayerData(playerID)
end

-- This function is called whenever any player sends a chat message to team or All
function GameMode:OnPlayerChat(keys)
	local teamonly = keys.teamonly
	local userID = keys.userid
--	local playerID = self.vUserIds[userID]:GetPlayerID()

	local text = keys.text

	local steamid = tostring(PlayerResource:GetSteamID(keys.playerid))
	local _text = tostring(text)
	api.imba.event(api.events.chat, {
		steamid,
		_text
	})

	-- This Handler is only for commands, ends the function if first character is not "-"
	if not (string.byte(text) == 45) then
		return nil
	end

	local caster = PlayerResource:GetPlayer(keys.playerid):GetAssignedHero()

	for str in string.gmatch(text, "%S+") do
		if IsInToolsMode() or GameRules:IsCheatMode() and api.imba.is_developer(steamid) then
			if str == "-dev_remove_units" then
				GameMode:RemoveUnits(true, true, true)
			end

			if str == "-spawnimbarune" then
				ImbaRunes:Spawn()
			end

			if str == "-replaceherowith" then
				text = string.gsub(text, str, "")
				text = string.gsub(text, " ", "")
				if PlayerResource:GetSelectedHeroName(caster:GetPlayerID()) ~= "npc_dota_hero_"..text then
					if caster.companion then
						caster.companion:ForceKill(false)
						caster.companion = nil
					end

					PrecacheUnitByNameAsync("npc_dota_hero_"..text, function()
						HeroSelection:GiveStartingHero(caster:GetPlayerID(), "npc_dota_hero_"..text, true)
					end)
				end
			end

			if str == "-getwearable" then
				Wearables:PrintWearables(caster)
			end
		end

		if str == "-gg" then
			CustomGameEventManager:Send_ServerToPlayer(caster:GetPlayerOwner(), "gg_init_by_local", {})
		end
	end
end

-- TODO: FORMAT THIS GARBAGE
function GameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_POST_GAME then return nil end
	if GameRules:IsGamePaused() then return 1 end

	CheatDetector()

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME or GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		if IsMutationMap() then
			Mutation:OnThink()
		end
	end

	for _, hero in pairs(HeroList:GetAllHeroes()) do
		if api.imba.is_donator(tostring(PlayerResource:GetSteamID(hero:GetPlayerID()))) == 10 then
			if not IsNearFountain(hero:GetAbsOrigin(), 1200) then
				local pos = Vector(-6700, -7165, 1509)
				if hero:GetTeamNumber() == 3 then
					pos = Vector(7168, 5750, 1431)
				end
				hero:SetAbsOrigin(pos)
			end
		end

		-- Make courier controllable, repeat every second to avoid uncontrollable issues
		if COURIER_TEAM then
			if COURIER_TEAM[hero:GetTeamNumber()] and not COURIER_TEAM[hero:GetTeamNumber()]:IsControllableByAnyPlayer() then
				print("Set team courier controllable!")
				COURIER_TEAM[hero:GetTeamNumber()]:SetControllableByPlayer(hero:GetPlayerID(), true)
			end
		end

		-- Undying talent fix
		if hero.undying_respawn_timer then
			if hero.undying_respawn_timer > 0 then
				hero.undying_respawn_timer = hero.undying_respawn_timer -1
			end

			break
		end

		-- Lone Druid fixes
		if hero:GetUnitName() == "npc_dota_hero_lone_druid" and hero.savage_roar then
			local Bears = FindUnitsInRadius(hero:GetTeam(), Vector(0, 0, 0), nil, FIND_UNITS_EVERYWHERE, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, 0, false)
			for _, Bear in pairs(Bears) do
				if Bear and string.find(Bear:GetUnitName(), "npc_dota_lone_druid_bear") and Bear:FindAbilityByName("lone_druid_savage_roar_bear") and Bear:FindAbilityByName("lone_druid_savage_roar_bear"):IsHidden() then
					Bear:FindAbilityByName("lone_druid_savage_roar_bear"):SetHidden(false)
				end

				break
			end
		elseif hero:GetUnitName() == "npc_dota_hero_morphling" and hero:GetModelName() == "models/heroes/morphling/morphling.vmdl" then
			for _, modifier in pairs(MORPHLING_RESTRICTED_MODIFIERS) do
				if hero:HasModifier(modifier) then
					hero:RemoveModifierByName(modifier)
				end
			end
		elseif hero:GetUnitName() == "npc_dota_hero_witch_doctor" then
			if hero:HasTalent("special_bonus_imba_witch_doctor_6") then
				if not hero:HasModifier("modifier_imba_voodoo_restoration") then
					local ability = hero:FindAbilityByName("imba_witch_doctor_voodoo_restoration")
					hero:AddNewModifier(hero, ability, "modifier_imba_voodoo_restoration", {})
				end
			end
		end

		-- Tusk fixes
		if hero:FindModifierByName("modifier_tusk_snowball_movement") then
			if hero:FindAbilityByName("tusk_snowball") then
				hero:FindAbilityByName("tusk_snowball"):SetActivated(false)
			end
		else
			if hero:FindAbilityByName("tusk_snowball") then
				hero:FindAbilityByName("tusk_snowball"):SetActivated(true)
			end
		end

		-- Find hidden modifiers
--		if hero:GetUnitName() == "npc_dota_hero_skeleton_king" then
--			for i = 0, hero:GetModifierCount() -1 do
--				print(hero:GetUnitName(), hero:GetModifierNameByIndex(i))
--			end
--		end
	end

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		-- End the game if one team completely abandoned
		if CustomNetTables:GetTableValue("game_options", "game_count").value == 1 then
			if not TEAM_ABANDON then
				TEAM_ABANDON = {} -- 15 second to abandon, is_abandoning?, player_count.
				TEAM_ABANDON[2] = {FULL_ABANDON_TIME, false, 0}
				TEAM_ABANDON[3] = {FULL_ABANDON_TIME, false, 0}
			end

			TEAM_ABANDON[2][3] = PlayerResource:GetPlayerCountForTeam(2)
			TEAM_ABANDON[3][3] = PlayerResource:GetPlayerCountForTeam(3)

			for ID = 0, PlayerResource:GetPlayerCount() -1 do
				local team = PlayerResource:GetTeam(ID)

				if PlayerResource:GetConnectionState(ID) ~= 2 then -- if disconnected then
					TEAM_ABANDON[team][3] = TEAM_ABANDON[team][3] -1
				end

				if TEAM_ABANDON[team][3] > 0 then
					TEAM_ABANDON[team][2] = false
				else
					if TEAM_ABANDON[team][2] == false then
						local abandon_text = "#imba_team_good_abandon_message"
						if team == 3 then
							abandon_text = "#imba_team_bad_abandon_message"
						end
						Notifications:BottomToAll({text = abandon_text.." ("..tostring(TEAM_ABANDON[team][1])..")", duration = 1.0, style = {color = "DodgerBlue"} })
					end

					TEAM_ABANDON[team][2] = true
					TEAM_ABANDON[team][1] = TEAM_ABANDON[team][1] -1

					if TEAM_ABANDON[2][1] <= 0 then
						GAME_WINNER_TEAM = 3
						GameRules:SetGameWinner(3)
					elseif TEAM_ABANDON[3][1] <= 0 then
						GAME_WINNER_TEAM = 2
						GameRules:SetGameWinner(2)
					end
				end
			end
		end
	end

	if i == nil then i = AP_GAME_TIME -1
	elseif i < 0 then
		if PICKING_SCREEN_OVER == false then
			PICKING_SCREEN_OVER = true
		end

		return 1
	else
		i = i - 1
	end

--	print("i = "..i)

	return 1
end

-- TODO: FORMAT LATER
-- A player last hit a creep, a tower, or a hero
function GameMode:OnLastHit(keys)
	if keys.PlayerID == -1 then return end
	local isFirstBlood = keys.FirstBlood == 1
	local isHeroKill = keys.HeroKill == 1
	local isTowerKill = keys.TowerKill == 1
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local killedEnt = EntIndexToHScript(keys.EntKilled)

	if isFirstBlood and player ~= nil then
		player:GetAssignedHero().kill_hero_bounty = 0
		Timers:CreateTimer(FrameTime() * 2, function()
				CombatEvents("kill", "first_blood", killedEnt, player:GetAssignedHero())
			end)
		return
	elseif isHeroKill and player ~= nil then
		if not player:GetAssignedHero().killstreak then player:GetAssignedHero().killstreak = 0 end
		player:GetAssignedHero().killstreak = player:GetAssignedHero().killstreak +1

--		for _,attacker in pairs(HeroList:GetAllHeroes()) do
--			for i = 0, killedEnt:GetNumAttackers() -1 do
--				if attacker == killedEnt:GetAttacker(i) then
--					log.debug(attacker:GetUnitName())
--				end
--			end
--		end

		player:GetAssignedHero().kill_hero_bounty = 0
		Timers:CreateTimer(0.1, function()
			CombatEvents("kill", "hero_kill", killedEnt, player:GetAssignedHero())
		end)
	end
end

-- A player killed another player in a multi-team context
function GameMode:OnTeamKillCredit(keys)

	-- Typical keys:
	-- herokills: 6
	-- killer_userid: 0
	-- splitscreenplayer: -1
	-- teamnumber: 2
	-- victim_userid: 7
	-- killer id will be -1 in case of a non-player owned killer (e.g. neutrals, towers, etc.)

	local killer_id = keys.killer_userid
	local victim_id = keys.victim_userid
	local killer_team = keys.teamnumber
	local nTeamKills = keys.herokills

	if GetMapName() == Map1v1() then
		if nTeamKills == IMBA_1V1_SCORE then
			GAME_WINNER_TEAM = killer_team
			GameRules:SetGameWinner( killer_team )
		end
	end

	-------------------------------------------------------------------------------------------------
	-- IMBA: Comeback gold logic
	-------------------------------------------------------------------------------------------------
	--	UpdateComebackBonus(1, killer_team)

	-------------------------------------------------------------------------------------------------
	-- IMBA: Deathstreak logic
	-------------------------------------------------------------------------------------------------
	if PlayerResource:IsValidPlayerID(killer_id) and PlayerResource:IsValidPlayerID(victim_id) then
		PlayerResource:ResetDeathstreak(killer_id)
		PlayerResource:IncrementDeathstreak(victim_id)

		-- Show Deathstreak message
		local victim_hero_name = PlayerResource:GetPlayer(victim_id):GetAssignedHero()
		local victim_player_name = PlayerResource:GetPlayerName(victim_id)
		local victim_death_streak = PlayerResource:GetDeathstreak(victim_id)
		local line_duration = 7

		if victim_death_streak then
			if victim_death_streak >= 3 then
				Notifications:BottomToAll({hero = victim_hero_name, duration = line_duration})
				Notifications:BottomToAll({text = victim_player_name.." ", duration = line_duration, continue = true})
			end

			if victim_death_streak == 3 then
				Notifications:BottomToAll({text = "#imba_deathstreak_3", duration = line_duration, continue = true})
			elseif victim_death_streak == 4 then
				Notifications:BottomToAll({text = "#imba_deathstreak_4", duration = line_duration, continue = true})
			elseif victim_death_streak == 5 then
				Notifications:BottomToAll({text = "#imba_deathstreak_5", duration = line_duration, continue = true})
			elseif victim_death_streak == 6 then
				Notifications:BottomToAll({text = "#imba_deathstreak_6", duration = line_duration, continue = true})
			elseif victim_death_streak == 7 then
				Notifications:BottomToAll({text = "#imba_deathstreak_7", duration = line_duration, continue = true})
			elseif victim_death_streak == 8 then
				Notifications:BottomToAll({text = "#imba_deathstreak_8", duration = line_duration, continue = true})
			elseif victim_death_streak == 9 then
				Notifications:BottomToAll({text = "#imba_deathstreak_9", duration = line_duration, continue = true})
			elseif victim_death_streak >= 10 then
				Notifications:BottomToAll({text = "#imba_deathstreak_10", duration = line_duration, continue = true})
			end
		end
	end

	-------------------------------------------------------------------------------------------------
	-- IMBA: Rancor logic
	-------------------------------------------------------------------------------------------------

	-- TODO: Format this into venge's hero file
	-- Victim stack loss
	local victim_hero = PlayerResource:GetPlayer(victim_id):GetAssignedHero()
	if victim_hero and victim_hero:HasModifier("modifier_imba_rancor") then
		local current_stacks = victim_hero:GetModifierStackCount("modifier_imba_rancor", VENGEFUL_RANCOR_CASTER)
		if current_stacks <= 2 then
			victim_hero:RemoveModifierByName("modifier_imba_rancor")
		else
			victim_hero:SetModifierStackCount("modifier_imba_rancor", VENGEFUL_RANCOR_CASTER, current_stacks - math.floor(current_stacks / 2) - 1)
		end
	end

	-- Killer stack gain
	if victim_hero and VENGEFUL_RANCOR and PlayerResource:IsImbaPlayer(killer_id) and killer_team ~= VENGEFUL_RANCOR_TEAM then
		local eligible_rancor_targets = FindUnitsInRadius(victim_hero:GetTeamNumber(), victim_hero:GetAbsOrigin(), nil, 1500, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD + DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_CLOSEST, false)
		if eligible_rancor_targets[1] then
			local rancor_stacks = 1

			-- Double stacks if the killed unit was Venge
			if victim_hero == VENGEFUL_RANCOR_CASTER then
				rancor_stacks = rancor_stacks * 2
			end

			-- Add stacks and play particle effect
			AddStacks(VENGEFUL_RANCOR_ABILITY, VENGEFUL_RANCOR_CASTER, eligible_rancor_targets[1], "modifier_imba_rancor", rancor_stacks, true)
			local rancor_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_vengeful/vengeful_negative_aura.vpcf", PATTACH_ABSORIGIN, eligible_rancor_targets[1])
			ParticleManager:SetParticleControl(rancor_pfx, 0, eligible_rancor_targets[1]:GetAbsOrigin())
			ParticleManager:SetParticleControl(rancor_pfx, 1, VENGEFUL_RANCOR_CASTER:GetAbsOrigin())
		end
	end

	-------------------------------------------------------------------------------------------------
	-- IMBA: Vengeance Aura logic
	-------------------------------------------------------------------------------------------------

	if victim_hero and PlayerResource:IsImbaPlayer(killer_id) then
		local vengeance_aura_ability = victim_hero:FindAbilityByName("imba_vengeful_command_aura")
		local killer_hero = PlayerResource:GetPlayer(killer_id):GetAssignedHero()
		if vengeance_aura_ability and vengeance_aura_ability:GetLevel() > 0 then
			vengeance_aura_ability:ApplyDataDrivenModifier(victim_hero, killer_hero, "modifier_imba_command_aura_negative_aura", {})
			victim_hero.vengeance_aura_target = killer_hero
		end
	end
end
