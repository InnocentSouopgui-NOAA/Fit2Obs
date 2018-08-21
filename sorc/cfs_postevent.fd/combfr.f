C$$$  MAIN PROGRAM DOCUMENTATION BLOCK
C
C MAIN PROGRAM: BUFR_COMBFR
C   PRGMMR: KEYSER           ORG: NP22        DATE: 2013-01-24
C
C ABSTRACT: CONCATENATES INDIVIDUAL BUFR FILES INTO A SINGLE BUFR FILE,
C   AND FOR DUMP FILES (OPTIONALLY) GENERATES TWO DUMMY MESSAGES AT THE
C   BEGINNING OF THE OUTPUT COMBINED DUMP FILE WHICH CONTAIN ONLY THE
C   DUMP CENTER TIME AND THE CURRENT PROCESSING TIME ("DUMP" TIME) IN
C   SECTION ONE.  CURRENTLY THE MAXIMUM NUMBER OF FILES THAT CAN BE
C   COMBINED IS 100.  THE PATH NAMES OF THE FILES TO COMBINE ARE READ
C   FROM STANDARD INPUT (UNIT 05) AND CONNECTED TO FORTRAN UNIT 20 VIA
C   THE FORTRAN OPEN STATEMENT. THE OUTPUT FILE (UNIT 50) MUST BE
C   CONNECTED EXTERNALLY.
C
C PROGRAM HISTORY LOG:
C 1996-09-06  J. WOOLLEN  ORIGINAL VERSION FOR IMPLEMENTATION
C 1996-11-27  J. WOOLLEN  MADE OUTPUT FILE BUFR TABLE CHOOSING MORE
C     SECURE
C 1999-06-03  D. KEYSER   MODIFIED TO PORT TO IBM SP AND RUN IN 4 OR 8
C     BYTE STORAGE
C 2006-03-02  D. KEYSER   ADDED OPTION TO WRITE "DUMMY" MESSAGES
C     CONTAINING DUMP CENTER TIME AND PROCESSING TIME, RESP. INTO FIRST
C     TWO MESSAGES OF OUTPUT COMBINED DUMP FILE (AFTER TABLE MSGS),
C     WILL ONLY DO SO IF EXECUTING SCRIPT VARIABLE "DUMMY_MSGS" (READ
C     IN VIA "GETENV") IS "YES" AND THE DUMP CENTER AND PROCESSING TIME
C     IS SUCCESSFULLY READ FROM NEW UNIT 17 - NORMALLY THIS PROGRAM
C     WILL PERFORM THIS FUNCTION ONLY WHEN IT IS EXECUTED BY DUMPJB IN
C     THE DUMP PROCESSING {IT HAD BEEN DONE IN DUMPJB PROGRAM
C     BUFR_DUMPMD, BUT SINCE THE LEVEL 2 RADAR DUMP PROCESSING NO
C     LONGER EXECUTES THIS PROGRAM IN ORDER TO SAVE TIME (BECAUSE THERE
C     IS SO MUCH DATA), IT HAS BEEN MOVED HERE FOR ALL DATA TYPES
C     (MAKES MORE SENSE TO DO IT HERE SINCE DUMMY MESSAGES WILL ONLY BE
C     WRITTEN ONCE TO A COMBINED DUMP FILE, IN BUFR_DUMPMD THEY WERE
C     WRITTEN TO THE TOP OF EACH INDIVIDUAL DUMP FILE), THE EXCEPTION
C     IS FOR CASES WHERE DUMPJB SCRIPT VARIABLE "FORM" IS SET TO "copy"
C     (IN THIS CASE, THIS PROGRAM DOES NOT RUN SO BUFR_DUMPMD MUST
C     WRITE THE DUMMY MESSAGES TO THE TOP OF THE DUMP FILE)}; MODIFIED
C     TO WRITE AN EXTERNAL BUFR TABLE INTO THE COMBINED OUTPUT FILE
C     WHEN UNIT 10 IS NOT EMPTY (IN THIS CASE UNIT 10 CONTAINS THE PATH
C     TO THE EXTERNAL BUFR TABLE WHICH IS PRINTED TO STANDARD OUTPUT
C     AND UNIT 15 CONTAINS THE EXTERNAL BUFR TABLE ITSELF), WHEN UNIT
C     10 IS EMPTY THE INTERNAL BUFR FILE IN THE FIRST FILE READ IS
C     WRITTEN INTO THE COMBINED OUTPUT FILE (THE ONLY OPTION BEFORE
C     THIS CHANGE) (NOTE: DUMPJB HAS NOT YET BEEN MODIFIED TO USE AN
C     EXTERNAL BUFR TABLE, SO UNIT 10 IS ALWAYS EMPTY); IMPROVED
C     DOCUMENTATION AND AUGMENTED STANDARD OUTPUT PRINT; REPLACED CALL
C     TO BUFRLIB ROUTINE BORT WITH CALL TO W3LIB ROUTINE ERREXIT; NOW
C     CALLS ERREXIT IF THE NUMBER OF INPUT FILES IS ZERO; INCREASED THE
C     NUMBER OF FILES THAT CAN BE COMBINED FROM 29 TO 100.
C 2012-11-20  J. WOOLLEN  INITIAL PORT TO WCOSS -- ADAPTED IBM/AIX
C     GETENV SUBPROGRAM CALL TO INTEL/LINUX SYNTAX; ADDED ERR TRAP TO
C     BUFRTAB_PATH READ
C 2013-01-13  J. WHITING  READIED FOR IMPLEMENTATION ON WCOSS LINUX
C     (UPDATED DOC-BLOCK, ETC.; NO LOGIC CHANGES)
C 2013-01-24  J. WOOLLEN  ADJUST LOGIC TO FIND TABLES TO AVOID USING 
C     BUFRLIB ROUTINE MESGBF
C 2013-01-24  D. KEYSER   A FEW MINOR MODS; USE INTRINSIC "TRIM"
C     CHARACTER STRING FUNCTION TO ELIMINATE NEED TO OBTAIN NUMBER OF
C     NON-BLANK CHARACTERS IN STRINGS; REPLACED GETENV WITH MORE
C     STANDARD GET_ENVIRONMENT_VARIABLE.
C
C USAGE:
C   INPUT FILES:
C     UNIT 05  - STANDARD INPUT - RECORDS CONTAINING THE INPUT FILE
C                NAMES FOR BUFR FILES BEING COMBINED INTO A SINGLE
C                FILE - ANY RECORD BEGINNING WITH "fort" IS SKIPPED
C     UNIT 10  - TEXT WHICH CONTAINS PATH TO THE EXTERNAL BUFR TABLE
C                (PRINTED TO STANDARD OUTPUT) READ IN UNIT 15 (IF THIS
C                IS EMPTY -- AND CURRENTLY IS ALWAYS IT! --, THE
C                INTERNAL BUFR FILE IN THE FIRST FILE READ IS WRITTEN
C                INTO THE COMBINED OUTPUT FILE)
C     UNIT 15  - EXTERNAL BUFR TABLE (ONLY READ IF UNIT 10 IS NOT
C                EMPTY -- CURRENTLY UNIT 10 IS ALWAYS EMPTY!!)
C     UNIT 17  - IF PRESENT, FIRST RECORD CONTAINS YYYYMMDDHH<.HH> DATE
C                OF THE DUMP CENTER TIME, SECOND RECORD CONTAINS THE
C                YYYYMMDDHHMM DATE OF THE CURRENT WALLCLOCK TIME; THE
C                ABSENCE OF THIS FILE IS A SIGNAL THAT THIS PROGRAM
C                SHOULD NOT WRITE CENTER AND DUMP TIME DUMMY MESSAGES
C                TO THE TOP OF THE OUTPUT COMBINED DUMP FILE
C     UNIT 20  - THE VARIOUS BUFR FILES IN THE LIST TO BE COMBINED
C                (CONNECTED INTERNALLY VIA FORTRAN OPEN STATEMENT)
C
C   OUTPUT FILES:
C     UNIT 50  - COMBINED BUFR FILE, POSSIBLY WITH CENTER TIME AND DUMP
C                TIME DUMMY MESSAGES AT THE BEGINNING (TOP) (CONNECTED
C                EXTERNALLY)
C
C   SUBPROGRAMS CALLED:
C     UNIQUE     - NONE
C     SYSTEM     - GET_ENVIRONMENT_VARIABLE
C     LIBRARY:
C       W3NCO    - W3TAGB   W3TAGE   ERREXIT
C       BUFRLIB  - DATELEN  OPENBF   COPYMG   CLOSBF   IREADMG
C                  OPENMG   MINIMG
C
C   EXIT STATES:
C     COND =   0 - SUCCESSFUL RUN
C            > 0 - ABNORMAL RUN
C
C REMARKS:
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 90
C   MACHINE:  WCOSS
C
C$$$

      PROGRAM BUFR_COMBFR
 
      PARAMETER (NFILES=100)  ! Number of input files being considered

      CHARACTER*500 BUFRTAB_PATH,FILI(NFILES),THIS_FILI
      CHARACTER*8   SUBSET
      CHARACTER*3   DUMMY_MSGS
      REAL(8)       CDATE,DDATE
      INTEGER(8)    LDATE_8,MDATE_8
      INTEGER       NCPY(NFILES)
      LOGICAL       COPY_DUMMY_MSGS

      DATA LUNIN,LUNDX,LUNOT/20,15,50/
 
