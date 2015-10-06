#include "include/Bass.au3"
#include "include/BassEnc.au3"
#include "include/FASM.au3"
;#####################################################
;MakeSound UDF by Sprenger120 @ www.autoit.de
;Make Sound Steht unter einer Creative Commons Namensnennung-Nicht-kommerziell-Weitergabe unter gleichen Bedingungen 3.0 Unported Lizenz.
;#####################################################

Global $_MakeSound_FASM = -1, $_MakeSound_AssemblerFuncPtr = -1, $_MakeSound_StartedUp = 0

; #FUNCTION# ======================================================================================
; Name ..........: _MakeSound_FreeWAV()
; Description ...: Frees all used resources from a MakeSound WAV.
; Syntax ........: _MakeSound_FreeWAV(ByRef $aWAV)
; Parameters ....: ByRef $aWAV - An array returned from _MakeSound_CreateWAV.
; Return values .: Success  - Return 1
;                  Failure  - Return -1 and set @error to the following values
;                  |1    - _MakeSound_StartUp() wasn`t callt before.
;                  |2    - MakeSound Array isn't valid
; Author ........: Sprenger120
; =================================================================================================
Func _MakeSound_FreeWAV(ByRef $aWAV)
	If Not $_MakeSound_StartedUp Then Return SetError(1, -1, -1)
	If Not IsArray($aWAV) Or UBound($aWAV) <> 7 Then Return SetError(2, -1, -1) ; prüfen ob aWAV die richtige größe hat

	$aWAV[0] = 0 ;struct löschen
	$aWAV[2] = 0 ;pointer löschen
	_BASS_StreamFree($aWAV[4])
	$aWAV = 0 ;array löschen
	Return 1
EndFunc   ;==>_MakeSound_FreeWAV

; #FUNCTION# ======================================================================================
; Name ..........: _MakeSound_Write()
; Description ...: Writes the SoundMake informations to the local WAV file and frees all used resources of the WAV.
; Syntax ........: _MakeSound_Write(ByRef $aWAV)
; Parameters ....: ByRef $aWAV - An array returned from _MakeSound_CreateWAV.
; Return values .: Success  - Return 1
;                  Failure  - Return -1 and set @error to the following values.
;                  |1    - _MakeSound_StartUp() wasn`t callt before.
;                  |2    - The given MakeSound Array is not valid.
; Author ........: Sprenger120
; =================================================================================================
Func _MakeSound_Write(ByRef $aWAV)
	If Not $_MakeSound_StartedUp Then Return SetError(1, -1, -1)
	If Not IsArray($aWAV) Or UBound($aWAV) <> 6 Or Not IsPtr($aWAV[2]) Or Not IsDllStruct($aWAV[0]) Then Return SetError(2, -1, -1)

	_BASS_Encode_Write($aWAV[5], $aWAV[2], DllStructGetSize($aWAV[0]))
	If @error Then Return SetError(4, @error, -1)
	_BASS_Encode_Stop($aWAV[5])
	_MakeSound_FreeWAV($aWAV)
	Return 1
EndFunc   ;==>_MakeSound_Write

; #FUNCTION# ======================================================================================
; Name ..........: _MakeSound_Sleep()
; Description ...: Insert a silence sequenze into the MakeSound WAV.
; Syntax ........: _MakeSound_Sleep(ByRef $aWAV, $iLenght)
; Parameters ....: ByRef $aWAV - An array returned from _MakeSound_CreateWAV.
;                  $iLenght    - Lenght of the tone in milliseconds. (minimal 10ms)
; Return values .: Success  - Return 1
;                  Failure  - Return -1 and set the @error value as _MakeSound_InsertSound.
; Author ........: Sprenger120
; =================================================================================================
Func _MakeSound_Sleep(ByRef $aWAV, $iLenght)
	If Not $_MakeSound_StartedUp Then Return SetError(1, -1, -1)
	_MakeSound_InsertSound($aWAV, 10, $iLenght)
	If @error Then Return SetError(2, @error, -1)
	Return 1
EndFunc   ;==>_MakeSound_Sleep

