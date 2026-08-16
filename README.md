# MBA Benefit Cycle — Maintenance Handoff

**System:** MBA-100 / MBA-200 / MBA-300 / MBA-400 ("the benefit cycle")
**Owner of record:** Meridian State Benefits Agency, Division of Application Services
**Document status:** handoff notes, revised on each maintainer change
**Everything in this repository is fictional.** The agency, the counties, the
claimants, the staff names and the policy constants were invented for this
exercise. There is no real program or real claimant data here.

---

## 1. What this system does

Once per month the agency determines who is eligible for a benefit, works out
how much they get, splits the award into two installments, and prints a payment
register for the county offices. Four COBOL batch programs do that, chained by
`jcl/NIGHTLY.JCL`:

| Load module | Source | Job step | Function |
|-------------|--------|----------|----------|
| MBA100 | `src/cobol/ELIGCALC.CBL` | `ELIGSTEP` | Eligibility determination |
| MBA200 | `src/cobol/BENEFITS.CBL` | `BENESTEP` | Benefit amount calculation |
| MBA300 | `src/cobol/PAYCALC.CBL`  | `PAYSTEP`  | Payment scheduling |
| MBA400 | `src/cobol/REPTGEN.CBL`  | `REPTSTEP` | MBA-400 payment register |

Everything between the programs is a fixed 80 byte flat file described by a
copybook in `src/copybooks/`. Nothing is a database. Nothing is online.
See `docs/ARCHITECTURE.md` for the data flow and record layouts.

## 2. Why it still runs

Three attempts to replace it are on file (1998 client/server pilot, 2009
package evaluation, 2017 "platform modernization" program). None of them
reached the payment register. The reasons it survived all three:

* **It is correct.** The county offices reconcile to the penny against MBA-400
  and have done so for decades. Any replacement inherits that bar, including
  the rounding behaviour documented in section 4.
* **The rules live in the code.** There is no policy engine and no parameter
  file. Roughly fifteen years of statute changes are expressed as edits to
  `WSCONST.CPY` and to the paragraph order in `ELIGCALC`. Nobody has a written
  specification that matches production — the code *is* the specification.
* **The consumers are not ours.** The determination file layout is read by a
  county extract job that Application Services does not own and cannot
  schedule. Field order in `BENEFIT.CPY` is effectively frozen.
* **It costs almost nothing to run.** The full cycle finishes inside its
  window with room to spare, so it never competes for funding.

## 3. Who to call (fictional)

| Role | Name | Notes |
|------|------|-------|
| Original author | Dolores Halvorsen | Wrote MBA100/200/400 in 1984. Retired 2004. Answers questions as a courtesy, not under contract. |
| Second maintainer | Rufus Okonkwo | Wrote MBA300, the partial month rule and the round indicator. Retired 2016. |
| Current maintainer | Marguerite Treadaway | Application Services. Sole person who has changed this code since 2011. |
| Batch operations | Bernard Quill | Owns the cycle schedule and the `PAYCYCLE` control card. Update the warrant seed before every cycle. |
| Program policy | Inés Bracamonte | Office of Program Policy. Approves any change to a constant in `WSCONST.CPY`. |
| County liaison | Harlan Voss | Fields the calls when the register looks wrong. |

## 4. Risk register — read before changing anything

Ordered most dangerous first.

1. **`ELIGCALC` (MBA100) — highest risk.** Every downstream amount comes from
   its determination record. Its `PROCEDURE DIVISION` is a single `GO TO`
   controlled flow with nine exit paths, and the order of the tests is
   load bearing: the disability disregard was moved ahead of the income band
   test in 1990, which changed roughly 400 awards, was backed out once, and
   then reinstated. Reordering paragraphs changes benefit outcomes.
2. **Rounding in `BENEFITS` (MBA200).** The proration is computed twice on
   purpose — once `ROUNDED`, once truncated — into `COMP-3` work fields, and
   the disagreement is stamped into `BN-ROUND-IND`. That indicator feeds a
   state report. Consolidating the two `COMPUTE` statements silently changes
   pennies on partial month awards. Fixture `MB1000105 ESTERBROOK` exists
   specifically to pin this: gross `460.33`, 15 eligible days,
   `460.33 * 15 / 30 = 230.165`, which `ROUNDED` gives `230.17` and truncation
   gives `230.16`.
3. **Warrant numbering in `PAYCALC` (MBA300).** The seed comes from the control
   card, not from the file. A stale card reissues warrant numbers, which means
   manual reconciliation with the Treasurer's office. This happened in 1992.
4. **Sort dependence in `REPTGEN` (MBA400).** MBA400 does not sort and does not
   check sequence. If `SORTSTEP` is skipped or its `SORT FIELDS` are changed,
   the register prints repeated county breaks and wrong subtotals, and nobody
   notices until the county offices call.
5. **Frozen record layouts.** `CLAIMANT.CPY` and `BENEFIT.CPY` are read by
   jobs outside this repository. Adding a field means consuming reserved
   `FILLER`, never lengthening the record.
6. **Hard coded policy constants.** Every rate change is a recompile plus a
   golden file rebaseline. There is no parameter file, despite the 1984 design
   note promising one "next fiscal year".

## 5. Running the cycle locally

The programs are ordinary COBOL and build with GnuCOBOL. The DD names in the
`SELECT` clauses are resolved from `DD_<ddname>` environment variables, which is
why the test harness reads like the JCL.

```sh
sudo apt-get install -y gnucobol      # or brew install gnu-cobol
./tests/run_golden_tests.sh
```

The harness compiles all four modules, runs the five job steps against the
fixtures in `data/golden/input/`, and byte compares every output against
`data/golden/expected/`. It must pass before any change is proposed; see
`tests/README.md` for what a rebaseline means and who has to approve one.

## 6. Repository layout

```
src/cobol/       ELIGCALC.CBL BENEFITS.CBL PAYCALC.CBL REPTGEN.CBL
src/copybooks/   CLAIMANT.CPY BENEFIT.CPY WSCONST.CPY
jcl/             NIGHTLY.JCL (full cycle)  ELIGRUN.JCL (MBA100 rerun)
data/golden/     input fixtures and baselined expected outputs
tests/           golden file harness
docs/            ARCHITECTURE.md  MODERNIZATION_BACKLOG.md
```
