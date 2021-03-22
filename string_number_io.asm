title String-Number I/O			(Proj6_gallivaj.asm)

; Author: Jack Gallivan
; Last Modified: 3/4/2021
; OSU email address: gallivaj@oregonstate.edu
; Course number/section:		CS271 Section 400
; Project Number: 6					Due Date: 3/14/2021
; Description:
;		(1) Get 10 valid 32-bit signed integers from the user as a string,
;		(2) convert them to their numeric values and store them in an array,
;		(3) calculate the sum and average of the numbers, then
;		(4) convert the numbers to strings and display them to the user.
;		Extra credit 2 does the same, but with REAL4 floats.

include Irvine32.inc

; ---------------------------------------------------------------------------------
; Name: mGetString
;
; Display a prompt, then get the user's keyboard input into a memory location.
;
; Preconditions:
;		prompt: string address
;		inLength: non-negative integer (imm or 32-bit reg/mem)
;
; Receives:
;		prompt (input, reference), outLoc (output, reference),
;		inLength (input, value), bytesRead (output, reference)
;
; Returns:
;		outLocation: string containing the user's input
;		bytesRead: number of bytes read
; ---------------------------------------------------------------------------------
mGetString macro prompt:req, outLocation:req, inLength:req, bytesRead:req
	push		eax
	push		ecx
	push		edx

	mov			edx, prompt
	call		WriteString

	mov			edx, outLocation
	mov			ecx, inLength
	call		ReadString
	mov			bytesRead, eax
	
	pop			edx
	pop			ecx
	pop			eax
endm

; ---------------------------------------------------------------------------------
; Name: mDisplayString
;
; Print the string which is stored in a specified memory location.
;
; Preconditions:
;		inputStr: string address
;
; Receives:
;		inputStr (input, reference)
; ---------------------------------------------------------------------------------
mDisplayString macro inputStr:req
	push		edx

	mov			edx, inputStr
	call		WriteString

	pop			edx
endm

.data
introMsg			byte		09,"String-Number I/O",09,"Author: Jack Gallivan",13,10
							byte		"**EC: Number each line of user input and display a running subtotal of the user's valid numbers.",13,10
							byte		"**EC: Implement procedure ReadFloatVal and WriteFloatVal for floating point numbers.",13,10
							byte		13,10,"Instructions:",13,10
							byte		"    Please enter 10 signed integers in decimal form.",13,10
							byte		"    After you have entered 10 valid integers, they will be displayed, along with their sum and",13,10
							byte		"      their average value, rounded down (floor) to the nearest integer.",13,10
							byte		"Constraints:",13,10
							byte		"    1. Other than digits, you may only enter '+' or '-' prepended to the string.",13,10
							byte		"    2. Each entered integer must be small enough to fit within a 32-bit register.",13,10,13,10,0
promptMsg			byte		"Please enter an integer: ",0
errorMsg			byte		"ERROR: Invalid input. Please try again: ",0
outMsg1				byte		"The following numbers were entered: ",0
outMsg2				byte		"The sum of these numbers is: ",0
outMsg3				byte		"The average of these numbers is: ",0
outroMsg			byte		"Thanks for using this program. Goodbye!",13,10,0

ec2Msg				byte		13,10,"The next section is similar to above, but now floats may be entered and values will be",13,10
							byte		"  stored as single-precision floats.",13,10
							byte		"The results will be calculated similarly to above, but values will be rounded to the",13,10
							byte		"  millionths digit when displayed. Trailing zeros will not be displayed.",13,10
							byte		"Constraints:",13,10
							byte		"    1. Other than digits, you may only enter a single radix point '.', and a '+' or '-' prepended to the string.",13,10
							byte		"    2. The integer and fractional parts of your input should be small enough to fit within an SDWORD when",13,10
							byte		"       extracted as integers.",13,10,13,10,0

userInput			sdword	10 dup(?)
sum						sdword	?
average				sdword	?

userFloat			real4		10 dup(?)
sumFloat			real4		?
averageFloat	real4		?

.code
main proc
	; Display intro message.
	push		offset introMsg
	call		DisplayMessage

	; Get user input.
	push		offset promptMsg
	push		offset errorMsg
	push		offset userInput
	call		ReadVal

	; Calculate/store the sum and average.
	push		offset userInput
	push		offset sum
	push		offset average
	call		Calculate

	; Display output, converting integers to strings.
	push		offset outMsg1
	push		offset outMsg2
	push		offset outMsg3
	push		offset userInput
	push		sum
	push		average
	call		DisplayOutput

