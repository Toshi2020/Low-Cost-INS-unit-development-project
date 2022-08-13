Option Explicit
Public DataBuf() As Variant

'Const YAWGAIN As Single = 1.000041934
Const YAWGAIN As Single = 1.001

Dim AfterPowerOnTime As Long
Dim bug As Double, bug1 As Double, bug2 As Double, bug3 As Double
Dim bug4 As Double, bug5 As Double
Dim bugf As Single
Dim YawOffset As Single, RollOffset As Single , PitchOffset As Single
Dim InsCourse As Single, InsCourse0 As Single
Dim Vreal As Single, GpsVreal As Single, Vreal0 As Single, VrealLog As Single
Dim VrealFilt As Single
Dim YawRaw As Integer, YawRate As Single
Dim Dt As Single
Dim GpsYawRate As Single, GpsCourse As Single, GpsCourseCalc As Single
Dim fGpsFix As Boolean
Dim fGpsConfirm As Boolean, fGpsYawConfirm As Boolean
Dim GpsLon As Long, GpsLat As Long, InsLon As Long, InsLat As Long
Dim GpsLonZ As Long, GpsLatZ As Long
Dim GpsFixCount As Long
Dim fGpsDoubt As Boolean, fGpsDoubt2 As Boolean
Dim fReverse As Boolean
Dim fReverseRun As Boolean
Dim ArealFilt As Single, ArealFiltZ As Single
Dim Jark As Single
Dim GpsHdop As Single
Dim fStop As Boolean
Dim fGpsRecv As Boolean
Dim SimLostTime As Single
Dim SimDoubtTime As Single
Dim AccelYRaw As Single
Dim Roll As Single, Pitch As Single
Dim fcurve As Boolean
Dim VspConst As Long, VspTime As Long
Dim SlopeG As Single
Dim RunTime As Long
Dim StopTime As Long
Dim StatDoubt As Integer
Dim SatLevelSum As Single		'// GPS SN�䍇�v
Dim SatLevel As Single			'// GPS SN�䕽��
Dim SatLevelFilt As Single		'// GPS SN�䕽�σt�B���^�l
Dim SatCount As Integer			'// GPS SN�䕽�σf�[�^��
Dim fBrakeDecel As Boolean
Dim fBrakeRecover As Boolean
Dim fPark As Boolean
Dim Temperature As Single
Dim YawRate0 As Single
Dim AccelY As Single
Dim AccelYFilt As Single

Const GFILT As Double = 0.08
Const L1e7 As Long = 10000000
Const F1e7 As Single = 10000000#
Const G1 As Single = 9.80665
Const GPSFILT As Single = 0.17
Const YAWV As Single = 10#			'// GPS���ʂ�������ԑ�[km/h]
Const CURVEYAW As Single = 2#		'// �J�[�u���胈�[���[�g [deg/s]
Const POWERONDELAYC As Long = 0		'// �ʓd����̈���҂�����[s]x10
Const POWERONDELAYYAW As Long = 600	'// �ʓd����̈���҂�����[s]x10
Const VSPLEARN_LV As Single = 20	'// VSP�w�K�Œ�ԑ�[km/h]
Const WHEELBASE As Single = 2530
Const TREAD As Single = 1470
Const CALTEMP As Single = 24.75	'// �L�����u���[�V�������̉��x
Const SLOPE_YAW As Single = -1.3527291E-02
Const SLOPE_G As Single = 1.4434167E-04

Sub GraphSim()
	Sheets("Log").Select
	Sim
	Sheets("Graph1").Select
end Sub

'-----------------------------------------------------------------------------
'�����񒆂̕����̏o������Ԃ�
Function StrCount(Source As String, Target As String) As Long
	Dim n As Long, cnt As Long
	do
		n = InStr(n + 1, Source, Target)
		if n = 0 Then
			Exit Do
		else
			cnt = cnt + 1
		end if
	Loop
	StrCount = cnt
end Function
'-----------------------------------------------------------------------------
'���Ԃ��v�Z���Ŗ��߂�
Private Sub Fill2end()
	Dim y1 As Long, y2 As Long

	y1 = Range("B2").end(xlDown).Row	'�f�[�^�̍ŏ��̍s��
	y2 = Range("W2").end(xlDown).Row	'�v�Z���̍ŏ��̍s��
	if y1 > y2 Then '�f�[�^�̕��������ꍇ�͌��Ԃ��v�Z���Ŗ��߂�W=23
		Range(Cells(y2, 23), Cells(y2, 30)).Copy _
			Destination:= _
			Range(Cells(y2 + 1, 23), Cells(y1, 30))
	elseif y1 < y2 Then '�v�Z���̕��������ꍇ�̓N���A����
		Range(Cells(y1 + 1, 23), Cells(y2, 30)).Clear
	end if
	y2 = Range("AL2").end(xlDown).Row	'�v�Z���̍ŏ��̍s��
	if y1 > y2 Then '�f�[�^�̕��������ꍇ�͌��Ԃ��v�Z���Ŗ��߂�W=23
		Range(Cells(y2, 38), Cells(y2, 45)).Copy _
			Destination:= _
			Range(Cells(y2 + 1, 38), Cells(y1, 45))
	elseif y1 < y2 Then '�v�Z���̕��������ꍇ�̓N���A����
		Range(Cells(y1 + 1, 38), Cells(y2, 45)).Clear
	end if
end Sub
'-----------------------------------------------------------------------------

'-----------------------------------------------------------------------------
'���O�t�@�C���̓ǂݍ���
Sub LoadFile()
	Dim fileToOpen As Variant
	Dim fso As Object, tstream As Object
	Dim sTmp As String
	Dim sLine() As String
	Dim ColNum As Long
	Dim DatNum As Long
	Dim sDat() As String
	Dim i As Long
	Dim j As Long
	Dim item As Variant
	Dim time0 As Double

	'EXCEL�t�@�C���̂���ꏊ�ֈړ�
	ChDrive ThisWorkbook.Path
	ChDir ThisWorkbook.Path

	'�t�@�C���I�[�v���_�C�A���O
	fileToOpen = Application.GetOpenFilename("���O�t�@�C��,*.txt")
	'�L�����Z�����ꂽ�牽�����Ȃ�
	if (fileToOpen = FALSE) Then
		Exit Sub
	end if

	'��x�t�@�C���̒��g�����ׂĕϐ��Ɉڂ�
	Set fso = CreateObject("Scripting.FileSystemObject")
	Set tstream = fso.OpenTextFile(fileToOpen)
	sTmp = tstream.ReadAll				'���ׂĂ�ǂݍ���
	ReDim DataBuf(30000, 31)			'�ő�s�ƌ������m�ۂ��ăN���A

	sLine = Split(sTmp, vbCrLf) 		'��s���Ƃɕ���
	ColNum = StrCount(sLine(0), ",") + 1 '�ő�J�����������߂�
	DatNum = UBound(sLine)				'�f�[�^�������߂�
	if(DatNum > 30000) Then DatNum = 30000
	for i = 0 To DatNum - 1 			'���ׂĂ̍s
		sDat = Split(sLine(i), ",") 	'��s���J���}��؂�ɂ��Ĕz��Ɉڂ�
		j = 0
		for Each item In sDat
			DataBuf(i, j) = item 		'�z��Ɋi�[
			if (i > 0 And j = 0) Then
				DataBuf(i, j) = DataBuf(i, j) - time0	'���Ԃ�0�����
			end if
			j = j + 1
		Next item
		if (i = 0) Then
			time0 = DataBuf(0, 0)
			DataBuf(0, 0) = 0.0
		end if
	Next
	tstream.Close			'�e�L�X�g�X�g���[����Close
	Set tstream = Nothing	'�I�u�W�F�N�g�N���A
	Set fso = Nothing

	'�V�[�g�ɏ�������
	Range("B4:AY65536").Clear
	Range("B2:V30002") = DataBuf

	'���Ԃ��v�Z���Ŗ��߂�
	Fill2end
	'�V�~�����[�V�����v�Z
	Sim
	'���X�P�[�����O���t1����2�ɃR�s�[
'	CopyAxis1to2
end Sub

