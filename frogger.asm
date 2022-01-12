#####################################################################
#
# CSC258H5S Fall 2021 Assembly Final Project
# University of Toronto, St. George
#
# Student: Name, Student Number 
#  - Zeyang Ni, 1006883696
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 5 
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. Display the number of lives remaining.
# 2. Dynamic increase in difficulty as game progresses
# 3. Have objects in different rows move at different speeds
# 4. Make a second level that starts after the player completes first level
# 5. Have some of the floating objects sink and reappear
#
# Any additional information that the TA needs to know:
# - Press r to start the game if the game is in stating phase
# - You need to press r again when the game was reset (died 3 times)
#
#####################################################################
.data 
	displayAddress: .word 0x10008000
	
	safeZoneStatus: .word 1
	winStatus: .word 0
	gameStatus: .word 0
	lifeCount: .word 3
	hittingStatus: .word 0
	healthColor: .word 0xff0000
	
	level: .word 0
	time: .word 0
	score: .word 0
	
	frogPixel: .word 0, 12, 128, 132, 136, 140, 260, 264, 384, 388, 392, 396
	frogCoor: .word 15, 28
	frogSize: .word 4, 4
	frogSpeed: .word 0
	frogColor: .word 0x009900
	
	logColor: .word 0x663300
	positiveLogSpeed: .word 2
	negativeLogSpeed: .word -1
	logSize: .word 8, 4
	positiveLogCoordinates: .word 4, 8, 20, 8 # Higer WaterZone
	negativeLogCoordinates: .word 8, 12, 28, 12 # Lower Water Zone
	sinkTime: .word 2
	sinkCount: .word 0
	isSink: .word 0

	carColor: .word 0xffff00
	slowCarSpeed: .word 1
	quickCarSpeed: .word -2
	carSize: .word 6, 4
	slowCarCoordinates: .word 0, 20, 15, 20
	quickCarCoordinates: .word 5, 24, 20, 24
	
	iterate: .word 0
	invariant: .word 15
	temp: .space 20 # Used as temporary array
	
	canvas: .space 1536
	
	
.text 
	
main:
	
	# Reset the game including data
	jal resetData
	
	resetFrogCoor: # Reset the coordinate of frog
	la $t1, frogCoor
	li $t2, 15
	sw $t2, 0($t1) 
	li $t2, 28
	sw $t2, 4($t1) 
	# End of the resetting
	
	# Init
	Init:
	jal drawBg
	jal drawObjs
	jal drawFrog
	jal drawCanvas
	# End of Init
	
	startMainLoop:
	
	bgt $zero, $zero, Exit
	jal reactKey # Check the key events
	
	# check collision and wining status
	jal collisionDetect
	
	# Check win status
	lw $t1, winStatus
	beq $t1, $zero, skip
	jal incrementSpeed
	jal nextLevelCheck
	la $t1, winStatus
	sw $zero, 0($t1)
	lw $t1, score # add 1 to score
	addi $t1, $t1, 1
	la $t2, score
	sw $t1, ($t2) 
	
	
	# Pain the zone as fullfilled
	li $t1, 0
	li $t2, 8
	innerRegionLoop:
	li $t3, 32
	la $t4, frogCoor
	lw $t4, ($t4) # store frog x coor into t4
	mul $t5, $t1, $t2 # t5 for left bound
	addi $t6, $t1, 1
	mul $t6, $t6, $t2 # t6 for right bound
	blt $t4, $t5, skipDrawCRegion
	# shen frog x greater than left bound 
	bge $t4, $t6, skipDrawCRegion
	
	# In the region, draw rectngle
	la $t1, endCheckingWin 
	add $s3, $t1, $zero # s3 for return address
	la $t1, canvas
	add $s1, $t1, $zero # s1 for canvas
	la $t4, frogCoor
	addi $t0, $t5, 0,  # t0 for x coor
	lw $t1, 4($t4) # t1 for y coor
	addi $t2, $zero, 8 # t2 for width
	addi $t3, $zero, 4 # t3 for height
	lw $t9, frogColor # t9 for color

	j drawRectangle
	
	skipDrawCRegion:
	addi $t1, $t1, 1
	j innerRegionLoop
	
	# End painting
	
	endCheckingWin:
	j resetFrogCoor
	skip:
	# End of checking sin status
	
	# reset the frog position if it is hit or drown
	lw $t1 hittingStatus
	beq $t1, $zero, noHitting
	la $t3, hittingStatus
	sw $zero, 0($t3) # Reset the hitting status
	# Action when frog hit something
	lw $t1, lifeCount
	addi $t1, $t1, -1 # Subtract 1 from the total life count
	la $t2 lifeCount
	sw $t1, ($t2)
	beq $t1, $zero, main
	j resetFrogCoor
	
	noHitting: # Frog does not hit anything
	
	# Check if the frog is on log and react accordingly
	jal frogOnLog
	
	lw $t1, gameStatus # is the game status is 0, freeze the canvas
	beq $t1, $zero, sleep
	
	lw $t1, iterate # Decide how fast shoud the objects be moved
	lw $t2, invariant
	bge $t1, $t2, moveBranch
	addi $t1, $t1, 1
	la $t2, iterate
	sw $t1, 0($t2)
	j current4
	
	moveBranch:
	la $t1, iterate
	sw $zero, 0($t1)
	jal sinkLog
	jal moveObjsCoor
	current4: # End of the moveing process
	
	jal drawBg
	jal drawObjs
	jal drawFrog
	jal drawCanvas
	
	sleep:
	li $v0, 32
	li $a0, 17
	syscall
	
	j startMainLoop
	