; EXTRA CREDIT: Float
	; Display instructions for float section.
	push		offset ec2Msg
	call		DisplayMessage

	; Get user input (floats)
	push		offset promptMsg
	push		offset errorMsg
	push		offset userFloat
	call		ReadFloatVal

	; Calculate and store sum and average (floats).
	push		offset userFloat
	push		offset sumFloat
	push		offset averageFloat
	call		CalculateFloat

	; Display output, converting floats to strings.
	push		offset outMsg1
	push		offset outMsg2
	push		offset outMsg3
	push		offset userFloat
	push		sumFloat
	push		averageFloat
	call		DisplayFloatOutput

; Display outro message.
	push		offset outroMsg
	call		DisplayMessage

	invoke ExitProcess,0	; exit to operating system
main endp

; ---------------------------------------------------------------------------------
; Name: DisplayMessage
;
; Displays a message to the user.
;
; Receives:
;		messageStr (input, reference)
;
; Preconditions:
;		messageStr: references a null-terminated string
;		mDisplayString macro exists
; ---------------------------------------------------------------------------------
DisplayMessage proc
	push		ebp
	mov			ebp, esp

	mDisplayString [ebp+8]				; [ebp+8]: messageStr address
	
	pop			ebp
	ret			4
DisplayMessage endp

; ---------------------------------------------------------------------------------
; Name: ReadVal
;
; 1. Invoke the mGetString macro to get user input in the form of a string.
;	2. Convert the string of ASCII digits to its numeric value representation
;			(SDWORD), validating the user's input is a valid number.
;	3. Store this value in a memory variable.
;
; Receives:
;		promptStr (input, reference), errorStr (input, reference),
;		outputArr (output, reference)
;
; Returns:
;		outputArr: array is filled with integers
;
; Preconditions:
;		promptStr, errorStr: references a null-terminated string
;		outputArr: references an SDWORD array of length 10
;		mGetString macro exists
; ---------------------------------------------------------------------------------
ReadVal proc
	local	inputStr[13]: byte, bytesRead: dword, sign: byte, validNums: dword
; inputStr: 13-byte array stores the user-input string.
; bytesRead: Stores the number of bytes entered by the user.
; sign: Represents whether user entered a positive or negative number.
; validNums: The number of valid numbers entered by the user.
	push		eax
	push		ebx
	push		ecx
	push		edx
	push		edi
	push		esi

; Initialize validNums
	mov			validNums, 0

; Copy outputArr address to EDI to use string primitives.
	mov			edi, [ebp+8]					; [ebp+8]: outputArr address

; Outer loop: Get 10 valid integers entered by the user.
	mov			ecx, 10								; Initialize loop counter to 10
