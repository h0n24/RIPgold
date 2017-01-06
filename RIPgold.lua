-----------------------------------------------------------------------------------------------
-- Client Lua Script for RIPgold
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

-- todo (no clue how to): check if mordechai is being blinded
-- todo (no clue how to): last boss in ssm
-- todo: SSM: reminder after 15s that you forgot to pick first relic in SSM, unit name: Spirit Relic of Blood
-- todo: some spells are counting twice or more per second, make a timer for every spell to add one failpoint once per two seconds (bugging bosses -> mordechai)
-- todo: SSM: write whisp message to people who are dead after 2s after spirit relics being placed "you can rezz up"

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
local STL = Apollo.GetPackage("Module:STL-1.0").tPackage
local KV = Apollo.GetPackage("Module:KV-1.0").tPackage
local SSM = Apollo.GetPackage("Module:SSM-1.0").tPackage
local SC = Apollo.GetPackage("Module:SC-1.0").tPackage

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

    return o
end

function RIPgold:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- RIPgold OnLoad
-----------------------------------------------------------------------------------------------
function RIPgold:OnLoad()
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
		self.checkDeadState = ApolloTimer.Create(1, true, "ALL:CheckForPlayerDeaths(self)", self) 
		self.checkDeadState:Stop()

		-- updating ui every second when opened
		self.updateStatsUI = ApolloTimer.Create(1, true, "UIn:UpdateRIPgoldStats(self)", self)
		self.updateStatsUI:Stop()

		self.hlp.isBossDead = {
			["ID"] = 0, ["name"] = "", ["dead"] = false, ["timer"] = ApolloTimer.Create(1, true, "ALL:checkForBossDeaths(self)", self)
		}
		--self.hlp.isBossDead = {}
		--self.hlp.isBossDead.timer = ApolloTimer.Create(1, true, "ALL:checkForBossDeaths(self)", self)
		self.hlp.isBossDead.timer:Stop()
		--self.hlp.isBossDead.ID = 0
		--self.hlp.isBossDead.name = ""
		--self.hlp.isBossDead.dead = false

		self.hlp.doesChannelerExists = ApolloTimer.Create(1, true, "STL:checkForChannelerDeaths(self)", self)
		self.hlp.doesChannelerExists:Stop()

		if self.tSavedVariables == nil then

			self.hlp.peMatch = nil
			self.hlp.isInDungeon = false

			ALL:InitializeVars(self)

			if not GroupLib.InRaid() then
				ALL:PreparePlayers(self)
			end

			self.set.sound = true
			-- additional sounds: self:PlaySound(Sound.PlayUIQueuePopsAdventure)
			-- additional sounds: self:PlaySound(Sound.PlayUI47CancelVirtual)
			self.set.soundType = Sound.PlayUI11To13GenericPushButtonDigital02
		end

		if self.rat == nil then
			local getCurrentPlayerName = GameLib.GetPlayerUnit(1):GetName()
			self.rat[getCurrentPlayerName] = {}
			self.rat[getCurrentPlayerName]["fails"] = 0
			self.rat[getCurrentPlayerName]["rating"] = 1000
			self.rat[getCurrentPlayerName]["dungs"] = 0
		end

		--- testing purposes
		--self.hlp.isInDungeon = true
		--self.hlp.boss["Blade-Wind the Invoker"] = true


	end
end

-----------------------------------------------------------------------------------------------
-- Trivial Functions
-----------------------------------------------------------------------------------------------

function RIPgold:addToSet(set, key) -- not being used, future reference
    set[key] = true
end

function RIPgold:removeFromSet(set, key) -- not being used, future reference
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

			--SendVarToRover("Dungeon event", peCurrent)

			if peCurrent:ShouldShowMedalsUI() then
				-- processed after and only entering new dungeon -> reseting points etc
				self:Debug("Everything reseted.")

				self.hlp.isInDungeon = true

				ALL:InitializeVars(self)
				ALL:PreparePlayers(self)

				self.checkDeadState:Start()
					
				self.hlp.peMatch = true

				SendVarToRover("self", self)
				
				return true
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

		function IsPeObjectives()
		   local getPeObjectives = peUpdated:GetObjectives() ~= nil
		end

		if pcall(IsPeObjectives) then

			-- technically all event points
			local objectives = peUpdated:GetObjectives()

			for i,obj in pairs(objectives) do
				if obj:GetShortDescription() == "Deathless in the Dungeon" then
					SendVarToRover("deathless", obj)
				end
			end

			-- test purpose

			--local getObjectives = peUpdated:GetObjectives()
			--local timeinfo = string.format("getObjectives - %s", GameLib.GetGameTime())
			--SendVarToRover(timeinfo, getObjectives)

		end

	end -- if not in raid

end

function RIPgold:OnWorldChange()

	-- updated function: resets only info about match, not resetting everything every world change
	self.hlp.peMatch = nil
	self.hlp.isInDungeon = false
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
					self:Debug(bossName .. " alive.")
				end
			end

			KV:OnCombat_IN(self, unitInCombat)
			SSM:OnCombat_IN(self, unitInCombat)
		end

		-- proceeds on leaving combat
		if not bInCombat then
			KV:OnCombat_OUT(self, unitInCombat)
			SSM:OnCombat_OUT(self, unitInCombat)
			SC:OnCombat_OUT(self, unitInCombat)		

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