Exit:
	
	li $v0, 10 # terminate the program gracefully

	syscall
	
	
frogOnLog:
	# Check is the frog is on log, if it is, then make the frog move with the log
	la $t0, frogCoor # to store the address of frog coordinate
	lw $t0, 4($t0) # t1 to store the y coordinate of frog
	li $t1, 8 
	blt $t0, $t1, noFrogOnLog1 #
	li $t1, 12
	bge $t0, $t1, noFrogOnLog1 #
	
	# Action when on positive logs
	lw $t1, positiveLogSpeed
	la $t2, frogSpeed
	sw $t1, 0($t2) # Assign frog a speed
	j frogOnLogEnd
	
	noFrogOnLog1:
	
	li $t1, 12
	blt $t0, $t1, noFrogOnLog2 #
	li $t1, 16
	bge $t0, $t1, noFrogOnLog2 #
	
	# Action when on negative logs
	lw $t1, negativeLogSpeed
	la $t2, frogSpeed
	sw $t1, 0($t2)
	j frogOnLogEnd
	
	noFrogOnLog2: # Reset the frog speed to 0 if it is not on log
	la $t1, frogSpeed
	sw $zero, 0($t1)
	
	frogOnLogEnd:
	
	jr $ra
	
	
	
collisionDetect: # input stack: coor1, coor2, size1, size2
		 # return flag, 1 for collision in car zone and drown in water zone
		 # t9 as temporary register
		la $t0, frogCoor # to store the address of frog coordinate
		lw $t1, 4($t0) # t1 to store the y coordinate of frog
		lw $t0, 0($t0) # t0 to store the x coordinate, override the previous value
	 	
	 	# First if the frog is in Car Zone
	 	li $t9, 20 # The beginning row of Car Zone
	 	blt $t1, $t9, aboveCarZone # frog is above the car Zone
	 	li $t9, 28  # the endingt row of car zone
	 	bge $t1, $t9, belowCarZone # frog is below the car Zone
	 	
	 	# At this point, frog is in the car Zone
	 	li $t9, 24
	 	bge $t1, $t9, quickCarDetect 
	 	
	 	# Action if in slow car Zone, checked
	 	la $t9, slowCarDetectEnd # push the parameters into the stack
	 	addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	la $t9, slowCarCoordinates
	 	addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	la $t9, carSize
	 	addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	j objCollisionWithFrog
	 	slowCarDetectEnd:
	 	lw $t9, 0($sp) # Store the hitting status into the t9 regiter
	 	addi $sp, $sp, 4
	 	la $t5, hittingStatus # Store the address of hitting Status into t5
	 	sw $t9, 0($t5)
	 	
	 	j finishDetect
	 	
	 	# Action in quick car Zone
	 	quickCarDetect:
	 	
	 	# Checked
	 	la $t9, quickCarDetectEnd # push the parameters into the stack
	 	addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	la $t9, quickCarCoordinates
	 	addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	la $t9, carSize
	 	addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	j objCollisionWithFrog
	 	quickCarDetectEnd:
	 	lw $t9, 0($sp) # Store the hitting status into the t9 regiter
	 	addi $sp, $sp, 4
	 	la $t5, hittingStatus # Store the address of hitting Status into t5
	 	sw $t9, 0($t5)
	 	j finishDetect
	 	
	 	aboveCarZone:
	 	li $t9, 8 # t9 store the starting y coordinate of waterZone
	 	blt $t1, $t9, safeZoneAction
	 	
	 	# Action when in mid Zone
	 	li $t9, 16
	 	beq $t1, $t9, finishDetect
	 	li $t9, 12
	 	beq $t1, $t9, negativeWaterDetect
	 	
	 	# Action in positiveWater Zone
		# Checked
	 	la $t9, positiveWaterDetectEnd # push the parameters into the stack
	 	addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	addi $sp, $sp, -4
	 	la $t8, positiveLogCoordinates
	 	sw $t8, 0($sp) # store the address of x, y coordinate into stack
	 	
	 	
	 	la $t9, logSize
	 	
		# Store the address of log width into stack
		addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	j objCollisionWithFrog
	 	positiveWaterDetectEnd:

	 	lw $t9, 0($sp) # Store the hitting status into the t9 regiter
	 	addi $sp, $sp, 4
	 	li $t8, 1
		sub $t9, $t8, $t9 # Store the opposite vaoue into the game status
	 	la $t5, hittingStatus # Store the address of hitting Status into t5
	 	sw $t9, 0($t5) 
	 	j finishDetect
	 	
	 	# Action in negative water Zone
	 	negativeWaterDetect:
	 	la $t9, negativeWaterDetectEnd # push the parameters into the stack
	 	addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	addi $sp, $sp, -4
	 	la $t8, negativeLogCoordinates
	 	sw $t8, 0($sp) # store the address of x, y coordinate into stack
	 	
	 	
	 	la $t9, logSize	 # Log width
		# Store the address of log width into stack
		addi $sp, $sp, -4
	 	sw $t9, 0($sp)
	 	
	 	j objCollisionWithFrog
	 	
	 	negativeWaterDetectEnd:
	 	lw $t9, 0($sp) # Store the hitting status into the t9 regiter
	 	addi $sp, $sp, 4
	 	li $t8, 1
		sub $t9, $t8, $t9 # Store the opposite vaoue into the game status
	 	la $t5, hittingStatus # Store the address of hitting Status into t5
	 	sw $t9, 0($t5)
	 	j finishDetect
	 	
	 	
	 	
	 	safeZoneAction: # The zone that win the game, can add more features
		# checked
	 	li $t9, 1
	 	la $t8, winStatus
	 	sw $t9, 0($t8)
	 	j finishDetect
	 	
	 	belowCarZone: 
	 	
	 	finishDetect:
	 	jr $ra
	 	
	 	
