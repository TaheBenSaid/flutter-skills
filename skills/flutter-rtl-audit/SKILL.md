---
name: flutter-rtl-audit
description: Find and fix right-to-left (RTL) layout bugs in a Flutter app so it works in Arabic, Hebrew, Persian and Urdu. Use when the user mentions RTL, Arabic support, mirrored layouts, "the app looks wrong in Arabic", EdgeInsets left/right, icons that don't flip, Arabic plurals, or scrambled phone numbers.
---

# Flutter RTL audit

The scanner is `scripts/rtl_audit.dart` in this skill's folder. It has no dependencies, so it runs anywhere Dart runs.

## Steps

1. From the Flutter project root, scan:

   ```bash
   dart <this-skill>/scripts/rtl_audit.dart lib
   ```

   The report has two parts: findings it can fix automatically, and findings that need a decision.

2. Show the user the summary line and the "Needs a decision" list. Don't paste the whole report if it's long.

3. If the user wants fixes, apply the safe ones:

   ```bash
   dart <this-skill>/scripts/rtl_audit.dart lib --fix
   ```

4. Run `flutter analyze`. A few APIs take `EdgeInsets` or `BorderRadius` and reject the directional versions, for example `TextField.scrollPadding` and `InkWell.borderRadius`. For those, either revert that one change or resolve it with `.resolve(Directionality.of(context))`.

5. Go through "Needs a decision" one by one, using the guide below. Ask the user when the right answer depends on the design.

6. Finish with the mirror test. Run the app in Arabic, take a screenshot, and compare it with English. Layout, padding, arrows and text alignment should be mirrored. Numbers, media controls, logos and photos should look the same.

## Decisions

**Directional assets.** Back arrows, chevrons, "next" and "send" icons should flip. Add `matchTextDirection: true` to `Image.asset` or `SvgPicture.asset`. Material's `Icons.arrow_back` and `Icons.chevron_right` already flip on their own. Play, pause and seek icons, checkmarks and logos should not flip.

**Gradients.** `Alignment.topLeft` in a gradient is often decorative. Only switch to `AlignmentDirectional` if the design should mirror.

**Plurals.** Arabic has six plural forms, so `'$count messages'` or `count == 1 ? ... : ...` breaks. Move it to the ARB files:

```json
"messages": "{count, plural, =0{No messages} =1{1 message} other{{count} messages}}"
```

```json
"messages": "{count, plural, =0{لا توجد رسائل} =1{رسالة واحدة} =2{رسالتان} few{{count} رسائل} many{{count} رسالة} other{{count} رسالة}}"
```

**Phone numbers, card numbers, IBANs.** Inside Arabic text, the digit groups get reordered. Set `textDirection: TextDirection.ltr` on the `Text` or `TextField` that shows them. Inside a sentence, wrap the number in `⁦` and `⁩` (left-to-right isolate).

**Dates and numbers.** Pass the locale: `DateFormat.yMMMd(locale)`, `NumberFormat.percentPattern(locale)`. Never assemble dates or percentages by hand.

**Reversed children.** `Row`, `ListView` and `Wrap` already follow `Directionality`. Reversing children for Arabic flips them back to LTR. Remove the `.reversed` unless the order really should change.

## Not covered by the scanner

Read through these by hand if the user wants a full pass:

- Fixed-width buttons and chips that cut off longer Arabic labels.
- An Arabic font missing for the Arabic locale, so the text falls back to a system font.
- Hardcoded `TextDirection.rtl` or `TextDirection.ltr` on whole screens.
- Swipe gestures and slide-in animations that use a fixed horizontal direction.