_GetUserInput:
	push		ecx										; Save outer loop counter.

	; Change display message to promptStr.
	mov			edx, [ebp+16]					; [ebp+16]: promptStr address
	jmp			_Continue
	
	_InvalidInput:
	; User input was invalid. Change display message to errorStr.
	mov			edx, [ebp+12]					; [ebp+12]: errorStr address

	_Continue:
	; Point ESI to first byte of inputStr.
	lea			esi, inputStr

	; Display the number of valid numbers entered so far.
	push		validNums
	call		WriteVal
	mov			al, '/'
	call		WriteChar
	mov			al, '1'
	call		WriteChar
	mov			al, '0'
	call		WriteChar
	mov			al, ' '
	call		WriteChar

	; Get user input. User input stored in inputStr (esi), bytes read stored in bytesRead.
	mGetString edx, esi, sizeof inputStr, bytesRead

	; Initial validation of user input checks bytesRead.
	;		If NOT (0 < bytesRead <= 11): Input invalid.
	cmp			bytesRead, 0
	je			_InvalidInput
	cmp			bytesRead, 11
	ja			_InvalidInput
	
	; Initialize inner loop counter to bytesRead, and EBX to 0.
	mov			ecx, bytesRead
	xor			ebx, ebx							; EBX: Stores the integer as its being converted from a string.

	; Check first byte of inputStr for a '+' or '-' symbol:
	mov			sign, 0								; Initialize sign to 0 (non-negative).
	cmp			byte ptr [esi], 43		; ASCII 43d: '+' symbol
	je			_Positive
	cmp			byte ptr [esi], 45		; ASCII 45d: '-' symbol
	je			_Negative
	jmp			_ConvertStrToInt			; First char is neither '+' nor '-'.

	_Negative:
	; First char is '-'. Set sign to 1 (negative).
	mov			sign, 1
	_Positive:
	; If first char is '+', sign already set to 0. Decrement counter and increment ESI.
	dec			ecx
	add			esi, 1
	
	_ConvertStrToInt:
		; Inner loop: Iterate over user-entered string and convert chars to digits.
		;		Jump to _InvalidInput if invalid input detected.
		cld
		lodsb													; Copy value in [esi] to al, then increment esi

		; If not (48 <= char <= 57): Invalid input. ASCII char not a number.
		cmp			al, 48
		jb			_InvalidInput
		cmp			al, 57
		ja			_InvalidInput
		
		; Convert ASCII char to decimal digit.
		sub			al, 48

		; Append the digit to EBX. (EBX = EBX * 10 + digit)
		;		If OF = 1 after arithmetic operations: Invalid input (Entered number is too large for SDWORD).
		imul		ebx, 10
		jo			_InvalidInput
		movzx		eax, al								; Zero-extend AL into EAX for 32-bit addition.
		add			ebx, eax
		jo			_InvalidInput
		loop		_ConvertStrToInt

	; If sign != 0: negate EBX (convert to negative integer).
	cmp			sign, 0
	je			_StoreVal
	neg			ebx

	_StoreVal:
	; Copy the converted number to outputArr.
	mov			eax, ebx
	cld
	stosd													; Copy value in EAX to outputArr ([EDI]), then increment EDI
	inc			validNums							; Valid numbers entered += 1

	; Restore outer loop counter and continue.
	pop			ecx
	dec			ecx
	jnz			_GetUserInput
	
	pop			esi
	pop			edi
	pop			edx
	pop			ecx
	pop			ebx
	pop			eax
	ret			12
ReadVal endp

; ---------------------------------------------------------------------------------
; Name: Calculate
;
; Calculates the sum and average of a given array of integers.
;
; Receives:
;		inputArr (input, reference), sumVar (output, reference),
;		averageVar (output, reference)
;
; Returns:
;		sumVar: contains the sum of inputArr values
;		averageVar: contains the average value of inputArr values (floor)
;
; Preconditions:
;		inputArr: references an SDWORD array of length 10 filled with integers
;		sumVar, averageVar: references an SDWORD
; ---------------------------------------------------------------------------------
Calculate proc
	local	ten: dword
; ten: Contains the decimal value 10.
	push		eax
	push		ebx
	push		ecx
	push		edx										; EDX used in CDQ, IDIV instructions
	push		esi

	mov			ten, 10								; Initialize ten to 10d.

; Copy inputArr address to ESI to use string primitives, and sumVar address to EBX for storage.
	mov			esi, [ebp+16]					; [ebp+16]: inputArr address
	mov			ebx, [ebp+12]					; [ebp+12]: sumVar address

; Sum the 10 integers stored in inputArr.
	mov			ecx, 10								; Set loop counter to 10
_Sum:
	; Copy inputArr value in [ESI] to EAX, then increment ESI.
	cld
	lodsd

	; Add copied value to sumVar
	add			[ebx], eax						; [ebx]: sumVar value
	loop		_Sum

; Copy sumVar value to EAX for division and averageVar address to EBX for storage.
	mov			eax, [ebx]
	mov			ebx, [ebp+8]					; [ebp+8]: averageVar address

; Divide sumVar by 10 and store the quotient in averageVar.
	cdq
	idiv		ten										; averageVar = sumVar / 10
	mov			[ebx], eax						; [ebx]: averageVar value
	
	pop			esi
	pop			edx
	pop			ecx
	pop			ebx
	pop			eax
	ret			12
Calculate endp