objCollisionWithFrog: # stack: return address, objCoordinate, objSize (Address)
		      # register used, t2-8
		     lw $t2, 0($sp) # use t2 to store the address of object size
		     addi $sp, $sp, 4
		     # lw $t3, 4($t2) # t3 store the height of the object
		     lw $t2, 0($t2) # t2 to store the width of the object
		     
		     lw $t4, 0($sp) # 
		     addi $sp, $sp, 4
		     add $s4, $t4, $zero # Copy the value in t4 to s4, the address of 
		     # lw $t5, 4($t4) # t5 to store the y coordinate of the object
		     lw $t4, 0($t4) # t4 to store the x coordiante of the object
		     
     
		     la $t6, frogCoor
		     # lw $t7, 4($t6) # t7 to store the y coordinate of the frog
		     lw $t6, 0($t6) # t6 to store the x coordinate of the frog
		     
		     add $t8, $t4, $t2 # the x coordinate of the right coner of the object
		     bge $t6, $t8, offCollision1
		     # Checked
		     addi $t8, $t6, 4 # t8 to store the right cooner of the frog
		     ble $t8, $t4, offCollision1
		     
		     li $t7, 1
		     lw $t8, 0($sp) # strote the return address to the t8
		     sw $t7, 0($sp) # store the return value into the stack
		     
		     jr $t8
		     
		     offCollision1:
		     
		     lw $t4, 8($s4) # t4 to store x coor of the object
		     # lw $t5, 4($t4) # t5 to store the y coordinate of the object
		     
     
		     la $t6, frogCoor
		     # lw $t7, 4($t6) # t7 to store the y coordinate of the frog
		     lw $t6, 0($t6) # t6 to store the x coordinate of the frog
		     
		     add $t8, $t4, $t2 # the x coordinate of the right coner of the object
		     bge $t6, $t8, offCollision2
		     # Checked
		     addi $t8, $t6, 4 # t8 to store the right cooner of the frog
		     ble $t8, $t4, offCollision2
		     
		     li $t7, 1
		     lw $t8, 0($sp) # strote the return address to the t8
		     sw $t7, 0($sp) # store the return value into the stack
		     jr $t8
		     
		     offCollision2:
		     
		     lw $t8, 0($sp) # strote the return address to the t2
		     sw $zero, 0($sp) # store the return value into the stack
		     jr $t8
		     
			
	 	
	 	
	
	
