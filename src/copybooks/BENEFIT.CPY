      *****************************************************************
      * COPYBOOK  BENEFIT    -  INTERFACE RECORDS FOR THE MBA NIGHTLY *
      *                         BENEFIT CYCLE                        *
      * SYSTEM    MBA-100 / MBA-200 / MBA-300 / MBA-400              *
      * LRECL     80  ALL THREE LAYOUTS - DO NOT CHANGE LENGTHS      *
      *                                                              *
      * ELIG-RECORD     WRITTEN BY ELIGCALC  READ BY BENEFITS        *
      * BENEFIT-RECORD  WRITTEN BY BENEFITS  READ BY PAYCALC         *
      * PAYMENT-RECORD  WRITTEN BY PAYCALC   READ BY REPTGEN         *
      *                                                              *
      * MAINT LOG                                                    *
      *   1984-04-02  D HALVORSEN   ORIGINAL CODING                  *
      *   1986-01-27  D HALVORSEN   EL-POINTS ADDED FOR THE REVIEW   *
      *                             QUEUE SCORE (NEVER RETIRED)      *
      *   1991-11-05  R OKONKWO     BN-ROUND-IND ADDED WHILE CHASING *
      *                             THE PENNY VARIANCE ON AR 91-233  *
      *****************************************************************
       01  ELIG-RECORD.
           05  EL-CASE-ID              PIC X(09).
           05  EL-LAST-NAME            PIC X(18).
           05  EL-COUNTY-CODE          PIC X(03).
           05  EL-ELIG-CODE            PIC X(01).
               88  EL-ELIGIBLE         VALUE 'E'.
               88  EL-PARTIAL          VALUE 'P'.
               88  EL-REFERRED         VALUE 'R'.
               88  EL-DENIED           VALUE 'D'.
           05  EL-REASON-CODE          PIC X(03).
           05  EL-INCOME-BAND          PIC 9(01).
           05  EL-DEPENDENT-COUNT      PIC 9(02).
           05  EL-COUNTABLE-INCOME     PIC 9(07)V99.
           05  EL-ELIG-DAYS            PIC 9(02).
           05  EL-POINTS               PIC 9(03).
           05  FILLER                  PIC X(29).
      *
       01  BENEFIT-RECORD.
           05  BN-CASE-ID              PIC X(09).
           05  BN-LAST-NAME            PIC X(18).
           05  BN-COUNTY-CODE          PIC X(03).
           05  BN-ELIG-CODE            PIC X(01).
               88  BN-PAYABLE          VALUE 'E' 'P'.
               88  BN-BELOW-MINIMUM    VALUE 'M'.
               88  BN-NOT-PAYABLE      VALUE 'D' 'R'.
           05  BN-BASE-AMOUNT          PIC 9(05)V99.
           05  BN-DEPENDENT-ALLOW      PIC 9(05)V99.
           05  BN-INCOME-OFFSET        PIC 9(05)V99.
           05  BN-PRORATE-DAYS         PIC 9(02).
           05  BN-NET-BENEFIT          PIC 9(05)V99.
           05  BN-ROUND-IND            PIC X(01).
               88  BN-ROUNDED-UP       VALUE 'R'.
           05  FILLER                  PIC X(18).
      *
       01  PAYMENT-RECORD.
           05  PY-CASE-ID              PIC X(09).
           05  PY-COUNTY-CODE          PIC X(03).
           05  PY-LAST-NAME            PIC X(18).
           05  PY-WARRANT-NO           PIC X(08).
           05  PY-INSTALLMENT-NO       PIC 9(01).
           05  PY-PAY-DATE             PIC 9(08).
           05  PY-AMOUNT               PIC 9(05)V99.
           05  PY-METHOD-CODE          PIC X(01).
               88  PY-WARRANT-MAILED   VALUE 'W'.
               88  PY-DIRECT-DEPOSIT   VALUE 'D'.
           05  PY-CYCLE-YYYYMM         PIC 9(06).
           05  FILLER                  PIC X(19).
