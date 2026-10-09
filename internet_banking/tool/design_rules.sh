#!/usr/bin/env bash
# Design-system and logging rules for lib/. Each rule has a ceiling: the build fails
# if the count goes above it. Ceilings start at the counts when the rule was added
# and only ever go down: lower one in the same change that removes violations.
# Run from internet_banking/: bash tool/design_rules.sh
set -euo pipefail

failed=0

check() {
  local name="$1" ceiling="$2" count="$3" hint="$4"
  if (( count > ceiling )); then
    echo "FAIL  $name: $count (allowed $ceiling). $hint"
    failed=1
  elif (( count < ceiling )); then
    echo "ok    $name: $count (allowed $ceiling; lower the ceiling to $count)"
  else
    echo "ok    $name: $count"
  fi
}

count() { grep -rnE "$1" lib --include='*.dart' | grep -vE "$2" | wc -l | tr -d ' '; }

check "Fonts set outside the theme" 181 \
  "$(count 'GoogleFonts\.' '^lib/theme/|GoogleFonts\.config')" \
  "Use context.text (the theme's TextTheme) instead of GoogleFonts.*."

check "Named Material colours outside the palette" 17 \
  "$(count 'Colors\.(black|red|green|grey|gray|blue|orange|amber|yellow|purple|pink|teal|cyan|indigo|brown|lime|deepOrange|deepPurple|lightBlue|lightGreen|blueGrey)' '^lib/theme/')" \
  "Use context.colors tokens (AppColors)."

check "Hex colours outside the palette" 8 \
  "$(count 'Color\(0x' '^lib/theme/|transaction_category\.dart|iban_bank_detector\.dart|^lib/l10n/')" \
  "Add the colour to AppColors (both themes) and use the token."

check "Deprecated withOpacity" 0 \
  "$(count '\.withOpacity\(' '^$')" \
  "Use .withValues(alpha: ...)."

check "print/debugPrint (logs reach release builds)" 0 \
  "$(count '(^|[^a-zA-Z_.])(print|debugPrint)\(' 'lib/core/utils/app_log\.dart')" \
  "Use AppLog.debug, which prints nothing in release builds."

check "Spacing written as raw numbers" 140 \
  "$(count 'EdgeInsets\.(all|symmetric|only|fromLTRB)\(' 'AppSpacing')" \
  "Use AppSpacing tokens."

exit $failed