reactKey:
	lw $t8, 0xffff0000
	beq $t8, 1, keyboard_input # react to key event if any key is stroken
	j noKeyEvent
	
	keyboard_input:
	
	lw $t2, 0xffff0004 # load the key value to t2
	
	beq $t2, 0x72, respond_to_R # Trigger r is ascii is 72 hex 
	lw $t6, gameStatus
	beq $t6, $zero, noKeyEvent # if the game status is 0, no key event will be respond
	
	beq $t2, 0x61, respond_to_A # Trigger a if ascii is 61 in hex
	beq $t2, 0x73, respond_to_S # Trigger s if ascii is 73 in hex
	beq $t2, 0x64, respond_to_D # Trigger d if ascii is 64 hex
	beq $t2, 0x77, respond_to_W # Trigger w if ascii if 77 hex

	j noKeyEvent # Do not trigger anything if the key event is not specified
	
	respond_to_A: # Move the frog left by two pixels
	la $t3, frogCoor
	la $t4, frogCoor
	lw $t3, 0($t3)
	addi $t3, $t3, -2
	
	blt $t3, $zero, boundLeft # Fix the x coordinate to 0 if it is smaller than 0
	
	j noBoundLeft
	boundLeft:
	add $t3, $zero, $zero
	noBoundLeft:
	sw $t3, 0($t4)
	
	j noKeyEvent
	
	respond_to_S: # Move the frog down by 4 pixels
	la $t3, frogCoor
	la $t4, frogCoor
	lw $t3, 4($t3)
	addi $t3, $t3, 4
	
	li $t5, 28
	bgt $t3, $t5, boundBot # Fix the y coordinate to 28 if it is greater than 124
	
	j noBoundBot
	boundBot:
	add $t3, $zero, $t5
	noBoundBot:
	sw $t3, 4($t4)
	
	j noKeyEvent
	
	respond_to_D: # Move the frog right by 4 pixels
	la $t3, frogCoor
	la $t4, frogCoor
	lw $t3, 0($t3)
	addi $t3, $t3, 2
	
	li $t5, 28
	bge $t3, $t5, boundRight # Fix the x coordinate to 28 if it is greater than 28
	
	j noBoundRight
	boundRight:
	li $t5, 28
	add $t3, $zero, $t5
	noBoundRight:
	sw $t3, 0($t4)
	
	j noKeyEvent
	
	respond_to_W: # Move the frog up by 4 pixels
	la $t3, frogCoor
	la $t4, frogCoor
	lw $t3, 4($t3)
	addi $t3, $t3, -4
	
	li $t5, 0
	blt $t3, $t5, boundTop # Fix the y coordinate to 0 if it is smaller than 28
	
	j noBoundTop
	boundTop:
	add $t3, $zero, $t5
	noBoundTop:
	sw $t3, 4($t4)
	
	j noKeyEvent
	
	respond_to_R:
	li $t5, 1
	lw $t3, gameStatus
	la $t4, gameStatus
	sub $t3, $t5, $t3 # If R is pressed, change the game status, either from start to end or end to start
	sw $t3, 0($t4) # 1 represent start and 0 represent end
	
	j noKeyEvent
	
	
	noKeyEvent:
	jr $ra

	
drawCanvas:
	la $t0, canvas
	lw $t1, displayAddress
	
	addi $t2, $zero, 0 # Use t2 to loop
	li $t3, 1024
	li $t7, 4
	
	lw $t5, 0($t0)
	sw $t5, 0($t1)
	
	drawLoopBegin:
	bge $t2, $t3, drawStopLoop
	
	add $t0, $t0, $t7
	add $t1, $t1, $t7
	
	lw $t5, 0($t0)
	sw $t5, 0($t1)
	addi $t2, $t2, 1
	j drawLoopBegin
	
	drawStopLoop:
	jr $ra
	
moveObjsCoor:
	# Move frog, the speed of the frog could be 0
	la $t2, frogCoor
	lw $t1, frogSpeed
	la $a1, frogMoveEnd
	j Move
	
	frogMoveEnd:
	# Fix the frog position in case it fall from the screen
	lw $t3, 0($t2) # store the x coordinate into t3
	blt $t3, $zero, setToZero
	li $t4, 28
	bge $t3, $t4, setToRightBound
	j frogFixEnd
	
	setToRightBound:
	li $t3, 27
	sw $t3, 0($t2)
	
	setToZero:
	li $t3, 0
	sw $t3, 0($t2)
	
	frogFixEnd:

	# 
	la $t2, positiveLogCoordinates
	lw $t1, positiveLogSpeed
	la $a1, logMoveEnd
	j Move
	
	logMoveEnd:
	addi $t2, $t2, 8
	la $a1, logMoveEnd1
	j Move
	
	logMoveEnd1:
	la $t2, negativeLogCoordinates
	lw $t1, negativeLogSpeed
	la $a1, logMoveEnd2
	j Move
	
	logMoveEnd2:
	addi $t2, $t2, 8
	la $a1, logMoveEnd3
	j Move
	
	logMoveEnd3:
	
	la $t2, slowCarCoordinates
	lw $t1, slowCarSpeed
	la $a1, carMoveEnd
	j Move
	
	carMoveEnd:
	addi $t2, $t2, 8
	la $a1, carMoveEnd1
	j Move
	
	carMoveEnd1:
	la $t2, quickCarCoordinates
	lw $t1, quickCarSpeed
	la $a1, carMoveEnd2
	j Move
	
	carMoveEnd2:
	addi $t2, $t2, 8
	la $a1, carMoveEnd3
	j Move
	
	carMoveEnd3:
	jr $ra
	
	Move:
	lw $t3, 0($t2)
	add $t3, $t3, $t1
	li $t4, 32
	bge $t3, $t4, resetCoor
	blt $t3, $zero, readdCoor
	j doNoReset
	
	resetCoor:
	sub $t3, $t3, $t4
	j doNoReset
	
	readdCoor:
	addi $t3, $t3, 32
	j doNoReset
	
	doNoReset:
	sw $t3, 0($t2)
	jr $a1
	