; ---------------------------------------------------------------------------------
; Name: DisplayOutput
;
; Displays the values of an array of integers, and their sum and average.
;
; Receives:
;		outMsg1 (input, reference), outMsg2 (input, reference), outMsg3 (input, reference)
;		inputArr (input, reference), sum (input, value), average (input, value)
;
; Preconditions:
;		outMsg1, outMsg2, outMsg3: references a null-terminated string
;		inputArr: references an SDWORD array of length 10 filled with integers
;		sum, average: an SDWORD integer value
;		mDisplayString macro exists
;		WriteVal procedure exists
; ---------------------------------------------------------------------------------
DisplayOutput proc
	push		ebp
	mov			ebp, esp
	push		eax
	push		ecx
	push		esi

; Copy inputArr address to ESI to use string primitives.
	mov			esi, [ebp+16]					; [ebp+16]: inputArr address

; 1A. Display first message: "The following numbers were entered: "
	call		CrLf
	mDisplayString [ebp+28]				; [ebp+28]: outMsg1 address

; 1B. Display the 10 user-entered numbers.
	mov			ecx, 10								; Set loop counter to 10.
_DisplayUserNums:
	; Copy inputArr value in [ESI] to EAX, then increment ESI.
	cld
	lodsd
	push		eax
	call		WriteVal

	; Separate list by ', ', unless last char was displayed.
	cmp			ecx, 1
	je			_NoSeparator
	mov			al, ','
	call		Writechar
	mov			al, ' '
	call		Writechar
	_NoSeparator:
	loop		_DisplayUserNums

; 2A. Display second message: "The sum of these numbers is: "
	call		CrLf
	mDisplayString [ebp+24]				; [ebp+24]: outMsg2 address

; 2B. Display sum
	push		[ebp+12]							; [ebp+12]: value of sum
	call		WriteVal

; 3A. Display third message: "The average of these numbers is: "
	call		CrLf
	mDisplayString [ebp+20]				; [ebp+20]: outMsg3 address

; 3B. Display average
	push		[ebp+8]								; [ebp+8]: value of average
	call		WriteVal
	call		CrLf
	call		CrLf

	pop			esi
	pop			ecx
	pop			eax
	pop			ebp
	ret			24
DisplayOutput endp

; ---------------------------------------------------------------------------------
; Name: WriteVal
;
; 1. Convert a numeric SDWORD value to a string of ASCII chars.
;	2. Invoke the mDisplayString macro to print the ASCII representation of the
;			SDWORD value to the output.
;
; Receives:
;		inputNum (input, value)
;
; Preconditions:
;		inputNum: an SDWORD integer value
;		mDisplayString macro exists
; ---------------------------------------------------------------------------------
WriteVal proc
	local	outputStr[13]: byte, sign: byte, ten:dword
; outputStr: Stores the input integer as a string after integer:string conversion.
; sign: Represents whether inputNum is a positive or negative number.
; ten: Contains the decimal value 10.
	push		eax
	push		edx
	push		edi
	push		esi

; Initialize locals
	mov			ten, 10								; Initialize ten to 10d.
	mov			sign, 0								; Initialize sign to 0 for a positive number.
	lea			edi, outputStr
	add			edi, 12								; Set EDI to last byte of outputStr

	; Store a null character at the end of outputStr then decrement EDI.
	mov			al, 0
	std
	stosb

; Copy inputNum ([ebp+8]) into EAX then check its sign
	mov			eax, [ebp+8]
	cmp			eax, 0
	jns			_ConvertIntToStr			; inputNum non-negative
	mov			sign, 1								; inputNum negative. Set sign to 1.
	neg			eax										; Negate to get a positive integer.

; Repeatedly divide inputNum by 10 to get digits as remainder, then convert remainder
;		digit to ASCII and store it in outputStr. Do this until quotient = 0.
_ConvertIntToStr:
	; Divide inputNum (EAX) by 10 to get last digit as remainder.
	xor			edx, edx
	div			ten

	; Copy remainder to AL, convert to ASCII char, then store in outputStr.
	push		eax										; Save quotient.
	mov			al, dl
	add			al, 48
	std
	stosb
	pop			eax										; Restore quotient.

	; If quotient = 0: we're done.
	cmp			eax, 0
	jz			_ConvertDone
	jmp			_ConvertIntToStr

_ConvertDone:
	; Check sign and prepend '-' if sign != 0.
	cmp			sign, 0
	je			_DisplayVal
	mov			al, '-'
	std
	stosb

