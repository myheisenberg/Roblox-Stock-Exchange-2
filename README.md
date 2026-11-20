# 📈 Roblox Stock Exchange 2 (RSE2) - Auto Scalper Bot v1

An automated, smart multi-position crypto trading bot for **Roblox Stock Exchange 2 (RSE2)** built with **Fluent UI Renewed**. Features curve predictive exits, extreme peak detection, impact-budgeted position sizing, auto-adaptive account leveling, and live metrics.

---

### ⚡ Key Features
- **100% Keyless:** Execute and profit immediately with zero link checkpoints or ads.
- **Predictive Curve Analysis:** Reads future price movement (`PE.priceAt`) to exit *before* sharp adverse reversals occur.
- **Peak / Valley Detection:** Detects theoretical extremes and closes positions at peak profitability.
- **Impact-Aware Sizing:** Automatically calculates market liquidity and impact budget so large trades don't eat into profits.
- **Multi-Position Engine:** Dynamically enters the best ranked cryptocurrency opportunities simultaneously (up to 8 positions).
- **Auto-Adaptive Leveling:** Automatically queries and clamps to your account's maximum unlocked leverage and position limits.
- **Live Fluent Dashboard:** Real-time net worth, cash, open PnL percentages, and detailed execution logs.

---

### 🚀 Quick Start / Loader

Paste the following into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/myheisenberg/Roblox-Stock-Exchange-2/main/loader.luau"))()
```

---

### 💬 Community & Support
Join our official Discord server for updates, future script releases, and community discussions:
👉 **[Join Zynex Hub Discord](https://discord.gg/ehbX2MVbTw)**