drawObjs: # draw the objects
	la $s1, canvas
	
	lw $t9, logColor # Use t9 to store color
	la $t8, positiveLogCoordinates # t4 for coordinates
	la $a0, logSize # t5 for obj size
	la $s2 objCurrent0
	j draw
	objCurrent0:
	
	addi $t8, $t8, 8
	la $s2 objCurrent1
	j draw
	objCurrent1:
	
	la $t8, negativeLogCoordinates
	la $s2 objCurrent2
	j draw
	objCurrent2:
	
	addi $t8, $t8, 8
	la $s2 objCurrent3
	j draw
	objCurrent3:
	
	lw $t9, carColor # Use t9 to store color
	la $t8, slowCarCoordinates # t4 for coordinates
	la $a0, carSize # t5 for obj size
	la $s2 objCurrent4
	j draw
	objCurrent4:
	
	addi $t8, $t8, 8
	la $s2 objCurrent5
	j draw
	objCurrent5:
	
	la $t8, quickCarCoordinates
	la $s2 objCurrent6
	j draw
	objCurrent6:
	
	addi $t8, $t8, 8
	la $s2 objCurrent7
	j draw
	objCurrent7:
	
	# Start draw life indicator
	
	lw $s5, lifeCount # Store life count to t4
	li $s4, 0
	
	addi $sp, $sp, -4
	sw $s4, ($sp)
	addi $sp, $sp, -4
	sw $s5, ($sp)
	
	startLifeIndicator:
	lw $s5, ($sp)
	addi $sp, $sp, 4
	lw $s4, ($sp)
	addi $sp, $sp, 4
	
	beq $s5, $s4, endDrawObjs # Indicate the remaining lives
	
	addi $s4, $s4, 1
	addi $sp, $sp, -4 # push s4
	sw $s4, ($sp)
	addi $sp, $sp, -4 # push s5
	sw $s5, ($sp)
	
	
	lw $t9, healthColor
	
	la $t5, jumpingTo # Pop the address of return to stack
	addi $sp, $sp, -4
	sw $t5, ($sp)
	
	addi $sp, $sp, -4 # Pop the value of color into stack
	sw $t9, ($sp)
	
	la $t5, canvas # pop the address of canvas into stack
	addi $sp, $sp, -4
	sw $t5, ($sp)
	
	li $t5, 3
	addi $s4, $s4, -1
	mul $t5, $t5, $s4 # The x coordinate of the rectangle
	addi $sp, $sp, -4
	sw $t5, ($sp)
	
	addi $sp, $sp, -4
	sw $zero, ($sp) # The y coordinate of the rectangle
	
	li $t5, 2 
	addi $sp, $sp, -4 # Pop the width and height into the stack
	sw $t5, ($sp)
	
	addi $sp, $sp, -4
	sw $t5, ($sp)
	
	j drawRectangleByStack
	
	jumpingTo:
	addi $s4, $s4, 1
	j startLifeIndicator
	
	endDrawObjs:
	jr $ra
	
	
	draw:	
	lw $t0, 0($t8) # Coordinates
	lw $t1, 4($t8)
	
	lw $t2, 0($a0) # Width
	lw $t3, 4($a0) # Height
	
	la $s3, drawObj
	j drawRectangle
	
	drawObj:
	jr $s2
	
	
