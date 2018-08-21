C-----------------------------------------------------------------------
C  MAIN PROGRAM SURUFIT
!   Author: Suranjana Saha
C-----------------------------------------------------------------------
c   make sure when you change levels, you check pmandt and pmandb
C-----------------------------------------------------------------------
      PROGRAM SURUFIT

      PARAMETER (IDBUG=0,IPR=1)
      PARAMETER (NSTC=9)
      PARAMETER (NPLV=3)
      PARAMETER (NVAR=4)
      PARAMETER (NREG=1)
      PARAMETER (NSUB=1)
      PARAMETER (NBAK=2)
 
      CHARACTER*80 HDSTR,OBSTR,FCSTR,ANSTR,QMSTR,PSTR
      CHARACTER*8  SUBSET

      real(8)      HDR(14)
      real(8)      PSOB(4),PSPR(4)
      real(8)      BAK(10,255,NBAK)
      real(8)      OBS(10,255),QMS(10,255),BMISS

      real(8)      SPRS(NSTC,NPLV,NVAR,NREG,NSUB,NBAK)
      real(8)      CNTO,CNTN,RAT1,RAT2,WT1,WT2 
      real(8)      PMANDB(NPLV),PMANDT(NPLV)
      real(8)      STC(NSTC,5,NBAK)

      real(4)      GDATA(NREG,NSUB)

      LOGICAL      MANDONLY,REGION
      INTEGER      INDEXV(NVAR)

      DATA HDSTR
     ./'SID XOB YOB DHR ELV TYP T29 ITP SQN RQM DUP PRG SRC RUD'/
      DATA PSTR /'POB PAN PFC PQM CAT=0'/
      DATA OBSTR/'POB QOB TOB ZOB UOB VOB'/
      DATA FCSTR/'PFC QFC TFC ZFC UFC VFC'/
      DATA ANSTR/'PAN QAN TAN ZAN UAN VAN'/
      DATA QMSTR/'PQM QQM TQM ZQM WQM CAT'/
 
      DATA BMISS /  10E10 /
      DATA RMISS / -9.99E+33 /
      DATA LUBFR/11/
      data indexv/2,3,4,1/
c...  t,z,w,q
c
      DATA PMANDB / 1000,700,300/
      DATA PMANDT /  700,300,150/
c
      bmiss=10e10; call setbmiss(bmiss) ! this sets bufrlib missing value to 10e10

      levt1=pmandt(1)
      levb1=pmandb(1)
      levt2=pmandt(2)
      levb2=pmandb(2)
      levt3=pmandt(3)
      levb3=pmandb(3)
c
       CALL OPENBF(LUBFR,'IN ',LUBFR)
c
C-----------------------------------------------------------------------
 
C  ZERO THE FIT ARRAYS
C  -------------------
 
      SPRS = 0.
C  --------------------------------------
 
C  READ AND "SURU-FIT" THE PREPDA/BUFR RECORDS
C  -------------------------------------------
 
10    DO WHILE(IREADMG(LUBFR,SUBSET,IDATE).EQ.0)
c... check for subset...
      IF(ITYP(SUBSET).EQ.0) GOTO 10
11    DO WHILE(IREADSB(LUBFR).EQ.0)

c... check for acars only...
      CALL UFBINT(LUBFR,HDR,14,  1,NLEV,HDSTR)
c
c... check for region...
      XOB=hdr(2)
      YOB=hdr(3)
c
      IF(.NOT.REGION(XOB,YOB,0)) GOTO 11
 
C  READ THE DATA
C  -------------
C  GENERATE A PRESSURE LEVEL LOOKUP TABLE
      CALL UFBINT(LUBFR,OBS,10,255,NLEV,OBSTR)
      CALL UFBINT(LUBFR,BAK(1,1,1),10,255,NLFC,FCSTR)
      CALL UFBINT(LUBFR,BAK(1,1,2),10,255,NLAN,ANSTR)
      CALL UFBINT(LUBFR,QMS,10,255,NLQM,QMSTR)
c

C  CREATE AND ACCUMULATE THE STATISTICS ARRAY FOR EACH REALIZATION
C  ---------------------------------------------------------------
 
      POB = OBS(1,1)
      PQM = QMS(1,1)
      CAT = QMS(6,1)
C
      if(idbug.eq.1) print *,' pob ',pob,' pqm ',pqm,' cat ',cat
