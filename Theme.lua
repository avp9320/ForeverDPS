-- ForeverDPS uses a compact and readable meter, not a decorated tooltip
-- panel. Core owns the frame and row layout; this theme keeps it understated.
local function ApplyForeverDPSTheme()
    local frame = _G.ForeverDPSFrame
    if not frame then return false end
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0.02, 0.02, 0.025, 0.74)
        frame:SetBackdropBorderColor(0.20, 0.20, 0.24, 0.70)
    end
    if frame.footer then frame.footer:SetTextColor(0.75, 0.75, 0.78) end
    if frame.lockText then frame.lockText:SetTextColor(0.55, 0.55, 0.56) end
    frame.ForeverStockTheme = true
    return true
end

ApplyForeverDPSTheme()
local themeEvents = CreateFrame("Frame")
themeEvents:RegisterEvent("ADDON_LOADED")
themeEvents:RegisterEvent("PLAYER_LOGIN")
themeEvents:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "ForeverDPS" then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, ApplyForeverDPSTheme)
    else
        ApplyForeverDPSTheme()
    end
end)