drawRectangle: # t0 to store the x and t1 to store the y, t2 to store the width and t3 to store the height and t9 for color, s1 for canvas
		# x and y goes from 0 to 32, corresponding to the pixels, use s3 to jump back
		
	li $t4, 128 # Transfer the coordinate of y into relative addres values/diatance from the starting position
	mul $t1, $t1, $t4
	addi $v1, $t1, 0 # index for looping
	
	li $t4, 4 # Transfer the coordinate of x into relative addres values/diatance from the starting position
	mul $t0, $t0, $t4
	addi $v0, $t0, 0 # index for looping
	
	add $t6, $t0, $t1 # Store the value of distance from initial point to current point, already by 4
	
	add $t7, $t0, $t1 # Same as above, used as cursor for looping, change horizontally
	
	
	li $t4, 0 # Will be used as loop variant for outer loop
	li $t5, 0 # Will be used as loop variant for inner loop
	
	recOuter:
	beq $t4, $t3, recOuterEnd # The outer loop for the y 
	li $t5, 0
	
	recInner:
	beq $t5, $t2, recInnerEnd # The inner loop for the x
	
	add $a3, $t7, $s1
	sw $t9, 0($a3) # paint the color
	
	addi $t5, $t5, 1 # Accumulate
	
	
	
	la $s5, recCurrent0
	addi $s7, $t7, 0 # Set s7 to the t7, passing the parameter to the helper function
	j addressToCoordinate # Calculate the coordinate
	
	recCurrent0:
	add $a1, $k1, $zero # Store the y coordinate to a1, later to compare with a2
	
	addi $t7, $t7, 4 # Add t7 by 4, move the cursor right by one pixel
	
	la $s5, recCurrent1
	addi $s7, $t7, 0 # Set s7 to the t7, passing the parameter to the helper function
	j addressToCoordinate # Calculate the coordinate
	
	recCurrent1:
	add $a2, $k1, $zero # Store the later y coordinate as a2
	
	bgt $a2, $a1, verticalMoveBack # If a2 is greater than a1, than move the vertical cursor up by one pixel
	j recNothing
	
	verticalMoveBack:
	li $a1, 128
	sub $t7, $t7, $a1
	
	
	recNothing: 
	
	j recInner
	
	recInnerEnd:
	addi $t4, $t4, 1 # Accumulate
	addi $t6, $t6, 128 # Add 128 to t6 so that the cursor move one pixel down
	addi $t7, $t6, 0 # reset the t7 to t6 so that its horizontal position is back on zero
	j recOuter
	
	recOuterEnd:
	jr $s3
	
addressToCoordinate: # Take s7 as the address and store x to k0, y to k1, use s5 to jump back

	li $k1, 0 # Use k0 as the number the s7 can subtract 128
	li $k0, 0
	
	transStart: # First determine the y/k1
	blt $s7, $zero, transEnd # 
	
	li $s6, 128
	sub $s7, $s7, $s6 # Keep subtracting $s7 by 128
	addi $k1, $k1, 1 # Accumulate by add onr to k1
	j transStart
	
	transEnd: # Then Determine the x/k0
	addi $k1, $k1, -1 # Add -1 to be the actual value, note that y start from 0 rather than 1
	addi $s7, $s7, 128 # Since s7 is smaller than 0 at the end of the loop, we add it back
	
	transStart2:
	blt $s7, $zero, transEnd2 # 
	
	li $s6, 4
	sub $s7, $s7, $s6
	addi $k0, $k0, 1
	j transStart2
	
	transEnd2:
	addi $k0, $k0, -1 # Same as above
	jr $s5
	
	
drawBg:
	la $t0, canvas
	li $t1, 0xffffff # $t1 stores the red colour code
	li $t2, 128 # 4 rows of color $t1 at the top
	li $t3, 0
	
	# lw $t4, safeZoneStatus
	# la $t5, safeZoneStatus
	# sw $zero, ($t5)
	# bgt, $t4, $zero, resetSafeZone
	# j startDrawTop
	# resetSafeZone:
	# li $t2, 256
	startDrawTop:
		beq $t3, $t2, stopTop
		sw $t1, 0($t0)
		addi $t0, $t0, 4
		addi $t3, $t3, 1
		j startDrawTop 
	stopTop:
	
	# bgt, $t4, $zero, noIncrement
	# addi $t0, $t0, 512
	# noIncrement:
	li $t1, 0x3399ff # $t1 stores the colour 
	addi $t3, $zero, 0
	addi $t2, $zero, 256
	
	startDrawMid0:
		beq $t3, $t2, stopMid0
		sw $t1, 0($t0)
		addi $t0, $t0, 4
		addi $t3, $t3, 1
		j startDrawMid0 
	stopMid0:
	
	li $t1, 0xff6666 # $t1 stores the red colour code
	addi $t3, $zero, 0
	addi $t2, $zero, 128
	
	startDrawMid:
		beq $t3, $t2, stopMid
		sw $t1, 0($t0)
		addi $t0, $t0, 4
		addi $t3, $t3, 1
		j startDrawMid 
	stopMid:
	
	li $t1, 0xa0a0a0 # $t1 stores the red colour code
	addi $t3, $zero, 0
	addi $t2, $zero, 256
	
	startDrawBot:
		beq $t3, $t2, stopBot
		sw $t1, 0($t0)
		addi $t0, $t0, 4
		addi $t3, $t3, 1
		j startDrawBot 
	stopBot:
	
	li $t1, 0xffffff # $t1 stores the white colour code
	addi $t3, $zero, 0
	addi $t2, $zero, 128
	
	startDrawStart:
		beq $t3, $t2, stopStart
		sw $t1, 0($t0)
		addi $t0, $t0, 4
		addi $t3, $t3, 1
		j startDrawStart
	stopStart:
	jr $ra
	
		
		
