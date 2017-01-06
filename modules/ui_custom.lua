local MAJOR, MINOR = "Module:UIc-1.0", 1
local APkg = Apollo.GetPackage(MAJOR)
if APkg and (APkg.nVersion or 0) >= MINOR then
  return -- no upgrade needed
end
local UIc = APkg and APkg.tPackage or {}
local _ENV = nil -- blocking globals in Lua 5.2
UIc.null = setmetatable ({}, {
  __toinn = function () return "null" end
})

-----------------------------------------------------------------------------------------------
-- Initialize variables
-----------------------------------------------------------------------------------------------

function UIc:OnBTN_customClick(self)
	self.wndMain:FindChild("WIN_stats"):Show(false)
	self.wndMain:FindChild("WIN_ratings"):Show(false)
	self.wndMain:FindChild("WIN_custom"):Show(true)
	self.wndMain:FindChild("WIN_settings"):Show(false)

	self.wndMain:FindChild("TOP_BG_stats"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_ratings"):SetBGColor("99000000")
	self.wndMain:FindChild("TOP_BG_custom"):SetBGColor("ef000000")
	self.wndMain:FindChild("TOP_BG_settings"):SetBGColor("99000000")

	self.wndMain:FindChild("WIN_custom"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_ALL"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_STL"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_KV"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_SC"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("WRAP_SSM"):ArrangeChildrenVert(0)
end



function UIc:OnLoad() end

Apollo.RegisterPackage(UIc, MAJOR, MINOR, {})