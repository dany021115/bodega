---
paths:
  - "apps/bodega/lib/app/presentation/**/*.dart"
  - "apps/bodega/lib/app/shared/widgets/**/*.dart"
---

# Widget Standards

## Structure
- One widget per file in `widgets/`
- Pages read their BLoC; shared pieces go in `app/shared/widgets/`
- If a page provides its own BLoC, split it into `XPage` (provider) and `XView`, so that tests can render the view

## Project Widgets
- `CustomLoading`, never a raw progress indicator
- `EmptyState` for empty sections
- `StatusChip` for states
- `AppIcon` for an app's logo or initial
- `confirm()` before anything that closes or deletes: name the bottle, and say what is lost
- `AppToast` for messages that pass; `SelectableText` for errors worth copying

## Design Tokens
- Text: `AppTextStyle(context)`. Never hardcode a `fontFamily`: `null` is SF Pro
- Spacing: `AppSpacing`. Radius: `AppRadius`
- Color: `Theme.of(context).colorScheme`, or `AppColor` for catalog states and brands. Never `Colors.x` for UI

## Layout
- The window goes down to 720×480, so the content can be 652 px wide
- From `DESKTOP` (801 px): sidebar with text, and two columns in the catalog. Below: icons, and one column
- No fixed heights for what holds text: let it size itself, or scroll it

## Accessibility
- `Semantics(liveRegion: true)` on progress and other text that changes by itself
- `tooltip` on icon-only buttons
- `ExcludeSemantics` on decorative icons
