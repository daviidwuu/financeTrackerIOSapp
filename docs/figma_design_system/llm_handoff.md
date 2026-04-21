# 🤖 Figma Design & Flow Orchestration Guide

**Target Audience**: AI / LLM Agents acting as Figma designers.
**Objective**: Build a high-fidelity Figma file including Local Styles, Components, and Prototyping flows.

---

## 🏗️ 1. Project Scaffolding

### Core Tokens
- **Grid**: 4px / Standard iPhone 15 Pro (393x852)
- **Colors**: Variables for `backgroundPrimary`, `cardBackground`, `themeAccent`.
- **Typography**: SF Pro / SF Pro Rounded.

---

## 🗺️ 2. User Flows & Navigation Logic

| Trigger | Source Screen | Target Screen | Presentation |
| :--- | :--- | :--- | :--- |
| Login Success | Login | Home | Replace Root |
| Reset App | Settings | Welcome | Replace Root |
| Tap Tab 0 | Any | Home | Switch Tab |
| Tap Tab 1 | Any | Social | Switch Tab |
| Tap Tab 2 | Any | Wallet | Switch Tab |
| Tap Tab 3 | Any | Add Transaction | **Modal Sheet** |
| Tap Avatar | Home | Profile | **Full Screen Cover** |
| Deep Link | Any | Daily Summary | **Modal Sheet** |

---

## 🎨 3. Branding & Entry Visuals

### Welcome Screen Assets
- **Main Logo**: 120x120 White Circle. Shadow: Color #FFFFFF at 30%, Blur 20, Y 10.
- **"Get Started" Button**: Primary White background, black text. Shadow: Color #FFFFFF at 30%, Blur 10, Y 5.

---

## 🧠 4. Conditional Layout Logic (Machine-readable)

```json
{
  "Premium_Check": {
    "condition": "AppState.isPremiumUser == true",
    "effect": "Show PremiumBadge(type: .king/.pro/.saver)",
    "location": "Header, Profile, Social Rows"
  },
  "Streak_Check": {
    "condition": "AppState.streakCount > 0",
    "effect": "Show Flame Pill with count",
    "location": "Home Header"
  }
}
```

---

## 🎯 5. Prototyping Interactions

- **Navigation Transitions**: Use `Move In` (Right-to-Left) for standard push.
- **Sheet Transitions**: Use `Move In` (Bottom-to-Top) for all Modal Sheets.
- **Micro-animations**: Smart Animate Scale down to 98% on "While Pressing".
