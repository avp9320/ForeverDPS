-- ForeverDPS visual theme
-- Compact persistent meters use Blizzard tooltip assets rather than a custom flat panel.

local function ApplyForeverDPSTheme()
    local frame = _G.ForeverDPSFrame
    if not frame then return false end

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.02, 0.02, 0.02, 0.94)
        frame:SetBackdropBorderColor(0.72, 0.58, 0.22, 0.92)
    end

    if frame.title then
        frame.title:SetFontObject(GameFontNormalLarge)
        frame.title:SetTextColor(1.00, 0.82, 0.20)
    end

    if frame.footer then
        frame.footer:SetTextColor(0.82, 0.82, 0.82)
    end

    if frame.lockText then
        frame.lockText:SetTextColor(0.55, 0.55, 0.55)
    end

    frame.ForeverStockTheme = true
    return true
end

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
