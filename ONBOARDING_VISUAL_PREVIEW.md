# 🎨 Onboarding Screen - Visual Preview

## 📱 Screen Layout

```
┌─────────────────────────────────────┐
│  OncoGuide          [Skip]          │  ← Header
├─────────────────────────────────────┤
│                                     │
│                                     │
│         ╭─────────────╮            │
│        ╱               ╲           │
│       │   ◉  ◉  ◉  ◉   │          │  ← Pulsing circles
│       │      🔬         │          │  ← Icon
│        ╲               ╱           │
│         ╰─────────────╯            │  ← Gradient circle
│                                     │
│                                     │
│   AI-Powered Breast Cancer         │  ← Title (Bold, 28px)
│        Detection                    │
│                                     │
│  Advanced machine learning          │  ← Description (16px)
│  algorithms analyze mammograms      │
│  and ultrasounds with high          │
│  accuracy                           │
│                                     │
│  ┌──────────┐ ┌──────────┐        │  ← Feature badges
│  │ Machine  │ │   High   │        │
│  │ Learning │ │ Accuracy │        │
│  └──────────┘ └──────────┘        │
│       ┌──────────┐                 │
│       │   Fast   │                 │
│       │ Results  │                 │
│       └──────────┘                 │
│                                     │
├─────────────────────────────────────┤
│         ● ─── ○ ○ ○                │  ← Page indicators
│                                     │
│  ┌─────────────────────────────┐  │
│  │         Next  →             │  │  ← Gradient button
│  └─────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

---

## 🎨 Page 1: AI-Powered Detection

### Visual Elements:
```
Color Scheme: Pink Gradient
┌──────────────────────┐
│   Gradient Colors    │
│  #FF6F91 → #FF9671  │
└──────────────────────┘

Icon: 🧠 Psychology/Brain
Size: 80px
Color: White

Background:
- Large circle (200x200px)
- Pink gradient fill
- Pulsing white circles (180px, 150px)
- Soft shadow (blur: 40px)

Feature Badges:
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Machine     │  │    High      │  │    Fast      │
│  Learning    │  │  Accuracy    │  │   Results    │
└──────────────┘  └──────────────┘  └──────────────┘
   Pink tint         Pink tint         Pink tint
```

---

## 📊 Page 2: Risk Assessment

### Visual Elements:
```
Color Scheme: Purple Gradient
┌──────────────────────┐
│   Gradient Colors    │
│  #6C63FF → #9D8CFF  │
└──────────────────────┘

Icon: 📊 Analytics
Size: 80px
Color: White

Background:
- Large circle (200x200px)
- Purple gradient fill
- Pulsing white circles
- Soft shadow

Feature Badges:
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Personalized │  │   Clinical   │  │    SHAP      │
│              │  │     Data     │  │  Analysis    │
└──────────────┘  └──────────────┘  └──────────────┘
  Purple tint       Purple tint       Purple tint
```

---

## ✅ Page 3: Smart Recommendations

### Visual Elements:
```
Color Scheme: Green Gradient
┌──────────────────────┐
│   Gradient Colors    │
│  #10B981 → #34D399  │
└──────────────────────┘

Icon: ✓ Checkmark
Size: 80px
Color: White

Background:
- Large circle (200x200px)
- Green gradient fill
- Pulsing white circles
- Soft shadow

Feature Badges:
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Evidence-   │  │     WHO      │  │  Actionable  │
│    Based     │  │  Guidelines  │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
   Green tint        Green tint        Green tint
```

---

## 🔒 Page 4: Security

### Visual Elements:
```
Color Scheme: Blue Gradient
┌──────────────────────┐
│   Gradient Colors    │
│  #3B82F6 → #60A5FA  │
└──────────────────────┘

Icon: 🔒 Lock/Security
Size: 80px
Color: White

Background:
- Large circle (200x200px)
- Blue gradient fill
- Pulsing white circles
- Soft shadow

Feature Badges:
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Encrypted   │  │    HIPAA     │  │   Private    │
│              │  │  Compliant   │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
    Blue tint         Blue tint         Blue tint
```

---

## 🎬 Animation Timeline

### Page Load (0-800ms)
```
0ms    ─────────────────────────────────────
       │
100ms  │ ┌─ Logo FadeInDown + ZoomIn
       │ │
300ms  │ ├─ Title FadeInUp
       │ │
500ms  │ ├─ Description FadeInUp
       │ │
700ms  │ └─ Badges FadeInUp
       │
800ms  └─ All elements visible
```

### Continuous Animations
```
Pulse Animation (Infinite):
  ┌─────────────────────────────────┐
  │  Circle 1: 2s cycle             │
  │  ○ → ◉ → ○ (expand/contract)   │
  │                                 │
  │  Circle 2: 2s cycle (500ms delay)│
  │  ○ → ◉ → ○                      │
  └─────────────────────────────────┘
