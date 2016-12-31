-----------------------------------------------------------------------------------------------
-- Client Lua Script for RIPgold
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

-- todo (no clue how to): check if mordechai is being blinded
-- todo (no clue how to): last boss in ssm
-- todo: SSM: reminder after 15s that you forgot to pick first relic in SSM, unit name: Spirit Relic of Blood
-- todo: some spells are counting twice or more per second, make a timer for every spell to add one failpoint once per two seconds (bugging bosses -> mordechai)
-- todo: SSM: write whisp message to people who are dead after 2s after spirit relics being placed "you can rezz up"
-- todo: sound when you fuck up challenge

require "Apollo"
require "Window"
require "GroupLib"
require "GameLib"
 
-----------------------------------------------------------------------------------------------
-- RIPgold Module Definition
-----------------------------------------------------------------------------------------------
local RIPgold = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function RIPgold:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function RIPgold:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)

	-- instance = {
	-- -- Persisted configuration: defaults.
	-- config = {
	--   achievements = {},
	-- },
	-- }
	-- setmetatable(instance, self)

	-- Apollo.RegisterAddon(instance, false, "", {
	-- "RIPgold.dung_stl",
	-- })

	-- return instance

end

-- local dung_stl
-- function RIPgold:LoadDependencies()
--   dung_stl = Apollo.GetPackage("RIPgold.dung_stl").tPackage
-- end
 

-----------------------------------------------------------------------------------------------
-- RIPgold OnLoad
-----------------------------------------------------------------------------------------------
function RIPgold:OnLoad()
	--self:LoadDependencies()

	--self.myClass = require("dung_stl")
	--self.myClass:helloWorld()
	--publicClass.helloWorld()

    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("RIPgold.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- RIPgold OnDocLoaded
-----------------------------------------------------------------------------------------------
function RIPgold:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "RIPgoldForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded",  "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("ToggleRIPgoldUI", "OnRIPgoldOn", self)

		Apollo.RegisterSlashCommand("rip", "OnRIPgoldOn", self)
		Apollo.RegisterSlashCommand("rap", "HowManyFails", self)

		-- Do additional Addon initialization here
		Apollo.RegisterEventHandler("UnitEnteredCombat", "OnCombat", self)
		Apollo.RegisterEventHandler("CombatLogDamage", "OnCombatLogDamage", self)

		Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
		Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)

		Apollo.RegisterEventHandler("CombatLogVitalModifier", "OnCombatLogVitalModifier", self)

		Apollo.RegisterEventHandler("PublicEventStart",	"OnPublicEventStart", self)
		Apollo.RegisterEventHandler("PublicEventStatsUpdate", "OnPublicEventStatsUpdate", self)

		Apollo.RegisterEventHandler("ChangeWorld", "OnWorldChange", self)

		-- first: seconds how often is repeated, second if its repeating
		self.checkDeadState = ApolloTimer.Create(1, true, "CheckForPlayerDeaths", self) 
		self.checkDeadState:Stop()


		-- updating ui every second when opened
		self.updateStatsUI = ApolloTimer.Create(1, true, "UpdateRIPgoldStatsUI", self)
		self.updateStatsUI:Stop()

		self.hlp = {} -- all helpers
		self.set = {} -- all settings

		self.hlp.isBossDead = {}
		self.hlp.isBossDead.timer = ApolloTimer.Create(1, true, "ALL_checkForBossDeaths", self)
		self.hlp.isBossDead.timer:Stop()
		self.hlp.isBossDead.ID = 0
		self.hlp.isBossDead.name = ""
		self.hlp.isBossDead.dead = false

		self.hlp.doesChannelerExists = ApolloTimer.Create(1, true, "STL_checkForChannelerDeaths", self)
		self.hlp.doesChannelerExists:Stop()

		self.hlp.peMatch = nil
		self.hlp.isInDungeon = false

		self:InitializeVars()

		if not GroupLib.InRaid() then
			self:PreparePlayers()
		end

		-- has to be outside InitializeVars() becouse it would get reseted after game creates Channelers
		self.hlp.WindInvokerChanellerID = { 
			[1] = 0, [2] = 0, [3] = 0, [4] = 0 
		}

		--- testing purposes
		self.set.sound = true
		-- additional sounds: self:PlaySound(Sound.PlayUIQueuePopsAdventure)
		-- additional sounds: self:PlaySound(Sound.PlayUI47CancelVirtual)
		self.set.soundType = Sound.PlayUI11To13GenericPushButtonDigital02

		--self.hlp.isInDungeon = true
		--self.hlp.boss["Blade-Wind the Invoker"] = true

	end
end

-----------------------------------------------------------------------------------------------
-- RIPgold Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function RIPgold:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "RIPgold", {"ToggleRIPgoldUI", "", ""}) --IconSprites:Icon_Windows_UI_CRB_Rival icon before (terrible meh)
end

