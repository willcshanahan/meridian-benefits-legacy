       IDENTIFICATION DIVISION.
       PROGRAM-ID.     ELIGCALC.
       AUTHOR.         D HALVORSEN.
       INSTALLATION.   MERIDIAN STATE BENEFITS AGENCY.
       DATE-WRITTEN.   1984-03-11.
      *****************************************************************
      * MODULE   ELIGCALC   (LOAD MODULE MBA100)                      *
      * FUNCTION MONTHLY ELIGIBILITY DETERMINATION FOR THE MERIDIAN    *
      *          BENEFIT CYCLE.  READS THE CLAIMANT MASTER EXTRACT,    *
      *          APPLIES THE COUNTABLE INCOME AND RESIDENCY RULES AND  *
      *          WRITES ONE DETERMINATION RECORD PER CLAIMANT.         *
      *                                                               *
      * DD NAMES CLAIMIN  I  CLAIMANT MASTER EXTRACT      LRECL 80     *
      *          ELIGOUT  O  DETERMINATION FILE           LRECL 80     *
      *          ELIGAUD  O  RUN CONTROL TOTALS           LRECL 80     *
      *                                                               *
      * WARNING  THE DETERMINATION FILE IS CONSUMED BY MBA200 AND ITS  *
      *          LAYOUT IS ALSO READ BY THE COUNTY EXTRACT JOB THAT    *
      *          THE FIELD OFFICES RUN ON THEIR OWN SCHEDULE.  DO NOT  *
      *          REORDER FIELDS.                                       *
      *                                                               *
      * MAINT LOG                                                     *
      *   1984-03-11  D HALVORSEN  ORIGINAL CODING                    *
      *   1986-01-27  D HALVORSEN  REVIEW QUEUE SCORE (EL-POINTS)      *
      *   1987-09-02  R OKONKWO    PARTIAL MONTH RULE  AR 87-114       *
      *   1990-02-19  R OKONKWO    DISABILITY DISREGARD MOVED AHEAD    *
      *                            OF THE BAND TEST.  THIS CHANGED     *
      *                            ABOUT 400 AWARDS AND WAS BACKED     *
      *                            OUT ONCE BEFORE IT STUCK.          *
      *   1996-04-15  M TREADAWAY  COUNTY TABLE EDIT ADDED            *
      *****************************************************************
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.  MSB-HOST.
       OBJECT-COMPUTER.  MSB-HOST.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CLAIMANT-FILE   ASSIGN TO "CLAIMIN"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-CLAIM-STATUS.
           SELECT ELIG-FILE       ASSIGN TO "ELIGOUT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-ELIG-STATUS.
           SELECT AUDIT-FILE      ASSIGN TO "ELIGAUD"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-AUDIT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  CLAIMANT-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS CLAIMANT-IMAGE.
       01  CLAIMANT-IMAGE          PIC X(80).
       FD  ELIG-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS ELIG-IMAGE.
       01  ELIG-IMAGE              PIC X(80).
       FD  AUDIT-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS AUDIT-IMAGE.
       01  AUDIT-IMAGE             PIC X(80).
       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS-AREA.
           05  WS-CLAIM-STATUS         PIC X(02)    VALUE '00'.
           05  WS-ELIG-STATUS          PIC X(02)    VALUE '00'.
           05  WS-AUDIT-STATUS         PIC X(02)    VALUE '00'.
           05  WS-ABEND-DDNAME         PIC X(08)    VALUE SPACES.
       01  WS-SWITCHES.
           05  WS-EOF-SWITCH           PIC X(01)    VALUE 'N'.
               88  WS-END-OF-INPUT     VALUE 'Y'.
           05  WS-COUNTY-SWITCH        PIC X(01)    VALUE 'N'.
               88  WS-COUNTY-ON-TABLE  VALUE 'Y'.
       01  WS-COUNTERS.
           05  WS-READ-COUNT           PIC 9(07)    VALUE ZERO.
           05  WS-ELIGIBLE-COUNT       PIC 9(07)    VALUE ZERO.
           05  WS-PARTIAL-COUNT        PIC 9(07)    VALUE ZERO.
           05  WS-REFERRED-COUNT       PIC 9(07)    VALUE ZERO.
           05  WS-DENIED-COUNT         PIC 9(07)    VALUE ZERO.
           05  WS-WRITE-COUNT          PIC 9(07)    VALUE ZERO.
       01  WS-WORK-AREA.
           05  WS-REASON               PIC X(03)    VALUE SPACES.
           05  WS-COUNTABLE            PIC S9(07)V99 VALUE ZERO.
           05  WS-DISREGARD            PIC S9(07)V99 VALUE ZERO.
           05  WS-INCOME-LIMIT         PIC S9(07)V99 VALUE ZERO.
           05  WS-LIMIT-PCT            PIC S9(05)   VALUE ZERO.
           05  WS-ELIG-DAYS            PIC S9(03)   VALUE ZERO.
           05  WS-POINTS               PIC S9(05)   VALUE ZERO.
           05  WS-MIN-RESIDENCY        PIC 9(03)    VALUE ZERO.
           05  WS-SUB                  PIC 9(02)    VALUE ZERO.
       01  WS-AUDIT-LINE.
           05  FILLER                  PIC X(08)    VALUE 'MBA100  '.
           05  WS-AL-LABEL             PIC X(28)    VALUE SPACES.
           05  FILLER                  PIC X(02)    VALUE SPACES.
           05  WS-AL-COUNT             PIC 9(07)    VALUE ZERO.
           05  FILLER                  PIC X(35)    VALUE SPACES.
       COPY "CLAIMANT.CPY".
       COPY "BENEFIT.CPY".
       COPY "WSCONST.CPY".
       PROCEDURE DIVISION.
      *----------------------------------------------------------------
      * MAIN LINE.  FLOW IS DELIBERATELY LINEAR - THE 1984 SHOP
      * STANDARD FORBADE NESTED PERFORM THRU RANGES.
      *----------------------------------------------------------------
       0000-MAIN-CONTROL.
           PERFORM 1000-HOUSEKEEPING.
           GO TO 2000-READ-NEXT-CLAIM.
      *
       1000-HOUSEKEEPING.
           OPEN INPUT CLAIMANT-FILE.
           IF WS-CLAIM-STATUS NOT = '00'
               MOVE 'CLAIMIN ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           OPEN OUTPUT ELIG-FILE.
           IF WS-ELIG-STATUS NOT = '00'
               MOVE 'ELIGOUT ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           OPEN OUTPUT AUDIT-FILE.
           MOVE ZERO  TO WS-READ-COUNT WS-WRITE-COUNT.
           MOVE ZERO  TO WS-ELIGIBLE-COUNT WS-PARTIAL-COUNT.
           MOVE ZERO  TO WS-REFERRED-COUNT WS-DENIED-COUNT.
           MOVE 'N'   TO WS-EOF-SWITCH.
      *
       2000-READ-NEXT-CLAIM.
           READ CLAIMANT-FILE INTO CLAIMANT-RECORD
               AT END
                   MOVE 'Y' TO WS-EOF-SWITCH
                   GO TO 8000-CONTROL-TOTALS.
           ADD 1 TO WS-READ-COUNT.
           MOVE SPACES TO ELIG-RECORD.
           MOVE ZERO   TO EL-INCOME-BAND EL-ELIG-DAYS EL-POINTS.
           MOVE ZERO   TO EL-COUNTABLE-INCOME.
           MOVE CL-CASE-ID         TO EL-CASE-ID.
           MOVE CL-LAST-NAME       TO EL-LAST-NAME.
           MOVE CL-COUNTY-CODE     TO EL-COUNTY-CODE.
           MOVE CL-DEPENDENT-COUNT TO EL-DEPENDENT-COUNT.
           MOVE ZERO TO WS-POINTS WS-ELIG-DAYS WS-LIMIT-PCT.
           GO TO 2100-EDIT-CLAIM.
      *
       2100-EDIT-CLAIM.
           IF CL-CASE-ID = SPACES
               MOVE 'E01' TO WS-REASON
               GO TO 2900-DENY-CLAIM.
           IF CL-DEPENDENT-COUNT > WC-MAX-DEPENDENTS
               MOVE 'E07' TO WS-REASON
               GO TO 2900-DENY-CLAIM.
           MOVE 'N' TO WS-COUNTY-SWITCH.
           IF CL-COUNTY-VALID
               MOVE 'Y' TO WS-COUNTY-SWITCH.
           IF NOT WS-COUNTY-ON-TABLE
               MOVE 'E09' TO WS-REASON
               GO TO 2900-DENY-CLAIM.
           IF CL-CLOSED
               MOVE 'C11' TO WS-REASON
               GO TO 2900-DENY-CLAIM.
           IF CL-SUSPENDED
               MOVE 'C14' TO WS-REASON
               GO TO 2850-REFER-CLAIM.
           GO TO 2200-COUNTABLE-INCOME.
      *
       2200-COUNTABLE-INCOME.
           COMPUTE WS-DISREGARD =
               CL-DEPENDENT-COUNT * WC-DISREGARD-PER-DEP.
           IF CL-DISABLED
               ADD WC-DISREGARD-DISABLED TO WS-DISREGARD.
           COMPUTE WS-COUNTABLE = CL-MONTHLY-INCOME - WS-DISREGARD.
           IF WS-COUNTABLE < ZERO
               MOVE ZERO TO WS-COUNTABLE.
           MOVE WS-COUNTABLE TO EL-COUNTABLE-INCOME.
           COMPUTE WS-INCOME-LIMIT = WC-LIMIT-BASE
               + (CL-DEPENDENT-COUNT * WC-LIMIT-PER-DEP).
           GO TO 2300-RESIDENCY-TEST.
      *
       2300-RESIDENCY-TEST.
           MOVE WC-MIN-RESIDENCY-MOS TO WS-MIN-RESIDENCY.
           IF CL-DISABLED
               MOVE WC-MIN-RESIDENCY-DIS TO WS-MIN-RESIDENCY.
           IF CL-RESIDENCY-MONTHS >= WS-MIN-RESIDENCY
               GO TO 2400-INCOME-BAND.
           IF CL-PRIOR-CLAIM
               MOVE 'R09' TO WS-REASON
               GO TO 2850-REFER-CLAIM.
           MOVE 'R02' TO WS-REASON.
           GO TO 2900-DENY-CLAIM.
      *
       2400-INCOME-BAND.
           IF WS-COUNTABLE > WS-INCOME-LIMIT
               MOVE 'I05' TO WS-REASON
               GO TO 2900-DENY-CLAIM.
           COMPUTE WS-LIMIT-PCT ROUNDED =
               (WS-COUNTABLE / WS-INCOME-LIMIT) * 100.
           MOVE 4 TO EL-INCOME-BAND.
           IF WS-LIMIT-PCT NOT > WC-BAND-3-PCT
               MOVE 3 TO EL-INCOME-BAND.
           IF WS-LIMIT-PCT NOT > WC-BAND-2-PCT
               MOVE 2 TO EL-INCOME-BAND.
           IF WS-LIMIT-PCT NOT > WC-BAND-1-PCT
               MOVE 1 TO EL-INCOME-BAND.
           GO TO 2500-SCORE-CLAIM.
      *
       2500-SCORE-CLAIM.
           COMPUTE WS-POINTS = 10
               + (CL-DEPENDENT-COUNT * 5)
               + ((5 - EL-INCOME-BAND) * 12).
           IF CL-DISABLED
               ADD 20 TO WS-POINTS.
           IF CL-PENDING
               ADD 6 TO WS-POINTS.
           IF WS-POINTS > 999
               MOVE 999 TO WS-POINTS.
           MOVE WS-POINTS TO EL-POINTS.
           GO TO 2600-PARTIAL-MONTH.
      *
       2600-PARTIAL-MONTH.
           IF CL-FULL-MONTH
               MOVE WC-CYCLE-DAYS TO WS-ELIG-DAYS
               MOVE 'A00' TO WS-REASON
               MOVE 'E'   TO EL-ELIG-CODE
               GO TO 2700-AWARD-CLAIM.
           COMPUTE WS-ELIG-DAYS =
               (WC-CYCLE-DAYS - CL-ELIG-START-DAY) + 1.
           IF WS-ELIG-DAYS < 1
               MOVE 'R02' TO WS-REASON
               GO TO 2900-DENY-CLAIM.
           MOVE 'P03' TO WS-REASON.
           MOVE 'P'   TO EL-ELIG-CODE.
           GO TO 2700-AWARD-CLAIM.
      *
       2700-AWARD-CLAIM.
           MOVE WS-REASON   TO EL-REASON-CODE.
           MOVE WS-ELIG-DAYS TO EL-ELIG-DAYS.
           IF EL-POINTS > WC-REVIEW-THRESHOLD
               MOVE 'R' TO EL-ELIG-CODE
               MOVE 'R09' TO EL-REASON-CODE
               ADD 1 TO WS-REFERRED-COUNT
               GO TO 2950-WRITE-DETERMINATION.
           IF EL-PARTIAL
               ADD 1 TO WS-PARTIAL-COUNT
           ELSE
               ADD 1 TO WS-ELIGIBLE-COUNT.
           GO TO 2950-WRITE-DETERMINATION.
      *
       2850-REFER-CLAIM.
           MOVE 'R'         TO EL-ELIG-CODE.
           MOVE WS-REASON   TO EL-REASON-CODE.
           MOVE ZERO        TO EL-ELIG-DAYS.
           ADD 1 TO WS-REFERRED-COUNT.
           GO TO 2950-WRITE-DETERMINATION.
      *
       2900-DENY-CLAIM.
           MOVE 'D'         TO EL-ELIG-CODE.
           MOVE WS-REASON   TO EL-REASON-CODE.
           MOVE ZERO        TO EL-ELIG-DAYS.
           ADD 1 TO WS-DENIED-COUNT.
           GO TO 2950-WRITE-DETERMINATION.
      *
       2950-WRITE-DETERMINATION.
           WRITE ELIG-IMAGE FROM ELIG-RECORD.
           IF WS-ELIG-STATUS NOT = '00'
               MOVE 'ELIGOUT ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           ADD 1 TO WS-WRITE-COUNT.
           GO TO 2000-READ-NEXT-CLAIM.
      *
       8000-CONTROL-TOTALS.
           MOVE 'RECORDS READ' TO WS-AL-LABEL.
           MOVE WS-READ-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'DETERMINATIONS WRITTEN' TO WS-AL-LABEL.
           MOVE WS-WRITE-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'ELIGIBLE FULL MONTH' TO WS-AL-LABEL.
           MOVE WS-ELIGIBLE-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'ELIGIBLE PARTIAL MONTH' TO WS-AL-LABEL.
           MOVE WS-PARTIAL-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'REFERRED FOR REVIEW' TO WS-AL-LABEL.
           MOVE WS-REFERRED-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'DENIED' TO WS-AL-LABEL.
           MOVE WS-DENIED-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           GO TO 9000-END-OF-JOB.
      *
       9000-END-OF-JOB.
           CLOSE CLAIMANT-FILE ELIG-FILE AUDIT-FILE.
           MOVE ZERO TO RETURN-CODE.
           STOP RUN.
      *
       9500-FILE-ABEND.
           DISPLAY 'MBA100 OPEN OR IO FAILURE ON ' WS-ABEND-DDNAME
               UPON SYSERR.
           MOVE 16 TO RETURN-CODE.
           STOP RUN.
