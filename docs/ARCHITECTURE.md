# MBA Benefit Cycle — Architecture

Fictional system, fictional agency, fictional data. See `README.md`.

## 1. Data flow

```
        MBA.PROD.CLAIMANT.EXTRACT           (80 bytes, CLAIMANT.CPY)
                    |
                    v
   ELIGSTEP  +---------------+   ELIGAUD ->  MBA.PROD.ELIG.AUDIT
             |    MBA100     |
             |   ELIGCALC    |   eligibility determination
             +---------------+
                    |  determination file (80 bytes, ELIG-RECORD)
                    v
   BENESTEP  +---------------+   BENEAUD ->  MBA.PROD.BENE.AUDIT
             |    MBA200     |
             |   BENEFITS    |   benefit amount, COMP-3 arithmetic
             +---------------+
                    |  benefit amount file (80 bytes, BENEFIT-RECORD)
                    v
   PAYSTEP   +---------------+   PAYAUD ->   MBA.PROD.PAY.AUDIT
             |    MBA300     | <--- PAYCTL  MBA.PROD.PARMLIB(PAYCYCLE)
             |    PAYCALC    |   two installments per award
             +---------------+
                    |  payment schedule (80 bytes, PAYMENT-RECORD)
                    v
   SORTSTEP  +---------------+
             |    DFSORT     |   SORT FIELDS=(10,3,CH,A,1,9,CH,A)
             +---------------+   county code, then case id
                    |
                    v
   REPTSTEP  +---------------+ <--- REPTCTL  same PAYCYCLE card
             |    MBA400     |
             |    REPTGEN    |   MBA-400 register, 132 byte print file
             +---------------+
                    |
                    v
              SYSOUT=A  DEST=CENTRALPRT
```

Every interface is a sequential fixed length file. No program calls another
program; the coupling is entirely record layout plus step order. The two
programs that need a cycle date read the same `PAYCYCLE` control card so the
register cannot disagree with the warrants it reports.

## 2. Record layouts

All interface records are 80 bytes with reserved `FILLER` at the end. Lengths
are frozen — jobs outside this repository read the same layouts.

### CLAIMANT-RECORD — `CLAIMANT.CPY`, input to MBA100

| Pos | Len | Field | Notes |
|-----|-----|-------|-------|
| 1   | 9   | `CL-CASE-ID` | blank fails edit E01 |
| 10  | 18  | `CL-LAST-NAME` | |
| 28  | 1   | `CL-FIRST-INIT` | |
| 29  | 3   | `CL-COUNTY-CODE` | must be on the 88-level county table |
| 32  | 8   | `CL-FILING-DATE` | `9(8)`, carried for audit only |
| 40  | 9   | `CL-MONTHLY-INCOME` | `9(7)V99`, implied decimal |
| 49  | 2   | `CL-DEPENDENT-COUNT` | > `WC-MAX-DEPENDENTS` fails E07 |
| 51  | 3   | `CL-RESIDENCY-MONTHS` | |
| 54  | 1   | `CL-DISABILITY-FLAG` | `Y` lowers the residency minimum |
| 55  | 1   | `CL-PRIOR-CLAIM-FLAG` | `Y` routes a short residency to review |
| 56  | 2   | `CL-ELIG-START-DAY` | `01` = full month, else proration |
| 58  | 2   | `CL-STATUS-CODE` | `AC` `PN` `SU` `CL` |
| 60  | 21  | `FILLER` | reserved |

### ELIG-RECORD — `BENEFIT.CPY`, MBA100 to MBA200

| Pos | Len | Field | Notes |
|-----|-----|-------|-------|
| 1   | 9   | `EL-CASE-ID` | |
| 10  | 18  | `EL-LAST-NAME` | |
| 28  | 3   | `EL-COUNTY-CODE` | |
| 31  | 1   | `EL-ELIG-CODE` | `E` full month, `P` partial, `R` referred, `D` denied |
| 32  | 3   | `EL-REASON-CODE` | `A00` `P03` `C11` `C14` `E01` `E07` `E09` `I05` `R02` `R09` |
| 35  | 1   | `EL-INCOME-BAND` | 1 to 4, banded against the household limit |
| 36  | 2   | `EL-DEPENDENT-COUNT` | |
| 38  | 9   | `EL-COUNTABLE-INCOME` | income less disregards, floored at zero |
| 47  | 2   | `EL-ELIG-DAYS` | 30 for a full month |
| 49  | 3   | `EL-POINTS` | review queue score, referral above `WC-REVIEW-THRESHOLD` |
| 52  | 29  | `FILLER` | reserved |

### BENEFIT-RECORD — `BENEFIT.CPY`, MBA200 to MBA300