-- on SlashCommand "/rip"
function RIPgold:OnRIPgoldOn()

	self.updateStatsUI:Start()

	self:UpdateRIPgoldStatsUI()
	self:OnBTN_statsClick() --instead of self.wndMain:FindChild("WRAP_FAILS"):ArrangeChildrenVert(1)

	self.wndMain:Invoke() -- show the window

	-- self:Debug(self.hlp.player[1].name .. ": " .. self.hlp.player[1].fails)
	-- self:Debug(self.hlp.player[2].name .. ": " .. self.hlp.player[2].fails)
	-- self:Debug(self.hlp.player[3].name .. ": " .. self.hlp.player[3].fails)
	-- self:Debug(self.hlp.player[4].name .. ": " .. self.hlp.player[4].fails)
	-- self:Debug(self.hlp.player[5].name .. ": " .. self.hlp.player[5].fails)

end

function RIPgold:UpdateRIPgoldStatsUI()

	for i=1,5 do
		if self.hlp.player[i].name ~= "" then

			self.wndMain:FindChild("WIN_stats"):FindChild("INFO_fails_name_"..i):SetText(self.hlp.player[i].name)
			self.wndMain:FindChild("WIN_stats"):FindChild("INFO_fails_stat_"..i):SetText(self.hlp.player[i].fails)
		else
			self.wndMain:FindChild("INFO_fails_name_"..i):SetText("")
			self.wndMain:FindChild("INFO_fails_stat_"..i):SetText("")
		end
	end

end

function RIPgold:HowManyFails()

	self:InformOthers("So, how many fails did you do this dungeon?", false)

	self:InformOthers(self.hlp.player[1].name .. ": " .. self.hlp.player[1].fails, false)
	self:InformOthers(self.hlp.player[2].name .. ": " .. self.hlp.player[2].fails, false)
	self:InformOthers(self.hlp.player[3].name .. ": " .. self.hlp.player[3].fails, false)
	self:InformOthers(self.hlp.player[4].name .. ": " .. self.hlp.player[4].fails, false)
	self:InformOthers(self.hlp.player[5].name .. ": " .. self.hlp.player[5].fails, false)

end

function RIPgold:InitializeVars()

	self.hlp.alreadyFailedChallenge = false
	self.hlp.alreadyFailedDeathless = false

	self.hlp.boss = {
		["Grond the Corpsemaker"] = false,
		["Slavemaster Drokk"] = false,
		["Forgemaster Trogun"] = false,
		["Stew-Shaman Tugga"] = false,
		["Thunderfoot"] = false,
		["Laveka the Dark-Hearted"] = false,
		["Bosun Octog"] = false,
		["Mordechai Redmoon"] = false,
		["Blade-Wind the Invoker"] = false,	
		["Aethros"] = false,		
		["Stormtalon"] = false,	
		["Deadringer Shallaos"] = false,
		["Rayna Darkspeaker"] = false,
		["Moldwood Overlord Skash"] = false,
		["Ondu Lifeweaver"] = false,
		["Spiritmother Selene the Corrupted"] = false,
		["Invulnotron"] = false,
		["Gromka the Flamewitch"] = false,
		["Iruki Boldbeard"] = false,
		["Wrathbone"] = false,
	}

	self.hlp.nPoints = 0
	self.hlp.nBronze = 0
	self.hlp.nSilver = 0
	self.hlp.nGold = 0

	self.hlp.SelenePercentage = 0
	self.hlp.TrogunStacks = 0
	self.hlp.OctogStacks = 0
	self.hlp.ShallaosStacks = { 
		[1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, 
	}
	self.hlp.WindInvokerTargetPlayer = {
		["name"] = "", ["x"] = 0, ["y"] = 0, ["z"] = 0,
	}

	self.hlp.WindInvokerDiffs = { 
		[1] = 0, [2] = 0, [3] = 0, [4] = 0 
	}

	self.hlp.WindInvokerInvisibleUnitID = 0

	self.hlp.WindInvokerLastGametime = GameLib.GetGameTime() 

end

function RIPgold:PreparePlayers()

	self.hlp.player = {
		[1] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
		[2] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
		[3] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
		[4] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
		[5] = {["name"] = "", ["fails"] = 0, ["dead"] = false},
	}

	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone

	if getGroupMaxSize == 0 then

		function GetPlayerName()
		   local getBossBuffs = GameLib.GetPlayerUnit(1):GetName() ~= nil
		end

		if pcall(GetPlayerName) then
			local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
			self.hlp.player[1].name = getCurrentPlayerName
		end

	else

		for nGroupIndex=1,getGroupMaxSize do 

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getGroupMemberName = getGroupMember.strCharacterName
				self.hlp.player[nGroupIndex].name = getGroupMemberName
			end
		end
	end
end

function RIPgold:OnPublicEventStart()

	if self.hlp.peMatch then
		return true
	end

	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do

		function IsPeUpdated()
		   local getPeUpdated = peCurrent:GetEventType() ~= nil
		end

		if pcall(IsPeUpdated) then

			local getEventType = peCurrent:GetEventType()
			if getEventType ~= PublicEvent.PublicEventType_Dungeon then
				return
			end

			--SendVarToRover("Dungeon event", peCurrent)

			if peCurrent:ShouldShowMedalsUI() then
				-- processed after and only entering new dungeon -> reseting points etc
				self:Debug("Everything reseted.")

				self.hlp.isInDungeon = true

				self:InitializeVars()
				self:PreparePlayers()

				self.checkDeadState:Start()

				self.hlp.nPoints = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_None)
				self.hlp.nBronze = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_Bronze)
				self.hlp.nSilver = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_Silver)
				self.hlp.nGold = peCurrent:GetRewardThreshold(PublicEvent.PublicEventRewardTier_Gold)
					
				self.hlp.peMatch = peCurrent

				SendVarToRover("self", self)
				
				return true
			end
		end
	end

	return false

