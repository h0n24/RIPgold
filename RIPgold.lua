-----------------------------------------------------------------------------------------------
-- Client Lua Script for RIPgold
-- Copyright (c) NCsoft. All rights reserved
--
-- Made by Aki @Jabbit, feel free to report bugs at https://github.com/h0n24/RIPgold
-----------------------------------------------------------------------------------------------

-- todo: iccom: at making group, share&update player's rating, number of dungeons, ilvl and heroism
-- todo: make announcing more simpler → include repeating announcing to normal announcing + turn of in settings
-- todo: use custom messages from settings
-- todo: disband doesnt grants rating to players, same for leaver

-- things to ask Zod: do i need to use pcalls like i do? can it be done better way?
-- things to ask Zod: can "REDIRECT_nameoftimer" be done better?
-- things to ask Zod: how to solve group join and group leave efficiently?
-- things to ask Zod: do i need to transfer self variable when comunicating with modules like i do? example: KV:OnPublicEventStatsUpdate(self)
-- things to ask Zod: how can i call other modules from other modules and is it better performance than current "workaround"
-- things to ask Zod: how effectively include calling reQue addon after group gets full or after boss in dungeon gets killed (momentarily done with /rq command)

require "Apollo"
require "Window"
require "GroupLib"
require "GameLib"
 
-----------------------------------------------------------------------------------------------
-- RIPgold Module Definition
-----------------------------------------------------------------------------------------------
local RIPgold = {}

-- modules for specific dungeons
local ALL = Apollo.GetPackage("Module:ALL-1.0").tPackage
local PA = Apollo.GetPackage("Module:PA-1.0").tPackage
local STL = Apollo.GetPackage("Module:STL-1.0").tPackage
local KV = Apollo.GetPackage("Module:KV-1.0").tPackage
local SC = Apollo.GetPackage("Module:SC-1.0").tPackage
local SSM = Apollo.GetPackage("Module:SSM-1.0").tPackage

-- modules for UI
local UIn = Apollo.GetPackage("Module:UIn-1.0").tPackage
local UIr = Apollo.GetPackage("Module:UIr-1.0").tPackage
local UIc = Apollo.GetPackage("Module:UIc-1.0").tPackage
local UIs = Apollo.GetPackage("Module:UIs-1.0").tPackage

 
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
    self.tSavedVariables = {}
	self.hlp = {} -- all helpers
	self.set = {} -- all settings
	self.rat = {} -- all ratings

	-- initialize core variables here (wont be saved, performance related)
	self.get = {}
	self.get.GroupMaxSize = GroupLib.GetGroupMaxSize() -- its 5 when in group, 0 when alone and 20 when in raid
    return o
end