function RIPgold:OnCombatLogVitalModifier(tEventArgs)

	if self.hlp.isInDungeon then 
		SSM:OnCombatLogVitalModifier(self, tEventArgs)
		KV:OnCombatLogVitalModifier(self, tEventArgs)
		SC:OnCombatLogVitalModifier(self, tEventArgs)
	end
end

function RIPgold:OnUnitCreated(unit)

	STL:OnUnitCreatedBeforeEnteringDungeon(self, unit) -- ! has to be outside hlp.isInDungeon
	if self.hlp.isInDungeon then
		STL:OnUnitCreated(self, unit)
		SSM:OnUnitCreated(self, unit)
	end
end

function RIPgold:OnUnitDestroyed(unit)

	if self.hlp.isInDungeon then
		STL:OnUnitDestroyed(self, unit)
	end
end

function RIPgold:OnCombatLogDamage(tEventArgs)

	if self.hlp.isInDungeon then 

		local validTarget = tEventArgs.unitTarget ~= nil
		local validCaster = tEventArgs.unitCaster ~= nil
		local validSpell = tEventArgs.splCallingSpell:GetName() ~= nil
		if validTarget and validCaster and validSpell then

			if tEventArgs.unitTarget:IsInYourGroup() or tEventArgs.unitTarget:IsThePlayer() then -- if target is in your party

				SC:OnCombatLogDamage(self, tEventArgs)
				STL:OnCombatLogDamage(self, tEventArgs)
				SSM:OnCombatLogDamage(self, tEventArgs)
				KV:OnCombatLogDamage(self, tEventArgs)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Core Functions
-----------------------------------------------------------------------------------------------

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
	else
		ChatSystemLib.Command("/s "..fnString)
	end
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
-- UI Functions (RIPgoldForm Functions)
-----------------------------------------------------------------------------------------------

-- icon for interface menu
function RIPgold:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "RIPgold", {"ToggleRIPgoldUI", "", ""}) --IconSprites:Icon_Windows_UI_CRB_Rival icon before (terrible meh)
end

-- on SlashCommand "/rip"
function RIPgold:OnRIPgoldOn()

	self.updateStatsUI:Start()

	UIn:UpdateRIPgoldStats(self)
	self:OnBTN_statsClick() --instead of self.wndMain:FindChild("WRAP_FAILS"):ArrangeChildrenVert(0)

	self.wndMain:Invoke() -- show the window

	SendVarToRover("self.tSavedVariables",self.tSavedVariables)

	--SendVarToRover("self.rat",self.tSavedVariables)

	--table.insert("test", self.rat)	

	--self:Debug(self.hlp.player[1].name .. ": " .. self.hlp.player[1].fails)
	--self:Debug(self.hlp.player[2].name .. ": " .. self.hlp.player[2].fails)
	--self:Debug(self.hlp.player[3].name .. ": " .. self.hlp.player[3].fails)
	--self:Debug(self.hlp.player[4].name .. ": " .. self.hlp.player[4].fails)
	--self:Debug(self.hlp.player[5].name .. ": " .. self.hlp.player[5].fails)
end

-- when the Cancel button is clicked
function RIPgold:OnCancel()
	self.wndMain:Close() -- hide the window
	self.updateStatsUI:Stop()
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

-- ## card: settings
function RIPgold:OnBTN_SET_SoundClick(wndControl)
	UIs:OnBTN_SET_SoundClick(self, wndControl)
end

-- ## card: my group (old statistics)

-- function RIPgold:UpdateRIPgoldStatsUI() -- not being used
-- 	UIn:UpdateRIPgoldStats(self)
-- end

-- function RIPgold:UpdateAnnounceUI() -- not being used
-- 	UIn:UpdateAnnounceUI(self)
-- end

function RIPgold:onBOX_announceChange(wndControl)
	UIn:onBOX_announceChange(self, wndControl)
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

-----------------------------------------------------------------------------------------------
-- Save and Restore Data
-----------------------------------------------------------------------------------------------
function RIPgold:OnSave(eLevel)
	local tData = {}
	-- This example uses account level saves.
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
	-- Set your variables into tData
		tData.hlp = {}
		for name,data in pairs(self.hlp) do
			tData.hlp[name] = data
		end
		tData.set = {}
		for name,data in pairs(self.set) do
			tData.set[name] = data
		end
		tData.rat = {}
		for name,data in pairs(self.rat) do
			tData.rat[name] = data
		end
		--Sound.Play(Sound.PlayUIQueuePopsAdventure) testing purposes
	end
	
	return tData
end

function RIPgold:OnRestore(eLevel, tData)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
		-- Set your reference for the saved variables
		-- This example simply sets a table to mimic the loaded data. You can change this to split data up as you like.
		
		for name,data in pairs(tData.hlp) do
			self.hlp[name] = data
		end
		for name,data in pairs(tData.set) do
			self.set[name] = data
		end
		for name,data in pairs(tData.rat) do
			self.rat[name] = data
		end

		self.tSavedVariables = tData
	end
end

-----------------------------------------------------------------------------------------------
-- RIPgold Instance
-----------------------------------------------------------------------------------------------
local RIPgoldInst = RIPgold:new()
RIPgoldInst:Init()