drawFrog:
	la $t0, canvas	#
	lw $t1, frogColor # $t1 stores the frog colour code
	
	la $t2, frogCoor # $t2 is used to store the address of x and y coordinates 
	la $t3, frogPixel # $t3 is used to store relative the addres of frogPixel
	li $t4, 0
	li $t5, 12
	
	li $s7 4
	lw $s6 0($t2)
	mul $t8, $s6, $s7
	li $s7, 128
	
	lw $s6 4($t2)
	mul $t9, $s6, $s7
	add $t2, $t8, $t9
	
	beginDrawFrog:
		li $t7, 4
		beq $t4, $t5, endDrawFrog
		mul $s1, $t7, $t4
		add $s1, $t3, $s1 # The position index of frogpixel in array
		
		lw $t6, 0($s1) # t6 to store the distance from the initial position, already by 4
		
		# initial posiiton, should be multiplied by 4
		add $t7, $t2, $zero

		add $t7, $t7, $t6 # let t7 to store the absolute position
		add $t7, $t0, $t7
		sw $t1, 0($t7)
		addi $t4, $t4, 1
		j beginDrawFrog
	endDrawFrog:
		jr $ra
		
	
drawRectangleByStack: # Stack: returnAddress, colorValue, Canvas, xCoor, yCoor, Width, Height
		# t0 to store the x and t1 to store the y, t2 to store the width and t3 to store the height and t9 for color, s1 for canvas
		# x and y goes from 0 to 32, corresponding to the pixels, use s3 to jump back
	lw $t3, 0($sp) # t3 for height
	addi $sp, $sp, 4
	lw $t2, ($sp) # t2 for width
	addi $sp, $sp, 4
	lw $t1, ($sp) # t1 for y coordinate
	addi $sp, $sp, 4
	lw $t0, ($sp) # t0 for x coordinate
	addi $sp, $sp, 4
	
	lw $s1, ($sp) # s1 for address of canvas 
	addi $sp, $sp, 4
	
	lw $t9, ($sp) # t9 for color value
	addi $sp, $sp, 4
	
	lw $s3, ($sp) # s3 for jump back address
	addi $sp, $sp, 4
	
		
	li $t4, 128 # Transfer the coordinate of y into relative addres values/diatance from the starting position
	mul $t1, $t1, $t4
	addi $v1, $t1, 0 # index for looping
	
	li $t4, 4 # Transfer the coordinate of x into relative addres values/diatance from the starting position
	mul $t0, $t0, $t4
	addi $v0, $t0, 0 # index for looping
	
	add $t6, $t0, $t1 # Store the value of distance from initial point to current point, already by 4
	
	add $t7, $t0, $t1 # Same as above, used as cursor for looping, change horizontally
	
	
	li $t4, 0 # Will be used as loop variant for outer loop
	li $t5, 0 # Will be used as loop variant for inner loop
	
	recOuter1:
	beq $t4, $t3, recOuterEnd1 # The outer loop for the y 
	li $t5, 0
	
	recInner1:
	beq $t5, $t2, recInnerEnd1 # The inner loop for the x
	
	add $a3, $t7, $s1
	sw $t9, 0($a3) # paint the color
	
	addi $t5, $t5, 1 # Accumulate
	
	
	
	la $s5, recCurrent01
	addi $s7, $t7, 0 # Set s7 to the t7, passing the parameter to the helper function
	j addressToCoordinate # Calculate the coordinate
	
	recCurrent01:
	add $a1, $k1, $zero # Store the y coordinate to a1, later to compare with a2
	
	addi $t7, $t7, 4 # Add t7 by 4, move the cursor right by one pixel
	
	la $s5, recCurrent11
	addi $s7, $t7, 0 # Set s7 to the t7, passing the parameter to the helper function
	j addressToCoordinate # Calculate the coordinate
	
	recCurrent11:
	add $a2, $k1, $zero # Store the later y coordinate as a2
	
	bgt $a2, $a1, verticalMoveBack1 # If a2 is greater than a1, than move the vertical cursor up by one pixel
	j recNothing1
	
	verticalMoveBack1:
	li $a1, 128
	sub $t7, $t7, $a1
	
	
	recNothing1: 
	
	j recInner1
	
	recInnerEnd1:
	addi $t4, $t4, 1 # Accumulate
	addi $t6, $t6, 128 # Add 128 to t6 so that the cursor move one pixel down
	addi $t7, $t6, 0 # reset the t7 to t6 so that its horizontal position is back on zero
	j recOuter1
	
	recOuterEnd1:
	jr $s3
	