C----------------------------------------------------------------------
C----------------------------------------------------------------------
      CALL W3TAGB('BUFR_COMBFR',2013,0024,0053,'NP22')
 
      print *
      print * ,'---> Welcome to BUFR_COMBFR - Version 01-24-2013'
      print *

      CALL DATELEN(10)

      NFIL = 0

      COPY_DUMMY_MSGS = .FALSE.

      CALL GET_ENVIRONMENT_VARIABLE('DUMMY_MSGS',DUMMY_MSGS)
      IF(DUMMY_MSGS.EQ.'YES') THEN

C  Pgm expected to generate "Dummy" msgs containing center & dump times
C  --------------------------------------------------------------------

         READ(17,*,END=8,ERR=8) CDATE
         READ(17,*,END=8,ERR=8) DDATE
         PRINT *,'REQUESTED CENTER DATE IS ... ',CDATE
         PRINT *,'DUMP PROCESSING  DATE IS ... ',DDATE
         LDATE_8 = INT(CDATE)*100_8 + NINT((CDATE-INT(CDATE))*60.)
         MDATE_8 = DDATE
         LMINS = MOD(LDATE_8,100_8)
         MMINS = MOD(MDATE_8,100_8)
         LDATE = LDATE_8/100
         MDATE = MDATE_8/100
         COPY_DUMMY_MSGS = .TRUE.
      ENDIF

      GO TO 9

