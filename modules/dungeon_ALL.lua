local MAJOR, MINOR = "Module:ALL-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local ALL = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
ALL.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-----------------------------------------------------------------------------------------------
-- Initialize variables
-----------------------------------------------------------------------------------------------

function ALL:InitializeVars(self)

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

	self.hlp.event = {}

	self.hlp.SelenePercentage = 0
	self.hlp.TrogunStacks = 0
	self.hlp.OctogStacks = 0
	self.hlp.ShallaosStacks = { 
		[1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, 
	}
	self.hlp.WindInvokerTargetPlayer = {
		["name"] = "", ["name_before"] = "", ["x"] = 0, ["y"] = 0, ["z"] = 0,
	}

	self.hlp.varsForChallengeActive = {}

	self.hlp.WindInvokerDiffs = { 
		[1] = 0, [2] = 0, [3] = 0, [4] = 0 
	}

	self.hlp.WindInvokerInvisibleUnitTime = {}

	self.hlp.WindInvokerInvisibleUnitID = 0

	self.hlp.WindInvokerLastGametime = GameLib.GetGameTime()

	self.hlp.lastGametimeFailed = {}

end

-----------------------------------------------------------------------------------------------
-- Players
-----------------------------------------------------------------------------------------------

function ALL:PreparePlayers(self)

	self.get.GroupMaxSize = GroupLib.GetGroupMaxSize()

	local baseTooltip = "Yours or your team fails: \n\n"
	self.hlp.player = {
		[1] = {["name"] = "", ["fails"] = 0, ["dead"] = false, ["tooltip"] = baseTooltip}, ["ilvl"] = 0, ["hero"] = 0, ["dungs"] = 0,
		[2] = {["name"] = "", ["fails"] = 0, ["dead"] = false, ["tooltip"] = baseTooltip}, ["ilvl"] = 0, ["hero"] = 0, ["dungs"] = 0,
		[3] = {["name"] = "", ["fails"] = 0, ["dead"] = false, ["tooltip"] = baseTooltip}, ["ilvl"] = 0, ["hero"] = 0, ["dungs"] = 0,
		[4] = {["name"] = "", ["fails"] = 0, ["dead"] = false, ["tooltip"] = baseTooltip}, ["ilvl"] = 0, ["hero"] = 0, ["dungs"] = 0,
		[5] = {["name"] = "", ["fails"] = 0, ["dead"] = false, ["tooltip"] = baseTooltip}, ["ilvl"] = 0, ["hero"] = 0, ["dungs"] = 0,
	}

	if self.get.GroupMaxSize == 0 then

		function GetPlayerName()
		   local getBossBuffs = GameLib.GetPlayerUnit():GetName() ~= nil
		end

		if pcall(GetPlayerName) then
			self.hlp.player[1].name = GameLib.GetPlayerUnit():GetName()
		end

	else

		for nGroupIndex=1,self.get.GroupMaxSize do 

			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			if getGroupMember ~= nil then
				self.hlp.player[nGroupIndex].name = getGroupMember.strCharacterName
			end
		end
	end

	ALL:getTooltipStats(self)
end

function ALL:getTooltipStats(self)

	if self.get.GroupMaxSize == 0 or self.get.GroupMaxSize > 5 then
		function Getilvl()
		   local getBossBuffs = GameLib.GetPlayerUnit():GetEffectiveItemLevel() ~= nil
		end
		if pcall(Getilvl) then
			self.hlp.player[1].ilvl = Apollo.FormatNumber(GameLib.GetPlayerUnit():GetEffectiveItemLevel() or 0, 0, true)
		end
		function GetHero()
		   local getBossBuffs = GameLib.GetPlayerUnit():GetHeroism() ~= nil
		end
		if pcall(GetHero) then
			self.hlp.player[1].hero = Apollo.FormatNumber(GameLib.GetPlayerUnit():GetHeroism() or 0, 0, true)
		end
		-- get dungeons completed stat
		function GetPlayerName()
		   local get = GameLib.GetPlayerUnit():GetName() ~= nil
		end
		if pcall(GetPlayerName) then
			local playerName = GameLib.GetPlayerUnit():GetName()
			if self.rat[playerName] ~= nil and self.rat[playerName].dungs ~= nil then
				self.hlp.player[1].dungs = self.rat[playerName].dungs
			end
		end


	else
		for nGroupIndex=1,self.get.GroupMaxSize do 
			local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)
			local getPlayersName = self.hlp.player[nGroupIndex].name

			if getGroupMember ~= nil then

				-- get ilvl stat
				function Getilvl()
				   local getBossBuffs = GroupLib.GetUnitForGroupMember(nGroupIndex):GetEffectiveItemLevel() ~= nil
				end
				if pcall(Getilvl) then
					local ilvl = GroupLib.GetUnitForGroupMember(nGroupIndex):GetEffectiveItemLevel()

					if self.hlp.player[nGroupIndex].ilvl == nil then self.hlp.player[nGroupIndex].ilvl = 0 end
					if ilvl == nil then ilvl = 0 end

					if tonumber(self.hlp.player[nGroupIndex].ilvl) < ilvl then
						self.hlp.player[nGroupIndex].ilvl = Apollo.FormatNumber(ilvl or 0, 0, true)
					end

					if self.rat[getPlayersName] ~= nil then
						if self.rat[getPlayersName].ilvl ~= nil then
							if tonumber(self.rat[getPlayersName].ilvl) > tonumber(self.hlp.player[nGroupIndex].ilvl) then
								self.hlp.player[nGroupIndex].ilvl = self.rat[getPlayersName].ilvl
							end
						end
					end
				else
					if getPlayersName then
						if self.rat[getPlayersName] ~= nil and self.rat[getPlayersName].ilvl ~= nil then
							self.hlp.player[nGroupIndex].ilvl = self.rat[getPlayersName].ilvl
						end
					end
				end

				-- get heroism stat
				function GetHero()
				   local getBossBuffs = GroupLib.GetUnitForGroupMember(nGroupIndex):GetHeroism() ~= nil
				end
				if pcall(GetHero) then
					local hero = GroupLib.GetUnitForGroupMember(nGroupIndex):GetHeroism()
					local savedHero = tonumber(self.hlp.player[nGroupIndex].hero)

					if savedHero == nil then savedHero = 0 end
					if hero == nil then hero = 0 end

					if savedHero < hero then
						self.hlp.player[nGroupIndex].hero = Apollo.FormatNumber(hero or 0, 0, true)
					end

					if self.rat[getPlayersName] ~= nil then
						if self.rat[getPlayersName].hero ~= nil then
							if self.rat[getPlayersName].hero > self.hlp.player[nGroupIndex].hero then
								self.hlp.player[nGroupIndex].hero = self.rat[getPlayersName].hero
							end
						end
					end			
				else
					if getPlayersName then
						if self.rat[getPlayersName] ~= nil and self.rat[getPlayersName].hero ~= nil then
							self.hlp.player[nGroupIndex].hero = self.rat[getPlayersName].hero
						end
					end
				end

				-- get dungeons completed stat
				if getPlayersName then
					if self.rat[getPlayersName] ~= nil and self.rat[getPlayersName].dungs ~= nil then
						self.hlp.player[nGroupIndex].dungs = self.rat[getPlayersName].dungs
					end
				end
			end
		end
	end