end

function RIPgold:CheckForPlayerDeaths()

	if self.hlp.isInDungeon then 

		for nGroupIndex=1,GroupLib.GetGroupMaxSize() do
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

			if getGroupMember ~= nil then

				local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

				if getGroupMemberUnit ~= nil then
					local getDeathState = getGroupMemberUnit:IsDead()
					local getGroupMemberName = getGroupMember.strCharacterName

					if getDeathState then
						if self.hlp.player[nGroupIndex].dead == false then

							if self.hlp.alreadyFailedDeathless == false then
								local getDeadPlayerName = getGroupMemberUnit:GetName()
								local sToChat = string.format("%s just fucked up deathless challenge. RIPgold. :(.", getDeadPlayerName)
								self:InformOthers(sToChat, false, true)
								self:Debug(getGroupMemberUnit:GetName() .. " just fucked deathless.")
								self.hlp.alreadyFailedDeathless = true
							end

							self:Debug(getGroupMemberUnit:GetName() .. " is dead.")
							self.hlp.player[nGroupIndex].dead = true
							self:CountFails(getGroupMemberName)

						end
					else
						if self.hlp.player[nGroupIndex].dead then

							self:Debug(getGroupMemberUnit:GetName() .. " is alive.")
							self.hlp.player[nGroupIndex].dead = false
						end
					end
				end
			end
		end
	end
end

function RIPgold:OnPublicEventStatsUpdate(peUpdated)

	if not GroupLib.InRaid() then --if not in raid

		--local timeinfo = string.format("OnPublicEventStatsUpdate base - %s", GameLib.GetGameTime())
		--SendVarToRover(timeinfo, peUpdated)

		function IsPeUpdated()
		   local getPeUpdated = peUpdated:GetEventType() ~= nil
		end

		if pcall(IsPeUpdated) then

			if peUpdated:GetEventType() ~= PublicEvent.PublicEventType_Dungeon then
				return
			end

			self.hlp.isInDungeon = true
			self.checkDeadState:Start()

			local nCurrentPoints = peUpdated:GetStat(PublicEvent.PublicEventStatType.MedalPoints)
			if self.hlp.nPoints == nCurrentPoints then
				return
			end

			--SendVarToRover("self", self)

			-- code connected with event points

				--local timeinfo = string.format("OnPublicEventStatsUpdate - %s", GameLib.GetGameTime())
				--SendVarToRover(timeinfo, peUpdated)

		end

		-- function IsPeObjectives()
		--    local getPeObjectives = peUpdated:GetObjectives() ~= nil
		-- end

		-- if pcall(IsPeObjectives) then

		-- 	-- technically all event points
		-- 	local objectives = peUpdated:GetObjectives()

		-- 	for i,obj in pairs(objectives) do
		-- 		if obj:GetShortDescription() == "Deathless in the Dungeon" then
		-- 			SendVarToRover("deathless", obj)
		-- 		end
		-- 	end

		-- 	-- test purpose

		-- 	--local getObjectives = peUpdated:GetObjectives()
		-- 	--local timeinfo = string.format("getObjectives - %s", GameLib.GetGameTime())
		-- 	--SendVarToRover(timeinfo, getObjectives)

		-- end

	end -- if not in raid

end