8     CONTINUE

C  Center and dump times not found in unit 17, "dummy" messages can't
C   be generated
C  ------------------------------------------------------------------

      PRINT *
      PRINT *, '+++ WARNING: CENTER AND/OR DUMP DATE NOT FOUND IN ',
     $ 'UNIT 17 - "DUMMY" MESSAGES NOT WRITTEN TO TOP OF OUTPUT FILE'
      PRINT *

9     CONTINUE

C  READ THE LOCATIONS OF FILES TO COMBINE
C  --------------------------------------
 
      DO
         READ(5,'(A)',END=1) THIS_FILI
         IF(NFIL+1.GT.NFILES) THEN
            PRINT *
            PRINT *, '### BUFR_COMBFR: THE NUMBER OF INPUT FILES ',
     $       'EXCEEDS THE LIMIT OF ',NFILES,' -- STOP 99'
            PRINT *
            CALL W3TAGE('BUFR_COMBFR')
            CALL ERREXIT(99)
         ENDIF
         FILI(NFIL+1) = THIS_FILI
         IF(FILI(NFIL+1)(1:4).EQ.'fort')  CYCLE
         NFIL = NFIL+1
      ENDDO

1     CONTINUE

      IF(NFIL.EQ.0)  THEN
         PRINT *
         PRINT *, '### BUFR_COMBFR: THE NUMBER OF INPUT FILES IS ZERO',
     $    ' -- STOP 77'
         PRINT *
         CALL W3TAGE('BUFR_COMBFR')
         CALL ERREXIT(77)
      ENDIF

C  DETERMINE WHERE TO GET BUFR TABLE TO WRITE INTO OUTPUT FILE
C  -----------------------------------------------------------
 
      READ(10,'(A)',END=3,err=3) BUFRTAB_PATH