end

function ALL:CheckForPlayerDeaths(self)

	if self.hlp.isInDungeon then
		if self.get.GroupMaxSize == 0 then
			
			local getDeathState = GameLib.GetPlayerUnit():IsDead()
			local getName = GameLib.GetPlayerUnit():GetName()
			local nGroupIndex = 1
			ALL:IsPlayerDead(self, getDeathState, getName, nGroupIndex)
		else
			for nGroupIndex=1, self.get.GroupMaxSize do
				local getGroupMember = GroupLib.GetGroupMember(nGroupIndex)

				if getGroupMember ~= nil then
					local getGroupMemberUnit = GroupLib.GetUnitForGroupMember(nGroupIndex)

					if getGroupMemberUnit ~= nil then
						local getDeathState = getGroupMemberUnit:IsDead()
						local getGroupMemberName = getGroupMember.strCharacterName
						ALL:IsPlayerDead(self, getDeathState, getGroupMemberName, nGroupIndex)
					end
				end
			end
		end
	end
end

function ALL:IsPlayerDead(self, getDeathState, getName, nGroupIndex)

	if getDeathState then
		if self.hlp.player[nGroupIndex].dead == false then

			-- check if deathless doesnt collide with event's deathless (solves bug when player got teleported dead to instance but also /stuck problem (counts as ripdeathless))
			if self.hlp.event["Deathless in the Dungeon"] == 0 then

				if self.hlp.alreadyFailedDeathless == true then -- warning: cant be if+else, has to be separated
					local sToChatMin = "Died."
					self:AddTooltip(getName, sToChatMin)
				end
				
				if self.hlp.alreadyFailedDeathless == false then -- warning: cant be if+else, has to be separated
					local sToChatMin = "Ruined deathless challenge."
					self:AddTooltip(getName, sToChatMin)

					local sToChat = string.format("%s just fucked up deathless challenge. RIPgold. :(.", getName)
					self:InformOthers(sToChat, false, true)
					self:Rover(getName, false, "ruined deathless.")
					self.hlp.alreadyFailedDeathless = true
				end
				self:Rover(getName, false, "is dead.")
				self.hlp.player[nGroupIndex].dead = true
				self:CountFails(getName)
			end
		end
	else
		if self.hlp.player[nGroupIndex].dead then

			self:Rover(getName, false, "is alive.")
			self.hlp.player[nGroupIndex].dead = false
		end
	end

end

-----------------------------------------------------------------------------------------------
-- Fails
-----------------------------------------------------------------------------------------------

