--[[
    Passive Follow by ivan[russia]
	
    Updated for BoL by ikita
   
    Base wait for mana regen and health regen/summoner spell, follow menu added by One™
	 
	********************** updated and developed by B Boy Breaker for AFK fix ********************* 
	
	Code improvements and bug correction and latest updates by VictorGrego.
	
	Changes:
	- The recall when near a tower issue has been resolved
	- Recalls after tower, for best safety
	- Have a menu for dinamic adjust the distance
	- Now follow partner recall
]]

require "MapPosition"

--summoners
local DEFAULT_FOLLOW_DISTANCE = 400
local DEFAULT_MANA_REGEN = 80
local DEFAULT_HP_REGEN = 80
local isRecalling = false

--CONSTANTS

local SetupFollowAlly = true 	-- you start follow near ally when your followtarget have been died
local SetupRunAway = true 		-- if no ally was near when followtarget died, you run to close tower
local MIN_DISTANCE = 275
local HEAL_DISTANCE = 700
local DEFAULT_HEALTH_THRESHOLD = 70
local DEFAULT_MANA_THRESHOLD = 66
local HL_slot = nil
local CL_slot = nil
-- SETTINGS
do
-- you can change true to false and false to true
-- false is turn off
-- true is turn on

SetupToggleKey = 115 --Key to Toggle script. [ F4 - 115 ] default
					 --key codes
					 --http://www.indigorose.com/webhelp/ams/Program_Reference/Misc/Virtual_Key_Codes.htm

SetupToggleKeyText = "F4"

SetupAutoHold = true -- Need work
-- stop autohit creeps when following target

afktime = 180 -- the time if the adc is afk b4 change the follower per second
end

-- GLOBALS [Do Not Change]
do
SetupDebug = true
following = nil
temp_following = nil
stopPosition = false
breaker = false

--state of app enum
FOLLOW = 1
TEMP_FOLLOW = -33
WAITING_FOLLOW_RESP = 150
GOING_TO_TOWER = 666
RECALLING = 374

--by default
state = FOLLOW

-- spawn
allySpawn = nil
enemySpawn = nil

--player status
isRegen = false
manaRegenPercent = 0.8
healthRegenPercent = 0.8

--follow menu
SetupDrawX = 0.1
SetupDrawY = 0.15
MenuTextSize = 18

allies = {}
FollowKeysText = {"F5", "F6", "F7", "F8"} --Key names for menu
FollowKeysCodes = {116,117,118,119} --Decimal key codes corressponding to key names

version = 2.2
player = GetMyHero()
end

-- ABSTRACTION-METHODS

--return players table
function GetPlayers(team, includeDead, includeSelf)
	local players = {}
	for i=1, heroManager.iCount, 1 do
		local member = heroManager:getHero(i)
		if member ~= nil and member.valid and member.type == "obj_AI_Hero" and member.visible and member.team == team then
			if member.name ~= player.name or includeSelf then 
				if includeDead then
					table.insert(players,member)
				elseif member.dead == false then
					table.insert(players,member)
				end
			end
		end
	end
	if #players > 0 then
		return players
	else
		return false
	end
end

--return towers table
function GetTowers(team)
	local towers = {}
	for i=1, objManager.maxObjects, 1 do
		local tower = objManager:getObject(i)
		if tower ~= nil and tower.valid and tower.type == "obj_AI_Turret" and tower.visible and tower.team == team then
			table.insert(towers,tower)
		end
	end
	if #towers > 0 then
		return towers
	else
		return false
	end
end

--here get close tower
function GetCloseTower(hero, team)
	local towers = GetTowers(team)
	if #towers > 0 then
		local candidate = towers[1]
		for i=2, #towers, 1 do
			if (towers[i].health/towers[i].maxHealth > 0.1) and  hero:GetDistance(candidate) > hero:GetDistance(towers[i]) then candidate = towers[i] end
		end
		return candidate
	else
		return false
	end
end

--here get close player
function GetClosePlayer(hero, team)
	local players = GetPlayers(team,false,false)
	if #players > 0 then
		local candidate = players[1]
		for i=2, #players, 1 do
			if hero:GetDistance(candidate) > hero:GetDistance(players[i]) then candidate = players[i] end
		end
		return candidate
	else
		return false
	end
end

-- return count of champs near hero
function cntOfChampsNear(hero,team,distance)
	local cnt = 0 -- default count of champs near HERO
	local players = GetPlayers(team,false,true)
	for i=1, #players, 1 do
		if players[i] ~= hero and hero:GetDistance(players[i]) < distance then cnt = cnt + 1 end
	end
	return cnt
end