_DisplayVal:
	; Point ESI to the first valid char of outputStr (last char written), then display the string.
	mov			esi, edi
	inc			esi
	mDisplayString esi

	pop			esi
	pop			edi
	pop			edx
	pop			eax
	ret			4
WriteVal endp

; ---------------------------------------------------------------------------------
; Name: ReadFloatVal
;
; ReadVal but for floats.
;		1. Invoke the mGetString macro to get user input in the form of a string.
;		2. Convert the string of ASCII digits to its numeric value representation
;				(REAL4), validating the user's input is a valid float.
;		3. Store this value in a memory variable.
;
; Receives:
;		promptStr (input, reference), errorStr (input, reference),
;		outputArr (output, reference)
;
; Returns:
;		outputArr: array is filled with floats
;
; Preconditions:
;		promptStr, errorStr: references a null-terminated string
;		outputArr: references a REAL4 array of length 10
;		mGetString macro exists
; ---------------------------------------------------------------------------------
ReadFloatVal proc
	local	inputStr[24]: byte, bytesRead: dword, sign: byte, validNums: dword, floatDWord: dword, tens: dword
; inputStr: 20-byte array stores the user-input string.
; bytesRead: Stores the number of bytes entered by the user.
; sign: Represents whether user entered a positive or negative number.
; validNums: The number of valid numbers entered by the user.
; floatDWord: Used to transfer data to/from the FPU stack.
; tens: stores a 10 power integer (10, 100, 1000, etc.)
	push		eax
	push		ecx
	push		edx
	push		edi
	push		esi

; Initialize validNums
	mov			validNums, 0

; Copy outputArr address to EDI to use string primitives.
	mov			edi, [ebp+8]					; [ebp+8]: outputArr address

; Outer loop: Get 10 valid integers entered by the user.
	mov			ecx, 10								; Initialize loop counter to 10
