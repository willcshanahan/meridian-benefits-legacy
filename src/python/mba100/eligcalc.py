"""MBA100 ELIGCALC - monthly eligibility determination.

Python reimplementation of ``src/cobol/ELIGCALC.CBL`` (load module MBA100),
retired from COBOL by issue #1.  Reads the claimant master extract, applies the
countable income and residency rules and writes one determination record per
claimant plus a run control total file.

DD names, resolved from ``DD_<ddname>`` environment variables exactly as the
GnuCOBOL runtime resolved them for the COBOL module:

    CLAIMIN   I   claimant master extract     LRECL 80
    ELIGOUT   O   determination file          LRECL 80
    ELIGAUD   O   run control totals          LRECL 80

The determination file is consumed by MBA200 and its layout is also read by the
county extract job the field offices run on their own schedule, so field order
is frozen (see ``src/copybooks/BENEFIT.CPY``).

Behaviour notes carried over deliberately from the COBOL:

* The order of the tests in the determination flow is load bearing.  The
  disability disregard sits ahead of the income band test (AR 1990-02-19) and
  the ``I05`` over-limit denial sits ahead of banding.  Reordering changes
  awards.
* Files are ``ORGANIZATION IS LINE SEQUENTIAL``, so each 80 byte record image
  is written with its trailing blanks stripped.
* All money and percentage arithmetic uses ``decimal.Decimal`` with
  ``ROUND_HALF_UP`` to reproduce COBOL ``COMPUTE ... ROUNDED`` on the packed
  work fields.  Binary floating point would not be penny exact.
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

# --------------------------------------------------------------------------
# WSCONST.CPY - policy constants.  Hard coded by design; every rate change is
# a code change plus a golden file rebaseline approved by Program Policy.
# --------------------------------------------------------------------------
WC_LIMIT_BASE = Decimal("1450.00")
WC_LIMIT_PER_DEP = Decimal("310.00")
WC_DISREGARD_PER_DEP = Decimal("60.00")
WC_DISREGARD_DISABLED = Decimal("145.00")
WC_MIN_RESIDENCY_MOS = 6
WC_MIN_RESIDENCY_DIS = 3
WC_MAX_DEPENDENTS = 12
WC_CYCLE_DAYS = 30
WC_REVIEW_THRESHOLD = 85
WC_BAND_1_PCT = 50
WC_BAND_2_PCT = 75
WC_BAND_3_PCT = 90

VALID_COUNTY_CODES = frozenset({"011", "024", "037", "052", "068", "073"})

RECORD_LENGTH = 80
CENTS = Decimal("0.01")
ONE = Decimal(1)

AUDIT_PROGRAM_ID = "MBA100  "


class FileAbend(Exception):
    """9500-FILE-ABEND: unusable DD name.  RC 16."""

    def __init__(self, ddname: str) -> None:
        super().__init__(ddname)
        self.ddname = ddname


class DataAbend(Exception):
    """Unusable display data on an input record.  RC 16."""

    def __init__(self, field: str) -> None:
        super().__init__(field)
        self.field = field


def _display_digits(field: str) -> str:
    """Normalise a COBOL ``PIC 9`` display field to digits.

    An all-blank display field read as zero under the COBOL runtime, so a
    short or blank record reached ``2100-EDIT-CLAIM`` and was denied rather
    than killing the run.  Data that is neither blank nor numeric never had
    defined behaviour, so it abends instead of being guessed at.
    """
    if field.strip() == "":
        return "0" * len(field)
    if not field.isdigit():
        raise DataAbend(field)
    return field


def _display_int(field: str) -> int:
    """Read a COBOL ``PIC 9(n)`` display field as an integer."""
    return int(_display_digits(field))


def _money(field: str) -> Decimal:
    """Read a COBOL ``PIC 9(n)V99`` display field as an exact decimal."""
    digits = _display_digits(field)
    return Decimal(digits[:-2] + "." + digits[-2:])


def _pic_9(value: int, width: int) -> str:
    """Format an integer into ``PIC 9(width)``, truncating high order digits."""
    return f"{value:0{width}d}"[-width:]


def _pic_9v99(value: Decimal, width: int) -> str:
    """Format a decimal into an unsigned ``PIC 9(width-2)V99`` display field."""
    cents = int(abs(value).quantize(CENTS, rounding=ROUND_HALF_UP) * 100)
    return _pic_9(cents, width)


def _pic_x(value: str, width: int) -> str:
    return value[:width].ljust(width)


# --------------------------------------------------------------------------
# CLAIMANT.CPY - claimant master extract record.
# --------------------------------------------------------------------------
@dataclass(frozen=True)
class ClaimantRecord:
    case_id: str
    last_name: str
    first_init: str
    county_code: str
    filing_date: str
    monthly_income: Decimal
    dependent_count: int
    residency_months: int
    disability_flag: str
    prior_claim_flag: str
    elig_start_day: int
    status_code: str

    @classmethod
    def from_image(cls, image: str) -> ClaimantRecord:
        image = image.ljust(RECORD_LENGTH)
        return cls(
            case_id=image[0:9],
            last_name=image[9:27],
            first_init=image[27:28],
            county_code=image[28:31],
            filing_date=image[31:39],
            monthly_income=_money(image[39:48]),
            dependent_count=_display_int(image[48:50]),
            residency_months=_display_int(image[50:53]),
            disability_flag=image[53:54],
            prior_claim_flag=image[54:55],
            elig_start_day=_display_int(image[55:57]),
            status_code=image[57:59],
        )

    @property
    def county_valid(self) -> bool:
        return self.county_code in VALID_COUNTY_CODES

    @property
    def disabled(self) -> bool:
        return self.disability_flag == "Y"

    @property
    def prior_claim(self) -> bool:
        return self.prior_claim_flag == "Y"

    @property
    def full_month(self) -> bool:
        return self.elig_start_day == 1

    @property
    def pending(self) -> bool:
        return self.status_code == "PN"

    @property
    def suspended(self) -> bool:
        return self.status_code == "SU"

    @property
    def closed(self) -> bool:
        return self.status_code == "CL"


# --------------------------------------------------------------------------
# BENEFIT.CPY - ELIG-RECORD, written here and read by MBA200.
# --------------------------------------------------------------------------
@dataclass
class EligRecord:
    case_id: str = ""
    last_name: str = ""
    county_code: str = ""
    elig_code: str = " "
    reason_code: str = "   "
    income_band: int = 0
    dependent_count: int = 0
    countable_income: Decimal = Decimal("0.00")
    elig_days: int = 0
    points: int = 0

    @property
    def partial(self) -> bool:
        return self.elig_code == "P"

    def to_image(self) -> str:
        return (
            _pic_x(self.case_id, 9)
            + _pic_x(self.last_name, 18)
            + _pic_x(self.county_code, 3)
            + _pic_x(self.elig_code, 1)
            + _pic_x(self.reason_code, 3)
            + _pic_9(self.income_band, 1)
            + _pic_9(self.dependent_count, 2)
            + _pic_9v99(self.countable_income, 9)
            + _pic_9(self.elig_days, 2)
            + _pic_9(self.points, 3)
        ).ljust(RECORD_LENGTH)


class LineSequentialWriter:
    """``ORGANIZATION IS LINE SEQUENTIAL`` output: trailing blanks stripped."""

    def __init__(self, path: str, ddname: str) -> None:
        self.ddname = ddname
        try:
            self._stream = open(path, "w", encoding="ascii", newline="\n")
        except OSError as exc:
            raise FileAbend(ddname) from exc

    def write(self, image: str) -> None:
        try:
            self._stream.write(image.rstrip(" ") + "\n")
        except OSError as exc:
            raise FileAbend(self.ddname) from exc

    def close(self) -> None:
        # Writes are buffered, so a full volume usually only surfaces here.
        try:
            self._stream.close()
        except OSError as exc:
            raise FileAbend(self.ddname) from exc


class EligibilityRun:
    """The ``PROCEDURE DIVISION`` of MBA100.

    One method per COBOL paragraph.  The per-claimant paragraphs return the
    next paragraph to execute, which keeps the original ``GO TO`` flow and its
    nine exit paths visible instead of flattening it into nested conditions.
    """

    def __init__(self, claim_path: str, elig_path: str, audit_path: str) -> None:
        self._claim_path = claim_path
        self._elig_path = elig_path
        self._audit_path = audit_path

        self.read_count = 0
        self.write_count = 0
        self.eligible_count = 0
        self.partial_count = 0
        self.referred_count = 0
        self.denied_count = 0

        # WS-WORK-AREA fields that outlive a single paragraph.
        self.claim: ClaimantRecord
        self.elig: EligRecord
        self.reason = "   "
        self.countable = Decimal("0.00")
        self.income_limit = Decimal("0.00")
        self.elig_days = 0
        self.points = 0

    # 0000-MAIN-CONTROL
    def main_control(self) -> None:
        self.housekeeping()
        try:
            for image in self._claim_file:
                self.read_next_claim(image.rstrip("\n"))
        except OSError as exc:
            raise FileAbend("CLAIMIN ") from exc
        self.control_totals()
        self.end_of_job()

    # 1000-HOUSEKEEPING
    def housekeeping(self) -> None:
        # newline="\n" keeps the record boundary at the line-sequential
        # delimiter alone; the extract is read a record at a time as the
        # sequential READ did, not held in storage.
        try:
            self._claim_file = open(
                self._claim_path, "r", encoding="ascii", newline="\n"
            )
        except OSError as exc:
            raise FileAbend("CLAIMIN ") from exc
        self._elig_file = LineSequentialWriter(self._elig_path, "ELIGOUT ")
        self._audit_file = LineSequentialWriter(self._audit_path, "ELIGAUD ")

        self.read_count = 0
        self.write_count = 0
        self.eligible_count = 0
        self.partial_count = 0
        self.referred_count = 0
        self.denied_count = 0

    # 2000-READ-NEXT-CLAIM
    def read_next_claim(self, image: str) -> None:
        self.claim = ClaimantRecord.from_image(image)
        self.read_count += 1

        # MOVE SPACES TO ELIG-RECORD, then the identifying fields, which is why
        # a claim denied by the very first edit still carries its county code.
        self.elig = EligRecord(
            case_id=self.claim.case_id,
            last_name=self.claim.last_name,
            county_code=self.claim.county_code,
            dependent_count=self.claim.dependent_count,
        )
        self.points = 0
        self.elig_days = 0

        step = self.edit_claim
        while step is not None:
            step = step()

    # 2100-EDIT-CLAIM
    def edit_claim(self):
        if self.claim.case_id.strip() == "":
            self.reason = "E01"
            return self.deny_claim
        if self.claim.dependent_count > WC_MAX_DEPENDENTS:
            self.reason = "E07"
            return self.deny_claim
        if not self.claim.county_valid:
            self.reason = "E09"
            return self.deny_claim
        if self.claim.closed:
            self.reason = "C11"
            return self.deny_claim
        if self.claim.suspended:
            self.reason = "C14"
            return self.refer_claim
        return self.countable_income_step

    # 2200-COUNTABLE-INCOME
    def countable_income_step(self):
        disregard = self.claim.dependent_count * WC_DISREGARD_PER_DEP
        if self.claim.disabled:
            disregard += WC_DISREGARD_DISABLED
        self.countable = self.claim.monthly_income - disregard
        if self.countable < 0:
            self.countable = Decimal("0.00")
        self.elig.countable_income = self.countable
        self.income_limit = WC_LIMIT_BASE + (
            self.claim.dependent_count * WC_LIMIT_PER_DEP
        )
        return self.residency_test

    # 2300-RESIDENCY-TEST
    def residency_test(self):
        min_residency = (
            WC_MIN_RESIDENCY_DIS if self.claim.disabled else WC_MIN_RESIDENCY_MOS
        )
        if self.claim.residency_months >= min_residency:
            return self.income_band
        if self.claim.prior_claim:
            self.reason = "R09"
            return self.refer_claim
        self.reason = "R02"
        return self.deny_claim

    # 2400-INCOME-BAND
    def income_band(self):
        # The over-limit denial is ahead of banding, so a claim at the limit is
        # banded but a claim one cent over never reaches a band at all.
        if self.countable > self.income_limit:
            self.reason = "I05"
            return self.deny_claim
        limit_pct = (self.countable / self.income_limit * 100).quantize(
            ONE, rounding=ROUND_HALF_UP
        )
        # Descending assignment, not elif: the lowest band that fits wins.
        self.elig.income_band = 4
        if limit_pct <= WC_BAND_3_PCT:
            self.elig.income_band = 3
        if limit_pct <= WC_BAND_2_PCT:
            self.elig.income_band = 2
        if limit_pct <= WC_BAND_1_PCT:
            self.elig.income_band = 1
        return self.score_claim

    # 2500-SCORE-CLAIM
    def score_claim(self):
        self.points = (
            10 + (self.claim.dependent_count * 5) + ((5 - self.elig.income_band) * 12)
        )
        if self.claim.disabled:
            self.points += 20
        if self.claim.pending:
            self.points += 6
        if self.points > 999:
            self.points = 999
        self.elig.points = self.points
        return self.partial_month

    # 2600-PARTIAL-MONTH
    def partial_month(self):
        if self.claim.full_month:
            self.elig_days = WC_CYCLE_DAYS
            self.reason = "A00"
            self.elig.elig_code = "E"
            return self.award_claim
        self.elig_days = (WC_CYCLE_DAYS - self.claim.elig_start_day) + 1
        if self.elig_days < 1:
            self.reason = "R02"
            return self.deny_claim
        self.reason = "P03"
        self.elig.elig_code = "P"
        return self.award_claim

    # 2700-AWARD-CLAIM
    def award_claim(self):
        self.elig.reason_code = self.reason
        self.elig.elig_days = self.elig_days
        # Referral override: a high scoring award is restamped R/R09 for the
        # review queue but keeps the eligible days already determined, unlike
        # the 2850 referral path which zeroes them.
        if self.elig.points > WC_REVIEW_THRESHOLD:
            self.elig.elig_code = "R"
            self.elig.reason_code = "R09"
            self.referred_count += 1
            return self.write_determination
        if self.elig.partial:
            self.partial_count += 1
        else:
            self.eligible_count += 1
        return self.write_determination

    # 2850-REFER-CLAIM
    def refer_claim(self):
        self.elig.elig_code = "R"
        self.elig.reason_code = self.reason
        self.elig.elig_days = 0
        self.referred_count += 1
        return self.write_determination

    # 2900-DENY-CLAIM
    def deny_claim(self):
        self.elig.elig_code = "D"
        self.elig.reason_code = self.reason
        self.elig.elig_days = 0
        self.denied_count += 1
        return self.write_determination

    # 2950-WRITE-DETERMINATION
    def write_determination(self):
        self._elig_file.write(self.elig.to_image())
        self.write_count += 1
        return None

    # 8000-CONTROL-TOTALS
    def control_totals(self) -> None:
        totals = (
            ("RECORDS READ", self.read_count),
            ("DETERMINATIONS WRITTEN", self.write_count),
            ("ELIGIBLE FULL MONTH", self.eligible_count),
            ("ELIGIBLE PARTIAL MONTH", self.partial_count),
            ("REFERRED FOR REVIEW", self.referred_count),
            ("DENIED", self.denied_count),
        )
        for label, count in totals:
            image = (
                AUDIT_PROGRAM_ID
                + _pic_x(label, 28)
                + "  "
                + _pic_9(count, 7)
            ).ljust(RECORD_LENGTH)
            self._audit_file.write(image)

    # 9000-END-OF-JOB
    def end_of_job(self) -> None:
        self._claim_file.close()
        self._elig_file.close()
        self._audit_file.close()


def _dd(ddname: str) -> str:
    path = os.environ.get(f"DD_{ddname}")
    if not path:
        raise FileAbend(f"{ddname:<8}")
    return path


def main() -> int:
    try:
        run = EligibilityRun(_dd("CLAIMIN"), _dd("ELIGOUT"), _dd("ELIGAUD"))
        run.main_control()
    except FileAbend as abend:
        # 9500-FILE-ABEND
        print(
            f"MBA100 OPEN OR IO FAILURE ON {abend.ddname}",
            file=sys.stderr,
        )
        return 16
    except DataAbend as abend:
        print(
            f"MBA100 UNUSABLE NUMERIC DATA ON CLAIMIN  '{abend.field}'",
            file=sys.stderr,
        )
        return 16
    return 0


if __name__ == "__main__":
    sys.exit(main())