-- return %hp of champs near hero
function hpOfChampsNear(hero,team,distance)
	local percent = 0 -- default %hp of champs near HERO
	local players = GetPlayers(team,false, true)
	for i=1, #players, 1 do
		if players[i] ~= hero and hero:GetDistance(players[i]) < distance then percent = percent + players[i].health/players[i].maxHealth end
	end
	return percent
end

function OnProcessSpell(object,spellProc) --for soraka + sona
	if config.enableScript == true and object.name == player.name and (spellProc.name == "SonaHymnofValorAttack" or spellProc.name == "SonaAriaofPerseveranceAttack" or spellProc.name == "SonaBasicAttack" or spellProc.name == "SonaBasicAttack2" or spellProc.name == "SonaSongofDiscordAttack" or spellProc.name == "SorakaBasicAttack" or spellProc.name == "SorakaBasicAttack2") then
		Run(GetCloseTower(player,player.team))
	end
end

-- OnDeleteObj
function OnDeleteObj(obj)
	if obj.name:find("TeleportHome.troy") then
		-- Set isRecalling off after short delay to prevent using abilities once at base
		DelayAction(function() isRecalling = false end, 0.2)
	end
end

--Detects if my partner is Recalling
function OnCreateObj(object)
	if object.name == "TeleportHomeImproved.troy" or object.name == "TeleportHome.troy" then
		if GetDistance(following, object) < 70 and player:GetDistance(following) <= config.followChamp.followDist then
			CastSpell(RECALL)
			isRecalling = true
		elseif GetDistance(player, object) < 70 then
			isRecalling = true
		end
	end
end

-- turn (off - on) by SetupToggleKey
-- follow summoners via follow menu
function OnWndMsg(msg, keycode)
	
	for i=1, #allies, 1 do 
		if keycode == FollowKeysCodes[i] and msg == KEY_DOWN then
			following = allies[i]
			PrintChat("Passive Follow >> following summoner: "..allies[i].name)
			state = FOLLOW
		end
	end
end

-- CHAT CALLBACK
function OnSendChat(text)
	if string.sub(text,1,7) == ".follow" then
	BlockChat()
		if string.sub(text,9,13) == "start" then
			name = string.sub(text,15)
			players = GetPlayers(player.team, true, false)
			if players ~= false then
				for i=1, #players, 1 do
					if (string.lower(players[i].name) == string.lower(name))  then 
						following = players[i]
						PrintChat("Passive Follow >> following summoner: "..players[i].name)
						carryCheck = true
						if following.dead then state = WAITING_FOLLOW_RESP else state = FOLLOW end
					end
				end
				if following == nil then PrintChat("Passive Follow >> "..name.." did not found") end
			end
		end
		if string.sub(text,9,12) == "stop" then
			following = nil
			state = FOLLOW
			PrintChat("Passive Follow >> terminated")
		end
	end
end

-- TIMER CALLBACK
mytime = GetTickCount() 

