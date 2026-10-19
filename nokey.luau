local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local function elevateThread()
if setthreadidentity then pcall(setthreadidentity, 8) end
if setidentity then pcall(setidentity, 8) end
if set_thread_identity then pcall(set_thread_identity, 8) end
end
elevateThread()
if _G.RSECRYPTO_CLEANUP then pcall(_G.RSECRYPTO_CLEANUP) end
if _G.RSECRYPTO_INSTANCES then
for _, fn in ipairs(_G.RSECRYPTO_INSTANCES) do pcall(fn) end
end
_G.RSECRYPTO_INSTANCES = {}
pcall(function()
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
if PlayerGui then
for _, c in ipairs(PlayerGui:GetChildren()) do
if c.Name:find("RSE2") then
pcall(function() c:Destroy() end)
end
end
end
local okG, hui = pcall(function() return gethui and gethui() end)
local root = (okG and hui) or game:GetService("CoreGui")
for _, c in ipairs(root:GetChildren()) do
if c.Name:find("RSE2") then
pcall(function() c:Destroy() end)
end
end
end)
local Fluent = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/myheisenberg/Fluent-Renewed/main/Fluent.luau"))()
local State = require(LocalPlayer.PlayerScripts.Client.State)
local PE = require(game.ReplicatedStorage.Shared.PriceEngine)
local C = require(game.ReplicatedStorage.Shared.Config)
local seed = State.seed()
local S = {
running = false,
maxMarginPct = 95,
levCap = 30,
stopPct = 12,
lockPct = 10,
minMove = 0.3,
maxSim = 8,
impactPct = 0.1,
}
local Bot = { busy = false, holds = {}, holdsLoaded = false, lastEntryAt = 0 }
getgenv().RSECRYPTO_STATE = S
local Logs = {}
local updateTick
local function log(msg)
table.insert(Logs, os.date("%H:%M:%S") .. "  " .. tostring(msg))
if #Logs > 60 then table.remove(Logs, 1) end
end
local function getCash()
local ok, v = pcall(function() return State.profile and State.profile.cash or 0 end)
return ok and tonumber(v) or 0
end
local function levCapByLevel()
local cap = 1
for _, row in ipairs(C.UNLOCKS.LEVERAGE) do
if (State.profile.level or 1) >= (row.level or 1) then
cap = row.max or 1
break
end
end
return cap
end
local function freshSignal(a)
local okN, t = pcall(State.marketNow, a)
if not okN then return nil end
local p0 = PE.priceAt(seed, a, t)
local p15 = PE.priceAt(seed, a, t + 15)
local p60 = PE.priceAt(seed, a, t + 60)
local p120 = PE.priceAt(seed, a, t + 120)
local p240 = PE.priceAt(seed, a, t + 240)
if not (p0 and p15 and p60 and p120 and p240) or p0 <= 0 then return nil end
local m15 = (p15 - p0) / p0 * 100
local m60 = (p60 - p0) / p0 * 100
local m120 = (p120 - p0) / p0 * 100
local m240 = (p240 - p0) / p0 * 100
if m15 >= S.minMove and m60 > -0.1 and m120 > -0.1 and m240 > -0.1 then
return { dir = 1, move = m15, entry = p0 }
elseif m15 <= -S.minMove and m60 < 0.1 and m120 < 0.1 and m240 < 0.1 then
return { dir = -1, move = -m15, entry = p0 }
end
return nil
end
local function impactCappedNotional(a, notional, livePrice)
local shares = a.shares or a.supply or 0
local liq = shares * 1e6 * (livePrice or 0)
if liq <= 0 then return 0 end
local maxN = liq * ((S.impactPct or 0.1) / 1000)
if notional > maxN then notional = maxN end
if notional < 50 then return 0 end
return notional
end
local function marginPnlPct(pos)
local asset = pos and PE.resolveAsset(seed, pos.id)
local tNow = asset and State.marketNow(asset)
local mark = asset and PE.priceAt(seed, asset, tNow)
local entry = pos.avg or 0
local dirSign = 1
if (pos.qty or 0) < 0 or pos.direction == -1 then dirSign = -1 end
if mark and entry > 0 then
return (mark - entry) / entry * 100 * (pos.lev or 1) * dirSign
end
return 0
end
local function closePos(i)
local okA, rA = pcall(State.trade, { action = "close", index = i, fraction = 1 })
if okA and rA and rA.ok then return true end
local okB, rB = pcall(State.trade, { action = "close", index = i - 2, fraction = 1 })
return okB and rB and rB.ok or false
end
local function cryptoCycle()
if not S.running or Bot.busy then return end
local open = (State.profile and State.profile.positions or {})
local botPos = 0
local openIds = {}
if not Bot.holdsLoaded then
for _, pos in ipairs(open) do Bot.holds[pos.id] = true end
Bot.holdsLoaded = true
end
for i = #open, 1, -1 do
local pos = open[i]
openIds[pos.id] = true
if Bot.holds[pos.id] then
botPos = botPos + 1
local pnlPct = marginPnlPct(pos)
local asset = PE.resolveAsset(seed, pos.id)
local tNow = asset and State.marketNow(asset)
local age = tNow and pos.openedAt and (tNow - pos.openedAt) or 0
local hInfo = Bot.holds[pos.id]
local aheadBad = false
if asset and tNow then
local markNow = PE.priceAt(seed, asset, tNow)
if markNow and markNow > 0 then
local dirSign = 1
if (pos.qty or 0) < 0 or pos.direction == -1 then dirSign = -1 end
for step = 30, 240, 30 do
local okS, px = pcall(PE.priceAt, seed, asset, tNow + step)
if okS and px and px > 0 then
local swing = dirSign == 1 and (markNow - px) / markNow or (px - markNow) / markNow
if swing >= 0.006 then
aheadBad = true
break
end
end
end
end
end
local extremeExit = type(hInfo) == "table" and hInfo.t and tNow and (tNow >= hInfo.t - 60)
if extremeExit then
if closePos(i) then
Bot.holds[pos.id] = nil
openIds[pos.id] = nil
log(string.format("PEAK EXIT %s %+.1f%% (curve peak/valley)", tostring(pos.id), pnlPct))
end
elseif aheadBad then
if closePos(i) then
Bot.holds[pos.id] = nil
openIds[pos.id] = nil
log(string.format("PREDICT EXIT %s %+.1f%% (curve adverse turn)", tostring(pos.id), pnlPct))
end
elseif pnlPct <= -S.stopPct then
if closePos(i) then
Bot.holds[pos.id] = nil
openIds[pos.id] = nil
log(string.format("STOP LOSS %s -%.1f%% -> CLOSED", tostring(pos.id), -pnlPct))
end
elseif pnlPct >= S.lockPct and type(hInfo) ~= "table" then
if closePos(i) then
Bot.holds[pos.id] = nil
openIds[pos.id] = nil
log(string.format("PROFIT LOCK %s +%.1f%% -> BANKED", tostring(pos.id), pnlPct))
end
elseif age > 240 then
if closePos(i) then
Bot.holds[pos.id] = nil
openIds[pos.id] = nil
log(string.format("TIMEOUT %s %+.1f%% -> CLOSED", tostring(pos.id), pnlPct))
end
end
end
end
local slots = S.maxSim - botPos
if slots <= 0 then return end
if os.time() - Bot.lastEntryAt < 5 then return end
local cash = getCash()
if cash < 100 then return end
local cap = math.min(levCapByLevel(), S.levCap)
if cap < 5 then return end
local perTrade = cash * (S.maxMarginPct / 100) / math.max(slots, 1)
if perTrade < 100 then return end
local cands = {}
for _, a in ipairs(PE.listedAssets()) do
if a.class == "crypto" and not openIds[a.id] then
local sig = freshSignal(a)
if sig then
local notional = perTrade * cap
local cappedN = impactCappedNotional(a, notional, sig.entry)
if cappedN > 0 then
local pay = cappedN / math.max(notional, 1)
if pay < 0.3 and sig.move < 0.8 then
else
local score = sig.move * pay
cands[#cands + 1] = { id = a.id, asset = a, dir = sig.dir, entry = sig.entry, move = sig.move, notional = cappedN, score = score }
end
end
end
end
end
table.sort(cands, function(x, y) return x.score > y.score end)
for _, c in ipairs(cands) do
if slots <= 0 then break end
local freshNow = PE.priceAt(seed, c.asset, State.marketNow(c.asset))
local okDist = true
if freshNow and freshNow > 0 then
local dist = (c.entry - freshNow) / freshNow * 100 * c.dir
if dist > 0.5 then okDist = false end
end
if okDist then
local lev = cap
local margin = c.notional / lev
if margin > cash * 0.7 / math.max(slots, 1) then margin = cash * 0.7 / math.max(slots, 1) end
local qty = margin * lev / c.entry
Bot.busy = true
local ok, r = pcall(State.trade, {
action = "open", id = c.id, qty = qty,
direction = c.dir, lev = lev, maxOrder = false,
})
Bot.busy = false
if ok and r and r.ok then
local fillPrice = tonumber(r.price) or freshNow or c.entry
local hi, lo, hiT, loT = fillPrice, fillPrice, 0, 0
local aT = State.marketNow(c.asset)
for step = 15, 300, 15 do
local okS, px = pcall(PE.priceAt, seed, c.asset, aT + step)
if okS and px then
if px > hi then hi, hiT = px, aT + step end
if px < lo then lo, loT = px, aT + step end
end
end
local extremeT = c.dir == 1 and hiT or loT
Bot.holds[c.id] = { t = extremeT }
botPos = botPos + 1
slots = slots - 1
openIds[c.id] = true
log(string.format("ENTERED %s %s %dx | move %+.2f%% | target: curve %s",
c.id, c.dir == 1 and "LONG" or "SHORT", lev, c.move,
c.dir == 1 and "PEAK" or "BOTTOM"))
elseif ok and r and r.err then
log("ERROR " .. c.id .. ": " .. tostring(r.err))
end
end
end
end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
Fluent.GUI.Parent = PlayerGui
Fluent.GUI.DisplayOrder = 999999
Fluent.GUI.Enabled = false
local Window = Fluent:CreateWindow({
Title = "RSE2 Crypto Scalper",
SubTitle = "v1 | by zynex",
Size = UDim2.fromOffset(560, 440),
TabWidth = 150,
Theme = "Dark",
Acrylic = false,
})
local function disableAutoLocalize(root)
if not root then return end
pcall(function()
if root:IsA("TextLabel") or root:IsA("TextButton") or root:IsA("TextBox") then
root.AutoLocalize = false
end
for _, v in ipairs(root:GetDescendants()) do
if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
v.AutoLocalize = false
end
end
end)
end
Fluent.GUI.DescendantAdded:Connect(function(v)
if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
v.AutoLocalize = false
end
end)
disableAutoLocalize(Fluent.GUI)
local function accountInfo()
local pr = State.profile or {}
local cap = levCapByLevel()
local maxPos = 28
pcall(function() maxPos = C.maxPositionsFor and C.maxPositionsFor(State.profile) or 28 end)
return pr.level or 1, cap, maxPos
end
local discordLink = "https://discord.gg/ehbX2MVbTw"
pcall(function()
local okD, resD = pcall(function()
return game:HttpGetAsync("https://raw.githubusercontent.com/myheisenberg/Fluent-Renewed/main/discord.txt")
end)
if okD and resD and #resD > 5 then discordLink = resD:gsub("%s+", "") end
end)
local avatarIcon = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
local Tabs = {}
local okTabs = pcall(function()
Tabs.Main = Window:CreateTab({ Title = "Dashboard", Icon = avatarIcon })
Tabs.Risk = Window:CreateTab({ Title = "Risk", Icon = "shield" })
Tabs.Log = Window:CreateTab({ Title = "Logs", Icon = "phosphor-list-bold" })
Tabs.Settings = Window:CreateTab({ Title = "Settings", Icon = "settings" })
Tabs.Discord = Window:CreateTab({ Title = "Discord", Icon = "message-square" })
end)
if not okTabs or not Tabs.Main then
Tabs = {}
Tabs.Main = Window:CreateTab({ Title = "Dashboard", Icon = "home" })
Tabs.Risk = Window:CreateTab({ Title = "Risk", Icon = "shield" })
Tabs.Log = Window:CreateTab({ Title = "Logs", Icon = "phosphor-list-bold" })
Tabs.Settings = Window:CreateTab({ Title = "Settings", Icon = "settings" })
Tabs.Discord = Window:CreateTab({ Title = "Discord", Icon = "message-square" })
end
local statPar = Tabs.Main:CreateParagraph("Stat", { Title = "Status", Content = "Connecting to market engine..." })
local accPar = Tabs.Main:CreateParagraph("Account", { Title = "Account (auto-adaptive)", Content = "Loading account profile..." })
local logParDash = Tabs.Main:CreateParagraph("LogDash", { Title = "Live Activity & Logs", Content = "Engine ready." })
local statLabel = statPar and statPar.Instance and statPar.Instance.DescLabel
local accLabel = accPar and accPar.Instance and accPar.Instance.DescLabel
local logDashLabel = logParDash and logParDash.Instance and logParDash.Instance.DescLabel
for _, lbl in ipairs({ statLabel, accLabel, logDashLabel }) do
pcall(function()
if lbl then
lbl.AutomaticSize = Enum.AutomaticSize.Y
lbl.Size = UDim2.new(1, 0, 0, 0)
lbl.TextWrapped = true
end
end)
end
Tabs.Main:CreateToggle("Run", {
Title = "Bot Running",
Default = false,
Callback = function(v)
S.running = v
log(v and "STARTED" or "STOPPED")
if updateTick then pcall(updateTick) end
end,
})
Tabs.Main:CreateButton({
Title = "Join Discord Community",
Description = "Click to copy invite link (" .. discordLink .. ")",
Callback = function()
pcall(function() setclipboard(discordLink) end)
Fluent:Notify({ Title = "Discord", Content = "Discord invite link copied to clipboard!", Duration = 3 })
end,
})
local levSlider, maxSimSlider
local function safeSlider(tab, name, cfg)
local obj
local okS, err = pcall(function() obj = tab:CreateSlider(name, cfg) end)
if not okS then log("SLIDER-ERR " .. name .. ": " .. tostring(err)) end
return obj
end
local _lvl, _cap, _maxPos = accountInfo()
local levMaxS = math.max(tonumber(_cap) or 30, 1)
local maxPosS = math.max(tonumber(_maxPos) or 28, 1)
Tabs.Risk:CreateParagraph("RiskInfo", {
Title = "Developer: zynex",
Content = "These drive the engine live. Level caps auto-apply on top.",
})
safeSlider(Tabs.Risk, "MaxMargin", {
Title = "Cash % Per Trade",
Description = "Portion of cash used per entry",
Default = S.maxMarginPct, Min = 10, Max = 95, Rounding = 0,
Callback = function(v) S.maxMarginPct = v end,
})
levSlider = safeSlider(Tabs.Risk, "LevCap", {
Title = "Leverage Cap",
Description = "Account allows up to " .. tostring(levMaxS) .. "x at level " .. tostring(_lvl or 1) .. " (auto-clamped)",
Default = math.min(S.levCap, levMaxS), Min = 1, Max = levMaxS, Rounding = 0,
Callback = function(v) S.levCap = v end,
})
safeSlider(Tabs.Risk, "Stop", {
Title = "Stop Loss % (margin)",
Description = "Position closing at this loss instantly",
Default = S.stopPct, Min = 3, Max = 40, Rounding = 0,
Callback = function(v) S.stopPct = v end,
})
safeSlider(Tabs.Risk, "Lock", {
Title = "Profit Lock % (margin)",
Description = "For adopted positions without curve data",
Default = S.lockPct, Min = 3, Max = 50, Rounding = 0,
Callback = function(v) S.lockPct = v end,
})
safeSlider(Tabs.Risk, "MinMove", {
Title = "Min Entry Move %",
Description = "Lower = more trades, higher = fewer but stronger",
Default = S.minMove, Min = 0.1, Max = 1.5, Rounding = 2,
Callback = function(v) S.minMove = v end,
})
maxSimSlider = safeSlider(Tabs.Risk, "MaxSim", {
Title = "Max Simultaneous Positions",
Description = "Account allows up to " .. tostring(maxPosS) .. " at level " .. tostring(_lvl or 1),
Default = math.min(S.maxSim, maxPosS), Min = 1, Max = maxPosS, Rounding = 0,
Callback = function(v) S.maxSim = v end,
})
safeSlider(Tabs.Risk, "Impact", {
Title = "Impact Budget % (PROFIT MULTIPLIER)",
Description = "How much our order may move price. (0.1 = Safe, 0.3 = Turbo, 0.5 = Max)",
Default = S.impactPct, Min = 0.1, Max = 0.5, Rounding = 1,
Callback = function(v) S.impactPct = v end,
})
local logPar = Tabs.Log:CreateParagraph("LogView", { Title = "Events History", Content = "ready." })
local logViewLabel = logPar and logPar.Instance and logPar.Instance.DescLabel
pcall(function()
if logViewLabel then
logViewLabel.AutomaticSize = Enum.AutomaticSize.Y
logViewLabel.Size = UDim2.new(1, 0, 0, 0)
logViewLabel.TextWrapped = true
end
end)
Tabs.Log:CreateButton({
Title = "Clear Logs",
Description = "Clears event history",
Callback = function()
table.clear(Logs)
log("Logs cleared.")
pcall(function()
if logViewLabel and logViewLabel.Parent then logViewLabel.Text = "Logs cleared." end
if logDashLabel and logDashLabel.Parent then logDashLabel.Text = "Logs cleared." end
end)
end,
})
Tabs.Discord:CreateParagraph("DiscordInfo", {
Title = "Zynex Hub Official Discord",
Content = "Join our community for script updates, support, announcements, and upcoming releases!\n\nOfficial Link:\n" .. discordLink,
})
Tabs.Discord:CreateButton({
Title = "Copy Discord Link",
Description = "Copies " .. discordLink .. " to your clipboard",
Callback = function()
pcall(function() setclipboard(discordLink) end)
Fluent:Notify({ Title = "Discord", Content = "Discord link copied to clipboard!", Duration = 3 })
end,
})
pcall(function()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/myheisenberg/Fluent-Renewed/main/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/myheisenberg/Fluent-Renewed/main/Addons/InterfaceManager.luau"))()
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "Run" })
InterfaceManager:SetFolder("RSE2Scalp")
SaveManager:SetFolder("RSE2Scalp/configs")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
Tabs.Settings:CreateParagraph("DiscordInfoSet", {
Title = "Discord Community",
Content = "Join Zynex Hub for script updates, support & announcements:\n" .. discordLink,
})
Tabs.Settings:CreateButton({
Title = "Copy Discord Link",
Callback = function()
pcall(function() setclipboard(discordLink) end)
Fluent:Notify({ Title = "Discord", Content = "Discord link copied to clipboard!", Duration = 3 })
end,
})
end)
_G.RSECRYPTO_CLEANUP = function()
for _, fn in ipairs(_G.RSECRYPTO_INSTANCES) do pcall(fn) end
_G.RSECRYPTO_INSTANCES = {}
end
_G.RSECRYPTO_ALIVE = true
table.insert(_G.RSECRYPTO_INSTANCES, function()
S.running = false
_G.RSECRYPTO_ALIVE = false
pcall(function() Fluent:Destroy() end)
end)
task.spawn(function()
while _G.RSECRYPTO_ALIVE do
elevateThread()
pcall(cryptoCycle)
task.wait(0.5)
end
end)
Window:SelectTab(1)
Fluent.GUI.Enabled = true
disableAutoLocalize(Fluent.GUI)
updateTick = function()
pcall(function()
local open = (State.profile and State.profile.positions) or {}
local parts = {}
for i, pos in ipairs(open) do
if i > 4 then break end
local okP, pv = pcall(marginPnlPct, pos)
parts[#parts + 1] = string.format("%s %+.1f%%", tostring(pos.id), okP and pv or 0)
end
local info = #open > 0 and (#open .. " open: " .. table.concat(parts, ", ")) or "No open positions"
local nw = tonumber((State.netWorth and State.netWorth()) or (State.profile and State.profile.cash) or 0) or 0
local statusStr = string.format("Bot: %s | Cash: $%.0f | Net: $%.0f\nPositions: %s",
S.running and "RUNNING" or "STOPPED",
getCash(),
nw,
info
)
if statLabel and statLabel.Parent then
statLabel.Text = statusStr
elseif statPar and statPar.SetContent then
statPar:SetContent(statusStr)
end
end)
pcall(function()
local open = (State.profile and State.profile.positions) or {}
local lvl, capL, maxP = accountInfo()
local accStr = string.format(
"Level: %d | Leverage Max: %dx\nMax Positions: %d | Open: %d",
lvl, capL, maxP, #open
)
if accLabel and accLabel.Parent then
accLabel.Text = accStr
elseif accPar and accPar.SetContent then
accPar:SetContent(accStr)
end
local slLev = levSlider or (Fluent.Options and Fluent.Options.LevCap)
if slLev then
local newMaxLev = math.max(tonumber(capL) or 30, 1)
local oldMaxLev = slLev.Max or 1
if slLev.Max ~= newMaxLev or slLev._lastLvl ~= lvl then
slLev.Max = newMaxLev
slLev._lastLvl = lvl
local descText = string.format("Account allows up to %dx at level %d (auto-clamped)", newMaxLev, lvl)
if slLev.SetDesc then
pcall(slLev.SetDesc, slLev, descText)
end
if slLev.Instance and slLev.Instance.DescLabel then
slLev.Instance.DescLabel.Text = descText
slLev.Instance.DescLabel.AutoLocalize = false
end
if S.levCap >= oldMaxLev and newMaxLev > oldMaxLev then
S.levCap = newMaxLev
if slLev.SetValue then pcall(slLev.SetValue, slLev, newMaxLev) end
elseif slLev.SetValue and slLev.Value then
pcall(slLev.SetValue, slLev, math.min(slLev.Value, newMaxLev))
end
end
end
local slSim = maxSimSlider or (Fluent.Options and Fluent.Options.MaxSim)
if slSim then
local newMaxPos = math.max(tonumber(maxP) or 28, 1)
local oldMaxPos = slSim.Max or 1
if slSim.Max ~= newMaxPos or slSim._lastLvl ~= lvl then
slSim.Max = newMaxPos
slSim._lastLvl = lvl
local descText = string.format("Account allows up to %d at level %d", newMaxPos, lvl)
if slSim.SetDesc then
pcall(slSim.SetDesc, slSim, descText)
end
if slSim.Instance and slSim.Instance.DescLabel then
slSim.Instance.DescLabel.Text = descText
slSim.Instance.DescLabel.AutoLocalize = false
end
if S.maxSim >= oldMaxPos and newMaxPos > oldMaxPos then
S.maxSim = newMaxPos
if slSim.SetValue then pcall(slSim.SetValue, slSim, newMaxPos) end
elseif slSim.SetValue and slSim.Value then
pcall(slSim.SetValue, slSim, math.min(slSim.Value, newMaxPos))
end
end
end
end)
pcall(function()
local recent = {}
local sIdx = math.max(1, #Logs - 3)
for i = sIdx, #Logs do
table.insert(recent, Logs[i])
end
local dashLogText = #recent > 0 and table.concat(recent, "\n") or "Engine ready and waiting for start."
if logDashLabel and logDashLabel.Parent then
logDashLabel.Text = dashLogText
elseif logParDash and logParDash.SetContent then
logParDash:SetContent(dashLogText)
end
local full = {}
local fIdx = math.max(1, #Logs - 12)
for i = fIdx, #Logs do
table.insert(full, Logs[i])
end
local fullLogText = #full > 0 and table.concat(full, "\n") or "Engine ready and waiting."
if logViewLabel and logViewLabel.Parent then
logViewLabel.Text = fullLogText
elseif logPar and logPar.SetContent then
logPar:SetContent(fullLogText)
end
end)
end
log(string.format("v1 loaded | Cash: $%.0f", getCash()))
log("Engine ready and monitoring.")
elevateThread()
pcall(updateTick)
task.defer(function()
elevateThread()
task.wait(0.2)
elevateThread()
pcall(updateTick)
end)
task.spawn(function()
while _G.RSECRYPTO_ALIVE do
elevateThread()
pcall(updateTick)
task.wait(1)
end
end)
pcall(function()
elevateThread()
Fluent:Notify({ Title = "RSE2 Crypto Scalper v1", Content = "by zynex | Ready & Running", Duration = 4 })
end)