'/*---------------------------------------------------------------------------
'   �V�~�����[�V�����v�Z
'---------------------------------------------------------------------------*/
Sub Sim()
	Const RUNRV As Single = 5#			'// ���o�[�X���s��������ԑ�[km/h]
	Const STOPTIMEC As Long = 10		'// ��~���莞��[s]x10
	Const VSPLEARN_HV As Single = 180	'// VSP�w�K�ō��ԑ�[km/h]
	Const VSPLEARN_A As Single = 0.05	'// VSP�w�K�ō������x[G]
	Const GOFSTFILT As Single = 0.0001	'// �����x�Z���T�I�t�Z�b�g�t�B���^�萔
	Const GOFSTC  = 0.05				'// �����x�Z���T�I�t�Z�b�g�Z�oG[G]
	Const PERRGAIN As Single = 80.0		'// �ʒu���Z�b�g臒l�ԑ��Q�C��
	Const PERROFST As Single = 1000.0	'// �ʒu���Z�b�g臒l�I�t�Z�b�g
	Const CERR As single = 45.0			'// ���ʃ��Z�b�g臒l[deg]
	Const ERRTIME As Long = 10		'// INS�����Z�b�g����܂ł̎���臒l[��]
	Const INSFILT As Single = 0.2		'// INS GPS�ʒu��v�t�B���^�l
	Const INSFILTCRS As Single = 0.05	'// INS GPS���ʈ�v�t�B���^�l
	Const FILT_OFCANROLL As Single = 0.005'// ��~���I�t�Z�b�g�����t�B���^�萔
	Const SLOPEDEADG As Single = 0.04	'// ���z�����x�s����[G]
	Const SATLEVELMAX As Single = 50
	Const GPSLEVELFILT As Single = 0.01

	Dim y As Long
	Dim ans As Variant
	Dim tim As Single
	Dim x As Single
	static rtime As Long
	static yawratefilt As Single
	Dim yawratez As Single, yawratefiltz As Single
	Dim yawratezz As Single
	static cnt As Integer
	Dim errfilt As Single
	Dim tofst As Single
	Dim gcount As Long
	Dim poserrcount As Long, crserrcount As Long
	Dim laterr As Single, lonerr As Single, crserr As Single
	Dim poserr As Single
	Dim Gdist As Single, Idist As single
	Dim MaxDecel As Single
	Dim vofst As Single
	Dim TempRaw As Integer
	Dim cofst As Single
	Dim sgfilt As Single
	Dim latcal As Single, loncal As Single, crscal As single

	Gdist = 0
	Idist = 0
	AfterPowerOnTime = 0
	fReverseRun = FALSE
	fCurve = FALSE
	Roll = 0
	Pitch = 0
	ArealFilt = 0
	ArealFiltZ = 0
	GpsFixCount = 0
	poserrcount = 0
	crserrcount = 0
	yawratezz = 0
	yawratez = 0
	bug=0
	bug1=0
	bug2=0
	bug3=0
	bugf=0
	fBrakeDecel = FALSE
	fBrakeRecover = FALSE
	laterr = 0
	lonerr = 0
	crserr = 0


	SimLostTime = Cells(3, 1)	'sim �q�������X�g���鎞��
	SimDoubtTime = Cells(5, 1)	'sim �q�����^�킵���Ȃ鎞��

	YawOffset = Cells(2, Range("N1").Column)	'�I�t�Z�b�g�����l y(r)
	VspConst = Cells(2, Range("F1").Column)
	if (VspConst < 1300000) Then _
		VspConst = Cells(2, Range("R1").Column) * 10000
	if (VspConst < 1400000 Or VspConst > 1500000) Then _
		VspConst = Cells(2, Range("R1").Column) * 10000
	if (VspConst < 1400000 Or VspConst > 1500000) Then _
		VspConst = Cells(2, Range("AL1").Column)
	if (VspConst < 1400000 Or VspConst > 1500000) Then _
		VspConst = 1470000

	InsCourse = Cells(2, Range("Q1").Column)	'I��������=���O�ɏ]��
'	InsCourse = Cells(2, Range("P1").Column)	'I��������=G��������
	InsLon = Cells(2, Range("J1").Column)	'INS�����o�x=���O�ɏ]��
	InsLat = Cells(2, Range("K1").Column)	'INS�����ܓx=���O�ɏ]��
'	InsLon = Cells(2, Range("H1").Column)	'INS�����o�x=GPS�����o�x
'	InsLat = Cells(2, Range("I1").Column)	'INS�����o�x=GPS�����ܓx
	crscal = GetPI(0, TRUE)
	GpsCourse = Cells(2, Range("P1").Column)	'G����
	GpsLatZ = InsLat
	GpsLonZ = InsLon

	Vreal = Cells(2, Range("C1").Column)	'[km/h]
	RunTime = 0
	StopTime = 0
	if (Vreal > 10#) Then RunTime = 100
	if (Vreal = 0#) Then StopTime = 100
	SatLevelFilt = 30
	SatLevel = 30
	VrealFilt = Vreal

	Application.ScreenUpdating = FALSE	'��ʂ̍X�V���~
	Application.Calculation = xlCalculationManual	'�����v�Z��~

	Dt=0.1
	y = 2
	do while (Cells(y, Range("B1").Column) <> "")
		Call AddOnTime(TRUE, AfterPowerOnTime)	'// �ʓd��̎���[s]x10
		tim = Cells(y, Range("B1").Column)
		VrealLog = Cells(y, Range("C1").Column)	'[km/h]
		GpsVreal = Cells(y, Range("D1").Column) '[km/h]
		GpsYawRate = Cells(y, Range("L1").Column)	'GpsYawRate [deg/s]
		GpsCourse = Cells(y, Range("P1").Column)	'G����
		SatLevel = Cells(y, Range("U1").Column)
		if (SatLevel > 50) then SatLevel = 30
		if (tim < 1) then
			YawOffset = Cells(y, Range("N1").Column)
		end if

'		fReverse = VrealLog < 0#
		fReverse = Cells(y, Range("V1").Column) And 16	'// ���O�ɏ]��
		Call AddOnTime(fReverse, rtime) 	'// ���o�[�X�M���I������
		if (rtime >= 1) Then					'// ���o�[�X�M�A����ꂽ��
			fReverseRun = TRUE				'// ���o�[�X��Ԋm��
		elseif (rtime = 0 And Vreal >= RUNRV) Then	'// �O�i������
			fReverseRun = FALSE 			'// ���o�[�X��ԉ���
		end if

		fGpsFix = Cells(y, Range("V1").Column) And 2
		if (SimLostTime > 0 And tim >= SimLostTime) Then
			fGpsFix = FALSE
		end if

		if (y > 2) Then
			Dt = Cells(y, 2) - Cells(y - 1, 2)		'[s]
		end if
		VspTime = Cells(y, Range("F1").Column)

		'// YawG�Z���T���f�[�^�擾[deg/s]x250/32768
		'// ���E������X�A�O�������Y�Ƃ���B�E�����A�O����
		YawRaw = Cells(y, Range("G1").Column)		'[deg/s]x32768/250
		TempRaw = Cells(y, Range("T1").Column) 
		AccelYRaw = Cells(y, Range("E1").Column)	'[G]x32768/2
		Temperature = TempRaw / 340.0 + 36.53
'bug=Temperature
		tofst = (Temperature - CALTEMP) * SLOPE_G '// G�Z���T�I�t�Z�b�g
'bug=tofst
		AccelY = AccelYRaw * 2# / 32768#	'�Z���T�[�̑O������x[G]
		AccelY = AccelY - tofst

		'// �ԑ��Z�o����
		Vreal = CalcVsp(ArealFilt, Dt, SlopeG, AccelY, YawRate, fCurve, _
							fReverse, FALSE)
		Call Filter(VrealFilt, Vreal, GPSFILT)
		if (AfterPowerOnTime <= 1) Then '// �N������
			Vreal0 = VrealLog
		end if
		fPark = (tim < 1 And Vreal = 0)

		'���H���z�Z�o
		'// �I�t�Z�b�g�������Ďԑ����狁�߂������x�ƈʑ����킹
		Call Filter(AccelYFilt, AccelY, GPSFILT)
		'// ���������z�ɂ������x
		Call Filter(sgfilt, AccelYFilt - ArealFilt, GPSFILT)
		SlopeG = sgfilt
		if (Abs(sgfilt) < SLOPEDEADG) Then SlopeG = 0
'bug=ArealFilt*100
'bug1=accelyfilt*100
'bug=SlopeG*100
'bug3=(AccelYFilt - ArealFilt)*100

		Call AddOnTime(Vreal >= YAWV And Not fReverse, RunTime)
		Call AddOnTime(Vreal = 0# And Not fReverse, StopTime)
'		fStop = StopTime >= STOPTIMEC	'// ��~����
		fStop = Cells(y, Range("V1").Column) And 1	'// ���O�ɏ]��

		if (Cells(y, Range("H1").Column) <> "") Then
			GpsLon = Cells(y, Range("H1").Column)	'GPS�o�x[deg]x1e7
			GpsLat = Cells(y, Range("I1").Column)	'GPS�ܓx[deg]x1e7
'		else
'			GpsLon = Cells(y, Range("J1").Column)	'INS�o�x[deg]x1e7
'			GpsLat = Cells(y, Range("K1").Column)	'INS�ܓx[deg]x1e7
		end if

		'// GPS�f�[�^��M����
		Call RxGPS
'bug=SatLevel
'bug1=SatLevelFilt
		'// GPS���^�킵�����f
		fGpsDoubt = JudgeGpsDoubtLevel(Vreal, GpsVreal, fGpsFix, _
						SatLevel, SatLevelFilt) Or fGpsDoubt2
		if (SimDoubtTime > 0 And tim >= SimDoubtTime) Then
			fGpsDoubt = TRUE
		end if
		'// GPS���x�m��
		fGpsConfirm = GpsFixCount >= 2 And Not fGpsDoubt And Not fReverseRun

		'// GPS���[���[�g�m��
		'  (GPS2��ȏ�m��Ńo�b�N���s�łȂ��Ďԑ����K��ȏ�)
		fGpsYawConfirm = fGpsConfirm And Vreal >= YAWV

'bug=SatLevelFilt
'bug1=SatLevel

		'// �I�t�Z�b�g��������t�p�x�␳���Đ^�̃��[���[�g�𓾂�[deg/s]
		YawRate = GetTrueYawRate(YawOffset, YawRaw, Temperature, GpsYawRate, _
					Vreal, ArealFilt, fCurve, fPark, _
					fStop, _
					fGpsYawConfirm And Not fCurve And fGpsRecv)

		'// �J�[�u����
		fCurve = JudgeCurve(YawRate, GpsYawRate, GpsFixCount)

		'// ���[���[�g��ݐς���INS����0�`360[deg]�𓾂�
		if (Not fPark) then
			InsCourse = Normal360(InsCourse + (yawratez + YawRate) / 2.0 * Dt)
		end if
		'// ����l��������
		yawratez = YawRate

'If (AfterPowerOnTime = 2200) Then InsCourse = InsCourse + 20

		'// INS���Ԉʒu����
		Call CalcInsCoordinate(InsLat, InsLon, InsCourse, Vreal, Dt)

'bug=InsCourse
'bug1=GpsCourse
'bug3=fcurve * -160
		'// GPS�����M��������
		if (fGpsRecv) Then
			fGpsRecv = FALSE	'// GPS��M�t���O�N���A
'bug=GpsVreal
'bug1=Vreal
'bug2=GpsVreal - Vreal
			'// �ԑ�����^�킵�����f��ǉ�
			fGpsDoubt2 = JudgeGpsDoubtVreal(Vreal, GpsVreal, GpsFixCount)
			fGpsDoubt = fGpsDoubt Or fGpsDoubt2
			'// �^�킵�����
			if (fGpsDoubt2) then
				fGpsConfirm = false
				fGpsYawConfirm = false
			end if
			if (fGpsConfirm) Then
				'// ��M���x���̃t�B���^�����O
				Call Filter(SatLevelFilt, SatLevel, GPSLEVELFILT)

				'// INS��GPS�̍���
				laterr = GpsLat - InsLat
				lonerr = GpsLon - InsLon
				'// INS���W��GPS���W�Ɉ�v�����邽�߂̕␳��
				latcal = laterr * INSFILT
				loncal = lonerr * INSFILT
				'// INS���W��GPS���W�ɏ��X�Ɉ�v������
				InsLat = InsLat + latcal
				InsLon = InsLon + loncal
			else
				laterr = 0
				lonerr = 0
				latcal= 0
				loncal = 0
			end if
			if (fGpsYawConfirm And Not fCurve) then
				crserr = Normal180( _
					Normal180(GpsCourse) - Normal180(InsCourse))
				'// INS���ʂ�GPS���ʂɈ�v�����邽�߂̕␳��
				crscal = crserr * INSFILTCRS
				'// INS���ʂ�GPS���ʂɏ��X�Ɉ�v������
				InsCourse = Normal360(InsCourse + crscal)
			else
				crserr = 0
				crscal = 0
			end if
			'// GPS�f�[�^���^�킵�����f����ɉߋ��̕␳�ʂ�߂�
			'Call UndoCollect(InsCourse, crscal, fGpsDoubt)
'bug=crscal
'bug=GpsVreal - VrealFilt
'bug1=ArealFilt * 10
'bug2=Normal180(Normal180(GpsCourse) - Normal180(InsCourse))
'bug2=VrealFilt / 10
'bug3=YawRate / 10
			'// INS��GPS���傫������������
			poserr = Abs(Vreal) * PERRGAIN + PERROFST'// �ʒu���ꔻ�苗��
			Call AddOnTime(fGpsConfirm And _
					(Abs(laterr) >= poserr Or Abs(lonerr) >= poserr), _
					poserrcount)
			Call AddOnTime(fGpsYawConfirm And Abs(crserr) >= CERR, _
					crserrcount)

			'// INS��GPS���傫�������������̏�����
			if (poserrcount >= ERRTIME Or crserrcount >= ERRTIME) Then
				InsLat = GpsLat
				InsLon = GpsLon
				InsCourse = GpsCourse
			end if
			if (SimDoubtTime > 0 And tim < SimDoubtTime) Then
				InsLon = GpsLon
				InsLat = GpsLat
			end if

			'// VSP�萔�w�K����
					'// GPS�擾���^�킵���Ȃ�
					'// �o�b�N���s�ł͂Ȃ�����
					'// �ԑ����͈͓�����
					'// �����x���͈͓�����
					'// ���[���[�g���͈͓�
			VspConst = LearnVsp(VspConst, VrealFilt, GpsVreal, _
					fGpsConfirm And _
					Not fReverseRun And _
					Vreal >= VSPLEARN_LV And _
					Vreal <= VSPLEARN_HV And _
					Abs(ArealFilt) <= VSPLEARN_A And _
					Abs(GpsYawRate) <= CURVEYAW)

			gcount = 0

			GpsCourseCalc = Course(GpsLatZ, GpsLonZ, GpsLat, GpsLon)
			'// ����l��������
			GpsLatZ = GpsLat
			GpsLonZ = GpsLon
		end if



'bug2=GpsCourse
'bug=crserr
'bug1=Calib(3)
'bug1=Calib(2)
'bug2=fCurve * -15

		gcount = gcount + 1
		if (gcount = 5) Then
		end if

		Cells(y, Range("AE1").Column) = InsLon
		Cells(y, Range("AF1").Column) = InsLat
		Cells(y, Range("AG1").Column) = YawRate
		Cells(y, Range("AH1").Column) = YawOffset
		Cells(y, Range("AI1").Column) = InsCourse
		Cells(y, Range("AJ1").Column) = VspConst
		Cells(y, Range("AK1").Column) = -(fReverseRun * 16 + _
					fcurve * 8 + fGpsDoubt * 4 + _
					fGpsFix * 2 + fStop) + StatDoubt
		Cells(y, Range("AT1").Column) = bug
		Cells(y, Range("AU1").Column) = bug1
		Cells(y, Range("AV1").Column) = bug2
		Cells(y, Range("AW1").Column) = bug3
		Cells(y, Range("AX1").Column) = bug4
		Cells(y, Range("AY1").Column) = bug5

		y = y + 1
	Loop
	Cells(2, Range("F1").Column) = VspConst
'	Cells(2, Range("N1").Column) = YawOffset

	'�ŏI��~����
	Cells(18, Range("A1").Column) = Cells(y-1, Range("Q1").Column)
	Cells(20, Range("A1").Column) = InsCourse

	'���X�P�[�����O���t2����1�ɃR�s�[
'	CopyAxis2to1
	'���X�P�[�����O���t1����2�ɃR�s�[
'   CopyAxis1to2

	Application.ScreenUpdating = TRUE	'��ʂ̍X�V���ĊJ
	Application.Calculation = xlCalculationAutomatic '�����v�Z�ĊJ
end Sub
'/*---------------------------------------------------------------------------
'   GPS�f�[�^��M����
'---------------------------------------------------------------------------*/
static Function RxGPS()
	static glonz As Long, glatz As Long, gvz As Single
	static cnt As Long

	'GPS��������
	'// GPS�ω����������Ԃ��o�߂����H
	if (glonz <> GpsLon Or glatz <> GpsLat Or gvz <> GpsVreal Or _
				cnt = 0) Then
		cnt = 11
		Call AddOnTime(fGpsFix, GpsFixCount)
		fGpsRecv = TRUE '// GPS��M����
	end if

	glonz = GpsLon
	glatz = GpsLat
	gvz = GpsVreal
	Call DecNonZero(cnt)
end Function
'/*---------------------------------------------------------------------------
'   GPS�f�[�^���^�킵�����f����ɉߋ��̕␳�ʂ�߂�
'---------------------------------------------------------------------------*/
static Function UndoCollect0(lat As long, lon As long, crs As Single, _
				latcal As Single, loncal As Single, crscal As Single, _
				fdoubt As Boolean)

	Const CALMAX As Integer = 4
	static cal(3, CALMAX) As Single
	static ptop As Integer
	static fdoubtz As Boolean
	Dim sum(3) As Single
	Dim i As Integer

'bug2=latcal
'bug3=loncal
'bug4=crscal
'bug2=0
	if (AfterPowerOnTime <= 1) Then '// �N������
		'// �o�b�t�@�N���A
		cal(0, i) = 0
		cal(1, i) = 0
		cal(2, i) = 0
	end if

	'// GPS���^�킵���Ȃ�����
	if (Not fdoubt) then
		'// �␳�ʂ������O�o�b�t�@�Ƀ��������Ă���
		cal(0, ptop) = latcal
		cal(1, ptop) = loncal
		cal(2, ptop) = crscal
		ptop = (ptop + 1) And (CALMAX - 1)
	end if
	'// �^�킵�����f����
	if (fdoubt And Not fdoubtz) Then
		'// �ߋ����΂炭�̊��Ԃ̕␳�ʂ̍��v
		for i = 0 To 2
			sum(i) = 0
		next i
		for i = 0 To CALMAX - 1
			sum(0) = sum(0) + cal(0, i)
			sum(1) = sum(1) + cal(1, i)
			sum(2) = sum(2) + cal(2, i)
			'// �o�b�t�@�N���A
			cal(0, i) = 0
			cal(1, i) = 0
			cal(2, i) = 0
		next i
'bug2=sum(1)
'bug2=sum(0)
'bug3=sum(1)
'bug4=sum(2)
		'// �ߋ��ɕ␳�����ʂ�߂�
		lat = lat - sum(0)
		lon = lon - sum(1)
		crs = Normal360(crs - sum(2))
	end if
	fdoubtz = fdoubt
end Function
static Function UndoCollect(crs As Single, crscal As Single, _
				fdoubt As Boolean)

	Const CALMAX As Integer = 4
	static cal(CALMAX) As Single
	static ptop As Integer
	static fdoubtz As Boolean
	Dim sum As Single
	Dim i As Integer

	if (AfterPowerOnTime <= 1) Then '// �N������
		'// �o�b�t�@�N���A
		cal(i) = 0
	end if

	'// GPS���^�킵���Ȃ�����
	if (Not fdoubt) then
		'// �␳�ʂ������O�o�b�t�@�Ƀ��������Ă���
		cal(ptop) = crscal
		ptop = (ptop + 1) And (CALMAX - 1)
	end if
	'// �^�킵�����f����
	if (fdoubt And Not fdoubtz) Then
		'// �ߋ����΂炭�̊��Ԃ̕␳�ʂ̍��v
		sum = 0
		for i = 0 To CALMAX - 1
			sum = sum + cal(i)
			'// �o�b�t�@�N���A
			cal(i) = 0
		next i
		'// �ߋ��ɕ␳�����ʂ�߂�
		crs = Normal360(crs - sum)
	end if
	fdoubtz = fdoubt
end Function
'/*---------------------------------------------------------------------------
'   GPS�f�[�^���^�킵�����f(SatLevel)
'---------------------------------------------------------------------------*/
static Function JudgeGpsDoubtLevel(v As Single, vgps As Single, _
				fgpsfix As Boolean, _
				satlevel As Single, satlevelfilt As Single) As Boolean

	Const DOUBTON As Single = 0.8	'// GPS���^�킵���Ɣ��f���郌�x��
	Const DOUBTOFF As Single = 0.85	'// GPS���^�킵���Ȃ��Ɣ��f���郌�x��
	Const DOUBTOFFTIME As Long = 70	'// GPS���^�킵���Ȃ��Ɣ��f���鎞��[s]x10
	Const DOUBTV As Single = 5.0	'// �^�킵����ԉ񕜂̎ԑ��΍�[km/h]
	Const DOUBTTIMEC As Long = 200	'// �ԑ������������̉񕜎���[s]x10

	static fdoubt As Boolean
	static recovertime As Long, judgetime As Long, nodoubttime As Long
	Dim fleveldown As Boolean

	'// �q����M���x���̕��ϒl���ʏ�����ቺ
	fleveldown = fgpsfix And satlevel < satlevelfilt * DOUBTON
	if (fgpsfix) Then	'// GPS�m�蒆�Ȃ�
		'// �q����M���x���̕��ϒl���ʏ�����ቺ��������H
		if (Not fdoubt And fleveldown) Then
			fdoubt = TRUE	'// GPS���^�킵���Ɣ��f
		'// �q����M���x���̕��ϒl���񕜂��Ď��Ԃ��o�߂����H
		elseif (recovertime >= judgetime) Then
			fdoubt = FALSE	'// GPS���^�킵���Ȃ��Ɣ��f
			judgetime = 0
		end if
	else
		fdoubt = FALSE	'// GPS��FIX���Ă��Ȃ��Ȃ�t���O�������Ă���
	end if
	'// GPS���x�����܂��͖���M���p����������
	if ((fleveldown Or Not fgpsfix) And judgetime < DOUBTOFFTIME) then
		Call AddOnTime(TRUE, judgetime)	'// ����������Ԃ�ݒ肵�Ă���
	end if

	'// �q����M���x���̕��ϒl���񕜂��Ă���̌o�ߎ���
	Call AddOnTime(fdoubt And satlevel > satlevelfilt * DOUBTOFF, _
					recovertime)

	'// GPS���^�킵����Ԃ���񕜂ł��Ȃ��Ƃ���F/S
	'// GPS���^�킵����ԂŎԑ��������Ăقڐ���������
	Call AddOnTime(fdoubt And v >= YAWV And abs(v - vgps) <= DOUBTV, _
					nodoubttime)
	'// GPS�ԑ����قڐ�������Ԃ����������H
	if (fdoubt And nodoubttime >= DOUBTTIMEC) Then
		fdoubt = FALSE			'// GPS���^�킵���Ȃ��Ƃ���
		satlevelfilt = satlevel	'// ���񔻒�p�̒l�Ƃ��Č��ݒl���g�p����
		judgetime = 0
	end if
	JudgeGpsDoubtLevel = fdoubt
end Function
'/*---------------------------------------------------------------------------
'   GPS�f�[�^���^�킵�����f(Vreal)
'---------------------------------------------------------------------------*/
static Function JudgeGpsDoubtVreal0(v As Single, vgps As Single, _
				gpscount As Long) As Boolean

	Const VDOUBTX As Single = 2#	'// �^�킵����Ԃ̎ԑ���臒l�{��
	Const DOUBTV As Single = 5# 	'// �^�킵����Ԃ̎ԑ��΍��~�j�}��
	Const VDOUBTTIMEC As Long = 3	'// �ԑ��񕜑҂�����[s]
	Const VFILTC As Single = 0.1	'// �ԑ��΍��t�B���^�萔
	Dim level As Single, err As Single
	static errfilt As Single
	static fdoubt As Boolean
	static oktime As Long

	if (AfterPowerOnTime <= 1) Then '// �N������
		errfilt = 5
		fdoubt = FALSE
		oktime = 0
	end if

	if (gpscount >= 2) Then	'// GPS���m�肵�Ă���Ȃ�
'		if (v >= YAWV) Then '// �ԑ�����������x�ɑ��s���Ă���Ȃ�
		if (1) Then '   // �ԑ�����������x�ɑ��s���Ă���Ȃ�
			level = errfilt * VDOUBTX		'// ����ԑ��΍�臒l
			if (level < DOUBTV) Then level = DOUBTV '// �Ⴍ���߂��Ȃ�
			err = Abs(v - vgps)
'bug2=level
'bug3=err
			if (err >= level) Then		'// �ԑ������������H
				fdoubt = TRUE			'// �ԑ��ɂ��^�킵������J�n
				oktime = 0
			end if
			Call AddOnTime(err < level, oktime) '// �ԑ����񕜂�������
			if (oktime >= VDOUBTTIMEC) Then 	'// �񕜂��K��񐔂ɒB�����H
				fdoubt = FALSE			'// �^�킵�������艺��
			end if

			if (Not fdoubt) Then
				'// ���x�̂����Ƃ��̎ԑ��΍����t�B���^
				Call Filter(errfilt, err, VFILTC)
			end if
		end if
	else
		fdoubt = FALSE
		oktime = 0
	end if
'bug2=fdoubt* -8
	JudgeGpsDoubtVreal0 = fdoubt
end Function
static Function JudgeGpsDoubtVreal1(v As Single, vgps As Single, _
				gpscount As Long) As Boolean

	Const VDOUBTX As Single = 0.2	'// �^�킵����Ԃ̎ԑ���臒l�{��
	Const DOUBTV As Single = 5# 	'// �^�킵����Ԃ̎ԑ��΍��~�j�}��
	Const VDOUBTTIMEC As Long = 3	'// �ԑ��񕜑҂�����[s]
	Dim level As Single, err As Single
	static fdoubt As Boolean
	static oktime As Long

	if (AfterPowerOnTime <= 1) Then '// �N������
		fdoubt = FALSE
		oktime = 0
	end if

	if (gpscount >= 2) Then	'// GPS���m�肵�Ă���Ȃ�
'		if (v >= YAWV) Then '   // �ԑ�����������x�ɑ��s���Ă���Ȃ�
		if (1) Then '   // �ԑ�����������x�ɑ��s���Ă���Ȃ�
			level = v * VDOUBTX		'// ����ԑ��΍�臒l
			if (level < DOUBTV) Then level = DOUBTV '// �Ⴍ���߂��Ȃ�
			err = Abs(v - vgps)
'bug=v
'bug1=vgps
'bug2=err
'bug3=level
			if (err >= level) Then		'// �ԑ������������H
				fdoubt = TRUE			'// �ԑ��ɂ��^�킵������J�n
				oktime = 0
			end if
			Call AddOnTime(err < level, oktime) '// �ԑ����񕜂�������
			if (oktime >= VDOUBTTIMEC) Then 	'// �񕜂��K��񐔂ɒB�����H
				fdoubt = FALSE			'// �^�킵�������艺��
			end if
		end if
	else
		fdoubt = FALSE
		oktime = 0
	end if
'bug2=fdoubt* -8
	JudgeGpsDoubtVreal1 = fdoubt
end Function
static Function JudgeGpsDoubtVreal(v As Single, vgps As Single, _
				gpscount As Long) As Boolean

	Const DOUBTV As Single = 5# 	'// �^�킵����Ԃ̎ԑ��΍�
	Const VDOUBTTIMEC As Long = 3	'// �ԑ��񕜑҂�����[s]
	Dim err As Single
	static fdoubt As Boolean
	static oktime As Long

	if (AfterPowerOnTime <= 1) Then '// �N������
		fdoubt = FALSE
		oktime = 0
	end if

	if (gpscount >= 2) Then	'// GPS���m�肵�Ă���Ȃ�
			err = Abs(v - vgps)
'bug=v
'bug1=vgps
'bug2=err
'bug3=DOUBTV
			if (err >= DOUBTV) Then		'// �ԑ������������H
				fdoubt = TRUE			'// �ԑ��ɂ��^�킵������J�n
				oktime = 0
			end if
			Call AddOnTime(err < DOUBTV, oktime) '// �ԑ����񕜂�������
			if (oktime >= VDOUBTTIMEC) Then 	'// �񕜂��K��񐔂ɒB�����H
				fdoubt = FALSE			'// �^�킵�������艺��
			end if
	else
		fdoubt = FALSE
		oktime = 0
	end if
'bug2=fdoubt* -8
	JudgeGpsDoubtVreal = fdoubt
end Function
'/*---------------------------------------------------------------------------
'   �J�[�u����
'---------------------------------------------------------------------------*/
static Function JudgeCurve(yaw As Single, gpsyaw As Single, _
									gpscount As Long) As Boolean
	Const CRESTIMEC As Long = 300	'// �J�[�u���ԃ��Z�b�g����[s]x10
	Const CURVETIMEC As Long = 20	'// ���[���[�g����܂ł̔��莞��[s]x10
	Const CRETRYTIMEC As Long = 100 '// �^�킵�����ԃ��Z�b�g����[s]x10

	static fcurve As Boolean
	static curvedelay As Long, gytime As Long, ctime As Long
	static retrytime As Long

	if (AfterPowerOnTime <= 1) Then '// �N������
		curvedelay = 0
		gytime = 0
		ctime = 0
		retrytime = 0
		fcurve = FALSE
	end if

	'// GPS���[���[�g���o�Ă��Ȃ�����
	Call AddOnTime(Abs(gpsyaw) <= CURVEYAW And gpscount >= 2, gytime)
	Call DecNonZero(curvedelay) 	'// �J�[�u���s�^�C�}�f�N�������g
	Call DecNonZero(retrytime)		'// ���g���C�^�C�}�f�N�������g
	if (Abs(yaw) >= CURVEYAW) Then	'// ���[���[�g���o�Ă�����Ԃ�
		curvedelay = CURVETIMEC 	'// �^�C�}�ăZ�b�g
	end if
	fcurve = curvedelay > 0 '// �J�[�u���s�����f(��)
	Call AddOnTime(fcurve, ctime)	'// �J�[�u�Ɣ��肳��Ă��鎞��
'bug=gytime
'bug=gpscount
'bug=Abs(gpsyaw)
'bug1=ctime
'bug2=curvedelay

	'// �J�[�u�Ɣ��肳��Ă��鎞�Ԃ����������������Ȏ��Ԃ�����
	'// (���܂ł��I���Ȃ��Ȃ邱�Ƃ�h�~���邽�߂�F/S����)
	if (ctime >= CRESTIMEC And gytime >= CRESTIMEC) Then
		retrytime = CRETRYTIMEC '// ��������^�킵�����Ԃ������
	end if
	if (retrytime > 0) Then '// �f�B���C�^�C�}��0�łȂ����Ԃ�
		fcurve = FALSE		'// �J�[�u���f����艺����
	end if
	JudgeCurve = fcurve
end Function
'/*---------------------------------------------------------------------------
'   PI�����GPS���ʂɑ΂���INS���ʂ̕␳�ʂ𓾂�
'---------------------------------------------------------------------------*/
Function GetPI(err As Single, fenable As Boolean) As Single
	Const PGAIN As Single = 0.05
	Const IGAIN As Single = 0.05
	static ii As Single

	if (AfterPowerOnTime <= 1 Or Not fenable) Then '// �ʓd����͏�����
		ii = 0
	end if
	ii = ii + err * IGAIN		'// I��
	GetPI = err * PGAIN + ii	'// P�����v���X
end Function
'/*---------------------------------------------------------------------------
'   �����q�@�ɂ��ܓx���o�x���W���v�Z
'---------------------------------------------------------------------------*/
Function CalcInsCoordinate(lat As Long, lon As Long, _
				cs As Single, v As Single, dt As Single)
	Dim a As Single
	Dim L As Single
	Dim psi As Single
	Dim len_ As Single
	Dim thta As Single
	Dim dy As Single
	Dim dx As Single
	Dim angllat As Single
	Dim angllon As Single
	Dim x As Single
	static vz As Single, csz As Single

	if (AfterPowerOnTime <= 1) Then '// �N������
		vz = v
		csz = cs
	end if
	

	'�����x[m/s^2]
	if (vz > 0 And v > 0) Then
		a = (v - vz) / 3.6 * dt
	else
		a = 0
	end if
	'�i�񂾋��� = �ʂ̒���L = v�Et + 1/2�Ea�Et^2[m]
	L = (v + vz) / 2 / 3.6 * dt + a * dt * dt / 2.0
	'�O�񂩂�̊p�x�ω���[rad]
	psi = Radians(Normal180(Normal180(cs) - Normal180(csz)))
	if (psi <> 0) Then
		'���̒���l = 2�Esin(��/2)�EL / �� [m]
		len_ = 2 * Sin(psi / 2.0) * L / psi
	else
		len_ = L
	end if
	'�O��̃��[���h���ʂ����/2���ꂽ�����ɐi�񂾂��Ƃɂ���
	thta = Radians(csz) + psi / 2.0
	'�k�ɐi�񂾋���
	dy = len_ * Cos(thta)
	'�ܓx�ɕϊ�
	angllat = Degrees((Atn(dy / 6378150#)))
	'���ɐi�񂾋���
	dx = len_ * Sin(thta)
	'�ܓx�ɂ��␳��
	x = Abs(Cos(Radians(lat / F1e7)))
	x = WorksheetFunction.Max(x, 0.1)
	'�o�x�ɕϊ�
	angllon = Degrees(Atn(dx / (6378150# * x)))
	'�V���ȍ��W
	lat = lat + angllat * F1e7
	lon = lon + angllon * F1e7
	'// ���ݒl��������
	vz = v
	csz = cs

	CalcInsCoordinate = Array(lat, lon)
end Function

'/*---------------------------------------------------------------------------
'   2�̍��W�Ԃ̋�����Ԃ�
'---------------------------------------------------------------------------*/
Function Distance(lat1 As Long, lon1 As Long, _
					lat2 As Long, lon2 As Long)
	Dim x As Single, y As Single

	'// �������̈ړ�����
	x = Sin(Radians((lon2 - lon1) / F1e7)) * 6372795 * _
				Abs(Cos(Radians(lat2 / F1e7)))
	'// �c�����̈ړ�����
	y = Sin(Radians((lat2 - lat1) / F1e7)) * 6372795
	Distance = Sqr(x * x + y * y)
end Function
'/*---------------------------------------------------------------------------
'   2�̍��W�Ԃ̕��ʂ�Ԃ�
'---------------------------------------------------------------------------*/
Function Course(lat1 As Long, lon1 As Long, _
					lat2 As Long, lon2 As Long)
	Dim x As Single, y As Single, z As Single
	static ans As Single

	'// �������̈ړ�����/�n�����a(�E����)
	x = Sin(Radians((lon2 - lon1) / F1e7)) * Abs(Cos(Radians(lat2 / F1e7)))
	'// �c�����̈ړ�����/�n�����a(�オ��)
	y = Sin(Radians((lat2 - lat1) / F1e7))

	if (x <> 0) Then
		z = Abs(Degrees(Atn(y / x)))
		if (x >= 0 And y >= 0) Then
			ans = 90 - z
		elseif (x >= 0 And y < 0) Then
			ans = 90 + z
		elseif (x < 0 And y < 0) Then
			ans = 270 - z
		else
			ans = 270 + z
		end if
	end if
	Course = ans
end Function
'/*---------------------------------------------------------------------------
'   �t�B���^�[
'---------------------------------------------------------------------------*/
Function Filter(filt As Single, dat As Single, fact As Single)
	if (AfterPowerOnTime <= 1) Then 	'// �ʓd����͏�����
		filt = dat
	else
		filt = (1# - fact) * filt + fact * dat
	end if
end Function
'/*---------------------------------------------------------------------------
'   0�`360�ɐ��K��
'---------------------------------------------------------------------------*/
Function Normal360(dat As Single)
	Dim x As Single
	x = dat
	do while (x >= 360)
		x = x - 360
	Loop
	do while (x < 0)
		x = x + 360
	Loop
	Normal360 = x
end Function
'/*---------------------------------------------------------------------------
'   �}180�ɐ��K��
'---------------------------------------------------------------------------*/
Function Normal180(dat As Single)
	Dim x As Single
	x = dat
	do while (x >= 180)
		x = x - 360
	Loop
	do while (x < -180)
		x = x + 360
	Loop
	Normal180 = x
end Function
'/*---------------------------------------------------------------------------
'   180deg���]
'---------------------------------------------------------------------------*/
Function Add180(deg As Single)
	Dim x As Single
	x = deg
	x = x + 180#			'// 180deg���]
	if (x > 360#) Then
		x = x - 360#
	end if
	Add180 = x
end Function
'/*---------------------------------------------------------------------------
'   ������Ԃ�
'---------------------------------------------------------------------------*/
Function Sign(x As Single)
	if (x > 0) Then
		Sign = 1
	elseif (x < 0) Then
		Sign = -1
	else
		Sign = 0
	end if
end Function

'/*---------------------------------------------------------------------------
'   �t���O��TRUE�̉񐔂�ݐ�
'---------------------------------------------------------------------------*/
Function AddOnTime(f As Boolean, x As Long)
	if (f) Then
		x = x + 1
	else
		x = 0
	end if
	AddOnTime = x
end Function
'/*---------------------------------------------------------------------------
'   �t���O��TRUE�Ƃ����łȂ��̉񐔂�ݐ�
'---------------------------------------------------------------------------*/
Function AddOnOffTime(f As Boolean, x As Long, y As Long)
	if (f) Then
		x = x + 1
		y = 0
	else
		x = 0
		y = y + 1
	end if
	AddOnOffTime = x
end Function
'/*---------------------------------------------------------------------------
'   �l��0�łȂ��Ȃ猸�Z
'---------------------------------------------------------------------------*/
Function DecNonZero(x As Long)
	if (x > 0) Then
		x = x - 1
	end if
	DecNonZero = x
end Function
'/*---------------------------------------------------------------------------
'   ��
'---------------------------------------------------------------------------*/
Function Pai()
	Pai = Atn(1) * 4
end Function
'/*---------------------------------------------------------------------------
'   deg��rad�ϊ�
'---------------------------------------------------------------------------*/
Function Radians(x As Single)
	Radians = x * Atn(1) / 45
end Function
'/*---------------------------------------------------------------------------
'   rad��deg�ϊ�
'---------------------------------------------------------------------------*/
Function Degrees(x As Single)
	Degrees = x * 45 / Atn(1)
end Function
'/*---------------------------------------------------------------------------
'   bit
'---------------------------------------------------------------------------*/
Function Bit(x As Integer, pat As Integer, y1 As Single, y0 As Single)
	if (x And pat) Then
		Bit = y1
	else
		Bit = y0
	end if
end Function
'/*---------------------------------------------------------------------------
'   ���X�P�[�����O���t1����2�ɃR�s�[
'---------------------------------------------------------------------------*/
Public Sub CopyAxis1to2()
	Dim x0 As Double, x1 As Double
	Dim y0 As Double, y1 As Double
	Dim chtObj1 As ChartObject, chtObj2 As ChartObject
	Dim s As String

	for Each chtObj2 In ActiveSheet.ChartObjects
		if (chtObj2.Chart.HasTitle) Then
			s = chtObj2.Chart.ChartTitle.Text
			if (s = "GPS(���O)") Then
				for Each chtObj1 In ActiveSheet.ChartObjects
					if (chtObj1.Chart.HasTitle) Then
						s = chtObj1.Chart.ChartTitle.Text
						if (s = "INS(���O)") Then
							chtObj2.Activate		  '�O���t2�I��
							ActiveChart.Axes(xlValue).Select
							With ActiveChart.Axes(xlValue)
								y0 = .MinimumScale	'�c���̖ڐ��擾
								y1 = .MaximumScale
							end With
							ActiveChart.Axes(xlCategory).Select
							With ActiveChart.Axes(xlCategory)
								x0 = .MinimumScale	'�����̖ڐ��擾
								x1 = .MaximumScale
							end With
							chtObj1.Activate	  '�O���t1�I��
							ActiveChart.Axes(xlValue).Select
							With ActiveChart.Axes(xlValue)
								.MinimumScale = y0	'�c���̖ڐ��ݒ�
								.MaximumScale = y1
							end With
							ActiveChart.Axes(xlCategory).Select
							With ActiveChart.Axes(xlCategory)
								.MinimumScale = x0	'�����̖ڐ��ݒ�
								.MaximumScale = x1
							end With
						end if
						if (s = "INS(Sim)") Then
							chtObj2.Activate		  '�O���t2�I��
							ActiveChart.Axes(xlValue).Select
							With ActiveChart.Axes(xlValue)
								y0 = .MinimumScale	'�c���̖ڐ��擾
								y1 = .MaximumScale
							end With
							ActiveChart.Axes(xlCategory).Select
							With ActiveChart.Axes(xlCategory)
								x0 = .MinimumScale	'�����̖ڐ��擾
								x1 = .MaximumScale
							end With
							chtObj1.Activate	  '�O���t1�I��
							ActiveChart.Axes(xlValue).Select
							With ActiveChart.Axes(xlValue)
								.MinimumScale = y0	'�c���̖ڐ��ݒ�
								.MaximumScale = y1
							end With
							ActiveChart.Axes(xlCategory).Select
							With ActiveChart.Axes(xlCategory)
								.MinimumScale = x0	'�����̖ڐ��ݒ�
								.MaximumScale = x1
							end With
						end if
					end if
				Next
			end if
		end if
	Next
	ActiveSheet.Cells(2, 2).Activate	  '�J�[�\���������ʒu��
end Sub
'/*---------------------------------------------------------------------------
'   ���X�P�[�����O���t2����1�ɃR�s�[
'---------------------------------------------------------------------------*/
Private Sub CopyAxis2to1()
	Dim x0 As Double, x1 As Double
	Dim y0 As Double, y1 As Double
	Dim chtObj1 As ChartObject, chtObj2 As ChartObject
	Dim s As String

	for Each chtObj2 In ActiveSheet.ChartObjects
		if (chtObj2.Chart.HasTitle) Then
			s = chtObj2.Chart.ChartTitle.Text
			if (s = "I�ܓxS") Then
				for Each chtObj1 In ActiveSheet.ChartObjects
					if chtObj1.Chart.HasTitle Then
						s = chtObj1.Chart.ChartTitle.Text
						if (s = "G�ܓx") Then
							chtObj2.Activate		  '�O���t2�I��
							ActiveChart.Axes(xlValue).Select
							With ActiveChart.Axes(xlValue)
								y0 = .MinimumScale	'�c���̖ڐ��擾
								y1 = .MaximumScale
							end With
							ActiveChart.Axes(xlCategory).Select
							With ActiveChart.Axes(xlCategory)
								x0 = .MinimumScale	'�����̖ڐ��擾
								x1 = .MaximumScale
							end With
							chtObj1.Activate	  '�O���t1�I��
							ActiveChart.Axes(xlValue).Select
							With ActiveChart.Axes(xlValue)
								.MinimumScale = y0	'�c���̖ڐ��ݒ�
								.MaximumScale = y1
							end With
							ActiveChart.Axes(xlCategory).Select
							With ActiveChart.Axes(xlCategory)
								.MinimumScale = x0	'�����̖ڐ��ݒ�
								.MaximumScale = x1
							end With
						end if
					end if
				Next
			end if
		end if
	Next
	ActiveSheet.Cells(2, 2).Activate	  '�J�[�\���������ʒu��
end Sub


'/*---------------------------------------------------------------------------
'   VSP�萔�w�K����
'---------------------------------------------------------------------------*/
Function LearnVsp(VspConst As Long, v As Single, vgps As Single, _
					flearn As Boolean)
	static dvfilt As Single
	Const V1 As Single = 3.0
	Const VCMAX As Single = 100.0
	Dim vc As Single

	if (AfterPowerOnTime <= 1) Then '// �N������
		dvfilt = 0#
	end if
'bug3=flearn*-15
'bug=vgps
'bug1=v
'if (GpsVreal > 0 and flearn) then
'	bug2=(Vreal - GpsVreal) / GpsVreal * 1000
'	bug2=(Vreal - GpsVreal)*10
'else
'	bug2=0
'end if
'bug=v
'bug1=vgps
'bug2=dvfilt
	if (flearn) Then
		Call Filter(dvfilt, v - vgps, 0.1) '// �������t�B���^�����O
		vc = Abs(dvfilt) * VCMAX / V1
		if (vc > VCMAX) Then
			vc = VCMAX
		end if
		if (dvfilt > 0#) Then	'// ���[�^�ԑ����傫���Ȃ�
			VspConst = VspConst - vc '// �萔�����炷
		elseif (dvfilt < 0) Then	'// �����Ȃ����
			VspConst = VspConst + vc '// �萔�𑝂₷
		end if
	end if
'bug2=dvfilt*10
'bug4=VspConst/100000
	LearnVsp = VspConst
end Function

'/*---------------------------------------------------------------------------
'   �ԑ��Z�o����
'---------------------------------------------------------------------------*/
Function CalcVsp(afilt As Single, dt As Single, slp As Single, _
				accely As Single, yaw As Single, fcrv As Boolean, _
				fReverse As Boolean, fpark As Boolean)

	Const VSPMINV As Single = 0.1		'// VSP�Œ�ԑ� 0.1[km/h]
	Const VSPMINITVL As Long = 20		'// VSP��~����C���^�[�o�� 2[s]x10
	Const VSPSTARTG As Single = 0.015	'// ���i��������x�΍�[G]
	Const VSPDELAYC As Single = 30	'// G�ω��ɂ�锭�i����I�t�f�B���C[s]x10
	Const V0 As single = 5.0

	Dim ac As Single, dv As Single
	static v As Single, vz As Single
	static acz As Single
	static gtime As Long
	Dim ofst As Double, sp As Single

	if (AfterPowerOnTime <= 1) Then '// �N������
		v = 0
		vz = 0
		acz = 0
		gtime = 0
	end if
'bug2=vc
	if (VspTime > 0) Then		'// �p���X������Ȃ�
		'// �ԑ��v�Z[km/h]
		v = VspConst / VspTime
	else
		v = 0#
	end if

	Call DecNonZero(gtime)	'// �f�B���C�^�C�}���Z
	'// ��~����G�̕ω���臒l�𒴂����H
	if (v = 0# And Not fpark And Abs(accely - acz) >= VSPSTARTG) Then
		gtime = VSPDELAYC	'// ��~����G�ϓ��^�C�}�X�^�[�g
	end if
	'// �Ō�̃p���X����K�薢���܂��͒�~����G�ϓ����������H
	if (gtime > 0) Then
		if v < VSPMINV Then v = VSPMINV '// �Œ�ԑ���ݒ�
	end if
	acz = accely	'// �����G�Z���T�[�O������x��������

	if (fReverse) Then	'// ���o�[�X�Ȃ�
		v = v * -1# 	'// ��
	end if
	if (v < 5# And fpark) Then	'// �ԑ����Ⴍ�ăp�[�L���O�u���[�L�I���Ȃ�
		v = 0#	'// ��~
	end if

	v = CollectVspTire(v, afilt)	'// �^�C���̓����a�␳

	dv = v - vz '// �ԑ��ω���
	if (v >= 2# And vz >= 2# And dt > 0#) Then
		ac = dv / 3.6 / dt / G1 '// �ԑ������O������x[G]
	else
		ac = accely
	end if
	'// �ԑ��f�[�^�ƈʑ������킹�����[�^�[�����x
	Call Filter(afilt, ac, GPSFILT)
	vz = v

	'// ���z�ɂ��ԑ��␳
	sp = Abs(slp)
	if (sp > 1#) Then sp = 1#
	v = v * Cos(WorksheetFunction.Asin(sp))
'bug=v
	CalcVsp = v
end Function
'/*---------------------------------------------------------------------------
'   �ԑ��̔���`�␳
'---------------------------------------------------------------------------*/
Function CollectVsp0(v As Single)
	Const MAXCALV As Single = 20.0	'// �␳����ő�ԑ�[km/h]
	Const CALV As Single = 2		'// �␳����ԑ�[km/h]
	Dim v0 As Single

	v0 = v
	if (v0 > CALV And v0 <= MAXCALV) then
		v0 = v0 - CALV
	end if
	if (v0 < -CALV) then
		v0 = v0 + CALV
	end if

	CollectVsp0 = v0
end Function
Function CollectVsp1(v As Single, ac As Single)
	Const MAXCALV As Single = 120.0	'// �␳����ő�ԑ�[km/h]
	Const CALV As Single = 3		'// �␳����ԑ�[km/h]
	Const G2V As Single = 20		'// �����x�␳�ԑ��W��[G]��[km/h]
	Const GDEADZONE As Single = 0.1'// �����x�␳�s����[km/h]
	Dim v0 As Single, vc As Single

	'// �ԑ����v���X���ɂ���镪
	if (Abs(v) > MAXCALV) then
		vc = 0.0
	else
		vc = CALV - Abs(v) * CALV / MAXCALV
	end if

	v0 = v
	if (v0 > vc) then
		v0 = v0 - vc
	end if
	if (v0 < -vc) then
		v0 = v0 + vc
	end if

	vc = ac * G2V
	if (Abs(vc) < GDEADZONE) then
		vc = 0
	end if
	if (vc > 3) then vc = 3
	if (vc < -3) then vc = -3
	v0 = v0 - vc
	if (v = 0) then
		v0 = 0
	elseif (v > 0) then
		if (v0 < 0) then
			v0 = 0
		end if
	else
		if (v0 > 0) then
			v0 = 0
		end if
	end if
	CollectVsp1 = v0
end Function
'/*---------------------------------------------------------------------------
'	�^�C���̓����a�␳
'---------------------------------------------------------------------------*/
Function CollectVspTire(v As Single, ac As Single)
	Const MAXCALV As Single = 120.0	'// �␳����ő�ԑ�[km/h]
	Const VGAIN0 As Single = 0.995	'// �ԑ�0�ł̃Q�C��
	Const G2GAIN As Single = 0.0	'// �����x�␳�W��[G]��[�{]
	Const GDEADZONE As Single = 0.05'// �����x�␳�s����[G]
	Dim v0 As Single, vgain As Single, ggain As Single

	v0 = v
	'// �^�C���̓����a�␳
	if (Abs(v) > MAXCALV) then
		vgain = 1.0
	else
		vgain = VGAIN0 + Abs(v) * (1.0 - VGAIN0) / MAXCALV
	end if

'bug3=vgain
	v0 = v0 * vgain

	'// �������ɂ��X���b�v���␳
	ggain = 1.0 - ac * G2GAIN
	if (Abs(ac) < GDEADZONE) then
		ggain = 1.0
	end if
	if (v0 > 0) then	'// �O�i���̂ݕ␳����
		v0 = v0 * ggain
	end if
'bug3=ggain

	CollectVspTire = v0
end Function
'/*---------------------------------------------------------------------------
'   ���[���[�g�Z���T�̕⏞�ƃI�t�Z�b�g�������s���^�̃��[���[�g�𓾂�[deg/s]
'---------------------------------------------------------------------------*/
static Function GetTrueYawRate(yofst As Single, yawr As Integer, _
				temp As Single, _
				gpsyaw As Single, v As Single, accel As Single, _
				fcrv As Boolean, fpk As Boolean, _
				fstop As Boolean, frun As Boolean) As Single

	Const FILT_OFCANSTOP As Single = 0.01'// ��~���I�t�Z�b�g�����t�B���^�萔
	Const FILT_OFCAN As Single = 0.005	'// �I�t�Z�b�g�����t�B���^�萔
	Const ACCEL2ANGLE As Single = 35#	'// �����x�p�x�ϊ��W��

	Dim x As Single, rpgain As Single
	static yaw As Single, yawdelay As Single
	Dim rol As Single, pich As Single
	Dim tofst As Single

	if (AfterPowerOnTime <= 1) Then '// �N������
		yawdelay = yaw
	end if

	'// ���x�ɂ���Đ�����I�t�Z�b�g��[deg/s]
	tofst = (temp - CALTEMP) * SLOPE_YAW
'bug1=tofst
	'// ���x�⏞�������[���[�g[deg/s]
	yaw = yawr * 250# / 32768#
	yaw = yaw - tofst

	'// �X�P�[���Q�C���␳
	yaw = yaw * YAWGAIN

	'// �J�[�u���Ȃ烍�[���p�ƃs�b�`�p[rad]�𐄒�
	if (fcrv) then
		rol = v / 3.6 * Radians(yaw) / G1 * ACCEL2ANGLE
		if (rol >= 30) Then
			rol = 30
		elseif (rol <= -30) Then
			rol = -30
		end if
		rol = Radians(rol)
		pich = accel * ACCEL2ANGLE
		if (pich >= 30) Then
			pich = 30
		elseif (pich <= -30) Then
			pich = -30
		end if
		pich = Radians(pich)
	else
		rol = 0
		pich = 0
	end if
	'// �W���C��Z���̉���������̌X��[rad]
	x = Atn(Sqr(Tan(rol) ^ 2 + Tan(pich) ^ 2))
	x = Cos(x)	'// Z�����X�����Ƃɂ��Z���T�o�͂̌�����
	if (x <> 0#) Then
		rpgain = 1 / x	'// �X����␳���邽�߂̃Q�C��
	else
		rpgain = 1#
	end if

	'// ���[�����s�b�`�␳
	yaw = yaw * YAWGAIN * rpgain
'bug=yaw
	'// GPS���[���[�g�ƈʑ������킹�����[���[�g
	Call Filter(yawdelay, yaw, GPSFILT)

	'/*** ��~�����[���[�g�[���_�␳ ***/
	'// ��~���̃Z���T�o�͂͂��̂܂܃I�t�Z�b�g�Ƃ�����
	if (fstop) Then
		if (fpk) Then
			'// ���[���[�g�I�t�Z�b�g�A�b�v�f�[�g[deg/s]
			Call Filter(yofst, yaw, FILT_OFCANSTOP)
		else
			'// ���[���[�g�I�t�Z�b�g�A�b�v�f�[�g[deg/s]
			Call Filter(yofst, yaw, FILT_OFCAN)
		end if
'bug=0.01
	end if

	'/*** ���s�����[���[�g�[���_�␳ ***/
	if (frun And Abs(gpsyaw) <= CURVEYAW) Then
'bug=-0.01
		'// ���[���[�g�I�t�Z�b�g�A�b�v�f�[�g[deg/s]
		Call Filter(yofst, yawdelay - gpsyaw, FILT_OFCAN)
	end if
'bug1=yofst

	'// �I�t�Z�b�g��␳�������[���[�g
	yaw = yaw - yofst

'bug=rol
'bug1=pich
'bug2=rpgain

	'// ���[���[�g��Ԃ�
	GetTrueYawRate = yaw
end Function
