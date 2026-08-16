       IDENTIFICATION DIVISION.
       PROGRAM-ID.     REPTGEN.
       AUTHOR.         D HALVORSEN.
       INSTALLATION.   MERIDIAN STATE BENEFITS AGENCY.
       DATE-WRITTEN.   1984-06-25.
      *****************************************************************
      * MODULE   REPTGEN    (LOAD MODULE MBA400)                      *
      * FUNCTION PAYMENT REGISTER MBA-400.  CONTROL BREAK ON COUNTY    *
      *          CODE WITH COUNTY SUBTOTALS AND A GRAND TOTAL PAGE.    *
      *                                                               *
      * DD NAMES REPTIN   I  PAYMENT SCHEDULE SORTED BY COUNTY / CASE  *
      *          REPTCTL  I  CYCLE CONTROL CARD  SAME CARD AS MBA300   *
      *          REPTOUT  O  PRINT FILE  LRECL 132  RECFM FBA          *
      *                                                               *
      * THE INPUT MUST ARRIVE IN COUNTY THEN CASE ID ORDER.  MBA400    *
      * DOES NOT SORT AND DOES NOT VERIFY SEQUENCE - THE SORT STEP IN  *
      * NIGHTLY.JCL IS NOT OPTIONAL.  A MIS SORTED FILE PRODUCES A     *
      * REGISTER WITH REPEATED COUNTY BREAKS AND NOBODY NOTICES UNTIL  *
      * THE FIELD OFFICES CALL.                                        *
      *                                                               *
      * MAINT LOG                                                     *
      *   1984-06-25  D HALVORSEN  ORIGINAL CODING                    *
      *   1988-05-16  D HALVORSEN  PAGE DEPTH CUT TO 20 DETAIL LINES   *
      *                            FOR THE 8 1/2 INCH STOCK           *
      *   1994-02-11  M TREADAWAY  COUNTY NAME TABLE ADDED            *
      *****************************************************************
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.  MSB-HOST.
       OBJECT-COMPUTER.  MSB-HOST.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT PAYMENT-FILE    ASSIGN TO "REPTIN"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-PAYMENT-STATUS.
           SELECT CONTROL-FILE    ASSIGN TO "REPTCTL"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-CONTROL-STATUS.
           SELECT PRINT-FILE      ASSIGN TO "REPTOUT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS  IS WS-PRINT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  PAYMENT-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS PAYMENT-IMAGE.
       01  PAYMENT-IMAGE           PIC X(80).
       FD  CONTROL-FILE
           RECORD CONTAINS 80 CHARACTERS
           DATA RECORD IS CONTROL-IMAGE.
       01  CONTROL-IMAGE           PIC X(80).
       FD  PRINT-FILE
           RECORD CONTAINS 132 CHARACTERS
           DATA RECORD IS PRINT-IMAGE.
       01  PRINT-IMAGE             PIC X(132).
       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS-AREA.
           05  WS-PAYMENT-STATUS       PIC X(02)    VALUE '00'.
           05  WS-CONTROL-STATUS       PIC X(02)    VALUE '00'.
           05  WS-PRINT-STATUS         PIC X(02)    VALUE '00'.
           05  WS-ABEND-DDNAME         PIC X(08)    VALUE SPACES.
       01  CONTROL-CARD.
           05  CC-CARD-ID              PIC X(04).
               88  CC-CARD-VALID       VALUE 'MBA3'.
           05  FILLER                  PIC X(01).
           05  CC-CYCLE-YYYYMM         PIC 9(06).
           05  FILLER                  PIC X(69).
       01  WS-CONTROL-FIELDS.
           05  WS-HOLD-COUNTY          PIC X(03)    VALUE SPACES.
           05  WS-FIRST-REC-SW         PIC X(01)    VALUE 'Y'.
               88  WS-FIRST-RECORD     VALUE 'Y'.
           05  WS-LINE-COUNT           PIC 9(03)    VALUE ZERO.
           05  WS-PAGE-COUNT           PIC 9(03)    VALUE ZERO.
           05  WS-MAX-DETAIL           PIC 9(03)    VALUE 020.
       01  WS-ACCUMULATORS.
           05  WS-COUNTY-COUNT         PIC 9(07)    VALUE ZERO.
           05  WS-COUNTY-AMOUNT        PIC 9(09)V99 VALUE ZERO.
           05  WS-GRAND-COUNT          PIC 9(07)    VALUE ZERO.
           05  WS-GRAND-AMOUNT         PIC 9(09)V99 VALUE ZERO.
           05  WS-COUNTY-BREAKS        PIC 9(03)    VALUE ZERO.
       01  WS-COUNTY-NAME-TABLE.
           05  FILLER  PIC X(21) VALUE '011ALDER CREEK       '.
           05  FILLER  PIC X(21) VALUE '024BRANDT HOLLOW     '.
           05  FILLER  PIC X(21) VALUE '037CALDER PLAIN      '.
           05  FILLER  PIC X(21) VALUE '052DUNMORE RIDGE     '.
           05  FILLER  PIC X(21) VALUE '068ESKRIDGE FLATS    '.
           05  FILLER  PIC X(21) VALUE '073FAIRMOUNT BASIN   '.
       01  WS-COUNTY-TABLE REDEFINES WS-COUNTY-NAME-TABLE.
           05  WS-COUNTY-ENTRY OCCURS 6 TIMES.
               10  WS-CT-CODE          PIC X(03).
               10  WS-CT-NAME          PIC X(18).
       01  WS-SUB                      PIC 9(02)    VALUE ZERO.
       01  WS-COUNTY-NAME              PIC X(18)    VALUE SPACES.
      *
      * PRINT LINE LAYOUTS - 132 BYTE STOCK, COLUMN 1 IS DATA NOT
      * A CARRIAGE CONTROL CHARACTER.  THE ASA CHANNEL BYTE WAS
      * DROPPED WHEN THE 1988 PRINT SUBSYSTEM WENT IN.
      *
       01  WS-HEAD-LINE-1.
           05  FILLER      PIC X(08) VALUE 'MBA-400 '.
           05  FILLER      PIC X(38) VALUE
               'MERIDIAN STATE BENEFITS AGENCY        '.
           05  FILLER      PIC X(24) VALUE 'BENEFIT PAYMENT REGISTER'.
           05  FILLER      PIC X(46) VALUE SPACES.
           05  FILLER      PIC X(06) VALUE 'PAGE  '.
           05  WS-HL1-PAGE PIC ZZ9.
           05  FILLER      PIC X(07) VALUE SPACES.
       01  WS-HEAD-LINE-2.
           05  FILLER      PIC X(08) VALUE SPACES.
           05  FILLER      PIC X(14) VALUE 'PAYMENT CYCLE '.
           05  WS-HL2-CYCLE PIC 9(06).
           05  FILLER      PIC X(06) VALUE SPACES.
           05  FILLER      PIC X(09) VALUE 'COUNTY   '.
           05  WS-HL2-CODE PIC X(03).
           05  FILLER      PIC X(02) VALUE SPACES.
           05  WS-HL2-NAME PIC X(18).
           05  FILLER      PIC X(66) VALUE SPACES.
       01  WS-HEAD-LINE-3.
           05  FILLER      PIC X(09) VALUE 'CASE ID  '.
           05  FILLER      PIC X(02) VALUE SPACES.
           05  FILLER      PIC X(18) VALUE 'CLAIMANT NAME     '.
           05  FILLER      PIC X(03) VALUE SPACES.
           05  FILLER      PIC X(08) VALUE 'WARRANT '.
           05  FILLER      PIC X(04) VALUE SPACES.
           05  FILLER      PIC X(01) VALUE 'I'.
           05  FILLER      PIC X(04) VALUE SPACES.
           05  FILLER      PIC X(08) VALUE 'PAY DATE'.
           05  FILLER      PIC X(04) VALUE SPACES.
           05  FILLER      PIC X(09) VALUE '   AMOUNT'.
           05  FILLER      PIC X(06) VALUE SPACES.
           05  FILLER      PIC X(01) VALUE 'M'.
           05  FILLER      PIC X(55) VALUE SPACES.
       01  WS-DASH-LINE.
           05  FILLER      PIC X(132) VALUE ALL '-'.
       01  WS-DETAIL-LINE.
           05  WS-DL-CASE-ID   PIC X(09).
           05  FILLER          PIC X(02) VALUE SPACES.
           05  WS-DL-NAME      PIC X(18).
           05  FILLER          PIC X(03) VALUE SPACES.
           05  WS-DL-WARRANT   PIC X(08).
           05  FILLER          PIC X(04) VALUE SPACES.
           05  WS-DL-INST      PIC 9(01).
           05  FILLER          PIC X(04) VALUE SPACES.
           05  WS-DL-PAY-DATE  PIC 9(08).
           05  FILLER          PIC X(04) VALUE SPACES.
           05  WS-DL-AMOUNT    PIC ZZ,ZZZ.99.
           05  FILLER          PIC X(06) VALUE SPACES.
           05  WS-DL-METHOD    PIC X(01).
           05  FILLER          PIC X(55) VALUE SPACES.
       01  WS-SUBTOTAL-LINE.
           05  FILLER          PIC X(11) VALUE SPACES.
           05  FILLER          PIC X(14) VALUE 'COUNTY TOTAL  '.
           05  WS-ST-CODE      PIC X(03).
           05  FILLER          PIC X(03) VALUE SPACES.
           05  WS-ST-COUNT     PIC ZZZ,ZZ9.
           05  FILLER          PIC X(11) VALUE ' WARRANTS  '.
           05  WS-ST-AMOUNT    PIC ZZZ,ZZZ,ZZ9.99.
           05  FILLER          PIC X(73) VALUE SPACES.
       01  WS-GRAND-LINE.
           05  FILLER          PIC X(11) VALUE SPACES.
           05  FILLER          PIC X(20) VALUE 'STATEWIDE TOTAL     '.
           05  WS-GT-COUNT     PIC ZZZ,ZZ9.
           05  FILLER          PIC X(11) VALUE ' WARRANTS  '.
           05  WS-GT-AMOUNT    PIC ZZZ,ZZZ,ZZ9.99.
           05  FILLER          PIC X(73) VALUE SPACES.
       01  WS-EOR-LINE.
           05  FILLER          PIC X(11) VALUE SPACES.
           05  FILLER          PIC X(30) VALUE
               'END OF REPORT MBA-400         '.
           05  WS-EOR-BREAKS   PIC ZZ9.
           05  FILLER          PIC X(20) VALUE ' COUNTIES REPORTED  '.
           05  FILLER          PIC X(68) VALUE SPACES.
       COPY "BENEFIT.CPY".
       COPY "WSCONST.CPY".
       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       0000-MAIN-CONTROL.
           PERFORM 1000-HOUSEKEEPING.
           GO TO 2000-READ-NEXT-PAYMENT.
      *
       1000-HOUSEKEEPING.
           OPEN INPUT PAYMENT-FILE.
           IF WS-PAYMENT-STATUS NOT = '00'
               MOVE 'REPTIN  ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           OPEN INPUT CONTROL-FILE.
           OPEN OUTPUT PRINT-FILE.
           READ CONTROL-FILE INTO CONTROL-CARD
               AT END
                   MOVE 'REPTCTL ' TO WS-ABEND-DDNAME
                   GO TO 9500-FILE-ABEND.
           IF NOT CC-CARD-VALID
               MOVE 'REPTCTL ' TO WS-ABEND-DDNAME
               GO TO 9500-FILE-ABEND.
           MOVE CC-CYCLE-YYYYMM TO WS-HL2-CYCLE.
      *
       2000-READ-NEXT-PAYMENT.
           READ PAYMENT-FILE INTO PAYMENT-RECORD
               AT END
                   GO TO 7000-FINAL-TOTALS.
           IF WS-FIRST-RECORD
               MOVE 'N' TO WS-FIRST-REC-SW
               MOVE PY-COUNTY-CODE TO WS-HOLD-COUNTY
               PERFORM 4000-PAGE-HEADING.
           IF PY-COUNTY-CODE NOT = WS-HOLD-COUNTY
               PERFORM 5000-COUNTY-BREAK.
           PERFORM 3000-PRINT-DETAIL.
           GO TO 2000-READ-NEXT-PAYMENT.
      *
       3000-PRINT-DETAIL.
           IF WS-LINE-COUNT NOT < WS-MAX-DETAIL
               PERFORM 4000-PAGE-HEADING.
           MOVE PY-CASE-ID       TO WS-DL-CASE-ID.
           MOVE PY-LAST-NAME     TO WS-DL-NAME.
           MOVE PY-WARRANT-NO    TO WS-DL-WARRANT.
           MOVE PY-INSTALLMENT-NO TO WS-DL-INST.
           MOVE PY-PAY-DATE      TO WS-DL-PAY-DATE.
           MOVE PY-AMOUNT        TO WS-DL-AMOUNT.
           MOVE PY-METHOD-CODE   TO WS-DL-METHOD.
           WRITE PRINT-IMAGE FROM WS-DETAIL-LINE.
           ADD 1 TO WS-LINE-COUNT.
           ADD 1 TO WS-COUNTY-COUNT.
           ADD 1 TO WS-GRAND-COUNT.
           ADD PY-AMOUNT TO WS-COUNTY-AMOUNT.
           ADD PY-AMOUNT TO WS-GRAND-AMOUNT.
      *
       4000-PAGE-HEADING.
           ADD 1 TO WS-PAGE-COUNT.
           MOVE WS-PAGE-COUNT TO WS-HL1-PAGE.
           MOVE WS-HOLD-COUNTY TO WS-HL2-CODE.
           PERFORM 4500-LOOKUP-COUNTY.
           MOVE WS-COUNTY-NAME TO WS-HL2-NAME.
           WRITE PRINT-IMAGE FROM WS-HEAD-LINE-1.
           WRITE PRINT-IMAGE FROM WS-HEAD-LINE-2.
           WRITE PRINT-IMAGE FROM WS-DASH-LINE.
           WRITE PRINT-IMAGE FROM WS-HEAD-LINE-3.
           WRITE PRINT-IMAGE FROM WS-DASH-LINE.
           MOVE ZERO TO WS-LINE-COUNT.
      *
       4500-LOOKUP-COUNTY.
           MOVE 'COUNTY NOT ON TABLE' TO WS-COUNTY-NAME.
           PERFORM VARYING WS-SUB FROM 1 BY 1
                   UNTIL WS-SUB > 6
               IF WS-CT-CODE (WS-SUB) = WS-HOLD-COUNTY
                   MOVE WS-CT-NAME (WS-SUB) TO WS-COUNTY-NAME
               END-IF
           END-PERFORM.
      *
       5000-COUNTY-BREAK.
           PERFORM 6000-PRINT-SUBTOTAL.
           MOVE PY-COUNTY-CODE TO WS-HOLD-COUNTY.
           MOVE ZERO TO WS-COUNTY-COUNT WS-COUNTY-AMOUNT.
           PERFORM 4000-PAGE-HEADING.
      *
       6000-PRINT-SUBTOTAL.
           MOVE WS-HOLD-COUNTY   TO WS-ST-CODE.
           MOVE WS-COUNTY-COUNT  TO WS-ST-COUNT.
           MOVE WS-COUNTY-AMOUNT TO WS-ST-AMOUNT.
           WRITE PRINT-IMAGE FROM WS-DASH-LINE.
           WRITE PRINT-IMAGE FROM WS-SUBTOTAL-LINE.
           ADD 1 TO WS-COUNTY-BREAKS.
      *
       7000-FINAL-TOTALS.
           IF WS-FIRST-RECORD
               GO TO 9000-END-OF-JOB.
           PERFORM 6000-PRINT-SUBTOTAL.
           MOVE WS-GRAND-COUNT  TO WS-GT-COUNT.
           MOVE WS-GRAND-AMOUNT TO WS-GT-AMOUNT.
           MOVE WS-COUNTY-BREAKS TO WS-EOR-BREAKS.
           WRITE PRINT-IMAGE FROM WS-DASH-LINE.
           WRITE PRINT-IMAGE FROM WS-GRAND-LINE.
           WRITE PRINT-IMAGE FROM WS-EOR-LINE.
           GO TO 9000-END-OF-JOB.
      *
       9000-END-OF-JOB.
           CLOSE PAYMENT-FILE CONTROL-FILE PRINT-FILE.
           MOVE ZERO TO RETURN-CODE.
           STOP RUN.
      *
       9500-FILE-ABEND.
           DISPLAY 'MBA400 OPEN OR IO FAILURE ON ' WS-ABEND-DDNAME
               UPON SYSERR.
           MOVE 16 TO RETURN-CODE.
           STOP RUN.