function RIPgold:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = { -- to be honest i have no clue how this is supposed to work (using Apollo.GetPackage instead)
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- RIPgold OnLoad
-----------------------------------------------------------------------------------------------
function RIPgold:OnLoad()
    -- loading form file → on a mission of keeping it as smaler possible, cuz overwhelmed UI can slow down interface (example Carabine Addon WelcomeWindow or ChatLog)
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
		
		-- Register handlers for events, slash commands and timer, etc.
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded",  "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("ToggleRIPgoldUI", "OnRIPgoldOn", self)

		-- slash commands
		Apollo.RegisterSlashCommand("rip", "OnRIPgoldOn", self)

		-- core event handlers
		Apollo.RegisterEventHandler("UnitEnteredCombat", "OnCombat", self)
		Apollo.RegisterEventHandler("CombatLogDamage", "OnCombatLogDamage", self)
		Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
		Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)
		Apollo.RegisterEventHandler("CombatLogVitalModifier", "OnCombatLogVitalModifier", self)
		Apollo.RegisterEventHandler("PublicEventStart",	"OnPublicEventStart", self)
		Apollo.RegisterEventHandler("PublicEventStatsUpdate", "OnPublicEventStatsUpdate", self)
		Apollo.RegisterEventHandler("ChangeWorld", "OnWorldChange", self)

		-- Group related handlers, currently in testing → todo: simplify to most effective group management
		Apollo.RegisterEventHandler("Group_Join", "OnGroup_Join", self)
		Apollo.RegisterEventHandler("Group_Left", "OnGroup_Left", self)
		Apollo.RegisterEventHandler("Group_Player_Left", "OnGroup_Player_Left", self)
		Apollo.RegisterEventHandler("Group_Disbanded", "OnGroup_Disbanded", self)
		Apollo.RegisterEventHandler("Group_Add", "OnGroup_Add", self)
		Apollo.RegisterEventHandler("Group_Changed", "OnGroup_Changed", self)
		Apollo.RegisterEventHandler("Group_Other_Left", "OnGroup_Other_Left", self)
		Apollo.RegisterEventHandler("Group_Updated", "OnGroup_Updated", self)
		Apollo.RegisterEventHandler("Group_Remove", "OnGroup_Remove", self)

		-- ApolloTimer variables → first says in seconds how often is repeated, second if its repeating
		self.checkDeadState = ApolloTimer.Create(1, true, "REDIR_checkForPlayerDeaths", self) 
		self.checkDeadState:Stop()

		self.hlp.isBossDead = {}
		self.hlp.isBossDead.timer = ApolloTimer.Create(1, true, "REDIR_checkForBossDeaths", self)
		self.hlp.isBossDead.timer:Stop()
		self.hlp.isBossDead.ID = 0
		self.hlp.isBossDead.name = ""
		self.hlp.isBossDead.dead = false

		self.hlp.doesChannelerExists = ApolloTimer.Create(1, true, "REDIR_checkForChannelerDeaths", self)
		self.hlp.doesChannelerExists:Stop()

		self.hlp.isChannelerChallengeActive = ApolloTimer.Create(0.2, false, "REDIR_checkForChannelerChallengeActive", self)
		self.hlp.isChannelerChallengeActive:Stop()

		-- connects this file with ALL and SSM (can it be done better?)
		self.hlp.doesRelicBloodExist = ApolloTimer.Create(30, false, "REDIR_checkForRelicOfBlood", self)
		self.hlp.doesRelicBloodExist:Stop()

		if self.dataRestored == nil then -- gonna be processed only if something happened to previous saved file

			self.hlp.peMatch = nil
			self.hlp.isInDungeon = false
			self.hlp.updateStatsUI = false

			ALL:InitializeVars(self)

			if not GroupLib.InRaid() then
				ALL:PreparePlayers(self)
			end

			self.set.sound = true
			-- additional sounds (future reference): Sound.PlayUIQueuePopsAdventure
			-- additional sounds (future reference): Sound.PlayUI47CancelVirtual
			self.set.soundType = Sound.PlayUI11To13GenericPushButtonDigital02
		end

		if self.rat == nil then
			local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
			self.rat[getCurrentPlayerName] = {}
			self.rat[getCurrentPlayerName]["fails"] = 0
			self.rat[getCurrentPlayerName]["rating"] = 1000
			self.rat[getCurrentPlayerName]["dungs"] = 0
			self.rat[getCurrentPlayerName]["ilvl"] = 0
			self.rat[getCurrentPlayerName]["hero"] = 0
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Trivial Functions
-----------------------------------------------------------------------------------------------

function RIPgold:addToSet(set, key) -- not being used, future reference
    set[key] = true
end

function RIPgold:removeFromSet(set, key)
    set[key] = nil
end

function RIPgold:setContains(set, key)
    return set[key] ~= nil
end

function RIPgold:PlaySound(sound)
	if self.set.sound then
		Sound.Play(sound)
	end
end

function RIPgold:Debug(fnString)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, fnString, "RIPgold")
end

function RIPgold:Rover(testedVar, addTimeStamp, addSpecialVar)
	if SendVarToRover then

		local testedVarName = ""

		if testedVar == nil then
			testedVarName = ""
		else
			testedVarName = string.format("%s",testedVar)
		end

		if addTimeStamp == nil or addTimeStamp == false then
			addTimeStamp = ""
		else
			addTimeStamp = GameLib.GetGameTime()
		end

		if addSpecialVar == nil or addSpecialVar == false then
			addSpecialVar = ""
		end

		local message = string.format("%s %s %s",testedVarName,addSpecialVar,addTimeStamp)

		SendVarToRover(message, testedVar)
	end
end


-----------------------------------------------------------------------------------------------
-- Event Handlers
-----------------------------------------------------------------------------------------------

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

			--self:Rover(peCurrent, false, "Dungeon event")

			if peCurrent:ShouldShowMedalsUI() then
				-- processed after and only entering new dungeon -> reseting points etc
				self:Debug("Everything reseted.")

				self.hlp.isInDungeon = true

				ALL:InitializeVars(self)
				ALL:PreparePlayers(self)

				self.checkDeadState:Start()
				self.hlp.peMatch = true

				UIn:OnBTN_statsClick(self)

				return true
			end
		end
	end