c
      if(pqm>3) cycle
      j=0
      if((pob.le.levb1).and.(pob.gt.levt1)) j=1
      if((pob.le.levb2).and.(pob.gt.levt2)) j=2
      if((pob.le.levb3).and.(pob.gt.levt3)) j=3

      if(j<=0) cycle  
c
C  CREATE AND ACCUMULATE THE STATISTICS ARRAY FOR EACH REALIZATION
C  ---------------------------------------------------------------

      DO L=1,1 !!NLEV  single level data
      STC = 0.

      qms(4,l) = max(qms(3,l),qms(4,l)) ! use tqm for zqm
      POB = OBS(1,L); PQM = QMS(1,L); if(pqm>3) cycle
      CAT = QMS(6,L)
      if(idbug.eq.1) print *,' pob ',pob,' pqm ',pqm,' cat ',cat

      DO IB=1,2    ! background field
      DO IQ=1,nvar ! vars q,t,z,w

      IV=IQ+1; IR=IV+1

      IF(OBS(IV,L)   >=BMISS) cycle ! protect from missing observation !
      IF(BAK(IV,L,IB)>=BMISS) cycle ! protect from missing background  !
      IF(IV.EQ.2) THEN
         IF(IB.EQ.1) OBS(IV,L)=OBS(IV,L)*1.E-3
         BAK(IV,L,IB)=BAK(IV,L,IB)*1.E-3
      ENDIF
      IF(QMS(IV,L).LE.3 .AND. IQ.LT.5 .AND. CAT.NE.4) THEN
         STC(1,IQ,IB) = 1.
         STC(2,IQ,IB) =  BAK(IV,L,IB)-OBS(IV,L)
         STC(3,IQ,IB) = (BAK(IV,L,IB)-OBS(IV,L))**2
      ELSEIF(QMS(IV,L).LE.3 .AND. IV.EQ.5) THEN
         uob=OBS(IV,L)
         vob=OBS(IR,L)
         ubk=BAK(IV,L,IB)
         vbk=BAK(IR,L,IB)
         STC(1,IQ,IB) = 1.
         STC(2,IQ,IB) = sqrt(ubk**2+vbk**2)-sqrt(uob**2+vob**2)
         STC(3,IQ,IB) = (ubk-uob)**2+(vbk-vob)**2
      ENDIF
      ENDDO
      ENDDO

!  store the stats from this ob
!    j  is level (21)
!    k  is variable (5)
!    ll is region (7)
!    m  is subset (1)
!    n  is background (2)

      DO N=1   ,NBAK
      DO M=1   ,NSUB
      DO LL=1  ,NREG
      IF(REGION(XOB,YOB,LL)) THEN
         DO K=1,NVAR
         cnto = SPRS(1,J,K,LL,M,N)
         SPRS(1,J,K,LL,M,N) = SPRS(1,J,K,LL,M,N) + STC(1,K,N)
         cntn = SPRS(1,J,K,LL,M,N)
         if(cntn.gt.cnto) then
            wt1 = cnto/cntn
            wt2 = 1.-wt1
            DO I=2,3
            sprso = SPRS(I,J,K,LL,M,N)
            rat1 = wt1*SPRS(I,J,K,LL,M,N)
            rat2 = wt2*STC(I,K,N)
            SPRS(I,J,K,LL,M,N) = rat1 + rat2
            sprsn = SPRS(I,J,K,LL,M,N)
            ENDDO
         endif
         ENDDO
      ENDIF
! end region-typ-backg-level-loop
      ENDDO
      ENDDO
      ENDDO
      ENDDO
! end ireadsb-ireadmg-loop
      ENDDO
      ENDDO
      CALL CLOSBF(LUBFR)


