local MAJOR, MINOR = "Module:UIs-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local UIs = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
UIs.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-----------------------------------------------------------------------------------------------
-- Card buttons (top menu)
-----------------------------------------------------------------------------------------------

function UIs:OnBTN_settingsClick(self)
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_ratings"):Show(false)
	self.wndMain:FindChild("WIN_custom"):Show(false)
	self.wndMain:FindChild("WIN_settings"):Show(true)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_ratings"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("ef000000")

	self.wndMain:FindChild("SET_sound"):SetCheck(self.set.sound)
end

-----------------------------------------------------------------------------------------------
-- CARD: settings
-----------------------------------------------------------------------------------------------

function UIs:OnBTN_SET_SoundClick(self, wndControl)
	self.set.sound = wndControl:IsChecked()
	self:PlaySound(self.set.soundType)
end


function UIs:OnLoad() end

Apollo.RegisterPackage(UIs, MAJOR, MINOR, {})