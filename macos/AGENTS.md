# Native macOS UI instructions

## UI control rules

- Never ship unstyled/default macOS buttons, gray beveled controls, stock popup pickers, or expanding native menu bars inside application screens or sheets. This includes secondary actions and empty states, not only primary CTAs.
- Use shared Lemma design-system button, input, and selection controls with explicit typography, padding, hover/focus/disabled states, and intrinsic widths. Native OS file dialogs and system confirmation alerts are exempt.
- Primary actions get one restrained color accent; secondary actions use quiet outlined or text treatments. Reuse Textbook's established tool colors.
- Keep management flows compact: selectable file rows with inline actions, one clear primary action, and content-sized sheets. Do not add a separate picker when the same decision can be made in the existing list.
- Implement shared controls once and reuse them. Inspect every new screen, menu trigger, empty state, and sheet for accidental native chrome before handoff.
