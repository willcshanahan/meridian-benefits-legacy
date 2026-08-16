       IDENTIFICATION DIVISION.
       PROGRAM-ID.     PAYCALC.
       AUTHOR.         R OKONKWO.
       INSTALLATION.   MERIDIAN STATE BENEFITS AGENCY.
       DATE-WRITTEN.   1985-08-19.
      *****************************************************************
      * MODULE   PAYCALC    (LOAD MODULE MBA300)                      *
      * FUNCTION PAYMENT SCHEDULING.  SPLITS EACH PAYABLE AWARD INTO   *
      *          TWO SEMI MONTHLY INSTALLMENTS AND ASSIGNS WARRANT     *
      *          NUMBERS FROM THE CONTROL CARD SEED.  THE ODD PENNY    *
      *          GOES ON INSTALLMENT ONE BY STATUTE.                   *
      *                                                               *
      * DD NAMES PAYIN    I  BENEFIT AMOUNT FILE FROM MBA200 LRECL 80  *
      *          PAYCTL   I  CYCLE CONTROL CARD               LRECL 80 *
      *          PAYOUT   O  PAYMENT SCHEDULE FILE            LRECL 80 *
      *          PAYAUD   O  RUN CONTROL TOTALS               LRECL 80 *
      *                                                               *
      * CONTROL CARD LAYOUT                                           *
      *   01-04  CARD ID  MUST BE 'MBA3'                              *
      *   06-11  CYCLE YYYYMM                                         *
      *   13-14  FIRST INSTALLMENT DAY                                *
      *   16-17  SECOND INSTALLMENT DAY                               *
      *   19-19  DEFAULT DISBURSEMENT METHOD  W OR D                  *
      *   21-27  WARRANT NUMBER SEED                                  *
      *                                                               *
      * MAINT LOG                                                     *
      *   1985-08-19  R OKONKWO    ORIGINAL CODING                    *
      *   1992-03-30  R OKONKWO    WARRANT SEED MOVED TO CONTROL CARD  *
      *                            AFTER THE DUPLICATE WARRANT INCIDENT*
      *   1999-10-08  M TREADAWAY  Y2K - CYCLE DATE CARRIES CENTURY    *
      *****************************************************************
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.  MSB-HOST.
       OBJECT-COMPUTER.  MSB-HOST.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT BENEFIT-FILE    ASSIGN TO "PAYIN"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-BENEFIT-STATUS.
           SELECT CONTROL-FILE    ASSIGN TO "PAYCTL"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-CONTROL-STATUS.
           SELECT PAYMENT-FILE    ASSIGN TO "PAYOUT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-PAYMENT-STATUS.
           SELECT AUDIT-FILE      ASSIGN TO "PAYAUD"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-AUDIT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  BENEFIT-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS BENEFIT-IMAGE.
       01  BENEFIT-IMAGE           PIC X(80).
       FD  CONTROL-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS CONTROL-IMAGE.
       01  CONTROL-IMAGE           PIC X(80).
       FD  PAYMENT-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS PAYMENT-IMAGE.
       01  PAYMENT-IMAGE           PIC X(80).
       FD  AUDIT-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS AUDIT-IMAGE.
       01  AUDIT-IMAGE             PIC X(80).
       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS-AREA.
           05  WS-BENEFIT-STATUS       PIC X(02)    VALUE '00'.
           05  WS-CONTROL-STATUS       PIC X(02)    VALUE '00'.
           05  WS-PAYMENT-STATUS       PIC X(02)    VALUE '00'.
           05  WS-AUDIT-STATUS         PIC X(02)    VALUE '00'.
           05  WS-ABEND-DDNAME         PIC X(08)    VALUE SPACES.
       01  CONTROL-CARD.
           05  CC-CARD-ID              PIC X(04).
               88  CC-CARD-VALID       VALUE 'MBA3'.
           05  FILLER                  PIC X(01).
           05  CC-CYCLE-YYYYMM         PIC 9(06).
           05  FILLER                  PIC X(01).
           05  CC-PAY-DAY-1            PIC 9(02).
           05  FILLER                  PIC X(01).
           05  CC-PAY-DAY-2            PIC 9(02).
           05  FILLER                  PIC X(01).
           05  CC-METHOD               PIC X(01).
           05  FILLER                  PIC X(01).
           05  CC-WARRANT-SEED         PIC 9(07).
           05  FILLER                  PIC X(53).
       01  WS-COUNTERS.
           05  WS-READ-COUNT           PIC 9(07)    VALUE ZERO.
           05  WS-SKIP-COUNT           PIC 9(07)    VALUE ZERO.
           05  WS-PAYMENT-COUNT        PIC 9(07)    VALUE ZERO.
           05  WS-TOTAL-SCHEDULED      PIC 9(09)V99 VALUE ZERO.
       01  WS-WORK-AREA.
           05  WS-WARRANT-SEQ          PIC 9(07)    VALUE ZERO.
           05  WS-INSTALL-1            PIC S9(07)V99 COMP-3 VALUE ZERO.
           05  WS-INSTALL-2            PIC S9(07)V99 COMP-3 VALUE ZERO.
           05  WS-PAY-DATE-WORK.
               10  WS-PD-YYYYMM        PIC 9(06)    VALUE ZERO.
               10  WS-PD-DD            PIC 9(02)    VALUE ZERO.
           05  WS-WARRANT-EDIT.
               10  FILLER              PIC X(01)    VALUE 'W'.
               10  WS-WE-NUMBER        PIC 9(07)    VALUE ZERO.
       01  WS-AUDIT-LINE.
           05  FILLER                  PIC X(08)    VALUE 'MBA300  '.
           05  WS-AL-LABEL             PIC X(28)    VALUE SPACES.
           05  FILLER                  PIC X(02)    VALUE SPACES.
           05  WS-AL-COUNT             PIC 9(07)    VALUE ZERO.
           05  FILLER                  PIC X(35)    VALUE SPACES.
       01  WS-AUDIT-MONEY-LINE.
           05  FILLER                  PIC X(08)    VALUE 'MBA300  '.
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
           GO TO 2000-READ-NEXT-BENEFIT.
      *
       1000-HOUSEKEEPING.
           OPEN INPUT BENEFIT-FILE.
           IF WS-BENEFIT-STATUS NOT = '00'
               MOVE 'PAYIN   ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           OPEN INPUT CONTROL-FILE.
           IF WS-CONTROL-STATUS NOT = '00'
               MOVE 'PAYCTL  ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           OPEN OUTPUT PAYMENT-FILE.
           OPEN OUTPUT AUDIT-FILE.
           PERFORM 1100-READ-CONTROL-CARD.
      *
       1100-READ-CONTROL-CARD.
           READ CONTROL-FILE INTO CONTROL-CARD
               AT END
                   MOVE 'PAYCTL  ' TO WS-ABEND-DDNAME
                   GO TO 9500-FILE-ABEND.
           IF NOT CC-CARD-VALID
               MOVE 'PAYCTL  ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           MOVE CC-WARRANT-SEED TO WS-WARRANT-SEQ.
           MOVE CC-CYCLE-YYYYMM TO WS-PD-YYYYMM.
      *
       2000-READ-NEXT-BENEFIT.
           READ BENEFIT-FILE INTO BENEFIT-RECORD
               AT END
                   GO TO 8000-CONTROL-TOTALS.
           ADD 1 TO WS-READ-COUNT.
           IF NOT BN-PAYABLE
               ADD 1 TO WS-SKIP-COUNT
               GO TO 2000-READ-NEXT-BENEFIT.
           IF BN-NET-BENEFIT NOT > ZERO
               ADD 1 TO WS-SKIP-COUNT
               GO TO 2000-READ-NEXT-BENEFIT.
           GO TO 2100-SPLIT-INSTALLMENTS.
      *
       2100-SPLIT-INSTALLMENTS.
           COMPUTE WS-INSTALL-2 = BN-NET-BENEFIT / 2.
           COMPUTE WS-INSTALL-1 = BN-NET-BENEFIT - WS-INSTALL-2.
           GO TO 2200-SCHEDULE-FIRST.
      *
       2200-SCHEDULE-FIRST.
           MOVE SPACES TO PAYMENT-RECORD.
           MOVE BN-CASE-ID     TO PY-CASE-ID.
           MOVE BN-COUNTY-CODE TO PY-COUNTY-CODE.
           MOVE BN-LAST-NAME   TO PY-LAST-NAME.
           ADD 1 TO WS-WARRANT-SEQ.
           MOVE WS-WARRANT-SEQ TO WS-WE-NUMBER.
           MOVE WS-WARRANT-EDIT TO PY-WARRANT-NO.
           MOVE 1 TO PY-INSTALLMENT-NO.
           MOVE CC-PAY-DAY-1 TO WS-PD-DD.
           MOVE WS-PAY-DATE-WORK TO PY-PAY-DATE.
           MOVE WS-INSTALL-1 TO PY-AMOUNT.
           MOVE CC-METHOD TO PY-METHOD-CODE.
           MOVE CC-CYCLE-YYYYMM TO PY-CYCLE-YYYYMM.
           PERFORM 3000-WRITE-PAYMENT.
           GO TO 2300-SCHEDULE-SECOND.
      *
       2300-SCHEDULE-SECOND.
           IF WS-INSTALL-2 NOT > ZERO
               GO TO 2000-READ-NEXT-BENEFIT.
           ADD 1 TO WS-WARRANT-SEQ.
           MOVE WS-WARRANT-SEQ TO WS-WE-NUMBER.
           MOVE WS-WARRANT-EDIT TO PY-WARRANT-NO.
           MOVE 2 TO PY-INSTALLMENT-NO.
           MOVE CC-PAY-DAY-2 TO WS-PD-DD.
           MOVE WS-PAY-DATE-WORK TO PY-PAY-DATE.
           MOVE WS-INSTALL-2 TO PY-AMOUNT.
           PERFORM 3000-WRITE-PAYMENT.
           GO TO 2000-READ-NEXT-BENEFIT.
      *
       3000-WRITE-PAYMENT.
           WRITE PAYMENT-IMAGE FROM PAYMENT-RECORD.
           IF WS-PAYMENT-STATUS NOT = '00'
               MOVE 'PAYOUT  ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           ADD 1 TO WS-PAYMENT-COUNT.
           ADD PY-AMOUNT TO WS-TOTAL-SCHEDULED.
      *
       8000-CONTROL-TOTALS.
           MOVE 'BENEFIT RECORDS READ' TO WS-AL-LABEL.
           MOVE WS-READ-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'RECORDS BYPASSED' TO WS-AL-LABEL.
           MOVE WS-SKIP-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'WARRANTS SCHEDULED' TO WS-AL-LABEL.
           MOVE WS-PAYMENT-COUNT TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'LAST WARRANT NUMBER USED' TO WS-AL-LABEL.
           MOVE WS-WARRANT-SEQ TO WS-AL-COUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-LINE.
           MOVE 'TOTAL SCHEDULED DOLLARS' TO WS-AM-LABEL.
           MOVE WS-TOTAL-SCHEDULED TO WS-AM-AMOUNT.
           WRITE AUDIT-IMAGE FROM WS-AUDIT-MONEY-LINE.
           GO TO 9000-END-OF-JOB.
      *
       9000-END-OF-JOB.
           CLOSE BENEFIT-FILE CONTROL-FILE PAYMENT-FILE AUDIT-FILE.
           MOVE ZERO TO RETURN-CODE.
           STOP RUN.
      *
       9500-FILE-ABEND.
           DISPLAY 'MBA300 CONTROL CARD OR IO FAILURE ON '
               WS-ABEND-DDNAME UPON SYSERR.
           MOVE 16 TO RETURN-CODE.
           STOP RUN.