function OnTick()

	-- if in fountain and has no mana/hp, wait to fill up mana/hp bar before heading back out
	if InFountain() and (player.mana/player.maxMana * 100 < config.fontRegen.manaRegen or player.health/player.maxHealth * 100 < config.fontRegen.hpRegen) then
		if isRegen == false then
			PrintChat("Passive Follow >> Waiting at fountain to replenish mana and health.")
			isRegen = true
		end
		player:HoldPosition()
	else
		isRegen = false

		-- if there is no one go to bot "no adc(follower target)"
		if carryCheck == false and breaker == false and os.clock() >= breakers + afktime and following == nil then
			for i = 1, heroManager.iCount, 1 do --get heros
				local teammates = heroManager:getHero(i)
				if teammates.team == player.team and teammates.name ~= player.name and teammates.name ~= following.name and MapPosition:inBase(teammates) == false then 
					following = teammates
					PrintChat("Passive Follow >> following summoner: "..teammates.name)
					state = FOLLOW
					carryCheck = true
					breakers = os.clock()
				end
			end
		end
		
		-- if the target is afk
		if carryCheck == true and breaker == false then
			if MapPosition:inBase(following) == true then
				breakers = os.clock()
				breaker = true
			end
		end

		-- if the target moved again after afk "maybe the adc recall or die"
		if carryCheck == true and breaker == true then
			if MapPosition:inBase(following) == false then
				breaker = false
			end
		end
		
		-- choose new hero to follow
		if os.clock() >= breakers + afktime and breaker == true then 
			
			for i = 1, heroManager.iCount, 1 do --get heros

				local teammates = heroManager:getHero(i)

				if teammates.team == player.team and teammates.name ~= player.name and teammates.name ~= following.name and MapPosition:inBase(teammates) == false then --check if hero is alive, in my team(!) and not the same like before
				
					following = teammates
					PrintChat("Passive Follow >> following summoner: "..teammates.name)

					state = FOLLOW
					breaker = false
				end
			end
		end

		--Identify AD carry and follow
		if carryCheck == false then
			for i = 1, heroManager.iCount, 1 do
			local teammates = heroManager:getHero(i) 
			--Coordinates are for bots only
				if math.sqrt((teammates.x - 12143)^2 + (teammates.z - 2190)^2) < 4500 and teammates.team == player.team and teammates.name ~= player.name then
					following = teammates
					PrintChat("Passive Follow >> following summoner: "..teammates.name)
					state = FOLLOW
					carryCheck = true
				end
			end
		end

		if GetTickCount() - mytime > 800 and config.enableScript then 
			Brain()
			mytime = GetTickCount() 
		end
		
		if following ~= nil then
			Status(following)
		end
		
		if (following ~= nil and following.dead == false and (following.health/following.maxHealth) * 100 < config.autoSpells.healthThreshold and player:GetDistance(following) <= HEAL_DISTANCE) or (player.health/player.maxHealth) * 100 < config.autoSpells.healthThreshold then
			if HL_slot ~= nil and player:CanUseSpell(HL_slot) == READY then
				PrintChat("Passive Follow >> Used summoner spell.")
				CastSpell(HL_slot)
			end
		end
		
		-- use summoners if your mana is low 
		if (player.mana/player.maxMana) * 100 < config.autoSpells.manaThreshold then
			if CL_slot ~= nil and player:CanUseSpell(CL_slot) == READY then
				PrintChat("Passive Follow >> Used summoner spell: CLARITY.")
				CastSpell(CL_slot)
			end
		end
	end
end

-- STATUS CALLBACK
function Status(member)
	if member.dead and state == FOLLOW then
		PrintChat("Passive Follow >> "..member.name.." dead")
		-- if SetupFollowAlly == true and ALLYNEAR then temporary changing follow target
		if SetupFollowAlly and player:GetDistance(GetClosePlayer(player,player.team)) < config.followChamp.followDist then 
			temp_following = GetClosePlayer(player,player.team)
			PrintChat("Passive Follow >> "..(GetClosePlayer(player,player.team)).name.." temporary following")
			state = TEMP_FOLLOW
		elseif SetupRunAway then 
			state = GOING_TO_TOWER
		else
			state = WAITING_FOLLOW_RESP
		end
	end
	
	if not member.dead then
		if state == WAITING_FOLLOW_RESP then
			PrintChat("Passive Follow >> "..member.name.." alive")
			state = FOLLOW
		elseif state == TEMP_FOLLOW then
			temp_following = nil
			PrintChat("Passive Follow >> "..member.name.." alive")
			state = FOLLOW
		elseif state == GOING_TO_TOWER then
			PrintChat("Passive Follow >> "..member.name.." alive")
			state = FOLLOW
		end
	end
end

-- SEMICORE
-- run(follow) to target
function Run(target)
	if target.type == "obj_AI_Hero" then
		if target:GetDistance(allySpawn) > config.followChamp.followDist then
			if (player:GetDistance(target) > config.followChamp.followDist or player:GetDistance(target) < MIN_DISTANCE or player:GetDistance(allySpawn) + MIN_DISTANCE > target:GetDistance(allySpawn)) then
				followX = ((allySpawn.x - target.x)/(target:GetDistance(allySpawn)) * ((config.followChamp.followDist - 300) / 2 + 300) + target.x + math.random(-((config.followChamp.followDist-300)/3),((config.followChamp.followDist-300)/3)))
				followZ = ((allySpawn.z - target.z)/(target:GetDistance(allySpawn)) * ((config.followChamp.followDist - 300) / 2 + 300) + target.z + math.random(-((config.followChamp.followDist-300)/3),((config.followChamp.followDist-300)/3)))
				
				player:MoveTo(followX, followZ)
			else
				player:HoldPosition()
			end
		elseif SetupFollowRecall and player:GetDistance(allySpawn) > (config.followChamp.followDist * 2) then
			state = GOING_TO_TOWER
		end
	end
	if target.type == "obj_AI_Turret" then 
		if player:GetDistance(target) > 300 then 
			followX = ((allySpawn.x - target.x)/(target:GetDistance(allySpawn)) * ((config.followChamp.followDist - 300) / 2 + 300) + target.x + math.random(-((config.followChamp.followDist-300)/3),((config.followChamp.followDist-300)/3)))
			followZ = ((allySpawn.z - target.z)/(target:GetDistance(allySpawn)) * ((config.followChamp.followDist - 300) / 2 + 300) + target.z + math.random(-((config.followChamp.followDist-300)/3),((config.followChamp.followDist-300)/3)))
			
			player:MoveTo(followX, followZ)
		elseif SetupRunAwayRecall then
			
			if following.dead then
				state = WAITING_FOLLOW_RESP
				CastSpell(RECALL)
			else
				state = FOLLOW
			end
		end
	end
