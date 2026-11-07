#!/bin/sh
# Renders raw store screenshots, one flutter_tester process per locale (each
# script needs its own primary font).
# Usage: tool/store/run_store_screenshots.sh [locale ...]   (none = all)
# Output: build/store_raw/<locale>/<n>-<slug>.png
set -e
cd "$(dirname "$0")/../.."
LOCALES=${*:-en-US en-CA en-GB en-AU de nl sv da no fr-FR fr-CA es-ES es-MX it pt-BR pt-PT pl ru tr ar-SA ar hi ur id ja ko th vi zh-Hans zh-Hant}
for l in $LOCALES; do
  STORE_LOCALES=$l flutter test --run-skipped --tags store --concurrency=1 test/store_screenshots >/dev/null 2>&1 || { echo "FAILED $l"; exit 1; }
  echo "ok $l"
done