C  FINISH UP
C  ---------
C   write out grads data file...
 
      iw=50
      do ibak=1,nbak
      iw=iw+1

      do ivarx=1,nvar
      ivar=indexv(ivarx)
      nstat=6
      if(ivar.eq.nvar) nstat=9
      if(idbug.eq.1) print *,ibak,' ivar ',ivar,' nstat ',nstat

      do nst=1,nstat
      do iplv=1,nplv
      do isub=1,nsub
      do ireg=1,nreg

      gdata(ireg,isub)=sprs(nst,iplv,ivar,ireg,isub,ibak)
      if(nst==3) gdata(ireg,isub)=sqrt(gdata(ireg,isub))

      enddo
      enddo

      write(iw) gdata

      if(ipr.eq.1) then
      if(ibak.eq.1) then
      if(iplv.eq.1) then
      ilevt=pmandt(iplv)
      ilevb=pmandb(iplv)
      if(ivar.eq.1)
     *write(6,1231) ibak,nst,ilevt,ilevb,(gdata(ireg,1),ireg=1,nreg)
      if(ivar.eq.2)
     *write(6,1232) ibak,nst,ilevt,ilevb,(gdata(ireg,1),ireg=1,nreg)
      if(ivar.eq.3)
     *write(6,1233) ibak,nst,ilevt,ilevb,(gdata(ireg,1),ireg=1,nreg)
      if(ivar.eq.4)
     *write(6,1234) ibak,nst,ilevt,ilevb,(gdata(ireg,1),ireg=1,nreg)
      endif
      endif
      endif

      enddo
      enddo
      enddo
      close(iw)
      enddo

 1231  format('q fcs=',i2,2x,'stat = ',i2,2x,'lev = ',2i6,2x,7f12.2)
 1232  format('t fcs=',i2,2x,'stat = ',i2,2x,'lev = ',2i6,2x,7f12.2)
 1233  format('z fcs=',i2,2x,'stat = ',i2,2x,'lev = ',2i6,2x,7f12.2)
 1234  format('w fcs=',i2,2x,'stat = ',i2,2x,'lev = ',2i6,2x,7f12.2)
c
 3000  format('reg ',i2,' cnto ',f4.0,' cntn ',f4.0,
     *        ' wt1 ',f5.2,' wt2 ',f5.2,2x,5f12.2)
c
      PRINT'("SURUFIT PROCESSING COMPLETED")'
      STOP
      END
C-----------------------------------------------------------------------
C-----------------------------------------------------------------------
      LOGICAL FUNCTION REGION(X,Y,I)
 
      PARAMETER(NREG=1)
 
      DIMENSION X1(NREG),X2(NREG),Y1(NREG),Y2(NREG)
 
C.... X goes from east to west
C.... Y goes from south to north
c... north america
      DATA X1(1),X2(1),Y1(1),Y2(1) /235.,295.,25.,55./
c... global
c     DATA X1(2),X2(2),Y1(2),Y2(2) /0.,360.,-90.,90./
C-----------------------------------------------------------------------
 
C  CHECK FOR A VALID REGION INDEX AND BE OPTIMISTIC
C  ------------------------------------------------
 
      IF(I.LT.0.OR.I.GT.NREG) THEN
         REGION = .FALSE.
         RETURN
      ELSE
         REGION = .TRUE.
      ENDIF
 
C  SETUP THE SEARCH PARAMETERS
C  ---------------------------
 
      IF(I.EQ.0) THEN
         I1 = 1
         I2 = NREG
      ELSE
         I1 = I
         I2 = I
      ENDIF
 
C  LOOK FOR A REGION MATCH
C  -----------------------
 
      DO I0=I1,I2
      IF(Y.GE.Y1(I0) .AND. Y.LE.Y2(I0)) THEN
         IF(X1(I0).LE.X2(I0)) THEN
            IF(X.GE.X1(I0) .AND. X.LE.X2(I0)) RETURN
         ELSEIF(X1(I0).GT.X2(I0)) THEN
            IF(X.GE.X1(I0) .OR.  X.LE.X2(I0)) RETURN
         ENDIF
      ENDIF
      ENDDO
 
C  IF NO MATCH, RETURN FALSE
C  -------------------------
 
      REGION = .FALSE.
      RETURN
      END
C-----------------------------------------------------------------------
C-----------------------------------------------------------------------
      INTEGER FUNCTION ITYP(SUBSET)
 
      PARAMETER(NSUB=1)
 
      CHARACTER*8 SUBSET,SUBTYP(1)
      DATA SUBTYP /'AIRCAR'/
C
C     CHARACTER*8 SUBSET,SUBTYP(15)
C     DATA SUBTYP /'ADPUPA','AIRCAR','AIRCFT','SATWND','PROFLR',
C    .             'VADWND','SATBOG','SATEMP','ADPSFC','SFCSHP',
C    .             'SFCBOG','SPSSMI','SYNDAT','ERS1DA','GOESND'/
 
C  LOOK FOR A MATCH TO RETURN NON-ZERO
C  -----------------------------------
 
      DO I=1,NSUB
      ITYP = I
      IF(SUBSET.EQ.SUBTYP(I)) RETURN
      ENDDO
 
C  IF NO MATCH, RETURN ZERO
C  ------------------------
 
      ITYP = 0
      RETURN
      END