incrementSpeed:
	
	li $t3, 3
	# speed up positive log
	lw $t0, invariant
	li $t1, 5
	ble $t0, $t1, skipSpeedingPLog
	sub $t0, $t0, $t3
	
	la $t1, invariant
	sw $t0, ($t1)
	skipSpeedingPLog:
	# end of speeding up
	jr $ra
	
resetData:
	# Reset the data
	la $t1, safeZoneStatus
	li $t2, 1
	sw $t2, 0($t1)
	
	la $t1, logSize # reset the log size, only the width
	li $t2, 8
	sw $t2, 0($t1)
	
	la $t1, positiveLogSpeed # reset the log speed, only the width
	li $t2, 2
	sw $t2, 0($t1)
	
	la $t1, negativeLogSpeed # reset the log speed, only the width
	li $t2, -1
	sw $t2, 0($t1)
	
	la $t1, slowCarSpeed# reset the car speed, only the width
	li $t2, 1
	sw $t2, 0($t1)
	
	la $t1, quickCarSpeed# reset the car speed, only the width
	li $t2, -2
	sw $t2, 0($t1)
	
	la $t1, logSize # reset the log size, only the width
	li $t2, 8
	sw $t2, 0($t1)

	
	la $t1, level
	sw $zero, 0($t1)
	
	la $t1, score
	sw $zero, 0($t1)
	
	la $t1, healthColor
	li $t2, 0xff0000
	sw $t2, 0($t1)
	
	la $t1, winStatus
	sw $zero, 0($t1)
	
	la $t1, gameStatus
	sw $zero, 0($t1)
	
	la $t1, hittingStatus
	sw $zero, 0($t1)
	
	la $t1, lifeCount
	li $t2, 3
	sw $t2, 0($t1)
	
	la $t1, iterate
	sw $zero, 0($t1)
	
	la $t1, invariant
	li $t2, 15
	sw $t2, 0($t1)
	
	la $t1, frogSpeed
	sw $zero, 0($t1)
	
	jr $ra
	
nextLevelCheck:
	lw $t1, score
	li $t2, 2
	blt $t1, $t2, noNextLevel
	# Go to next level
	la $t1, logSize
	li $t2, 4
	sw $t2, ($t1)
	
	# 7f00ff as color for health indicator
	la $t1, healthColor
	li $t2, 0x7f00ff
	sw $t2, ($t1)
	
	noNextLevel:
	jr $ra
	
sinkLog:
	lw $t1, sinkCount
	lw $t2, isSink
	lw $t3, sinkTime
	
	# Action when float
	addi $t1, $t1, 1
	la $t4, sinkCount
	sw $t1, ($t4)
	bge $t1, $t3, changeSinkStatus
	j endOfChanging
	# Action when still floating
	
	changeSinkStatus:
	la $t1, sinkCount
	sw $zero, ($t1)
	li $t4, 1
	sub $t2, $t4, $t2 # change the sinking status
	la $t1, isSink
	sw $t2, ($t1)
	
	# Case when change to sink
	beq $t2, $zero, toFloat
	# Action to hide the second log so that two logs overlay
	la $t5, positiveLogCoordinates
	lw $t6, 8($t5) # x coor of second log
	lw $t7, ($t5) # x coor of the first log
	sub $t8, $t6, $t7 # x of 2 - x of 1
	sw $t7, 8($t5) # Store the first x into the second x
	addi $sp, $sp, -4
	sw $t8, ($sp) # push the diff into the diference
	# end of hiding the log
	j endOfChanging
	
	toFloat:
	# Action to restore the second log
	la $t5, positiveLogCoordinates
	lw $t6, ($sp) # t6 for the diff between first and second log
	addi $sp, $sp, 4
	lw $t7, ($t5)
	add $t7, $t7, $t6 # t7 for the actual log x coor
	sw $t7, 8($t5) # restore
	# End of action
	
	endOfChanging:
	jr $ra
	
		
	
Testing:
	li $v0,1

move $a0,$t2

syscall

li $a0, 'f'
li $v0, 11    # print_character
syscall
