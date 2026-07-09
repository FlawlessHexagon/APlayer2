# UI Design System
## Styling Guidelines & Brand Tokens

*Prepared July 9, 2026*

*This document defines the core visual identity, typography, and color palette for APlayer2. All Flutter UI development must strictly adhere to these design tokens.*

---

## 1. Typography

- **Primary Font:** `JetBrains Mono`
- **Usage:** JetBrains Mono must be used as the main application font for all text (headings, body, numbers, and UI elements) to give the application a distinct, technical, and precise aesthetic.

---

## 2. Color Palette

The app uses a dark, premium aesthetic centered around deep purples, warm accents, and high-contrast typography.

| Token Name | Hex Value | Suggested Usage |
| :--- | :--- | :--- |
| **Deep Purple** | `#2A1B3D` | Primary App Background, scaffolds, large structural containers. |
| **Purple Accent** | `#3B2755` | Elevated surfaces, cards, interactive elements, bottom sheets. |
| **Beige** | `#D9CBB0` | Primary accent color (active states, primary buttons, seek bar progress). |
| **Off-White** | `#F5F3EF` | Primary text (high contrast against dark backgrounds), active icons. |
| **Mid Grey** | `#8A8580` | Secondary text, inactive icons, subtle borders, track duration labels. |
| **Near-Black** | `#161616` | Deepest shadows, modal overlays, extreme contrast elements. |

---

## 3. Implementation Guidelines

- **Theme Data:** These colors must be mapped directly into Flutter's `ThemeData` (e.g., `scaffoldBackgroundColor`, `colorScheme.surface`, `colorScheme.primary`, etc.).
- **Consistency:** Do not use arbitrary material colors (e.g., standard `Colors.red` or `Colors.blue`). Always reference these hex values.
- **Font Package:** Use the `google_fonts` package to easily integrate JetBrains Mono, or bundle the font files directly in the `assets/fonts` directory.