function RIPgold:OnCombat(unitInCombat, bInCombat)

	if self.hlp.isInDungeon then 

		local unitInCombatName = unitInCombat:GetName()
		local unitInCombatDead = unitInCombat:IsDead() -- not working

		if bInCombat then
			for bossName,bossState in pairs(self.hlp.boss) do
				if bossName == unitInCombatName then
					self.hlp.boss[bossName] = true
					-- info about fails at the end of the dungeon -> starts timer when these names occurs
					self:ALL_precheckForBossDeaths(unitInCombat)
					self:Debug(bossName .. " alive.")
				end
			end

			if unitInCombatName == "Slavemaster Drokk" then
				-- workaround if player get hit by Phase Blast before Slavemaster Drokk
				if self.hlp.alreadyFailedChallenge then
					self.hlp.alreadyFailedChallenge = false
				end
			end

			if unitInCombatName == "Rayna Darkspeaker" then
				-- workaround if player get hit by Torine Totems of Flame before Rayna Darkspeaker
				if self.hlp.alreadyFailedChallenge then
					self.hlp.alreadyFailedChallenge = false
				end
			end
		end

		-- proceeds on leaving combat
		if not bInCombat then 

			-- specific bosses

			if unitInCombatName == "Stew-Shaman Tugga" then

				function IsTuggaStuffed()
				   local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName() ~= nil
				end

				if pcall(IsTuggaStuffed) then

					local getBossBuffs = unitInCombat:GetBuffs().arBeneficial[1].splEffect:GetName()

					if getBossBuffs == "Devour Flesh" then

						local sToChat = "Stew-Shaman Tugga ate Devour Flesh during combat. The challenge is lost. Someone from this team can't interrupt at right time. Is that you, slacker?"
						self:AddFails()
						self:InformOthers(sToChat, true, false)
					end
				end
			end

			if unitInCombatName == "Forgemaster Trogun" then 
				if self.hlp.TrogunStacks > 0 then

					local sToChat = string.format("Forgemaster got %s stacks of Primal Rage. The challenge is lost.", self.hlp.TrogunStacks)
					self:AddFails()
					self:InformOthers(sToChat, true, false)
				end
			end

			if unitInCombatName == "Deadringer Shallaos" then

				local failsInfo = ""
				for i=1,5 do

					if self.hlp.player[i].name ~= "" then

						local additionalComma = ""
						if i > 1 then
							additionalComma = ","
						end

						local failWord = "stacks"
						if self.hlp.ShallaosStacks[i] == 1 then
							failWord = "stack"
						end

						if self.hlp.ShallaosStacks[i] > 5 then -- counts as fails when you reach more than 5 stacks, because 25 stacks is limit per a group
							local countedFails = self.hlp.ShallaosStacks[i]
							countedFails = countedFails - 5
							local oldFails = self.hlp.player[i].fails
							self.hlp.player[i].fails = oldFails + countedFails
						end

						failsInfo = string.format("%s%s %s (%s %s)", failsInfo, additionalComma, self.hlp.player[i].name, self.hlp.ShallaosStacks[i], failWord)
					end
				end

				local sToChat = string.format("Who is the best player here? %s", failsInfo)
				--self:Debug(sToChat)
				self:InformOthers(sToChat, true, false)

				--SendVarToRover("self", self)
			end
		

			-- boss leaving combat
			for bossName,bossState in pairs(self.hlp.boss) do
				if bossName == unitInCombatName then
					self.hlp.boss[bossName] = false
					self.hlp.alreadyFailedChallenge = false
					self:Debug(bossName .. " out of combat.")
				end
			end

		end
	end
end

function RIPgold:OnWorldChange()

	-- updated function: resets only info about match, not resetting everything every world change
	self.hlp.peMatch = nil
	self.hlp.isInDungeon = false
end


function RIPgold:OnCombatLogVitalModifier(tEventArgs)

	if self.hlp.isInDungeon then 

		local getCaster = tEventArgs.unitCaster:GetName()

		if getCaster == "Spiritmother Selene's Echo" then

			local SeleneHealth = tEventArgs.unitCaster:GetHealth()
			local SeleneMaxHealth = tEventArgs.unitCaster:GetMaxHealth()
			local SelenePercentage = SeleneHealth / SeleneMaxHealth
			self.hlp.SelenePercentage = SelenePercentage
		end

		if self.hlp.boss["Deadringer Shallaos"] then

			local getHarmfulBuffs = tEventArgs.unitTarget:GetBuffs().arHarmful
			if getHarmfulBuffs ~= nil then

				for i,buff in pairs(getHarmfulBuffs) do

					local getDebuffName = buff.splEffect:GetName()
					if getDebuffName ~= nil then

						if getDebuffName == "Resonance" then

							local getTarget = tEventArgs.unitTarget:GetName()
							--local sToChat = string.format("%s resonance stacks",getTarget)
							--SendVarToRover(sToChat, buff.nCount)
							local getGroupMaxSize = GroupLib.GetGroupMaxSize(); -- its 5 when in group, 0 when alone

							if getGroupMaxSize == 0 then
								self.hlp.ShallaosStacks[1] = buff.nCount
							else
								for nGroupIndex=1,getGroupMaxSize do

									local getGroupMember = GroupLib.GetGroupMember(nGroupIndex); 
									if getGroupMember ~= nil then

										local getGroupMemberName = getGroupMember.strCharacterName
										if getGroupMemberName == getTarget then
											-- workaround if, because you usually lose all stacks on death and it would give you 0
											if buff.nCount > self.hlp.ShallaosStacks[nGroupIndex] then
												self.hlp.ShallaosStacks[nGroupIndex] = buff.nCount
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end


		if self.hlp.boss["Mordechai Redmoon"] then

			function IsTerablinded()
			   local getBossBuffs = tEventArgs.unitTarget:GetBuffs().arHarmful[1].strTooltip ~= nil
			end

			if pcall(IsTerablinded) then

				if tEventArgs.unitTarget:GetBuffs().arHarmful[1].strTooltip == "Blinded!" then

					local getTarget = tEventArgs.unitTarget:GetName()
					local sToChat = string.format("%s was blinded. Mordechai Redmoon's challenge is lost. Remember to always look out to prevent this!", getTarget)

					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end
			end
		end

		if self.hlp.boss["Bosun Octog"] then

			function IsBosunBroken()
			   local getBossBuffs = tEventArgs.unitCaster:GetBuffs().arHarmful[1].strTooltip ~= nil
			end

			if pcall(IsBosunBroken) then

				local getBossBuffs = tEventArgs.unitCaster:GetBuffs()
				if getBossBuffs.arHarmful[1].strTooltip == "Broken Armor" then
					self.hlp.OctogStacks = getBossBuffs.arHarmful[1].nCount
				end
			end
		end

		if self.hlp.boss["Forgemaster Trogun"] then  

			function IsForgemasterBuffed()
			   local BossBuffs = tEventArgs.unitCaster:GetBuffs().arBeneficial[1].strTooltip ~= nil
			end

			if pcall(IsForgemasterBuffed) then

				local getBossBuffs = tEventArgs.unitCaster:GetBuffs()

				if getBossBuffs.arBeneficial[1].strTooltip == "Primal Rage" then
					self.hlp.TrogunStacks = getBossBuffs.arBeneficial[1].nCount
				end
			end
		end
	end --in dungeon
