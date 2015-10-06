#include-once
#include 'MakeSound.au3'

#cs
	RTTL/Nokring player
		written by Jefrey S. Santos <jefrey[at]jefrey[dot]ml>

		Based on:
			https://en.wikipedia.org/wiki/Ring_Tone_Transfer_Language
			http://www.mobilefish.com/services/midi_maker/midi_maker.php
			http://merwin.bespin.org/t4a/specs/nokia_rtttl.txt
			http://www.phy.mtu.edu/~suits/notefreqs.html
#ce


Global $aWAV

Func _RTTL_Play($sCode)
	_MakeSound_Startup()
	$aWAV = _MakeSound_CreateWAV(@ScriptDir & "\rttl.wav", 100000)

	Local $RTTL_DURATION = 4
	Local $RTTL_OCTAVE = 4
	Local $RTTL_BEAT = 112

	; First split the three parts of the code
	; song name : settings : keys
	$sCode = StringReplace($sCode, " ", "") ; rem. spaces
	$aCode = StringSplit($sCode, ":")

	; Get settings
	$aSettings = StringSplit($aCode[2], ",", 2)
	For $sSetting In $aSettings
		$aSet = StringSplit($sSetting, "=")
		Switch $aSet[1]
			Case 'd'
				$RTTL_DURATION = Int($aSet[2])
			Case 'o'
				$RTTL_OCTAVE = Int($aSet[2])
			Case 'b'
				$RTTL_BEAT = Int($aSet[2])
		EndSwitch
	Next

	; Split all keys
	$aKeys = StringSplit($aCode[3], ",")
	$j = UBound($aKeys)-1
	For $i = 1 To $j
		$sKey = StringLower($aKeys[$i]) ; current key

		; [duration] pitch [octave] [dotted-duration], ...


		; Was duration supplied?
		If Int(StringLeft($sKey, 1)) Then
			$dur = Int($sKey)
			$duration = 1/$dur
			$sKey = StringTrimLeft($sKey, StringLen(String($dur)))
			If Not StringRegExp(String($dur), "^(1|2|4|8|16|32|64|128)$") Then
				$duration = 1/$RTTL_DURATION
			EndIf
		Else
			$duration = 1/$RTTL_DURATION
		EndIf

		; Get pitch
		$pitch = StringRegExp($sKey, "^(a\#|c\#|d\#|f\#|g\#|a|b|c|d|e|f|g|h|p)", 1)[0]
		$sKey = StringTrimLeft($sKey, StringLen($pitch))

		; Was octave supplied?
		If Int($sKey) Then
			$octave = Int($sKey)
			$sKey = StringTrimLeft($sKey, StringLen(String($octave)))
			If $octave > 8 Then $octave = $RTTL_OCTAVE
		Else
			$octave = $RTTL_OCTAVE
		EndIf

		; Was dotted duration supplied?
		If StringInStr($sKey, ".") Then
			$sKey = StringRegExpReplace($sKey, "[^\.]", "")
			$times = StringLen($sKey)
			$original_dur = $duration
			For $tt = 1 To $times
				$t = 2^$tt
				$duration += $original_dur/$t
			Next
		EndIf

		__RTTL_Play($pitch, $octave, $duration, $RTTL_BEAT)
	Next
	_MakeSound_Write($aWAV)
	_MakeSound_Shutdown()
	ShellExecute(@ScriptDir & "\rttl.wav")
EndFunc

Func _RTTL_GetName($sCode)
	Return StringSplit($sCode, ":")[1] <> $sCode ? StringSplit($sCode, ":")[1] : Null
EndFunc

Func _RTTL_IsValid($sCode)
	Return StringRegExp($sCode, '^([a-zA-Z0-9]{1,10})\:(d|o|b)\=([0-9]+)\,(d|o|b)\=([0-9]+)\,(d|o|b)\=([0-9]+)\:([a\#|c\#|d\#|f\#|g\#|a|b|c|d|e|f|g|h|p|,|.|0-9]+)$')
EndFunc

; ########### internal use only ###########

Func __RTTL_Play($sKey, $iOctave, $fDuration, $iBeat)
	; gen array with all support. octaves
	Local $steps[0], $basic_steps = StringSplit("c,c#,d,d#,e,f,f#,g,g#,a,a#,b", ",", 2)
	For $i = 0 To 8
		For $key In $basic_steps
			$ubound = UBound($steps)+1
			ReDim $steps[$ubound]
			$steps[$ubound-1] = $key & $i
		Next
	Next

	; calculate tempo
	$tempo = (60/$iBeat)*4

	$this_dur = $fDuration*$tempo*1000
	;ConsoleWrite($this_dur & " ")

	; calculate frequency
	If $sKey <> 'p' Then
		$j = UBound($steps)-1
		$halfsteps = 0
		For $s = 0 To $j
			If $steps[$s] = $sKey & $iOctave Then
				$halfsteps = $s
			EndIf
		Next
		$halfsteps -= 45 ; "tuning" (45 = a3 index on $steps)
		$freq = 440*(2^(1/12))^$halfsteps
	Else
		$freq = 0
	EndIf

	;~ MsgBox(0, "", "Key: " & $sKey & @CRLF & "Octave: " & $iOctave & @CRLF & "Duration: " & $fDuration & @CRLF & "Beat: " & $iBeat & @CRLF & "Frequency: " & $freq & @CRLF & "Duration: " & $this_dur)

	; plays
	If $sKey = 'p' Then ; pause
		_MakeSound_Sleep($aWAV, $this_dur)
	Else
		_MakeSound_InsertSound($aWAV, $freq, $this_dur)
	EndIf
EndFunc