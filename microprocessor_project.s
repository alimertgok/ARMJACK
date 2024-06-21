.data
HEXTABLE:
    .word 0b00111111   @ 0
    .word 0b00000110   @ 1
    .word 0b01011011   @ 2
    .word 0b01001111   @ 3
    .word 0b01100110   @ 4
    .word 0b01101101   @ 5
    .word 0b01111101   @ 6
    .word 0b00000111   @ 7
    .word 0b01111111   @ 8
    .word 0b01101111   @ 9
	
HEXWORDS:
	.word 0b00111000 // L word
	.word 0b00111111 // O word
	.word 0b01101101 // S word
	.word 0b01111001 // E word
.text
.global _start
_start:
.equ SEVENT_SEGMENT, 0xFF200020 
.equ TIMER_BASE, 0xFFFEC600
.equ KEY_BASE, 0xFF200050
.equ LED_BASE, 0xFF200000

	LDR R0, =SEVENT_SEGMENT // SEVEN SEGMENT DISPLAY
	LDR R8, =HEXWORDS
	LDR R7, =HEXTABLE

	
	// configure timer
	LDR R1, =TIMER_BASE
	LDR R2, =200000000 // 200 MHz (1 sec)
	STR R2, [R1] // store frequency to load register
	MOV R3, #0b011 // enable auto-restart and enable bits
	STR R3, [R1, #8]
	

	BL RANDOM_NUMBER
	
CHECK_STATUS:
	LDR R4, =CURRENT_SUM
	LDR R4, [R4] // take the current card number
	
	CMP R4, #21 // compare my card number with 21
	BGT LOSE // if your card number is greater than 21, you lose
	
WON:
	PUSH {R1}
	MOV R1, #0
	STR R1, [R0] // clear seven segment
	POP {R1}
	
	BL FLASH_LEDS_AND_DISPLAY // Call the subroutine to flash LEDs and display "21"
	
	
	// LOOP:
		// LDR R6, [R1, #4] // current timer value
		// LDR R2, =100000000 // 200 MHz (0.5 sec)
		// CMP R6, R2
		// BGE IF
		// B ELSE
	
//	IF:
	//	PUSH {R2,R3}
		//MOV R3, #0
		//MOV R2, #0b01011011
		//ORR R3, R3, R2, LSL #8 // number 2 is in hex1

//		MOV R2, #0b00000110
	//	ORR R3, R3, R2 // number 1 is in hex0
		
	//	STR R3, [R0]
		//POP {R2,R3}
		
		//B LOOP
	
	//ELSE:
		//PUSH {R1}
		//MOV R1, #0
		//STR R1, [R0] // clear seven segment
		//POP {R1}
		
		//B LOOP

LOSE:
	PUSH {R1}
	MOV R1, #0
	STR R1, [R0] // clear seven segment
	POP {R1}
	
	MOV R5, #0
	// take L word
	LDR R6, [R8]
	ORR R5, R5, R6, LSL #24 // shift the L word to HEX3
	
	// take O word
	LDR R6, [R8, #4]
	ORR R5, R5, R6, LSL #16 // shift the O word to HEX2
	
	// take S word
	LDR R6, [R8, #8]
	ORR R5, R5, R6, LSL #8 // shift the S word to HEX1
	
	// take E word
	LDR R6, [R8, #12]
	ORR R5, R5, R6 // shift the S word to HEX0
	
	STR R5, [R0]
	
	B END

RANDOM_NUMBER:
	PUSH {R1-R12, LR}
	LDR R2, =CURRENT_SUM
	MOV R3, #0 // to shift the hex
	LDR R4, =KEY_BASE // base address of pushbutton KEY port
	MOV R8, #0 // initialize sum = 0
	MOV R10, #1 // using for ack
	
LOOP_RANDOM:
	LDR R1, =TIMER_BASE
	LDR R5, [R4, #0xC] // read edge capture register
	AND R5, R5, #1 // mask to only consider key 0
	CMP R5, #1
	BNE LOOP_RANDOM
	STREQ R10, [R4, #12] // ack to push button
	//STREQ R10, [R1, #12] // ack to timer
	
	LDREQ R6, [R1, #4] // take the current value of the timer
	AND R6, R6, #11 // masking for generate 0-10
	ADD R6, R6, #1 // numbers between 1-11 now
	
	MOV R12, #0 // increment for taking the second digit
	
	ADD R8, R8, R6 // take that number and update sum
	
	CMP R8, #9 // if your sum > 10
	BLE sub_loop2
	MOV R1, R8 // temp register for sum value
	B sub_loop
	
	sub_loop2:
		MOV R11, R8
		B sub_loop3
		
	sub_loop:
		SUB R11, R1, #10 // sub with 10 to get the first digit
		ADD R12, R12, #1 // second digit
		MOV R1, R11
		CMP R11, #10
		BGE sub_loop
		
	sub_loop3:
		MOV R3, #0
		PUSH {R7}
		LDR R7, =HEXTABLE
		LSL R12, #2
		ADD R12, R12, R7
		LDR R9, [R12, #0] // offset of second digit
		ORR R3, R3, R9, LSL #8
		POP {R7}

		PUSH {R7}
		LDR R7, =HEXTABLE
		LSL R11, #2
		ADD R11, R11, R7
		LDR R9, [R11, #0] // offset of first digit
		ORR R3, R3, R9
		POP {R7}
	
	PUSH {R1}
	MOV R1, #0
	STR R1, [R0] // clear seven segment
	POP {R1}
	
	STR R3, [R0] // display in seven segment
	
	CMP R8, #21
	BLT LOOP_RANDOM
	
	STR R8, [R2] // store the current card
	
	POP {R1-R12, PC}
	
	BX LR
	
FLASH_LEDS_AND_DISPLAY:
	LDR R0, =SEVENT_SEGMENT
	LDR R1, =LED_BASE
	LDR R2, =0x3FF // set all LEDs to on
	MOV R3, #0b00000110 // number 2
	MOV R4, #0b01011011 // number 1
	MOV R5, #0 // initial state
	
	FLASH_DISPLAY_LOOP:
		// Flash LEDs
		STR R2, [R1] // turn LEDs on
		BL DELAY
		MOV R2, #0 // turn LEDs off
		STR R2, [R1]
		
		// Flash seven segment display
		ORR R5, R3, R4, LSL #8 // display 21
		STR R5, [R0]
		BL DELAY
		MOV R5, #0 // clear display
		STR R5, [R0]
		BL DELAY
		
		LDR R2, =0x3FF // set all LEDs to on again
		B FLASH_DISPLAY_LOOP

DELAY:
	PUSH {R0, R1, R2, R3}
	LDR R0, =0x200000 // arbitrary delay value
	DELAY_LOOP:
		SUBS R0, R0, #1
		BNE DELAY_LOOP
	POP {R0, R1, R2, R3}
	BX LR

CURRENT_SUM:
	.word 0x0

END: B END