end

function RIPgold:OnUnitCreated(unit)

	local getUnitName = unit:GetName()

	-- Warning! Checking for "Thundercall Channeler unit has to be before checking for dungeons because it happens before entring the dungeon in function OnPublicEventStatsUpdate() 
	if getUnitName == "Thundercall Channeler" then 
		self:STL_getChannelerID(unit)
	end

	if self.hlp.isInDungeon then 

		if getUnitName == "Spiritmother Selene" then

			local SelenePercentage = self.hlp.SelenePercentage * 100

			if (100 > SelenePercentage and SelenePercentage > 0) then
					
				local SelenePercentageString = string.format("%.f %%", SelenePercentage);
				local sToChat = string.format("Spiritmother was at %s health. Challenge is lost. She has to be full at the end of battle.", SelenePercentageString)
				self:AddFails()
				self:InformOthers(sToChat, true, false)
			end
		end

		if self.hlp.boss["Blade-Wind the Invoker"] then
			if getUnitName == "Hostile Invisible Unit for Fields (0 hit radius)" then
				--SendVarToRover("unit created ".. GameLib.GetGameTime(), unit)
				self.hlp.WindInvokerInvisibleUnitID = unit:GetId()
				self:STL_getPlayerWithCircle(unit)
				self.hlp.doesChannelerExists:Start()
			end
		end
	end --in dungeon
end

function RIPgold:ALL_precheckForBossDeaths(unitInCombat)
	--if self.hlp.isInDungeon then 
		self.hlp.isBossDead.dead = false
		self.hlp.isBossDead.name = unitInCombat:GetName()
		self.hlp.isBossDead.ID = unitInCombat:GetId()
		self.hlp.isBossDead.timer:Start()
	--end
end

function RIPgold:ALL_checkForBossDeaths()
	--if self.hlp.isInDungeon then 

		function doesBossExist()
		   local isBossDead = GameLib.GetUnitById(self.hlp.isBossDead.ID):IsDead() ~= nil
		end

		if pcall(doesBossExist) then
			local isBossDead = GameLib.GetUnitById(self.hlp.isBossDead.ID):IsDead()
			if isBossDead then
				self.hlp.isBossDead.dead = true
				self.hlp.isBossDead.timer:Stop()

				if self.hlp.isBossDead.name == "Stormtalon" then
					self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Spiritmother Selene the Corrupted" then
					self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Mordechai Redmoon" then
					self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Forgemaster Trogun" then
					self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Wrathbone" then
					self:HowManyFails()
				end
				if self.hlp.isBossDead.name == "Blade-Wind the Invoker" then
					self.hlp.doesChannelerExists:Stop() --test if its working
				end
				if self.hlp.isBossDead.name == "Bosun Octog" then
					if self.hlp.OctogStacks < 10 then
						local sToChat = string.format("Bosun got %s from 10 stacks of Broken Armor. The challenge is lost.", self.hlp.OctogStacks)
						self:AddFails()
						self:InformOthers(sToChat, false, false)
					end
				end

				self:Debug(self.hlp.isBossDead.name .. " is dead.")
				--SendVarToRover("boss", self.hlp.isBossDead)
			end
		end
	--end
end