| Pos | Len | Field | Notes |
|-----|-----|-------|-------|
| 1   | 9   | `BN-CASE-ID` | |
| 10  | 18  | `BN-LAST-NAME` | |
| 28  | 3   | `BN-COUNTY-CODE` | |
| 31  | 1   | `BN-ELIG-CODE` | `E` `P` payable, `M` under minimum, `D` `R` not payable |
| 32  | 7   | `BN-BASE-AMOUNT` | `9(5)V99` |
| 39  | 7   | `BN-DEPENDENT-ALLOW` | |
| 46  | 7   | `BN-INCOME-OFFSET` | countable income times `WC-OFFSET-RATE`, `ROUNDED` |
| 53  | 2   | `BN-PRORATE-DAYS` | copied from `EL-ELIG-DAYS` |
| 55  | 7   | `BN-NET-BENEFIT` | zero when suppressed or not payable |
| 62  | 1   | `BN-ROUND-IND` | `R` when `ROUNDED` and truncated disagree |
| 63  | 18  | `FILLER` | reserved |

### PAYMENT-RECORD — `BENEFIT.CPY`, MBA300 to MBA400

| Pos | Len | Field | Notes |
|-----|-----|-------|-------|
| 1   | 9   | `PY-CASE-ID` | secondary sort key |
| 10  | 3   | `PY-COUNTY-CODE` | primary sort key, drives the control break |
| 13  | 18  | `PY-LAST-NAME` | |
| 31  | 8   | `PY-WARRANT-NO` | `W` plus a 7 digit sequence from the card seed |
| 39  | 1   | `PY-INSTALLMENT-NO` | 1 or 2 |
| 40  | 8   | `PY-PAY-DATE` | cycle `YYYYMM` plus the installment day |
| 48  | 7   | `PY-AMOUNT` | installment 1 carries the odd penny |
| 55  | 1   | `PY-METHOD-CODE` | from the control card |
| 56  | 6   | `PY-CYCLE-YYYYMM` | |
| 62  | 19  | `FILLER` | reserved |

## 3. Determination logic in MBA100

Flow is linear with `GO TO` transfers. Nine paragraphs, nine ways out.

1. `2100-EDIT-CLAIM` — case id present, dependent count within limit, county on
   table, status not closed; suspended cases go straight to referral.
2. `2200-COUNTABLE-INCOME` — subtract the per dependent disregard and, when the
   disability flag is set, the disability disregard. Floor at zero. Compute the
   household limit as `WC-LIMIT-BASE + dependents * WC-LIMIT-PER-DEP`.
3. `2300-RESIDENCY-TEST` — minimum residency is lower for disabled claimants; a
   prior claim converts a short residency into a review referral (`R09`) rather
   than a denial (`R02`).
4. `2400-INCOME-BAND` — over the limit denies with `I05`; otherwise the
   countable income percentage of the limit is banded 1 to 4.
5. `2500-SCORE-CLAIM` — review queue score from dependents, band and flags.
6. `2600-PARTIAL-MONTH` — `CL-ELIG-START-DAY` of `01` is a full 30 day award
   (`A00`, code `E`); anything later prorates over `31 - start day` days
   (`P03`, code `P`).
7. `2700-AWARD-CLAIM` — a score above `WC-REVIEW-THRESHOLD` overrides the award
   and refers the case, which is why some high dependent low income households
   never reach a payment.
8. `2850-REFER-CLAIM` / `2900-DENY-CLAIM` — write a zero day determination.
9. `8000-CONTROL-TOTALS` — six control total lines to `ELIGAUD`.

## 4. Money and rounding

MBA200 does all arithmetic in `PIC S9(7)V99 COMP-3` work fields. Two behaviours
are deliberate and are pinned by the golden files:

* `WS-OFFSET` uses `COMPUTE ... ROUNDED` on `countable income * 0.333`, so the
  offset is rounded half up to the penny before it reduces the grant.
* The proration is computed twice, once with `ROUNDED` and once without. The
  truncated value is not paid — it exists only to detect that rounding moved a
  penny, which is stamped as `BN-ROUND-IND = 'R'`.

MBA300 then splits the net award with a truncating divide and puts the odd penny
on installment 1, so `230.17` pays as `115.09` and `115.08`.

## 5. Control totals

Each program writes its own audit file, and the totals are expected to tie:

* `MBA100 DETERMINATIONS WRITTEN` equals `MBA200 DETERMINATIONS READ`.
* `MBA200 TOTAL AWARD DOLLARS` equals `MBA300 TOTAL SCHEDULED DOLLARS`.
* `MBA300 TOTAL SCHEDULED DOLLARS` equals the `STATEWIDE TOTAL` on MBA-400.

Those three equalities are the first thing to check when a cycle looks wrong,
and they are asserted implicitly by the golden file comparison.
