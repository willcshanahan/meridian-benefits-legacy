      *****************************************************************
      * COPYBOOK  WSCONST    -  POLICY CONSTANTS AND LITERAL TABLES   *
      * SYSTEM    MBA-100 THRU MBA-400                               *
      *                                                              *
      * THESE VALUES ARE HARD CODED BY DESIGN.  THE 1984 DESIGN NOTE  *
      * SAID A PARAMETER FILE WOULD FOLLOW "NEXT FISCAL YEAR".        *
      * IT HAS NOT FOLLOWED YET.  EVERY RATE CHANGE IS A RECOMPILE    *
      * AND A FULL GOLDEN FILE REBASELINE - SEE TESTS/README.         *
      *                                                              *
      * MAINT LOG                                                    *
      *   1984-03-11  D HALVORSEN   ORIGINAL CODING                  *
      *   1989-07-01  R OKONKWO     GRANT TABLE UPLIFT 3.1 PCT       *
      *   1996-04-15  M TREADAWAY   MINIMUM WARRANT RAISED TO 25.00  *
      *****************************************************************
       01  WS-POLICY-CONSTANTS.
           05  WC-LIMIT-BASE           PIC 9(05)V99 VALUE 1450.00.
           05  WC-LIMIT-PER-DEP        PIC 9(05)V99 VALUE 0310.00.
           05  WC-DISREGARD-PER-DEP    PIC 9(05)V99 VALUE 0060.00.
           05  WC-DISREGARD-DISABLED   PIC 9(05)V99 VALUE 0145.00.
           05  WC-BASE-GRANT           PIC 9(05)V99 VALUE 0742.50.
           05  WC-DEP-ALLOWANCE        PIC 9(05)V99 VALUE 0128.75.
           05  WC-OFFSET-RATE          PIC 9V999    VALUE 0.333.
           05  WC-MIN-RESIDENCY-MOS    PIC 9(03)    VALUE 006.
           05  WC-MIN-RESIDENCY-DIS    PIC 9(03)    VALUE 003.
           05  WC-MAX-DEPENDENTS       PIC 9(02)    VALUE 12.
           05  WC-CYCLE-DAYS           PIC 9(02)    VALUE 30.
           05  WC-MIN-WARRANT          PIC 9(05)V99 VALUE 0025.00.
           05  WC-REVIEW-THRESHOLD     PIC 9(03)    VALUE 085.
           05  WC-BAND-1-PCT           PIC 9(03)    VALUE 050.
           05  WC-BAND-2-PCT           PIC 9(03)    VALUE 075.
           05  WC-BAND-3-PCT           PIC 9(03)    VALUE 090.
      *
       01  WS-REASON-TEXT-TABLE.
           05  FILLER  PIC X(28) VALUE 'C11 CASE CLOSED IN MASTER   '.
           05  FILLER  PIC X(28) VALUE 'C14 CASE SUSPENDED - REVIEW '.
           05  FILLER  PIC X(28) VALUE 'E01 CASE ID MISSING         '.
           05  FILLER  PIC X(28) VALUE 'E07 DEPENDENT COUNT INVALID '.
           05  FILLER  PIC X(28) VALUE 'E09 COUNTY CODE NOT ON TABLE'.
           05  FILLER  PIC X(28) VALUE 'I05 INCOME OVER LIMIT       '.
           05  FILLER  PIC X(28) VALUE 'R02 RESIDENCY UNDER MINIMUM '.
           05  FILLER  PIC X(28) VALUE 'R09 RESIDENCY WAIVER REVIEW '.
           05  FILLER  PIC X(28) VALUE 'P03 PARTIAL MONTH AWARD     '.
           05  FILLER  PIC X(28) VALUE 'A00 FULL MONTH AWARD        '.
       01  WS-REASON-TABLE REDEFINES WS-REASON-TEXT-TABLE.
           05  WS-REASON-ENTRY OCCURS 10 TIMES.
               10  WS-RT-CODE          PIC X(03).
               10  FILLER              PIC X(01).
               10  WS-RT-TEXT          PIC X(24).