function RIPgold:STL_checkForChannelerDeaths()

	if self.hlp.isInDungeon then 
		for chanellerIndex=1,4 do

			function doesThundercallExist()
			   local getThundercallPosition = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerIndex]):IsDead() ~= nil
			end

			if pcall(doesThundercallExist) then
				local getThundercallPosition = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerIndex]):IsDead()
				if getThundercallPosition then
					self.hlp.WindInvokerChanellerID[chanellerIndex] = 0
				end
			end
		end
	end
end

function RIPgold:STL_getPlayerWithCircle(unit)
	
	local circlePosition = unit:GetPosition()

	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone
	if getGroupMaxSize == 0 then
		function GetPlayerName()
		   local getName = GameLib.GetPlayerUnit(1):GetName() ~= nil
		end

		if pcall(GetPlayerName) then
			local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
			local playerPosition = GameLib.GetPlayerUnit(1):GetPosition()

			self.hlp.WindInvokerTargetPlayer["name"] = getCurrentPlayerName
			self.hlp.WindInvokerTargetPlayer["x"] = playerPosition["x"]
			self.hlp.WindInvokerTargetPlayer["z"] = playerPosition["z"]
		end
	else
		for nGroupIndex=1,getGroupMaxSize do 
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

			if getGroupMember ~= nil then

				local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

				if getGroupMemberUnit ~= nil then
					local playerPosition = getGroupMemberUnit:GetPosition()

					local diff_x = math.abs(circlePosition["x"] - playerPosition["x"])
					local diff_z = math.abs(circlePosition["z"] - playerPosition["z"])
					local diffs = math.sqrt(math.pow(diff_x, 2) + math.pow(diff_z, 2))

					self.hlp.WindInvokerDiffs[nGroupIndex] = diffs
				end
			end
		end
	
		local isNearest = self.hlp.WindInvokerDiffs[1]
		local isNearestPlayer = 1

		for nGroupIndex=1,getGroupMaxSize do
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

			if getGroupMember ~= nil then
				local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

				if getGroupMemberUnit ~= nil then
					local getGroupMemberName = getGroupMember.strCharacterName

					if self.hlp.WindInvokerDiffs[nGroupIndex] < isNearest then
						isNearest = self.hlp.WindInvokerDiffs[nGroupIndex]
						isNearestPlayer = nGroupIndex
					end
				end
			end
		end

		self.hlp.WindInvokerTargetPlayer["name"] = GroupLib.GetGroupMember(isNearestPlayer).strCharacterName
		local targetedPlayerPosition = GroupLib.GetUnitForGroupMember(isNearestPlayer):GetPosition()
		self.hlp.WindInvokerTargetPlayer["x"] = targetedPlayerPosition["x"]
		self.hlp.WindInvokerTargetPlayer["z"] = targetedPlayerPosition["z"]
	end
end

function RIPgold:STL_getChannelerID(unit)

	--SendVarToRover("STL_getChannelerID " .. GameLib.GetGameTime(),unit)

	-- workaround for "feature" when sometimess channeler is first from all four chennelers and sometimes last from all which makes different ID ranges
	local ThundercallChannelerID = unit:GetId()
	local numberBasePosition = -4
	for actualPosition=1,7 do
		local numberPosition = numberBasePosition + actualPosition
		local testedID = ThundercallChannelerID + numberPosition
		local doesExist = GameLib.GetUnitById(testedID)

		if doesExist ~= nil then
			local doesHaveName = GameLib.GetUnitById(testedID):GetName()
			if doesHaveName == "Thundercall Channeler" then
				local numberID = math.abs(numberPosition) + 1
				self.hlp.WindInvokerChanellerID[numberID] = testedID
			end
		end
	end
end

function RIPgold:STL_getCircleDistances(unit)

	local shortestDistance = 999
	for n=1,4 do
		local actualDistance = self:STL_getCircleDistance(unit, n)

		if actualDistance ~= nil then
			if actualDistance < shortestDistance then
				shortestDistance = actualDistance
			end
		end
	end

	if shortestDistance ~= 999 then 

		-- workaround with gametime to prevent "feature" when circle occurs two times at the same time
		local actualGametime = GameLib.GetGameTime()
		if self.hlp.WindInvokerLastGametime ~= actualGametime then

			local channelerRadius = 7.89 -- the best constant I've found after numbers of tries, still only guess, not real constant
			if shortestDistance > channelerRadius then
				local missedDistance = shortestDistance - channelerRadius
				missedDistance = Apollo.FormatNumber(missedDistance, 2, true)
				local sToChat = string.format("%s missed placing AOE by %s m.", self.hlp.WindInvokerTargetPlayer["name"], missedDistance)
				self:Debug(sToChat)
				self:InformOthers(sToChat, true, false)
				self:CountFails(self.hlp.WindInvokerTargetPlayer["name"])
			end
		end
		self.hlp.WindInvokerLastGametime = actualGametime

	end

end