_GetInput:
	push		ecx										; Save outer loop counter.

	; Change display message to promptStr.
	mov			edx, [ebp+16]					; [ebp+16]: promptStr address
	jmp			_ContinueGetInput
	
	_InvalidInput:
	; User input was invalid. Change display message to errorStr.
	mov			edx, [ebp+12]					; [ebp+12]: errorStr address

	_ContinueGetInput:
	; Point ESI to first byte of inputStr.
	lea			esi, inputStr

	; Display the number of valid numbers entered so far.
	push		validNums
	call		WriteVal
	mov			al, '/'
	call		WriteChar
	mov			al, '1'
	call		WriteChar
	mov			al, '0'
	call		WriteChar
	mov			al, ' '
	call		WriteChar

	; Get user input. User input stored in inputStr (esi), bytes read stored in bytesRead.
	mGetString edx, esi, sizeof inputStr, bytesRead

	; Initial validation of user input checks bytesRead.
	;		If NOT (0 < bytesRead <= 150): Input invalid.
	cmp			bytesRead, 0
	je			_InvalidInput
	cmp			bytesRead, 22
	ja			_InvalidInput
	
	; initialize FPU, inner loop counter, and tens, and push 0 to the FPU stack.
	finit
	mov			ecx, bytesRead
	mov			tens, 10
	mov			floatDWord, 0
	fild		floatDWord

	; Check first byte of inputStr for a '+' or '-' symbol:
	mov			sign, 0								; Initialize sign to 0 (non-negative).
	cmp			byte ptr [esi], 43		; ASCII 43d: '+' symbol
	je			_Positive
	cmp			byte ptr [esi], 45		; ASCII 45d: '-' symbol
	je			_Negative
	jmp			_ConvertIntegers			; First char is neither '+' nor '-'.

	_Negative:
	; First char is '-'. Set sign to 1 (negative).
	mov			sign, 1
	_Positive:
	; If first char is '+', sign already set to 0. Decrement counter and increment ESI.
	dec			ecx
	add			esi, 1
	
	_ConvertIntegers:
		; Inner loop: Iterate over user-entered string and convert chars to digits.
		;		Jump to _InvalidInput if invalid input detected.
		cld
		lodsb													; Copy value in [esi] to al, then increment esi

		; Check for radix point. If the radix point is found, decrement ecx and
		;		jump to the next loop, which handles fractions (_ConvertFractions).
		cmp			al, 46
		jne			_ContinueConvertIntegers
		dec			ecx
		cmp			ecx, 0
		jz			_ChangeSign
		jmp			_ConvertFractions

		_ContinueConvertIntegers:

		; If not (48 <= char <= 57): Invalid input. ASCII char not a number.
		cmp			al, 48
		jb		_InvalidInput
		cmp			al, 57
		ja		_InvalidInput
		
		; Convert ASCII char to decimal digit, then store in floatDWord.
		sub			al, 48
		movzx		eax, al								; Zero-extend AL into EAX.
		mov			floatDWord, eax

		; Append the digit to the number in the FPU stack.
		fimul		tens									; ST(0) = ST(0) * 10
		fiadd		floatDWord						; ST(0) = ST(0) + floatDWord (digit)
		loop		_ConvertIntegers

		jmp			_ChangeSign

	_ConvertFractions:
		; Convert chars to the right of the radix point to fractions.
		cld
		lodsb

		; If not (48 <= char <= 57): Invalid input. ASCII char not a number.
		cmp			al, 48
		jb			_InvalidInput
		cmp			al, 57
		ja			_InvalidInput

		; Convert ASCII char to decimal digit and store in floatDWord.
		sub			al, 48
		movzx		eax, al								; Zero-extend AL into EAX.
		mov			floatDWord, eax

		; Convert the digit to a fraction and add it to the float stored on the FPU stack.
		fild		floatDWord						; ST(0) = floatDWord
		fidiv		tens									; ST(0) = ST(0) / tens
		fadd													; ST(1) = ST(0) + ST(1) -> pop ST(0) (ST(0) <- ST(1))
		mov			eax, tens
		imul		eax, 10								; Increase tens by 1 power for next fractional digit.
		mov			tens, eax							; tens = 10^n, where n is the # of digits to the right of the radix point.
		loop		_ConvertFractions

	_ChangeSign:
	; If sign != 0: change sign of ST(0) (convert to negative).
	cmp			sign, 0
	je			_Validate
	fchs

	_Validate:
	; Check status word of FPU. If either underflow (bit 4) or overflow (bit 3) flags are set, user input was invalid.
	fstsw		ax										; Store status word in AX
	fwait
	test		ax, 16+8							; Test bits 3 (8d) and 4 (16d)
	jnz			_InvalidInput

	; Pop the converted number from the FPU stack, then copy to EAX, and store in outputArr.
	fstp		floatDWord
	mov			eax, floatDWord
	cld
	stosd													; Copy value in EAX to outputArr ([EDI]), then increment EDI
	inc			validNums							; Valid numbers entered += 1

	; Restore outer loop counter and continue.
	pop			ecx
	dec			ecx
	jnz			_GetInput
	
	pop			esi
	pop			edi
	pop			edx
	pop			ecx
	pop			eax
	ret			12
ReadFloatVal endp

; ---------------------------------------------------------------------------------
; Name: CalculateFloat
;
; Calculates the sum and average of a given array of floats.
;
; Receives:
;		inputArr (input, reference), sumVar (output, reference),
;		averageVar (output, reference)
;
; Returns:
;		sumVar: contains the sum of inputArr values
;		averageVar: contains the average value of inputArr values
;
; Preconditions:
;		inputArr: references a REAL4 array of length 10 filled with floats.
;		sumVar, averageVar: references a REAL4
; ---------------------------------------------------------------------------------
CalculateFloat proc
	local	ten: dword, floatNum: real4
; ten: Contains the decimal value 10.
; floatNum: Used to transfer data to/from the FPU stack.
	push		eax
	push		ebx
	push		ecx
	push		esi

	mov			ten, 10								; Initialize ten to 10d.

; Copy inputArr address to ESI to use string primitives, and sumVar address to EBX for output.
	mov			esi, [ebp+16]					; [ebp+16]: inputArr address
	mov			ebx, [ebp+12]					; [ebp+12]: sumVar address

; Initialize FPU and load the first value from inputArr onto the FPU stack.
	finit
	cld
	lodsd
	mov			floatNum, eax
	fld			floatNum

; Sum the 10 integers stored in inputArr.
	mov			ecx, 9								; Set counter to 9