function ALL:HowManyFails(self)

	local totalfails = self.hlp.player[1].fails + self.hlp.player[2].fails + self.hlp.player[3].fails + self.hlp.player[4].fails + self.hlp.player[5].fails

	if totalfails == 0 then
		self:InformOthers("No mistakes. Well done!", false, false)
	else
		self:InformOthers("So, how many fails did you do this dungeon?", false, false)

		for i=1,5 do
			if self.hlp.player[i].name ~= "" then
				self:InformOthers(self.hlp.player[i].name .. ": " .. self.hlp.player[i].fails, false, false)
			end
		end
	end

	-- new function new rat
	for i=1,5 do
		if self.hlp.player[i].name ~= "" then

			-- human readable fails
			local failWord = "fails"
			if self.hlp.player[i].fails == 1 then
				failWord = "fail"
			end

			if self:setContains(self.rat, self.hlp.player[i].name) then
				
				local rating = self.rat[self.hlp.player[i].name]["rating"]
				if self.hlp.player[i].fails > 0 then
					rating = rating - self.hlp.player[i].fails
				else
					rating = rating + 50
				end

				self.rat[self.hlp.player[i].name]["fails"] = self.rat[self.hlp.player[i].name]["fails"] + self.hlp.player[i].fails
				self.rat[self.hlp.player[i].name]["rating"] = rating
				self.rat[self.hlp.player[i].name]["dungs"] = self.rat[self.hlp.player[i].name]["dungs"] + 1
				self.rat[self.hlp.player[i].name]["ilvl"] = self.hlp.player[i].ilvl
				self.rat[self.hlp.player[i].name]["hero"] = self.hlp.player[i].hero
			else

				local rating = 1000
				if self.hlp.player[i].fails > 0 then
					rating = rating - self.hlp.player[i].fails
				else
					rating = rating + 50
				end

				self.rat[self.hlp.player[i].name] = {}
				self.rat[self.hlp.player[i].name]["fails"] = self.hlp.player[i].fails
				self.rat[self.hlp.player[i].name]["rating"] = rating
				self.rat[self.hlp.player[i].name]["dungs"] = 1
				self.rat[self.hlp.player[i].name]["ilvl"] = self.hlp.player[i].ilvl
				self.rat[self.hlp.player[i].name]["hero"] = self.hlp.player[i].hero
			end

			sToChat = string.format("%s %s, %s rating", self.hlp.player[i].fails, failWord, self.rat[self.hlp.player[i].name]["rating"])
			self:Debug(self.hlp.player[i].name .. ": ".. sToChat)
		end
	end

	if GroupLib.AmILeader() then
		ChatSystemLib.Command("/rq") -- proceeds reQue after end of dungeon if you are a leader
	end

end

-----------------------------------------------------------------------------------------------
-- Boss deaths
-----------------------------------------------------------------------------------------------


function ALL:precheckForBossDeaths(self, unitInCombat)
	if self.hlp.isInDungeon then 
		self.hlp.isBossDead.dead = false
		self.hlp.isBossDead.name = unitInCombat:GetName()
		self.hlp.isBossDead.ID = unitInCombat:GetId()
		self.hlp.isBossDead.timer:Start()
	end
end

function ALL:checkForBossDeaths(self)
	if self.hlp.isInDungeon then 
		--self:Debug("checkForBossDeaths fnc started")

		function doesBossExist()
		   local isBossDead = GameLib.GetUnitById(self.hlp.isBossDead.ID):IsDead() ~= nil
		end

		if pcall(doesBossExist) then
			local isBossDead = GameLib.GetUnitById(self.hlp.isBossDead.ID):IsDead()
			if isBossDead then
				self.hlp.isBossDead.dead = true
				self.hlp.isBossDead.timer:Stop()

				if self.hlp.isBossDead.name == "Stormtalon" then
					self:REDIR_ALL_HowManyFails()
				end
				if self.hlp.isBossDead.name == "Spiritmother Selene the Corrupted" then
					self:REDIR_ALL_HowManyFails()
				end
				if self.hlp.isBossDead.name == "Mordechai Redmoon" then
					self:REDIR_ALL_HowManyFails()
				end
				if self.hlp.isBossDead.name == "Forgemaster Trogun" then
					self:REDIR_ALL_HowManyFails()
				end
				if self.hlp.isBossDead.name == "Wrathbone" then
					--self:REDIR_ALL_HowManyFails() --future reference
				end

				if self.hlp.isBossDead.name == "Blade-Wind the Invoker" then
					self.hlp.doesChannelerExists:Stop()
				end
				if self.hlp.isBossDead.name == "Bosun Octog" then
					if self.hlp.OctogStacks < 10 then
						local sToChatMin = string.format("Bosun got %s from 10 stacks.", self.hlp.OctogStacks)
						self:AddTooltips(sToChatMin)

						local sToChat = string.format("Bosun got %s from 10 stacks of Broken Armor. The challenge is lost.", self.hlp.OctogStacks)
						self:InformOthers(sToChat, false, false)

						self:AddFails()
					end
				end

				-- starts timer that checks if party forgot to pick Spirit-Relic of Blood
				if self.hlp.isBossDead.name == "Deadringer Shallaos" then
					self.hlp.doesRelicBloodExist:Start()
				end

				self:Rover(self.hlp.isBossDead.name, false, "is dead.")
			end
		end
	end
end





function ALL:OnLoad() end

Apollo.RegisterPackage(ALL, MAJOR, MINOR, {})