C  Come here if BUFR Table is found in an external file
C  ----------------------------------------------------

      PRINT 100, TRIM(BUFRTAB_PATH)
      CALL OPENBF(LUNOT,'OUT',LUNDX)
      GO TO 2

    3 CONTINUE

C  Come here if BUFR Table is NOT found in an external file (look for
C  first input file that has an internal table and use this table)
C  ------------------------------------------------------------------

      DO N=1,NFIL
         CALL CLOSBF(LUNIN)
         OPEN(LUNIN,FILE=TRIM(FILI(N)),FORM='UNFORMATTED')
         CALL OPENBF(LUNIN,'IN ',LUNIN)
         IF(IREADMG(LUNIN,SUBSET,IDATE)==0) THEN
            CALL OPENBF(LUNOT,'OUT',LUNIN)
            CALL CLOSBF(LUNIN)
            PRINT 101, TRIM(FILI(N))
            GO TO 2
         ENDIF
      ENDDO

      PRINT *
      PRINT *, '+++ WARNING: CANNOT FIND A BUFR TABLE TO WRITE INTO ',
     $ 'OUTPUT FILE - OUTPUT FILE MUST BE EMPTY!!'
      PRINT *

    2 CONTINUE

C  COMBINE ALL MESSAGES FROM ALL INPUT FILES
C  -----------------------------------------
 
      NCPY = 0
      DO N=1,NFIL
         CALL CLOSBF(LUNIN)
         OPEN(LUNIN,FILE=TRIM(FILI(N)),FORM='UNFORMATTED')
         CALL OPENBF(LUNIN,'IN',LUNOT)
         DO WHILE(IREADMG(LUNIN,SUBSET,IDATE).EQ.0)
            IF(COPY_DUMMY_MSGS)  THEN

C  FIRST TIME IN LOOP (ONLY), GENERATE "DUMMY" MESSAGES CONTAINING
C   CENTER AND DUMP TIMES AND WRITE TO OUTPUT COMBINED DUMP FILE
C  ---------------------------------------------------------------

C  First message in output file contains only dump center time in Sec 1
C  --------------------------------------------------------------------

               CALL OPENMG(LUNOT,SUBSET,LDATE)
               CALL MINIMG(LUNOT,LMINS)

C  Second message in output file contains only current time in Sec 1
C  -----------------------------------------------------------------

               CALL OPENMG(LUNOT,SUBSET,MDATE)
               CALL MINIMG(LUNOT,MMINS)
               CALL CLOSMG(LUNOT)
               COPY_DUMMY_MSGS = .FALSE.
               PRINT 102
            ENDIF
            CALL COPYMG(LUNIN,LUNOT)
            NCPY(N) = NCPY(N) + 1
         ENDDO
         PRINT 103, NCPY(N),TRIM(FILI(N))
      ENDDO

      IF(COPY_DUMMY_MSGS) THEN

C  Can only get here if code expected to generate and write out dummy
C   messages and this didn't happen because no data messages were found
C   in any of the input files - in this case output (dump) file must be
C   empty, otherwise some codes reading it (e.g., IW3UNPBF) will fail
C   when they cannot find values for the dump center & processing times
C  --------------------------------------------------------------------

         PRINT *
         PRINT *, 'NO INPUT DATA MESSAGES FOUND - FORCE OUTPUT (DUMP) ',
     $            'FILE TO BE EMPTY'
         PRINT *
         ENDFILE 50
         CALL SYSTEM('cp /dev/null fort.50')
      END IF

      PRINT *
      PRINT *, 'PROGRAM COMPLETED SUCCESSFULLY'
      PRINT *

      CALL W3TAGE('BUFR_COMBFR')

      STOP

  100 FORMAT(/' --> Will write output file using external BUFR table'/
     $ 5X,A/)
  101 FORMAT(/' --> Will write output file using BUFR table internal ',
     $ 'to'/5X,A/5X,'(the first non-empty input file)'/)
  102 FORMAT(/' ==> "Dummy" messages containing dump center time and ',
     $ 'wall-clock processing time successfully written to top of ',
     $ 'output file'/)
  103 FORMAT(//2X,'--',I7,' BUFR MESSAGES COPIED FROM INPUT FILE ',A,
     $ ' TO COMBINED OUTPUT FILE')

      END
