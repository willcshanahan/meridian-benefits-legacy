       IDENTIFICATION DIVISION.
       PROGRAM-ID.     BENEFITS.
       AUTHOR.         D HALVORSEN.
       INSTALLATION.   MERIDIAN STATE BENEFITS AGENCY.
       DATE-WRITTEN.   1984-04-02.
      *****************************************************************
      * MODULE   BENEFITS   (LOAD MODULE MBA200)                      *
      * FUNCTION BENEFIT AMOUNT CALCULATION.  ONE PASS OVER THE        *
      *          DETERMINATION FILE PRODUCED BY MBA100.  ALL MONEY     *
      *          ARITHMETIC IS DONE IN PACKED DECIMAL WORK FIELDS.     *
      *                                                               *
      * DD NAMES BENEIN   I  DETERMINATION FILE FROM MBA100  LRECL 80  *
      *          BENEOUT  O  BENEFIT AMOUNT FILE             LRECL 80  *
      *          BENEAUD  O  RUN CONTROL TOTALS              LRECL 80  *
      *                                                               *
      * ROUNDING NOTE                                                 *
      *   THE PRORATION IS COMPUTED TWICE ON PURPOSE.  WS-NET-ROUNDED  *
      *   USES THE ROUNDED PHRASE, WS-NET-TRUNCATED DOES NOT.  WHEN    *
      *   THE TWO DISAGREE THE RECORD IS STAMPED BN-ROUND-IND = 'R'    *
      *   SO THE PENNY VARIANCE CAN BE RECONCILED AGAINST THE FIELD    *
      *   OFFICE WORKSHEETS, WHICH TRUNCATE.  DO NOT "SIMPLIFY" THIS   *
      *   INTO ONE COMPUTE - THE INDICATOR IS ON A STATE REPORT.       *
      *                                                               *
      * MAINT LOG                                                     *
      *   1984-04-02  D HALVORSEN  ORIGINAL CODING                    *
      *   1989-07-01  R OKONKWO    GRANT UPLIFT PICKED UP FROM WSCONST *
      *   1991-11-05  R OKONKWO    ROUND INDICATOR ADDED  AR 91-233    *
      *   1996-04-15  M TREADAWAY  MINIMUM WARRANT SUPPRESSION 'M'     *
      *****************************************************************
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.  MSB-HOST.
       OBJECT-COMPUTER.  MSB-HOST.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT DETERM-FILE     ASSIGN TO "BENEIN"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-DETERM-STATUS.
           SELECT BENEFIT-FILE    ASSIGN TO "BENEOUT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-BENEFIT-STATUS.
           SELECT AUDIT-FILE      ASSIGN TO "BENEAUD"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-AUDIT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  DETERM-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS DETERM-IMAGE.
       01  DETERM-IMAGE            PIC X(80).
       FD  BENEFIT-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS BENEFIT-IMAGE.
       01  BENEFIT-IMAGE           PIC X(80).
       FD  AUDIT-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS AUDIT-IMAGE.
       01  AUDIT-IMAGE             PIC X(80).
       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS-AREA.
           05  WS-DETERM-STATUS        PIC X(02)    VALUE '00'.
           05  WS-BENEFIT-STATUS       PIC X(02)    VALUE '00'.
           05  WS-AUDIT-STATUS         PIC X(02)    VALUE '00'.
           05  WS-ABEND-DDNAME         PIC X(08)    VALUE SPACES.
       01  WS-SWITCHES.
           05  WS-EOF-SWITCH           PIC X(01)    VALUE 'N'.
               88  WS-END-OF-INPUT     VALUE 'Y'.
       01  WS-COUNTERS.
           05  WS-READ-COUNT           PIC 9(07)    VALUE ZERO.
           05  WS-PAYABLE-COUNT        PIC 9(07)    VALUE ZERO.
           05  WS-SUPPRESS-COUNT       PIC 9(07)    VALUE ZERO.
           05  WS-ZERO-COUNT           PIC 9(07)    VALUE ZERO.
           05  WS-ROUND-COUNT          PIC 9(07)    VALUE ZERO.
           05  WS-TOTAL-AWARD          PIC 9(09)V99 VALUE ZERO.
      *
      * PACKED DECIMAL WORK FIELDS - COMP-3 AS SHIPPED IN 1984
      *
       01  WS-CALC-AREA.
           05  WS-BASE-GRANT           PIC S9(07)V99 COMP-3 VALUE ZERO.
           05  WS-DEP-ALLOW            PIC S9(07)V99 COMP-3 VALUE ZERO.
           05  WS-OFFSET               PIC S9(07)V99 COMP-3 VALUE ZERO.
           05  WS-GROSS                PIC S9(07)V99 COMP-3 VALUE ZERO.
           05  WS-NET-ROUNDED          PIC S9(07)V99 COMP-3 VALUE ZERO.
           05  WS-NET-TRUNCATED        PIC S9(07)V99 COMP-3 VALUE ZERO.
       01  WS-AUDIT-LINE.
           05  FILLER                  PIC X(08)    VALUE 'MBA200  '.
           05  WS-AL-LABEL             PIC X(28)    VALUE SPACES.
           05  FILLER                  PIC X(02)    VALUE SPACES.
           05  WS-AL-COUNT             PIC 9(07)    VALUE ZERO.
           05  FILLER                  PIC X(35)    VALUE SPACES.
       01  WS-AUDIT-MONEY-LINE.
           05  FILLER                  PIC X(08)    VALUE 'MBA200  '.
           05  WS-AM-LABEL             PIC X(28)    VALUE SPACES.
           05  FILLER                  PIC X(02)    VALUE SPACES.
           05  WS-AM-AMOUNT            PIC 9(09)V99 VALUE ZERO.
           05  FILLER                  PIC X(31)    VALUE SPACES.
       COPY "BENEFIT.CPY".
       COPY "WSCONST.CPY".
       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       0000-MAIN-CONTROL.
           PERFORM 1000-HOUSEKEEPING.
           GO TO 2000-READ-NEXT-DETERM.
      *
       1000-HOUSEKEEPING.
           OPEN INPUT DETERM-FILE.
           IF WS-DETERM-STATUS NOT = '00'
               MOVE 'BENEIN  ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           OPEN OUTPUT BENEFIT-FILE.
           OPEN OUTPUT AUDIT-FILE.
           MOVE WC-BASE-GRANT TO WS-BASE-GRANT.
      *
       2000-READ-NEXT-DETERM.
           READ DETERM-FILE INTO ELIG-RECORD
               AT END
                   MOVE 'Y' TO WS-EOF-SWITCH
                   GO TO 8000-CONTROL-TOTALS.
           ADD 1 TO WS-READ-COUNT.
           MOVE SPACES TO BENEFIT-RECORD.
           MOVE ZERO   TO BN-BASE-AMOUNT BN-DEPENDENT-ALLOW
                          BN-INCOME-OFFSET BN-PRORATE-DAYS
                          BN-NET-BENEFIT.
           MOVE EL-CASE-ID     TO BN-CASE-ID.
           MOVE EL-LAST-NAME   TO BN-LAST-NAME.
           MOVE EL-COUNTY-CODE TO BN-COUNTY-CODE.
           MOVE EL-ELIG-CODE   TO BN-ELIG-CODE.
           MOVE ' '            TO BN-ROUND-IND.
           IF EL-DENIED OR EL-REFERRED
               ADD 1 TO WS-ZERO-COUNT
               GO TO 2900-WRITE-BENEFIT.
           GO TO 2100-GROSS-AWARD.
      *
       2100-GROSS-AWARD.
           COMPUTE WS-DEP-ALLOW =
               EL-DEPENDENT-COUNT * WC-DEP-ALLOWANCE.
           COMPUTE WS-OFFSET ROUNDED =
               EL-COUNTABLE-INCOME * WC-OFFSET-RATE.
           COMPUTE WS-GROSS =
               WS-BASE-GRANT + WS-DEP-ALLOW - WS-OFFSET.
           IF WS-GROSS < ZERO
               MOVE ZERO TO WS-GROSS.
           MOVE WS-BASE-GRANT TO BN-BASE-AMOUNT.
           MOVE WS-DEP-ALLOW  TO BN-DEPENDENT-ALLOW.
           MOVE WS-OFFSET     TO BN-INCOME-OFFSET.
           MOVE EL-ELIG-DAYS  TO BN-PRORATE-DAYS.
           GO TO 2200-PRORATE-AWARD.
      *
       2200-PRORATE-AWARD.
           IF EL-ELIG-DAYS NOT < WC-CYCLE-DAYS
               MOVE WS-GROSS TO WS-NET-ROUNDED
               MOVE WS-GROSS TO WS-NET-TRUNCATED
               GO TO 2300-MINIMUM-TEST.
           COMPUTE WS-NET-ROUNDED ROUNDED =
               (WS-GROSS * EL-ELIG-DAYS) / WC-CYCLE-DAYS.
           COMPUTE WS-NET-TRUNCATED =
               (WS-GROSS * EL-ELIG-DAYS) / WC-CYCLE-DAYS.
           IF WS-NET-ROUNDED NOT = WS-NET-TRUNCATED
               MOVE 'R' TO BN-ROUND-IND
               ADD 1 TO WS-ROUND-COUNT.
           GO TO 2300-MINIMUM-TEST.
      *
       2300-MINIMUM-TEST.
           IF WS-NET-ROUNDED > ZERO AND
              WS-NET-ROUNDED < WC-MIN-WARRANT
               MOVE 'M' TO BN-ELIG-CODE
               MOVE ZERO TO BN-NET-BENEFIT
               ADD 1 TO WS-SUPPRESS-COUNT
               GO TO 2900-WRITE-BENEFIT.
           MOVE WS-NET-ROUNDED TO BN-NET-BENEFIT.
           ADD WS-NET-ROUNDED TO WS-TOTAL-AWARD.
           ADD 1 TO WS-PAYABLE-COUNT.
           GO TO 2900-WRITE-BENEFIT.
      *
       2900-WRITE-BENEFIT.
           WRITE BENEFIT-IMAGE FROM BENEFIT-RECORD.
           IF WS-BENEFIT-STATUS NOT = '00'
               MOVE 'BENEOUT ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           GO TO 2000-READ-NEXT-DETERM.
      *
       8000-CONTROL-TOTALS.
           MOVE 'DETERMINATIONS READ' TO WS-AL-LABEL.
           MOVE WS-READ-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'PAYABLE AWARDS' TO WS-AL-LABEL.
           MOVE WS-PAYABLE-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'UNDER MINIMUM SUPPRESSED' TO WS-AL-LABEL.
           MOVE WS-SUPPRESS-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'NOT PAYABLE DENIED OR REFER' TO WS-AL-LABEL.
           MOVE WS-ZERO-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'ROUNDING ADJUSTMENTS' TO WS-AL-LABEL.
           MOVE WS-ROUND-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'TOTAL AWARD DOLLARS' TO WS-AM-LABEL.
           MOVE WS-TOTAL-AWARD TO WS-AM-AMOUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-MONEY-LINE.
           GO TO 9000-END-OF-JOB.
      *
       9000-END-OF-JOB.
           CLOSE DETERM-FILE BENEFIT-FILE AUDIT-FILE.
           MOVE ZERO TO RETURN-CODE.
           STOP RUN.
      *
       9500-FILE-ABEND.
           DISPLAY 'MBA200 OPEN OR IO FAILURE ON ' WS-ABEND-DDNAME
               UPON SYSERR.
           MOVE 16 TO RETURN-CODE.
           STOP RUN.