_Sum:
	; Copy inputArr value in [ESI] to EAX, then increment ESI.
	cld
	lodsd

	; Copy inputArr value to floatNum and add it to ST(0) on the FPU stack.
	mov			floatNum, eax
	fadd		floatNum
	loop		_Sum

; Copy the sum from ST(0) to sumVar ([ebx]).
	fst			real4 ptr [ebx]

; Copy averageVar address to EBX for output.
	mov			ebx, [ebp+8]					; [ebp+8]: averageVar address

; Divide the sum in ST(0) by 10, then store the value in averageVar ([ebx]).
	fidiv		ten
	fstp		real4 ptr [ebx]
	
	pop			esi
	pop			ecx
	pop			ebx
	pop			eax
	ret			12
CalculateFloat endp

; ---------------------------------------------------------------------------------
; Name: DisplayFloatOutput
;
; DisplayOutput but for floats.
;		Displays the values of an array of floats, and their sum and average.
;
; Receives:
;		outMsg1 (input, reference), outMsg2 (input, reference), outMsg3 (input, reference)
;		inputArr (input, reference), sum (input, value), average (input, value)
;
; Preconditions:
;		outMsg1, outMsg2, outMsg3: references a null-terminated string
;		inputArr: references a REAL4 array of length 10 filled with floats
;		sum, average: a REAL4 float value
;		mDisplayString macro exists
;		WriteFloatVal procedure exists
; ---------------------------------------------------------------------------------
DisplayFloatOutput proc
	push		ebp
	mov			ebp, esp
	push		eax
	push		ecx
	push		esi

; Copy inputArr address to ESI to use string primitives.
	mov			esi, [ebp+16]					; [ebp+16]: inputArr address

; 1A. Display first message: "The following numbers were entered: "
	call		CrLf
	mDisplayString [ebp+28]				; [ebp+28]: outMsg1 address

; 1B. Display the 10 user-entered numbers.
	mov			ecx, 10								; Set loop counter to 10.
_DisplayUserNums:
	; Copy inputArr value in [ESI] to EAX, then increment ESI.
	cld
	lodsd
	push		eax
	call		WriteFloatVal

	; Separate list by ', ', unless last char was displayed.
	cmp			ecx, 1
	je			_NoSeparator
	mov			al, ','
	call		Writechar
	mov			al, ' '
	call		Writechar
	_NoSeparator:
	loop		_DisplayUserNums

; 2A. Display second message: "The sum of these numbers is: "
	call		CrLf
	mDisplayString [ebp+24]				; [ebp+24]: outMsg2 address

; 2B. Display sum
	push		[ebp+12]							; [ebp+12]: value of sum
	call		WriteFloatVal

; 3A. Display third message: "The average of these numbers is: "
	call		CrLf
	mDisplayString [ebp+20]				; [ebp+20]: outMsg3 address

; 3B. Display average
	push		[ebp+8]								; [ebp+8]: value of average
	call		WriteFloatVal
	call		CrLf
	call		CrLf
	
	pop			esi
	pop			ecx
	pop			eax
	pop			ebp
	ret			24
DisplayFloatOutput endp

; ---------------------------------------------------------------------------------
; Name: WriteFloatVal
;
; WriteVal but for floats.
;		1. Convert a numeric REAL4 value to a string of ASCII chars. The float will
; 			be rounded to the millionths place.
;		2. Invoke the mDisplayString macro to print the ASCII representation of the
; 			REAL4 value to the output.
;
; Receives:
;		inputNum (input, value)
;
; Preconditions:
;		inputNum: a REAL4 float value
;		mDisplayString macro exists
; ---------------------------------------------------------------------------------
WriteFloatVal proc
	local	outputStr[24]: byte, sign: byte, tens:dword, oldCW: word, floatPart: dword
; outputStr: Used to store inputNum as a string after conversion to ASCII.
; sign: Used to store inputNum's sign (set to 0: positive or 1: negative).
; tens: Set to a power of 10 (10, 10^6, etc.), used for multiplication and division.
; oldCW: Used to store the FPU's Control Word register.
; floatPart: Used to hold the integer or fractional part of the float as an integer.
	push		eax
	push		ecx
	push		edx
	push		edi
	push		esi

; Initialize FPU and load inputNum ([ebp+8]) into the FPU stack.
	finit
	fld			real4 ptr [ebp+8]