end

function RIPgold:OnPublicEventStatsUpdate(peUpdated)
	if self.hlp.isInDungeon then --if in dungeon

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

			-- code connected with event points
			--self:Rover(peUpdated, true, "OnPublicEventStatsUpdate")
		end

		function IsPeObjectives()
		   local getPeObjectives = peUpdated:GetObjectives() ~= nil
		end

		if pcall(IsPeObjectives) then

			-- technically all event points
			local objectives = peUpdated:GetObjectives()

			for i,obj in pairs(objectives) do

				if obj:GetCategory() == 3 then -- only works for gold medal conected achievements
					eventName = obj:GetShortDescription()
					eventStatus = obj:GetStatus()

					self.hlp.event[eventName] = eventStatus
				end

				-- specifically for collecting torine relics
				if obj:GetShortDescription() == "Collect Torine Spirit-Relics" then
					self.hlp.TorineRelicsCount = obj:GetCount()
				end
			end

			PA:OnPublicEventStatsUpdate(self)
			STL:OnPublicEventStatsUpdate(self)
			KV:OnPublicEventStatsUpdate(self)
			SC:OnPublicEventStatsUpdate(self)
			SSM:OnPublicEventStatsUpdate(self)
		end
	end --if in dungeon
end

function RIPgold:OnWorldChange()

	-- updated function: resets only info about match, not resetting everything every world change
	self.hlp.peMatch = nil
	self.hlp.isInDungeon = false

	UIn:OnBTN_statsClick(self)
end

function RIPgold:OnCombat(unitInCombat, bInCombat)
	if self.hlp.isInDungeon then 
		local unitInCombatName = unitInCombat:GetName()

		if bInCombat then
			for bossName,bossState in pairs(self.hlp.boss) do
				if bossName == unitInCombatName then
					self.hlp.boss[bossName] = true
					-- info about fails at the end of the dungeon -> starts timer when these names occurs
					ALL:precheckForBossDeaths(self, unitInCombat)
					self:Rover(bossName, false, "alive.")
				end
			end
			PA:OnCombat_IN(self, unitInCombat)
			STL:OnCombat_IN(self, unitInCombat)
			KV:OnCombat_IN(self, unitInCombat)
			SC:OnCombat_IN(self, unitInCombat)
			SSM:OnCombat_IN(self, unitInCombat)
		end

		-- proceeds on leaving combat
		if not bInCombat then
			PA:OnCombat_OUT(self, unitInCombat)
			STL:OnCombat_OUT(self, unitInCombat)
			KV:OnCombat_OUT(self, unitInCombat)
			SC:OnCombat_OUT(self, unitInCombat)
			SSM:OnCombat_OUT(self, unitInCombat)

			-- boss leaving combat
			for bossName,bossState in pairs(self.hlp.boss) do
				if bossName == unitInCombatName then
					self.hlp.boss[bossName] = false
					self.hlp.alreadyFailedChallenge = false
					self:Rover(bossName, false, "out of combat.")
				end
			end
		end
	end
end

function RIPgold:OnCombatLogVitalModifier(tEventArgs)
	if self.hlp.isInDungeon then
		PA:OnCombatLogVitalModifier(self, tEventArgs)
		STL:OnCombatLogVitalModifier(self, tEventArgs)
		KV:OnCombatLogVitalModifier(self, tEventArgs)
		SC:OnCombatLogVitalModifier(self, tEventArgs)
		SSM:OnCombatLogVitalModifier(self, tEventArgs)
	end
end

function RIPgold:OnUnitCreated(unit)
	-- WARNING! Has to be outside hlp.isInDungeon because isInDungeon is set in OnPublicEventStart which happens after Units are created and so variables with these units would be overriden
	STL:OnUnitCreatedBeforeEnteringDungeon(self, unit)
	PA:OnUnitCreatedBeforeEnteringDungeon(self, unit)

	if self.hlp.isInDungeon then
		PA:OnUnitCreated(self, unit)
		STL:OnUnitCreated(self, unit)
		KV:OnUnitCreated(self, unit)
		SC:OnUnitCreated(self, unit)
		SSM:OnUnitCreated(self, unit)
	end
end