function RIPgold:STL_getCircleDistance(unit, chanellerID)

	function doesThundercallExist()
	   local getBossBuffs = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerID]):GetPosition() ~= nil
	end

	if pcall(doesThundercallExist) then

		local circlePosition = unit:GetPosition()
		local channelerPosition = GameLib.GetUnitById(self.hlp.WindInvokerChanellerID[chanellerID]):GetPosition()

		local diff_x = math.abs(circlePosition["x"] - channelerPosition["x"])
		local diff_z = math.abs(circlePosition["z"] - channelerPosition["z"])
		local diffs = math.sqrt(math.pow(diff_x, 2) + math.pow(diff_z, 2))

		return diffs
	end
end

function RIPgold:OnUnitDestroyed(unit)

	if self.hlp.isInDungeon then

		local getUnitName = unit:GetName()

		if self.hlp.boss["Blade-Wind the Invoker"] then
			if getUnitName == "Hostile Invisible Unit for Fields (0 hit radius)" then
				local unitID = unit:GetId()
				--SendVarToRover("invisible unit".. GameLib.GetGameTime(), self.hlp.WindInvokerInvisibleUnitID)
				--SendVarToRover("unit destroyed ".. GameLib.GetGameTime(), unit)
				--SendVarToRover("Channelers exist.", self.hlp.WindInvokerChanellerID[1] .. " " .. self.hlp.WindInvokerChanellerID[2] .. " " .. self.hlp.WindInvokerChanellerID[3] .. " " .. self.hlp.WindInvokerChanellerID[4])

				if unitID == self.hlp.WindInvokerInvisibleUnitID then
					self:STL_getCircleDistances(unit)
				end
			end
		end
	end
end

