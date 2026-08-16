#!/usr/bin/env bash
#
# MBA GOLDEN FILE TEST HARNESS
#
# Compiles the four batch modules with GnuCOBOL, runs the same step
# sequence that NIGHTLY.JCL runs on the host, and compares every output
# byte for byte against the baselined expected files in data/golden.
#
# The DD names in the COBOL SELECT clauses are resolved by GnuCOBOL
# through DD_<ddname> environment variables, so the step definitions
# below read almost exactly like the DD cards in the JCL.
#
#   ./tests/run_golden_tests.sh              run the suite
#   ./tests/run_golden_tests.sh --rebaseline overwrite the expected files
#
# A REBASELINE IS A POLICY DECISION, NOT A BUILD STEP.  See tests/README.md.
#
set -u

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

SRC="$ROOT/src/cobol"
CPY="$ROOT/src/copybooks"
IN="$ROOT/data/golden/input"
EXPECT="$ROOT/data/golden/expected"
WORK="$ROOT/build/work"
LOAD="$ROOT/build/load"

REBASELINE="no"
if [ "${1:-}" = "--rebaseline" ]; then
  REBASELINE="yes"
fi

PASS=0
FAIL=0

banner() { printf '%s\n' "----------------------------------------------------------------"; }

die() { printf 'HARNESS ERROR: %s\n' "$1" >&2; exit 99; }

command -v cobc >/dev/null 2>&1 || die "cobc (GnuCOBOL) not found on PATH"

rm -rf "$WORK" "$LOAD"
mkdir -p "$WORK" "$LOAD" "$EXPECT"

banner
echo "STEP COMPILE   - GnuCOBOL $(cobc --version | head -1 | awk '{print $3}')"
banner
for pgm in BENEFITS PAYCALC REPTGEN; do
  if cobc -x -Wall -I "$CPY" -o "$LOAD/$pgm" "$SRC/$pgm.CBL" 2>"$WORK/$pgm.cobc.log"; then
    echo "  COMPILE $pgm ... OK"
  else
    echo "  COMPILE $pgm ... FAILED"
    cat "$WORK/$pgm.cobc.log"
    exit 99
  fi
done

# ---------------------------------------------------------------------
# compare <expected-name> <actual-file>
# ---------------------------------------------------------------------
compare() {
  name="$1"
  actual="$2"
  want="$EXPECT/$name"

  if [ ! -f "$actual" ]; then
    echo "  ASSERT $name ... FAILED (step produced no output)"
    FAIL=$((FAIL + 1))
    return
  fi

  if [ "$REBASELINE" = "yes" ]; then
    cp "$actual" "$want"
    echo "  BASELINE $name ... written ($(wc -l < "$want" | tr -d ' ') lines)"
    return
  fi

  if [ ! -f "$want" ]; then
    echo "  ASSERT $name ... FAILED (no baseline; run --rebaseline)"
    FAIL=$((FAIL + 1))
    return
  fi

  if cmp -s "$want" "$actual"; then
    echo "  ASSERT $name ... PASS (byte exact, $(wc -l < "$actual" | tr -d ' ') lines)"
    PASS=$((PASS + 1))
  else
    echo "  ASSERT $name ... FAILED (byte compare)"
    diff "$want" "$actual" | head -20
    FAIL=$((FAIL + 1))
  fi
}

banner
echo "STEP ELIGSTEP  - MBA100 ELIGCALC  eligibility determination (Python)"
banner
PYTHONPATH="$ROOT/src/python" \
DD_CLAIMIN="$IN/CLAIMANT.DAT" \
DD_ELIGOUT="$WORK/ELIG.DAT" \
DD_ELIGAUD="$WORK/ELIGCALC.AUD" \
  python3 -m mba100.eligcalc || die "ELIGCALC returned RC=$?"
compare ELIG.DAT     "$WORK/ELIG.DAT"
compare ELIGCALC.AUD "$WORK/ELIGCALC.AUD"

banner
echo "STEP BENESTEP  - MBA200 BENEFITS  benefit amount calculation"
banner
DD_BENEIN="$WORK/ELIG.DAT" \
DD_BENEOUT="$WORK/BENEFIT.DAT" \
DD_BENEAUD="$WORK/BENEFITS.AUD" \
  "$LOAD/BENEFITS" || die "BENEFITS returned RC=$?"
compare BENEFIT.DAT  "$WORK/BENEFIT.DAT"
compare BENEFITS.AUD "$WORK/BENEFITS.AUD"

banner
echo "STEP PAYSTEP   - MBA300 PAYCALC   payment scheduling"
banner
DD_PAYIN="$WORK/BENEFIT.DAT" \
DD_PAYCTL="$IN/PAYCYCLE.CTL" \
DD_PAYOUT="$WORK/PAYMENT.DAT" \
DD_PAYAUD="$WORK/PAYCALC.AUD" \
  "$LOAD/PAYCALC" || die "PAYCALC returned RC=$?"
compare PAYMENT.DAT  "$WORK/PAYMENT.DAT"
compare PAYCALC.AUD  "$WORK/PAYCALC.AUD"

banner
echo "STEP SORTSTEP  - county / case sequence for MBA400"
banner
# Stands in for the DFSORT step in NIGHTLY.JCL:
#   SORT FIELDS=(10,3,CH,A,1,9,CH,A)
LC_ALL=C sort -k1.10,1.12 -k1.1,1.9 "$WORK/PAYMENT.DAT" > "$WORK/PAYSORT.DAT"
compare PAYSORT.DAT  "$WORK/PAYSORT.DAT"

banner
echo "STEP REPTSTEP  - MBA400 REPTGEN   payment register"
banner
DD_REPTIN="$WORK/PAYSORT.DAT" \
DD_REPTCTL="$IN/PAYCYCLE.CTL" \
DD_REPTOUT="$WORK/REGISTER.TXT" \
  "$LOAD/REPTGEN" || die "REPTGEN returned RC=$?"
compare REGISTER.TXT "$WORK/REGISTER.TXT"

banner
if [ "$REBASELINE" = "yes" ]; then
  echo "REBASELINE COMPLETE - review the diff before committing"
  banner
  exit 0
fi
printf 'GOLDEN FILE RESULTS   PASS %d   FAIL %d\n' "$PASS" "$FAIL"
banner
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