function RIPgold:OnUnitDestroyed(unit)
	if self.hlp.isInDungeon then
		PA:OnUnitDestroyed(self, unit)
		STL:OnUnitDestroyed(self, unit)
		KV:OnUnitDestroyed(self, unit)
		SC:OnUnitDestroyed(self, unit)
		SSM:OnUnitDestroyed(self, unit)
	end
end

function RIPgold:OnCombatLogDamage(tEventArgs)

	if self.hlp.isInDungeon then 

		local validTarget = tEventArgs.unitTarget ~= nil
		local validCaster = tEventArgs.unitCaster ~= nil
		local validSpell = tEventArgs.splCallingSpell:GetName() ~= nil
		if validTarget and validCaster and validSpell then

			if tEventArgs.unitTarget:IsInYourGroup() or tEventArgs.unitTarget:IsThePlayer() then -- if target is in your party

				PA:OnCombatLogDamage(self, tEventArgs)
				STL:OnCombatLogDamage(self, tEventArgs)
				KV:OnCombatLogDamage(self, tEventArgs)
				SC:OnCombatLogDamage(self, tEventArgs)
				SSM:OnCombatLogDamage(self, tEventArgs)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Group-related event handlers, mostly testing purposes → will be simplified
-----------------------------------------------------------------------------------------------

function RIPgold:OnGroup_Join(var)
	self:Rover(var, true, "OnGroup_Join")

	if self.hlp.isInDungeon == false then
		UIn:OnBTN_statsClick(self)
	end
end

function RIPgold:OnGroup_Left(var)
	self:Rover(var, true, "OnGroup_Left")

	if self.hlp.isInDungeon == false then
		UIn:OnBTN_statsClick(self)
	end

	-- somehow not working 100% but why? would help af
	-- better version -> OnGroup_Remove
end

function RIPgold:OnGroup_Remove(var)
	self:Rover(var, true, "OnGroup_Remove")

	if self.hlp.isInDungeon == false then
		UIn:OnBTN_statsClick(self)
	end
	-- seems to be working everytime someone leaves party -> best function whatsoever

end

function RIPgold:OnGroup_Player_Left(var)
	self:Rover(var, true, "OnGroup_Player_Left")

	if self.hlp.isInDungeon == false then
		UIn:OnBTN_statsClick(self)
	end
end

function RIPgold:OnGroup_Other_Left(var)
	self:Rover(var, true, "OnGroup_Other_Left")

	if self.hlp.isInDungeon == false then
		UIn:OnBTN_statsClick(self)
	end
end

function RIPgold:OnGroup_Disbanded(var)
	self:Rover(var, true, "OnGroup_Disbanded")

	if self.hlp.isInDungeon == false then
		UIn:OnBTN_statsClick(self)
	end
end

function RIPgold:OnGroup_Add(var)
	self:Rover(var, true, "OnGroup_Add")

	if self.hlp.isInDungeon == false then
		UIn:OnBTN_statsClick(self)
	end
end

function RIPgold:OnGroup_Changed(var)
	self:Rover(var, true, "OnGroup_Changed")

	if self.hlp.isInDungeon == false then
		UIn:OnBTN_statsClick(self)
	end
end

function RIPgold:OnGroup_Updated(var)
	-- cycles virtually every sec which is meh event

	--self:Rover(var, true, "OnGroup_Updated")
	--UIn:OnBTN_statsClick(self)
end

-----------------------------------------------------------------------------------------------
-- Core Functions
-----------------------------------------------------------------------------------------------

function RIPgold:InformOthers(sToChat, setFailedChallenge, overrideGlobalVar)

	if overrideGlobalVar == false then
		if not self.hlp.alreadyFailedChallenge then

			self:SendToChat(sToChat)

			if setFailedChallenge then
				self.hlp.alreadyFailedChallenge = true
			else
				self.hlp.alreadyFailedChallenge = false
			end
		end
	end		
	if overrideGlobalVar == true then
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
	else
		ChatSystemLib.Command("/s "..fnString)
	end
end

function RIPgold:UpdateUIAlert(fails, tooltip) --icon alert base function
	Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", "RIPgold", {true, tooltip, fails})
end

function RIPgold:UpdateUIAlertForced() --updates icon alert

	local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
	for i=1,5 do
		if getCurrentPlayerName == self.hlp.player[i].name then
			if self.hlp.player[i].fails > 0 then
				self:UpdateUIAlert(self.hlp.player[i].fails, self.hlp.player[i].tooltip)
			end
		end 
	end