```

### Page Transition (400ms)
```
Swipe Left/Right:
  ┌─────────────────────────────────┐
  │  Current Page                   │
  │  ─────────────────→             │
  │              Next Page           │
  └─────────────────────────────────┘
  Duration: 400ms
  Curve: easeInOut
```

---

## 📐 Spacing & Dimensions

### Vertical Spacing:
```
┌─────────────────────────────────┐
│  Header (16px padding)          │
├─────────────────────────────────┤
│  ↕ Flexible space               │
│                                 │
│  Circle (200x200px)             │
│                                 │
│  ↕ 60px                         │
│                                 │
│  Title (28px font)              │
│                                 │
│  ↕ 20px                         │
│                                 │
│  Description (16px font)        │
│                                 │
│  ↕ 40px                         │
│                                 │
│  Badges (wrap)                  │
│                                 │
│  ↕ Flexible space               │
├─────────────────────────────────┤
│  Indicators (20px padding)      │
├─────────────────────────────────┤
│  Button (56px height)           │
│  (32px bottom padding)          │
└─────────────────────────────────┘
```

### Horizontal Spacing:
```
┌─────────────────────────────────┐
│ 16px │ Content │ 16px           │  ← Header
│                                 │
│ 32px │ Content │ 32px           │  ← Main content
│                                 │
│ 24px │ Button  │ 24px           │  ← Button
└─────────────────────────────────┘
```

---

## 🎨 Color Palette

### Page 1 - Pink
```
Primary:   #FF6F91 ████████
Secondary: #FF9671 ████████
Shadow:    #FF6F91 (30% opacity)
```

### Page 2 - Purple
```
Primary:   #6C63FF ████████
Secondary: #9D8CFF ████████
Shadow:    #6C63FF (30% opacity)
```

### Page 3 - Green
```
Primary:   #10B981 ████████
Secondary: #34D399 ████████
Shadow:    #10B981 (30% opacity)
```

### Page 4 - Blue
```
Primary:   #3B82F6 ████████
Secondary: #60A5FA ████████
Shadow:    #3B82F6 (30% opacity)
```

---

## 🔘 Interactive Elements

### Skip Button
```
┌──────────┐
│   Skip   │  ← TextButton
└──────────┘
Font: 15px, Semi-bold
Color: Text Secondary
Padding: 8px
```

### Page Indicators
```
Active:    ──────  (32x8px, gradient)
Inactive:  ●       (8x8px, gray 30%)
Spacing:   4px between dots
```

### Next/Get Started Button
```
┌─────────────────────────────────┐
│         Next  →                 │  ← Full width
└─────────────────────────────────┘
Height: 56px
Border Radius: 16px
Gradient: Current page gradient
Shadow: 20px blur, 10px offset
Font: 17px, Bold, White
```

---

## 📱 Responsive Behavior

### Portrait (Default)
```
┌─────────────┐
│             │
│   Content   │
│   Centered  │
│             │
└─────────────┘
```

### Landscape (Adapts)
```
┌─────────────────────────────────┐
│  Content adjusts to fit         │
│  Circle size may reduce         │
└─────────────────────────────────┘
```

---

## 🌓 Dark Mode Support

### Light Mode
```
Background: White / Light Gray
Text Primary: Dark Gray / Black
Text Secondary: Medium Gray
```

### Dark Mode
```
Background: Dark Gray / Black
Text Primary: White / Light Gray
Text Secondary: Medium Gray
Gradients: Same (vibrant colors work in both)
```

---

## ✨ Special Effects

### Gradient Button Shadow
```
┌─────────────────────────────────┐
│         Button Text             │
└─────────────────────────────────┘
         ╲                ╱
          ╲              ╱
           ╲            ╱  ← Soft shadow
            ╲          ╱     (20px blur)
             ╲        ╱
              ╲      ╱
               ╲    ╱
                ╲  ╱
                 ╲╱
```

### Pulsing Circles
```
Frame 1:  ○ (small)
Frame 2:  ◉ (medium)
Frame 3:  ⬤ (large)
Frame 4:  ◉ (medium)
Frame 5:  ○ (small)
Repeat infinitely
```

### Page Swipe
```
Before:  [Page 1] [Page 2]
         ↓
During:  [Page 1→] [←Page 2]
         ↓
After:   [Page 2] [Page 3]
```

---

## 🎯 User Flow

```
┌─────────────────┐
│  App Launch     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Splash Screen  │  (3 seconds)
└────────┬────────┘
         │
         ▼
    ┌────────────┐
    │ First time?│
    └─────┬──────┘
          │
    ┌─────┴─────┐
    │           │
   Yes         No
    │           │
    ▼           ▼
┌────────┐  ┌────────┐
│Onboard │  │ Login  │
│Screen  │  │ Screen │
└───┬────┘  └────────┘
    │
    ▼
┌────────┐
│ Login  │
│ Screen │
└────────┘
```

---

**This visual preview helps you understand the onboarding design without running the app!**