; #FUNCTION# ======================================================================================
; Name ..........: _MakeSound_InsertSound()
; Description ...: Generates a sinus tone and insert it into the given MakeSound WAV.
; Syntax ........: _MakeSound_InsertSound(ByRef $aWAV, $iFreq, $iLenght)
; Parameters ....: ByRef $aWAV - An array returned from _MakeSound_CreateWAV.
;                  $iFreq      - Frequenz of the tone.
;                  $iLenght    - Lenght of the tone in milliseconds. (minimal 10ms)
; Return values .: Success  - Return 1
;                  Failure  - Return -1 and set @error to the following values.
;                  |1    - _MakeSound_StartUp() wasn`t callt before.
;                  |2    - The given Parameters are not valid.
;                  |3    - The given MakeSound Array is not valid.
;                  |4    - $iLenght is beyond the end of the file.
; Author ........: Sprenger120
; =================================================================================================
Func _MakeSound_InsertSound(ByRef $aWAV, $iFreq, $iLenght)
	If Not $_MakeSound_StartedUp Then Return SetError(1, -1, -1)
	If $iFreq <= 0 Or $iLenght <= 10 Then Return SetError(2, -1, -1)
	If Not IsArray($aWAV) Or UBound($aWAV) <> 6 Or Not IsPtr($aWAV[2]) Or Not IsDllStruct($aWAV[0]) Then Return SetError(3, -1, -1) ; prüfen ob aWAV die richtige größe hat

	If $aWAV[3] + $iLenght > $aWAV[1] Then Return SetError(4, -1, -1)

	$iFreq = Round($iFreq, -1) ; Zahlen glätten damit Rechnung einwandfrei funktionieren kann
	$iLenght = Round($iLenght, -1)

	;pointer | start | länge | frequenz
	MemoryFuncCall("int:cdecl", $_MakeSound_AssemblerFuncPtr, "ptr", $aWAV[2], "int", Int(44100 * ($aWAV[3] / 1000) * 2), "int", Int(44100 * ($iLenght / 1000)), "int", Int(44100 / $iFreq))

	$aWAV[3] += $iLenght
	Return 1
EndFunc   ;==>_MakeSound_InsertSound

; #FUNCTION# ======================================================================================
; Name ..........: _MakeSound_CreateWAV()
; Description ...: Creates a WAV file for use in MakeSound
; Syntax ........: _MakeSound_CreateWAV($sPath, $iLenght)
; Parameters ....: $sPath   - Path for the WAV file.
;                  $iLenght - Lenght of the WAV file in milliseconds.
; Return values .: Success  - Returns an array for use in MakeSound
;                  Failure  - Return -1 and set @error to the following values
;                  |1   _MakeSound_StartUp() wasn`t callt before.
;                  |2   _BASS_StreamCreate failted. (error code in @extendet)
;                  |3   _BASS_Encode_Start failted. (error code in @extendet)
; Author ........: Sprenger120
; =================================================================================================
Func _MakeSound_CreateWAV($sPath, $iLenght)
	If Not $_MakeSound_StartedUp Then Return SetError(1, -1, -1)
	If $iLenght <= 10 Or $sPath = "" Then Return -1
	Local $aRet[6]
	$aRet[0] = DllStructCreate("short[" & 44100 * ($iLenght / 1000) & "]")
	$aRet[1] = $iLenght
	$aRet[2] = DllStructGetPtr($aRet[0])
	$aRet[3] = 0 ;reserviert
	$aRet[4] = _BASS_StreamCreate(44100, 1, 0, $STREAMPROC_DUMMY, 0)
	If @error Then Return SetError(2, @error, -1)
	$aRet[5] = _BASS_Encode_Start($aRet[4], $sPath, $BASS_ENCODE_PCM)
	If @error Then Return SetError(3, @error, -1)
	Return $aRet
EndFunc   ;==>_MakeSound_CreateWAV

; #FUNCTION# ======================================================================================
; Name ..........: _MakeSound_Startup()
; Description ...: Starts SoundMake.
; Syntax ........: _MakeSound_Startup()
; Return values .: Success  - Return 1
;                  Failure  - Return -1 and set @error to the following values.
;                  |1   - BASS startup failted. (error code in @extendet)
;                  |2   - BASS init failted. (error code in @extendet)
;                  |3   - BASS Enc startup failted. (error code in @extendet)
; Author ........: Sprenger120
; =================================================================================================
Func _MakeSound_Startup()
	If $_MakeSound_StartedUp Then Return 2
	If $_ghBassDll = -1 Then
		_BASS_Startup()
		If @error Then Return SetError(1, @error, -1)
		_BASS_Init(0, -1, 44100, 0, "")
		If @error Then Return SetError(2, @error, -1)
	EndIf
	If $_ghBassEncDll = -1 Then
		_BASS_ENCODE_Startup()
		If @error Then Return SetError(3, @error, -1)
	EndIf
	If $_MakeSound_FASM = -1 Then ;FASM initialisieren
		$_MakeSound_FASM = FASMInit()
		FASMReset($_MakeSound_FASM)
		___MakeSound_AssemblerFunc()
		$_MakeSound_AssemblerFuncPtr = FasmGetFuncPtr($_MakeSound_FASM)
	EndIf
	$_MakeSound_StartedUp = 1
	Return 1