end

function RIPgold:CountFails(getTarget)
	-- variables
	local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()

	-- sounds when player fails
	if getTarget == getCurrentPlayerName then
		self:PlaySound(self.set.soundType)
	end

	-- counting fails
	if self.get.GroupMaxSize == 0 then

		local getFailsOld = self.hlp.player[1].fails
		self.hlp.player[1].fails = getFailsOld + 1

		self:UpdateUIAlert(self.hlp.player[1].fails, self.hlp.player[1].tooltip)
	else
		for nGroupIndex=1,self.get.GroupMaxSize do 

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getGroupMemberName = getGroupMember.strCharacterName
				if getGroupMemberName == getTarget then

					local getFailsOld = self.hlp.player[nGroupIndex].fails
					self.hlp.player[nGroupIndex].fails = getFailsOld + 1

					if getCurrentPlayerName == self.hlp.player[nGroupIndex].name then
						self:UpdateUIAlert(self.hlp.player[nGroupIndex].fails, self.hlp.player[nGroupIndex].tooltip)
					end					
				end
			end
		end
	end

	-- update UI if the window is opened
	if self.hlp.updateStatsUI then
		UIn:UpdateRIPgoldStats(self)
	end
end

function RIPgold:AddFails()

	if self.get.GroupMaxSize == 0 then

		local getFailsOld = self.hlp.player[1].fails
		self.hlp.player[1].fails = getFailsOld + 1

		self:UpdateUIAlert(self.hlp.player[1].fails, self.hlp.player[1].tooltip)
	else
		for nGroupIndex=1,self.get.GroupMaxSize do

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getFailsOld = self.hlp.player[nGroupIndex].fails
				self.hlp.player[nGroupIndex].fails = getFailsOld + 1

				if GameLib.GetPlayerUnit(1):GetName() == self.hlp.player[nGroupIndex].name then
					self:UpdateUIAlert(self.hlp.player[nGroupIndex].fails, self.hlp.player[nGroupIndex].tooltip)
				end
			end
		end
	end

	-- update UI if the window is opened
	if self.hlp.updateStatsUI then
		UIn:UpdateRIPgoldStats(self)
	end	
end

function RIPgold:AddTooltip(getTarget, getMessage)

	if self.get.GroupMaxSize == 0 then

		local getTooltipOld = self.hlp.player[1].tooltip
		self.hlp.player[1].tooltip = getTooltipOld .. getMessage .. "\n"
	else
		for nGroupIndex=1,self.get.GroupMaxSize do 

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getGroupMemberName = getGroupMember.strCharacterName
				if getGroupMemberName == getTarget then

					local getTooltipOld = self.hlp.player[nGroupIndex].tooltip
					self.hlp.player[nGroupIndex].tooltip = getTooltipOld .. getMessage .. " \n"
				end
			end
		end
	end
end

function RIPgold:AddTooltips(getMessage)

	if self.get.GroupMaxSize == 0 then

		local getTooltipOld = self.hlp.player[1].tooltip
		self.hlp.player[1].tooltip = getTooltipOld .. getMessage .. "\n"
	else
		for nGroupIndex=1,self.get.GroupMaxSize do

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then

				local getTooltipOld = self.hlp.player[nGroupIndex].tooltip
				self.hlp.player[nGroupIndex].tooltip = getTooltipOld .. getMessage .. " \n"
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Timers redirect, because I have no clue how to transfer self variable in timers, RIPcoding
-----------------------------------------------------------------------------------------------

function RIPgold:REDIR_ALL_HowManyFails() -- workaround: because Apollo's lua is out of my understanding 
	ALL:HowManyFails(self)
end

function RIPgold:REDIR_checkForBossDeaths()
	ALL:checkForBossDeaths(self)
end

function RIPgold:REDIR_checkForPlayerDeaths()
	ALL:CheckForPlayerDeaths(self)
end

function RIPgold:REDIR_checkForChannelerDeaths()
	STL:checkForChannelerDeaths(self)
end

function RIPgold:REDIR_checkForChannelerChallengeActive()
	STL:checkForChannelerChallengeActive(self)
end

function RIPgold:REDIR_checkForRelicOfBlood()
	SSM:checkForRelicOfBlood(self)
end

-----------------------------------------------------------------------------------------------
-- UI Functions (RIPgoldForm Functions)
-----------------------------------------------------------------------------------------------