end

-- CORE
function Brain()
	if following ~= nil and player.dead == false and isRecalling == false then 
		if state == FOLLOW then Run(following) end
		if state == TEMP_FOLLOW and temp_following ~= nil then Run(temp_following) end
		if state == GOING_TO_TOWER then Run(GetCloseTower(player,player.team)) end
		
	end
end

-- Drawing follow menu
function OnDraw()
	local tempSetupDrawY = SetupDrawY

	DrawText("Press "..SetupToggleKeyText.." to toggle passive follow script.", MenuTextSize , (WINDOW_W - WINDOW_X) * SetupDrawX, (WINDOW_H - WINDOW_Y) * tempSetupDrawY , 0xffffff00) 
	tempSetupDrawY = tempSetupDrawY + 0.03
	
	for i=1, #allies, 1 do
		DrawText("Press "..FollowKeysText[i].." to follow player: "..allies[i].name.." ("..allies[i].charName..")", MenuTextSize , (WINDOW_W - WINDOW_X) * SetupDrawX, (WINDOW_H - WINDOW_Y) * tempSetupDrawY , 0xffffff00) 
		tempSetupDrawY = tempSetupDrawY + 0.03
	end
end

--Drawing Script Menu
function drawMenu()
	config = scriptConfig("Passive Follow", "Passive Follow") 

	config:addParam("enableScript", "Enable Script", SCRIPT_PARAM_ONKEYTOGGLE, true, 115)
	  
	config:addSubMenu("Follow Champion", "followChamp")
	config:addSubMenu("Regen at Fountain", "fontRegen")
	config:addSubMenu("Auto use SumSpells", "autoSpells")
	
	config.fontRegen:addParam("hpRegen", "min HP to leave", SCRIPT_PARAM_SLICE, DEFAULT_HP_REGEN, 0, 100, 0)
	config.fontRegen:addParam("manaRegen", "min Mana to leave", SCRIPT_PARAM_SLICE, DEFAULT_MANA_REGEN, 0, 100, 0)
	
	--config.autoSpells:addParam("useHeal", "Auto use Heal", SCRIPT_PARAM_ONOFF, false)
	--config.autoSpells:addParam("useClarity", "Auto use Clarity", SCRIPT_PARAM_ONOFF, false)
	config.autoSpells:addParam("manaThreshold", "Mana% for use Clarity", SCRIPT_PARAM_SLICE, DEFAULT_MANA_THRESHOLD, 0, 100, 0)
	config.autoSpells:addParam("healthThreshold", "HP% for use Cure", SCRIPT_PARAM_SLICE, DEFAULT_HEALTH_THRESHOLD, 0, 100, 0)
	
	config.followChamp:addParam("followDist", "Follow Distance", SCRIPT_PARAM_SLICE, DEFAULT_FOLLOW_DISTANCE, 400, 800, 0)
end

--TODO: Support other Spells
--Set Heal and Clarity
function setSummonerSlots()
	--set clarity
	if player:GetSpellData(SUMMONER_1).name == "SummonerMana" then
		CL_slot = SUMMONER_1
		HL_slot = SUMMONER_2
	elseif player:GetSpellData(SUMMONER_2).name == "SummonerMana" then
		HL_slot = SUMMONER_1
		CL_slot = SUMMONER_2
	end
end

-- AT LOADING OF SCRIPT
function OnLoad()
	breakers = os.clock()   --start timer
	PrintChat("Passive Follow >> v"..tostring(version).." LOADED")
	carryCheck = false
	setSummonerSlots()
	
	-- numerate spawn
	for i=1, objManager.maxObjects, 1 do
		local candidate = objManager:getObject(i)
		if candidate ~= nil and candidate.valid and candidate.type == "obj_SpawnPoint" then 
			if candidate.x < 3000 then 
				if player.team == TEAM_BLUE then allySpawn = candidate else enemySpawn = candidate end
			else 
				if player.team == TEAM_BLUE then enemySpawn = candidate else allySpawn = candidate end
			end
		end
	end
	
	--set allies player list
	allies = GetPlayers(player.team, true, false)
	drawMenu()
end
