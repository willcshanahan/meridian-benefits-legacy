      *****************************************************************
      * COPYBOOK  CLAIMANT   -  CLAIMANT MASTER EXTRACT RECORD        *
      * SYSTEM    MBA-100    MERIDIAN STATE BENEFITS AGENCY           *
      * LRECL     80         RECFM  FB                               *
      *                                                              *
      * MAINT LOG                                                    *
      *   1984-03-11  D HALVORSEN   ORIGINAL CODING                  *
      *   1987-09-02  R OKONKWO     ADDED CL-ELIG-START-DAY FOR THE  *
      *                             PARTIAL MONTH RULE (AR 87-114)   *
      *   1993-06-18  M TREADAWAY   RESERVED FILLER CUT TO 21 BYTES  *
      *****************************************************************
       01  CLAIMANT-RECORD.
           05  CL-CASE-ID              PIC X(09).
           05  CL-LAST-NAME            PIC X(18).
           05  CL-FIRST-INIT           PIC X(01).
           05  CL-COUNTY-CODE          PIC X(03).
               88  CL-COUNTY-VALID     VALUE '011' '024' '037'
                                             '052' '068' '073'.
           05  CL-FILING-DATE          PIC 9(08).
           05  CL-MONTHLY-INCOME       PIC 9(07)V99.
           05  CL-DEPENDENT-COUNT      PIC 9(02).
               88  CL-NO-DEPENDENTS    VALUE 00.
           05  CL-RESIDENCY-MONTHS     PIC 9(03).
           05  CL-DISABILITY-FLAG      PIC X(01).
               88  CL-DISABLED         VALUE 'Y'.
               88  CL-NOT-DISABLED     VALUE 'N'.
           05  CL-PRIOR-CLAIM-FLAG     PIC X(01).
               88  CL-PRIOR-CLAIM      VALUE 'Y'.
           05  CL-ELIG-START-DAY       PIC 9(02).
               88  CL-FULL-MONTH       VALUE 01.
           05  CL-STATUS-CODE          PIC X(02).
               88  CL-ACTIVE           VALUE 'AC'.
               88  CL-PENDING          VALUE 'PN'.
               88  CL-SUSPENDED        VALUE 'SU'.
               88  CL-CLOSED           VALUE 'CL'.
           05  FILLER                  PIC X(21).
