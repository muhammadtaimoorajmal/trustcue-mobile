# TrustCue Design Specification

**Purpose:** To guide the implementation of TrustCue's visual interface. TrustCue helps users understand potential warning signs in suspicious digital communication. The interface must feel calm, clear, approachable, and objective.

## A. Brand Expression
- **Palette:** A restrained combination of deep navy, teal, and neutral surfaces.
- **Visual Motif:** Subtle use of highlighted message excerpts and quotation marks, echoing the Evidence Trail.
- **Identity:** The application relies on the TrustCue text wordmark. Launcher icons and store assets are planned for a later phase.
- **Hierarchy:** Established through whitespace, typography, and clear grouping rather than heavy borders or bright background fills.

## B. Color Roles
**Note:** Brand colors are separate from analysis meanings. A teal action button does not imply a message is safe.

| Role | Light Theme Candidate | Dark Theme Candidate | Intended Use |
| :--- | :--- | :--- | :--- |
| **Primary Action** | `#00695C` (Dark Teal) | `#4DB6AC` (Light Teal) | Primary buttons, active states, key interactive elements. |
| **Action Foreground** | `#FFFFFF` | `#00332C` | Text and icons placed on top of the Primary Action color. |
| **App Bar / Header** | `#0A2540` (Deep Navy) | `#121212` (Very Dark Grey)| Branding bar and top-level navigation. |
| **Header Foreground** | `#FFFFFF` | `#FFFFFF` | Text and icons on the App Bar. |
| **Page Surface** | `#F8F9FA` (Off-White) | `#121212` (Very Dark Grey) | The main background of screens. |
| **Card Surface** | `#FFFFFF` (Pure White) | `#1E1E1E` (Dark Grey) | Elevated containers, message excerpts, evidence cards. |
| **Primary Text** | `#111111` | `#EEEEEE` | Standard body text, headings. |
| **Secondary Text** | `#555555` | `#AAAAAA` | Supporting text, timestamps, subtitles. |
| **Borders & Dividers** | `#E0E0E0` | `#333333` | Separating sections and outlining cards. |
| **Caution** | `#FFB300` | `#FFCA28` | Uncertainty, warning signs, "needs review". |
| **Caution Foreground** | `#332200` | `#332200` | Text/icons on caution backgrounds. |
| **Error** | `#D32F2F` | `#EF5350` | Failures, processing errors, system alerts. |
| **Error Foreground** | `#FFFFFF` | `#000000` | Text/icons on error backgrounds. |
| **Success** | `#388E3C` | `#66BB6A` | Successful operations (e.g., "Saved to history"). |

### Contrast Measurements (WCAG AA Method)
- Light Theme Text (`#111111`) on Surface (`#F8F9FA`): **Passes >4.5:1**
- Dark Theme Text (`#EEEEEE`) on Surface (`#121212`): **Passes >4.5:1**
- Light Primary Action (`#00695C`) with Foreground (`#FFFFFF`): **~6.61:1** (Passes >4.5:1)
- Dark Primary Action (`#4DB6AC`) with Foreground (`#0A2540`): **~6.36:1** (Passes >4.5:1)
- Deep Navy (`#0A2540`) on Light Surface (`#F8F9FA`): **~14.74:1** (Passes >4.5:1)
- Caution (`#FFB300`) with Foreground (`#332200`): **Passes >4.5:1**

## C. Typography and Layout
- **Font Strategy:** Use standard system fonts (`Roboto` on Android, `San Francisco` on iOS, etc.) to ensure no network font downloads are required and text renders perfectly out-of-the-box.
- **Hierarchy:**
  - *Headings:* Bold, clear.
  - *Body Text:* 16 logical pixels starting size.
  - *Supporting Text:* 14 logical pixels.
  - *Labels:* 14 logical pixels, medium weight.
- **Spacing Scale:** 4px, 8px, 16px, 24px, 32px.
- **Corner Radii:** 12px for cards and dialogs, 8px for buttons.
- **Layout & Readability:**
  - Limit line lengths to ~60-70 characters for comfortable reading of explanations.
  - Support enlarged text (scaling up to 200%) by avoiding fixed-height containers that clip text.
  - Long quoted messages should be contained in scrollable or expandable cards with clear visual boundaries (e.g. left border accent).

## D. Accessibility Requirements
- **Contrast:** Maintain at least 4.5:1 contrast ratio for all text against backgrounds.
- **Tap Targets:** Interactive elements must have at least 48x48 logical-pixel touch targets.
- **Color Independence:** Meaning must be communicated through text and icons, not color alone (e.g., an error must have an icon/text indicating failure, not just red color).
- **Dynamic Type:** All screens must accommodate up to 200% system font scaling gracefully.
- **Screen Readers:** Ensure meaningful screen-reader labels and logical reading order.
- **Motion:** Respect system accessibility preferences for reduced motion; minimize unnecessary animations.

## E. Product Language
TrustCue's tone is objective, respectful, and clear. It does not invent confidence percentages or make guaranteed protection claims.

**Examples of proper wording:**
- *"Potential warning signs"* (Not "100% Scam")
- *"Review extracted text"*
- *"Verify through an official channel"*
- *"We could not complete the analysis. Please try again."*
- *"No warning signs detected. This does not guarantee the message is safe."*

Keep application/system errors distinctly separate from findings about a message.

## F. Information Hierarchy
*These structures guide future implementation:*

1. **Starting a Check:** Clear input mechanism (paste text / upload screenshot), separated from recent history.
2. **Reviewing Text:** Showing exactly what was extracted, allowing the user to edit or redact private information before analysis.
3. **Processing Notice:** A clear explanation of what is being sent to the AI, establishing privacy boundaries.
4. **Evidence Trail (Results):**
   - The specific message excerpt.
   - Why it was flagged (the evidence).
   - What remains uncertain.
   - Recommended safer verification steps.