function RIPgold:OnCombatLogDamage(tEventArgs)

	if self.hlp.isInDungeon then 

		local validTarget = tEventArgs.unitTarget ~= nil
		local validCaster = tEventArgs.unitCaster ~= nil
		local validSpell = tEventArgs.splCallingSpell:GetName() ~= nil
		if validTarget and validCaster and validSpell then

			local getCaster = tEventArgs.unitCaster:GetName()
			local getTarget = tEventArgs.unitTarget:GetName()
			local getSpell = tEventArgs.splCallingSpell:GetName()

			if tEventArgs.unitTarget:IsInYourGroup() or tEventArgs.unitTarget:IsThePlayer() then -- if target is in your party

				local getSpell = tEventArgs.splCallingSpell:GetName()
				local getCaster = tEventArgs.unitCaster:GetName()
				local getTarget = tEventArgs.unitTarget:GetName()

				--- Skullcano

				if getSpell == "Seismic Tremor" and getCaster == "Thunderfoot" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Is really that hard to jump?", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end

				if getSpell == "Dark Fireball" and getCaster == "Laveka the Dark-Hearted" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, just evade small circular AOE, you are not that bad, are you?", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end

				--- Stormtalon's Lair

				if getCaster == "Blade-Wind the Invoker" then

					-- workaround, no clue why Invoker is exception from global boss incombat function, but it shouldnt fuck up with other things as well as it will be set false after he dies (which works)
					self.hlp.boss["Blade-Wind the Invoker"] = true

				end

				if getSpell == "Twister" and getCaster == "Aethros Twister" then

					local sToChat = string.format("%s was hit by %s. Aethros's challenge is lost. What's so problematic at dancing between tornados?", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)
				end

				if getSpell == "Lightning Strike" and getCaster == "Stormtalon" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Remember! Run around after moo and don't stay in the middle of moving telegraph.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end

				--- Sanctuary of the Swordmaiden

				if getCaster == "Deadringer Shallaos" then

					-- workaround, no clue why Shallaos is exception from global boss incombat function, but it shouldnt fuck up with other things as well as it will be set false after she dies (which works)
					self.hlp.boss["Deadringer Shallaos"] = true

				end

				if getSpell == "Righteous Fire" and getCaster == "Torine Totem of Flame" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end

				if getSpell == "Molten Wave" and getCaster == "Rayna Darkspeaker" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. You are bad at dancing between fire walls.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end

				if getSpell == "Plague Splatter" and getCaster == "Ondu Lifeweaver" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. You have to be blind to miss telegraph that big.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end

				if getSpell == "Corruption Pustule" and getCaster == "Moldwood Swarmling" then

					local sToChat = string.format("%s was hit by %s. Vitara's heart challenge is lost. If you can't run, kill him in less than 60s.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end

				if getTarget == "Spiritmother Selene's Echo" then

					local SeleneHealth = tEventArgs.unitTarget:GetHealth()
					local SeleneMaxHealth = tEventArgs.unitTarget:GetMaxHealth()
					local SelenePercentage = SeleneHealth / SeleneMaxHealth

					self.hlp.SelenePercentage = SelenePercentage
					self:Debug(string.format("%3.0f", SelenePercentage))

				end

				--- Ruins of the Kel Voreth

				if self.hlp.boss["Grond the Corpsemaker"] then

					if getSpell == "Bone Clamp" and getCaster == "Bone Cage" then

						local sToChat = string.format("%s felt into %s. Grond the Corpsemaker's challenge is lost. Can't you just look under your feet?", getTarget, getSpell, getCaster)
						self:CountFails(getTarget)
						self:InformOthers(sToChat, true, false)

					end

				end

				if getSpell == "Homing Barrage" and getCaster == "Slavemaster Drokk" then

					local sToChat = string.format("%s was hit by %s. %s's challenge is lost. Come on, that AOE is smaller than Korean dick... How did you caught it?", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end

				if getSpell == "Phase Blast" and getCaster == "Eldan Phase Blaster" then

					local sToChat = string.format("%s was hit by %s. And obviously challenge is lost. Yeah, so you wanna get vaporized... And wanna fuck the most easiest challenge. Well done. Well done.", getTarget, getSpell, getCaster)
					self:CountFails(getTarget)
					self:InformOthers(sToChat, true, false)

				end
			end
		end
	end -- in dungeon
end

function RIPgold:InformOthers(sToChat, setFailedChallenge, overrideGlobalVar)

	if not overrideGlobalVar then
		if not self.hlp.alreadyFailedChallenge then

			self:SendToChat(sToChat)

			if setFailedChallenge then
				self.hlp.alreadyFailedChallenge = true
			else
				self.hlp.alreadyFailedChallenge = false
			end
		end
	else
		self:SendToChat(sToChat)

		if setFailedChallenge then
			self.hlp.alreadyFailedChallenge = true
		end
	end
end

function RIPgold:SendToChat(fnString)
	if GroupLib.InInstance() then
		ChatSystemLib.Command("/i "..fnString)
	elseif GroupLib.InGroup() then
		ChatSystemLib.Command("/p "..fnString)
		--self:Debug(fnString)
	else
		self:Debug(fnString)
	end
end

function RIPgold:PlaySound(sound)
	if self.set.sound then
		Sound.Play(sound)
	end
end

function RIPgold:Debug(fnString)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, fnString, "RIPgold")
end

function RIPgold:CountFails(getTarget)

	-- sounds when player fails
	local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
	if getTarget == getCurrentPlayerName then
		self:PlaySound(self.set.soundType)
	end

	-- counting fails
	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone

	if getGroupMaxSize == 0 then

		local getFailsOld = self.hlp.player[1].fails
		self.hlp.player[1].fails = getFailsOld + 1
	else
		for nGroupIndex=1,getGroupMaxSize do 

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getGroupMemberName = getGroupMember.strCharacterName
				if getGroupMemberName == getTarget then

					local getFailsOld = self.hlp.player[nGroupIndex].fails
					self.hlp.player[nGroupIndex].fails = getFailsOld + 1
				end
			end
		end
	end
end

function RIPgold:AddFails()
	local getGroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone

	if getGroupMaxSize == 0 then

		local getFailsOld = self.hlp.player[1].fails
		self.hlp.player[1].fails = getFailsOld + 1
	else
		for nGroupIndex=1,getGroupMaxSize do

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getFailsOld = self.hlp.player[nGroupIndex].fails
				self.hlp.player[nGroupIndex].fails = getFailsOld + 1
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- RIPgoldForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function RIPgold:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function RIPgold:OnCancel()
	self.wndMain:Close() -- hide the window
	self.updateStatsUI:Stop()
end

-- when top buttons (cards) are clicked
function RIPgold:OnBTN_statsClick()
	self.wndMain:FindChild("WIN_stats"):Show(true)
	self.wndMain:FindChild("WIN_custom"):Show(false)
	self.wndMain:FindChild("WIN_settings"):Show(false)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("ef000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("99000000")

	self.wndMain:FindChild("WRAP_FAILS"):ArrangeChildrenVert(1)
end

function RIPgold:OnBTN_customClick()
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_custom"):Show(true)
	self.wndMain:FindChild("WIN_settings"):Show(false)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("ef000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("99000000")

	self.wndMain:FindChild("WIN_custom"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_ALL"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_STL"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_KV"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_SC"):ArrangeChildrenVert(1)
	self.wndMain:FindChild("WRAP_SSM"):ArrangeChildrenVert(1)
end

function RIPgold:OnBTN_settingsClick()
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_custom"):Show(false)
	self.wndMain:FindChild("WIN_settings"):Show(true)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("ef000000")

	self.wndMain:FindChild("SET_sound"):SetCheck(self.set.sound)
end

function RIPgold:OnBTN_SET_SoundClick(wndControl)
	self.set.sound = wndControl:IsChecked()
	self:PlaySound(self.set.soundType)
end

-----------------------------------------------------------------------------------------------
-- RIPgold Instance
-----------------------------------------------------------------------------------------------
local RIPgoldInst = RIPgold:new()
RIPgoldInst:Init()
