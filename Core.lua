-- XbiGold : démarrage et commandes
local _, XG = ...

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    XG:InitDB()
    XG:HookTooltips()
    pcall(XG.CreateMinimapButton, XG)
    C_Timer.After(1, function() XG:UpdateHUD() end)
end)

SLASH_XBIGOLD1 = "/xg"
SLASH_XBIGOLD2 = "/xbigold"
SlashCmdList.XBIGOLD = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "scan" then
        XG:StartScan()
    elseif msg == "session" or msg == "farm" then
        if XG:SessionRunning() then XG:PauseSession() else XG:StartSession() end
    elseif msg == "stop" then
        XG:StopSession()
    elseif msg == "deals" or msg == "affaires" then
        XG:Open("deals")
    elseif msg:find("^prix") then
        local arg = msg:gsub("^prix%s*", "")
        local key, id = XG.KeyFromLink(arg)
        if not id then id, key = XG:FindItemByName(arg) end
        if id then XG:ShowItem(id, key) else XG.Print("objet introuvable. Exemple : /xg prix longue plume") end
    elseif msg == "reset" then
        XG.M.items, XG.M.deals, XG.M.snap, XG.M.lastScan = {}, {}, {}, 0
        XG.Print("prix de ce marché effacés.")
        XG:RefreshUI()
    elseif msg == "help" or msg == "aide" then
        XG.Print("/xg : fenêtre · /xg scan · /xg session (démarrer/pause) · /xg stop · /xg affaires · /xg prix <nom ou lien> · /xg reset")
    else
        XG:Toggle()
    end
end
