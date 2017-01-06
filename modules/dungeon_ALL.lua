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

-----------------------------------------------------------------------------------------------
-- Players
-----------------------------------------------------------------------------------------------

function ALL:PreparePlayers(self)

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

function ALL:CheckForPlayerDeaths(self)

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

-----------------------------------------------------------------------------------------------
-- Fails
-----------------------------------------------------------------------------------------------

function ALL:HowManyFails(self)

	self:InformOthers("So, how many fails did you do this dungeon?", false)

	for i=1,5 do
		if self.hlp.player[i].name ~= "" then
			self:InformOthers(self.hlp.player[i].name .. ": " .. self.hlp.player[i].fails, false)
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

			-- supernew function
			--if self.rat ~= nil then
			if RIPgold:setContains(self.rat, self.hlp.player[i].name) then
				
				local rating = self.rat[self.hlp.player[i].name]["rating"]
				if self.hlp.player[i].fails > 0 then
					rating = rating - self.hlp.player[i].fails
				else
					rating = rating + 50
				end

				self.rat[self.hlp.player[i].name]["fails"] = self.rat[self.hlp.player[i].name]["fails"] + self.hlp.player[i].fails
				self.rat[self.hlp.player[i].name]["rating"] = rating
				self.rat[self.hlp.player[i].name]["dungs"] = self.rat[self.hlp.player[i].name]["dungs"] + 1
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
			end
			--end

			sToChat = string.format("%s %s, %s rating", self.hlp.player[i].fails, failWord, self.rat[self.hlp.player[i].name]["rating"])
			self:Debug(self.hlp.player[i].name .. ": ".. sToChat)
		end
	end

	SendVarToRover("self.rat",self.rat)

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

		function doesBossExist()
		   local isBossDead = GameLib.GetUnitById(self.hlp.isBossDead.ID):IsDead() ~= nil
		end

		if pcall(doesBossExist) then
			local isBossDead = GameLib.GetUnitById(self.hlp.isBossDead.ID):IsDead()
			if isBossDead then
				self.hlp.isBossDead.dead = true
				self.hlp.isBossDead.timer:Stop()

				if self.hlp.isBossDead.name == "Stormtalon" then
					ALL:HowManyFails(self)
				end
				if self.hlp.isBossDead.name == "Spiritmother Selene the Corrupted" then
					ALL:HowManyFails(self)
				end
				if self.hlp.isBossDead.name == "Mordechai Redmoon" then
					ALL:HowManyFails(self)
				end
				if self.hlp.isBossDead.name == "Forgemaster Trogun" then
					ALL:HowManyFails(self)
				end
				if self.hlp.isBossDead.name == "Wrathbone" then
					--ALL:HowManyFails(self)
				end
				if self.hlp.isBossDead.name == "Blade-Wind the Invoker" then
					self.hlp.doesChannelerExists:Stop() --test if it's working
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
	end
end





function ALL:OnLoad() end

Apollo.RegisterPackage(ALL, MAJOR, MINOR, {})