-- icon for interface menu
function RIPgold:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "RIPgold", {"ToggleRIPgoldUI", "", "IconSprites:Icon_Mission_Scientist_ScanMineral"})
	self:UpdateUIAlertForced()
end

-- on SlashCommand "/rip"
function RIPgold:OnRIPgoldOn()

	self.hlp.updateStatsUI = true --prevents window updating when its closed (false)
	UIn:UpdateRIPgoldStats(self)
	self:OnBTN_statsClick()

	self.wndMain:Invoke() -- show the window
end

-- when the Cancel button is clicked
function RIPgold:OnCancel()
	self.wndMain:Close() -- hide the window
	self.hlp.updateStatsUI = false --prevents window updating when its closed (false)
end

-- card menu, top menu buttons click
function RIPgold:OnBTN_statsClick()
	UIn:OnBTN_statsClick(self)
end

function RIPgold:OnBTN_ratingsClick()
	UIr:OnBTN_ratingsClick(self)
end

function RIPgold:OnBTN_customClick()
	UIc:OnBTN_customClick(self)
end

function RIPgold:OnBTN_settingsClick()
	UIs:OnBTN_settingsClick(self)
end

----[ card: settings ]------------------------------------------------------------
function RIPgold:OnBTN_SET_SoundClick(wndControl)
	UIs:OnBTN_SET_SoundClick(self, wndControl)
end

----[ card: group ]---------------------------------------------------------------

function RIPgold:onBOX_announceChange(wndControl)
	UIn:onBOX_announceChange(self, wndControl)
end

function RIPgold:onBOX_announceEscape()
	UIn:UpdateAnnounceOnEscape(self)
end

function RIPgold:onCOMB_roleClick()
	UIn:onCOMB_roleClick(self)
end

function RIPgold:onBTN_announceClick()
	UIn:onBTN_announceClick(self)
end

-- checkboxes
function RIPgold:CHCK_PLZ_dpsClick()
	UIn:CHCK_PLZ_dpsClick(self)
end

function RIPgold:CHCK_PLZ_healClick()
	UIn:CHCK_PLZ_healClick(self)
end

function RIPgold:CHCK_PLZ_tankClick()
	UIn:CHCK_PLZ_tankClick(self)
end

-- whispers
function RIPgold:BTN_PL_whisper_1Click()
	ChatSystemLib.Command("/w "..self.hlp.player[1].name.." "..self.hlp.player[1].tooltip)
end

function RIPgold:BTN_PL_whisper_2Click()
	ChatSystemLib.Command("/w "..self.hlp.player[2].name.." "..self.hlp.player[2].tooltip)
end

function RIPgold:BTN_PL_whisper_3Click()
	ChatSystemLib.Command("/w "..self.hlp.player[3].name.." "..self.hlp.player[3].tooltip)
end

function RIPgold:BTN_PL_whisper_4Click()
	ChatSystemLib.Command("/w "..self.hlp.player[4].name.." "..self.hlp.player[4].tooltip)
end

function RIPgold:BTN_PL_whisper_5Click()
	ChatSystemLib.Command("/w "..self.hlp.player[5].name.." "..self.hlp.player[5].tooltip)
end


-----------------------------------------------------------------------------------------------
-- Save and Restore Data
-----------------------------------------------------------------------------------------------
function RIPgold:OnSave(eLevel)
	local tData = {}
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then -- This addon uses account level saves
		tData.hlp = {} -- helpers & variables
		for name,data in pairs(self.hlp) do
			tData.hlp[name] = data
		end
		tData.set = {} -- settings related
		for name,data in pairs(self.set) do
			tData.set[name] = data
		end
		tData.rat = {} -- rating related
		for name,data in pairs(self.rat) do
			tData.rat[name] = data
		end
	end
	
	return tData
end

function RIPgold:OnRestore(eLevel, tData)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then -- This addon uses account level saves
		for name,data in pairs(tData.hlp) do -- helpers & variables
			self.hlp[name] = data
		end
		for name,data in pairs(tData.set) do -- settings related
			self.set[name] = data
		end
		for name,data in pairs(tData.rat) do -- rating related
			self.rat[name] = data
		end
		self.dataRestored = true --used in setting variables
	end
end

-----------------------------------------------------------------------------------------------
-- RIPgold Instance
-----------------------------------------------------------------------------------------------
local RIPgoldInst = RIPgold:new()
RIPgoldInst:Init()