; Copy inputNum ([ebp+8]) into EAX to check its sign (msb).
	mov			sign, 0								; Initialize sign to 0 (positive).
	cmp			dword ptr [ebp+8], 0	; Msb of floats holds the sign, same as integers.
	jns			_Positive
	mov			sign, 1								; Set sign to 1 (negative).
	fchs													; Change float to positive.

_Positive:

; Extract the integer part of the float.
	;	Change RC field (bits 10-11) of the FPU's Control Word to truncate values.
	fstcw		oldCW									; Store FPU's current Control Word.
	fwait
	mov			ax, oldCW
	or			ax, 0C00h							; Set RC field to 11b (truncate) without affecting other fields.
	push		ax
	fldcw		word ptr [esp]				; Load the modified Control Word.
	pop			ax
	
	; Copy the integer part of the float ST(0) to memory (truncated), then subtract it from ST(0).
	fist		floatPart							; Integer part stored.
	fisub		floatPart							; ST(0) now only contains the fraction part.
	push		floatPart							; Store the integer part.

; Extract the first 6 fractional digits from the float as a 6-digit integer.
	; Restore the oldCW to set RC field to round (00b).
	fldcw		oldCW

	; Convert the first 6 fractional digits to an integer by multiplying ST(0) by 10^6
	mov			tens, 1000000
	fimul		tens
	fist		floatPart							; Store the 6-digit integer, rounded.

; Initialize EDI to outputStr's last byte and write a null character.
	lea			edi, outputStr
	add			edi, 23								; Set EDI to last byte of outputStr
	mov			al, 0									; ASCII 0 = null
	std														; Direction flag set: primitives decrement EDI.
	stosb
	mov			tens, 10							; tens = 10 for integer division.

; Convert digits of fractional part of float to ASCII.
	; If (floatPart = 0): Skip to integer part.
	mov			eax, floatPart
	cmp			eax, 0
	jnz			_SetupConvertFrac
	jmp			_WriteIntDigits

_SetupConvertFrac:
	; Initialize ECX (loop counter) and push 0 to stack.
	mov			ecx, 6
	push		0											; Track number of digits written to avoid writing trailing zeros.

; Get each digit and write to outputStr, right to left. Don't write trailing zeros.
_ConvertFracToStr:
	; Divide floatPart (EAX) by 10 to get the last digit as remainder.
	xor			edx, edx
	div			tens

	; If (no digits written AND remainder = 0): Don't write trailing zero.
	cmp			dword ptr [esp], 0
	jnz			_WriteFrac						; A digit has been written already. Must write.
	cmp			edx, 0
	jz			_SkipWrite						; No digits have been written and remainder = 0.


	_WriteFrac:
	; Copy remainder to AL, convert to ASCII char, then store in outputStr.
	push		eax										; Save quotient.
	mov			al, dl
	add			al, 48
	std
	stosb
	pop			eax										; Restore quotient.
	inc			dword ptr [esp]				; Increment digits written.

	_SkipWrite:
	loop		_ConvertFracToStr
	
	; Restore esp without pop.
	add			esp, 4

; Write the radix point to outputStr.
	mov			al, '.'
	std
	stosb

_WriteIntDigits:
; Convert digits of integer part of float to ASCII.
	pop			floatPart							; Restore the integer part.
	mov			eax, floatPart

; Get each digit and write to outputStr, right to left.
_ConvertIntToStr:

	; Divide floatPart (EAX) by 10 to get the last digit as remainder.
	xor			edx, edx
	div			tens

	; Copy remainder to AL, convert to ASCII char, then store in outputStr.
	push		eax										; Save quotient.
	mov			al, dl
	add			al, 48
	std
	stosb
	pop			eax										; Restore quotient.

	; If quotient = 0: we're done.
	cmp			eax, 0
	jz			_ConvertDone
	jmp			_ConvertIntToStr

_ConvertDone:
	; Check sign and prepend '-' if sign != 0.
	cmp			sign, 0
	je			_DisplayVal
	mov			al, '-'
	std
	stosb

_DisplayVal:
	; Point ESI to the first valid char of outputStr (last char written), then display the string.
	mov			esi, edi
	inc			esi
	mDisplayString esi

	pop			esi
	pop			edi
	pop			edx
	pop			ecx
	pop			eax
	ret			4
WriteFloatVal endp

end main