EndFunc   ;==>_MakeSound_Startup

; #FUNCTION# ======================================================================================
; Name ..........: _MakeSound_Shutdown()
; Description ...: Free all used MakeSound resources.
; Syntax ........: _MakeSound_Shutdown()
; Return values .: 1
; Author ........: Sprenger120
; =================================================================================================
Func _MakeSound_Shutdown()
	If $_MakeSound_StartedUp = 0 Then Return
	FASMExit($_MakeSound_FASM)
	$_MakeSound_FASM = -1
	$_MakeSound_AssemblerFuncPtr = -1
	$_MakeSound_StartedUp = 0
	Return 1
EndFunc   ;==>_MakeSound_Shutdown

; #FUNCTION# ======================================================================================
; Name ..........: ___MakeSound_AssemblerFunc()
; Description ...: Internal Function
; Syntax ........: ___MakeSound_AssemblerFunc()
; Author ........: Sprenger120
; =================================================================================================
Func ___MakeSound_AssemblerFunc()
	FASMAdd($_MakeSound_FASM, "use32")
	FASMAdd($_MakeSound_FASM, "org " & Fasmgetbaseptr($_MakeSound_FASM))
	FASMAdd($_MakeSound_FASM, "finit");Co Prozi starten

	;Parameter abhohlen
	FASMAdd($_MakeSound_FASM, "mov edi, dword[esp+4]") ;Pointer auf die Struct
	FASMAdd($_MakeSound_FASM, "mov ebx, dword[esp+8]") ;start
	FASMAdd($_MakeSound_FASM, "mov ecx, dword[esp+12]") ;Länge
	FASMAdd($_MakeSound_FASM, "mov esi, dword[esp+16]") ;Frequenz


	FASMAdd($_MakeSound_FASM, "add edi,ebx") ;pointer der struct auf die startaddresse schieben

	FASMAdd($_MakeSound_FASM, "_schleife:")

	;Vorbereitungen für Sinus
	;Formel:   Pos*Pi*2 /   (44100 / Frequenz)
	FASMAdd($_MakeSound_FASM, "mov ebx,ecx") ; Pos in ebx schieben
	FASMAdd($_MakeSound_FASM, "mov eax,6") ; in eax 6 für Pi*2 schieben
	FASMAdd($_MakeSound_FASM, "mul ebx") ; eax*ebx | edx wird geleert |  in eax steht das ergebnis

	;eax = Pos*Pi*2

	FASMAdd($_MakeSound_FASM, "mov [ftemp],esi") ;  44100 / Freq in  ftemp schieben
	FASMAdd($_MakeSound_FASM, "fild [ftemp]") ;  44100 / Freq auf den co prozi stack schieben
	FASMAdd($_MakeSound_FASM, "mov [ftemp],eax") ;  Pos*Pi*2  in  ftemp schieben
	FASMAdd($_MakeSound_FASM, "fild [ftemp]") ;  eax auf den co prozi stack schieben
	FASMAdd($_MakeSound_FASM, "fdiv st0,st1") ; st0 / st1
	FASMAdd($_MakeSound_FASM, "fstp st1") ;st1 vom stack schmeißen

	FASMAdd($_MakeSound_FASM, "fsin") ; sinus von st0 ermitteln
	FASMAdd($_MakeSound_FASM, "mov [ftemp],32767") ; 32767  auf den co prozi stack schmeißen
	FASMAdd($_MakeSound_FASM, "fild [ftemp]")
	FASMAdd($_MakeSound_FASM, "fmulp") ; st0 * st1
	FASMAdd($_MakeSound_FASM, "fistp dword[ftemp]") ;ausgeben


	FASMAdd($_MakeSound_FASM, "mov eax, dword[ftemp]") ;das ergebnis der fpu rechnungen in eax schreiben
	FASMAdd($_MakeSound_FASM, "mov word[edi], ax") ; in struct schreiben + nur low und highbyte nehmen

	FASMAdd($_MakeSound_FASM, "add edi,2") ; den pointer 2 stellen nach oben setzen

	FASMAdd($_MakeSound_FASM, "sub ecx,1")
	FASMAdd($_MakeSound_FASM, "cmp ecx,0")
	FASMAdd($_MakeSound_FASM, "jne _schleife")
;~ 	FASMAdd($_MakeSound_FASM,"loop _schleife")

	FASMAdd($_MakeSound_FASM, "ret")

	FASMAdd($_MakeSound_FASM, "ftemp dd 0")
EndFunc   ;==>___MakeSound_AssemblerFunc