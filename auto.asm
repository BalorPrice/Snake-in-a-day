; SNAKE-IN-A-DAY by tobermory@cookingcircle.co.uk.   8-Nov-2017.

; Play with cursor keys and control to restart game.
; Developed using SimCoupe and PYZ80 cross-compiler.

; Converted from Gamkedo's Chris Deleon's Javascript demonstration of Snake done in 5 minutes here:  https://www.youtube.com/watch?v=xGmXxpIj6vs
; Just intended as a simple example of how games can be done in Z80 on the Sam Coupé quite easily.  This took about 3 hours to follow his rapid prototyping example, and convert into Z80.
; This uses one  routine - the pseudo-random number generator from Your Sinclair's Star Tips section.  It turns out wasn't originally written only by Jon Ritman as I thought, but Simon Brattel and Neil Mottershead.  Go figure.

;----------------------------------------------
; Entry point
				dump 1,0						; Dump objectcode to Page 1 with no offset, ie 32768 in BASIC's terminology
				autoexec						; Set to automatically load and call when sent to SimCoupé
				org 32768						; Org to same address.  No clever paging needed here.
main.start:
				di
	@set_low_page:
				ld a,8+32						; Set low pages as screen buffer, with ROM paged out
				out (250),a
	@set_video_page:
				ld a,10+96						; Set video to point to low pages XOR 2, mode 4
				out (252),a
	@set_stack:
				ld sp,stack						; Use our own stack, point to below bottom of stack
				jp main
				
				
				dm "** Snake-in-a-day! by tobermory@cookingcircle.co.uk 8-Nov-2017 **"
stack:
				
;----------------------------------------------
; GLOBAL VARIABLES

player_x:		db player_start_x				; Snake head current coords
player_y:		db player_start_y
player_start_x:	equ 10							; start coords for player
player_start_y:	equ 10

trail_len:		equ 128							; Longest possible length of trail.  NB Game crashes and resets if trail gets too long.
trail_start_len: equ 3							; start length of trail
trail:			for trail_len,db 10,10			; List of coords of previous positions, top length 128 for now.
tail:			db trail_start_len				; Current length of tail

x_vel:			db 0							; Input variables for x- and y-movement. -1, 0 or 1 for direction of travel
y_vel:			db 0

apple_x:		db 15							; Current 'apple' coords
apple_y:		db 15

game_size:		equ 20							; Dimensions of game grid

game_speed:		equ 4							; Pause between frames

;----------------------------------------------
; MAIN GAME LOOP

main:
				call reset_game
main_loop:
				ld b,game_speed
				call wait_B_frames				; slow down the game a bit - also read the keyboard on each frame
				call swap_screens
				call math.rand					; update random number generator
				call move_player				; Update player position
				call clear_tail
				call upd_snake
				call upd_apple
				jp main_loop
								
;----------------------------------------------
reset_game:
; Called if control pressed - start a new game
	@reset_tail_length:
				ld a,trail_start_len
				ld (tail),a
	@reset_tail_data:							; clear array of tail positions
				ld hl,trail
				ld de,trail+1
				ld bc,trail_len-1
				ld (hl),-1						; blank out trail array 
				ldir
	@reset_player_pos:
				ld a,player_start_x
				ld (player_x),a
				ld a,player_start_y
				ld (player_y),a
	@set_direction:								; Set initial direction of travel
				ld a,0
				ld (x_vel),a
				ld a,-1
				ld (y_vel),a
	@reset_apple:
				call random20
				ld (apple_x),a
				call random20
				ld (apple_y),a
				
				call set_palette
				call clear_screens				; Clear both screens
				call print_game_area
				ret
				
;----------------------------------------------
; HOUSEKEEPING ROUTINES

set_palette:
				ld bc,&05f8						; B=palette number+1 to start at, C=&f8
				ld hl,palette+4					; Set HL to end of palette+1
				otdr							; OUT with decrement repeatedly
				ret
				
palette:		db 8,64,32,0,127				; Up to 16 entries allowed
grey:			equ 0							; Labelling all the colours makes things easier to work out
green:			equ 1
red:			equ 2
black:			equ 3
white:			equ 4

clear_screens:
; Clear both screens
				call clear_screen
				call swap_screens
				call clear_screen
				ret
				
clear_screen:
; Clear one screen, slow version
				ld hl,0							; Mode 4 is 192 rows of 128 bytes, each with 2 nibbles for a pixel of colour info.
				ld de,1
				ld (hl),grey*&11				; Fill both nibbles with same colour
				ld bc,24575
				ldir
				ret
				
swap_screens:
; Swap displayed and buffer screens
				in a,(250)
				xor 2
				out (250),a
				in a,(252)
				xor 2
				out (252),a
				ret
			
wait_B_frames:
; Slow down the game speed, 50 fps too fast for me
	@loop:
				push bc
				call wait_frame
				call input_keys
				pop bc
				djnz @-loop
				ret
				
wait_frame:
; Wait until frame interrupt occurred - this sets it to 50fps 
				in a,(249)
				bit 3,a
				ret z
				jp wait_frame

;----------------------------------------------
input_keys:
; Get control and arrow keys in bits 0-4
	@input_keys:
				ld bc,&fffe						; Control and arrow keys all on &ff half-row of keyboard input
				in a,(c)
				cpl
				and %00011111
	@process_keys:
		@quit:									; If control pressed, reset the game
				bit 0,a
				jp z,@up
				call reset_game
				pop hl							; Junk return from this routine and jump to main loop again
				jp main
		@up:
				bit 1,a							; If up pressed, set y velocity to -1 and x to 0, etc etc
				jp z,@down
				xor a
				ld (x_vel),a
				ld a,-1
				ld (y_vel),a
				ret
		@down:
				bit 2,a
				jp z,@left
				xor a
				ld (x_vel),a
				ld a,1
				ld (y_vel),a
				ret
		@left:
				bit 3,a
				jp z,@right
				ld a,-1
				ld (x_vel),a
				xor a
				ld (y_vel),a
				ret
		@right:
				bit 4,a
				ret z
				ld a,1
				ld (x_vel),a
				xor a
				ld (y_vel),a
				ret

;----------------------------------------------
move_player:
	@update_position:							; Add x_vel to player_x, add y_vel to player_y
				ld a,(player_x)
				ld hl,x_vel
				add (hl)
				ld (player_x),a
				ld e,a
				
				ld a,(player_y)
				ld hl,y_vel
				add (hl)
				ld (player_y),a
				ld d,a
				
	@test_loop_left:							; Loop playing area
				ld a,e
				cp -1							; If x=255 then add width of playing area
				jp nz,@test_loop_right
				add game_size
				ld (player_x),a
				jp @test_loop_up
	@test_loop_right:
				cp game_size
				jp nz,@test_loop_up
				sub game_size
				ld (player_x),a
	@test_loop_up:
				ld a,d
				cp -1
				jp nz,@test_loop_down
				add game_size
				ld (player_y),a
				ret
	@test_loop_down:
				cp game_size
				ret nz
				sub game_size
				ld (player_y),a
				ret
				
				
;----------------------------------------------
print_game_area:
; Print game area as a massive rectangle.  Not used in main game loop for speed issues, instead just clear the old end of snake tail.
				call @+print
				call swap_screens
				call @+print
				ret
				
	@print:
				ld hl,0
				ld de,1
				ld a,game_size*8				; depth of playing area is 20 units of 8 pixels each
	@loop:
				ld (hl),black*&11
				for 80-1,ldi					; Overall width is 8*20 pixels, 40 bytes (minus first one done by hand)
				ld bc,128-(80-1)
				add hl,bc
				ex de,hl
				add hl,bc
				ex de,hl
				dec a
				jp nz,@-loop
				ret
				
clear_tail:
; As we're working with a buffer screen, clear last two squares of snake tail (current frame we're clearing up is 2 frames old now).
				ld a,(tail)						; Find tail end
				ld l,a
				ld h,0
				add hl,hl
				ld bc,trail
				add hl,bc
				
				ld b,2
	@loop:
				ld e,(hl)						; Get tail position
				inc hl
				ld d,(hl)
				inc hl
		@test_tail:								; If no entry, quit
				ld a,d
				and e
				cp -1
				ret z
				
				push bc
				push hl
				ex de,hl
				add hl,hl						; turn into screen position (each (coord/2)*8 to get screen address)
				add hl,hl
				ld c,black*&11
				call print_rectHLC
				pop hl
				pop bc
				djnz @-loop
				ret

;----------------------------------------------				
upd_snake:
				ld hl,trail
				ld a,(tail)						; Set loop for amount of squares of tail to print
				ld b,a
	@loop:
		@get_snake_coords:
				ld e,(hl)
				inc hl
				ld d,(hl)
				inc hl
				
		@check_entry:							; Quit printing if array has no further entries
				ld a,d
				and e
				cp -1
				jp z,@print_head
				
				push bc
				push hl
				
		@check_hit:								; If tail coords match player coords then lost game
				ld bc,trail+2
				and a
				sbc hl,bc
				jp z,@+skip
				
				ld a,(player_x)
				ld l,a
				ld a,(player_y)
				ld h,a
				and a
				sbc hl,de
				jp z,@+quit
			@skip:
				ex de,hl
				add hl,hl
				add hl,hl
				ld c,1*&11
				call print_rectHLC
				
				pop hl
				pop bc
				djnz @-loop
				
	@print_head:								; Extra credit - print snake head in white
				ld a,(player_X)
				ld l,a
				ld a,(player_y)
				ld h,a
				add hl,hl
				add hl,hl
				ld c,4*&11
				call print_rectHLC
				
	@push_trail:								; If tail getting longer, shuffle all tail elements along and add to top of list
				ld hl,trail+128-3				; As everything is going forwards in memory, move from the end of list and track backwards
				ld de,trail+128-1
				ld bc,128-2
				lddr
	@store_head:
				ld a,(player_x)
				ld (trail),a
				ld a,(player_y)
				ld (trail+1),a
				ret
				
	@quit:
				for 2,pop hl
				jp main
			
;----------------------------------------------
upd_apple:
; Update the apple.  Test if it's been eaten, if so choose a new place to be printed.
				ld a,(player_x)					; If apple coords and player coords are the same, choosse a new position for next apple.
				ld hl,apple_x
				cp (hl)
				jp nz,@+print
				ld a,(player_y)
				ld hl,apple_y
				cp (hl)
				jp nz,@+print
	@grow_tail:
				ld hl,tail
				inc (hl)
	@select_new_apple_coords:					; !! New apple can appear on top of tail
				call random20
				ld (apple_x),a
				call random20
				ld (apple_y),a
	@print:										; ! Regardless of whether eaten, print again anyway
				ld a,(apple_y)
				ld h,a
				ld a,(apple_x)
				ld l,a
				add hl,hl
				add hl,hl
				ld c,2*&11
				call print_rectHLC
				ret

random20:
; Make random number, times it by 20, return in A
				call math.rand					; Get 16-bit random number in HL
				ld h,0							; Turn into 8-bit, treat as number between 0/256 - 255/256
				ld d,h							; Multiply by 20
				ld e,l
				add hl,hl
				add hl,hl
				add hl,de
				add hl,hl
				add hl,hl
				ld a,h							; Take MSB only, ignore LSB
				ret

;----------------------------------------------
print_rectHLC:
; Print a 6*6 pixel rectangle at HL with colour C
				ld de,128
				add hl,de
				ld a,c
				and &0f
				or black*&10					; Hardcoded masking with game background
				ld e,a
				ld a,c
				and &f0
				or black
				ld d,a
				ld a,c
				ex af,af'
				ld a,6
				ld bc,128-3
	@loop:
				ex af,af'
				ld (hl),e
				inc l
				ld (hl),a
				inc l
				ld (hl),a
				inc l
				ld (hl),d
				add hl,bc
				ex af,af'
				dec a
				jp nz,@-loop
				ret
				
;============================================
; Pseudo-random number generator - by Jon Ritman, Simon Brattel, Neil Mottershead
; We don't need to know anything here, just that it works and returns a random 16-bit number in HL.

math.seed:		dm "C}_/"

math.rand:				
				ld hl,(math.seed+2)
				ld d,l
				add hl,hl
				add hl,hl
				ld c,h
				ld hl,(math.seed)
				ld b,h
				rl b
				ld e,h
				rl e
				rl d
				add hl,bc
				ld (math.seed),hl
				ld hl,(math.seed+2)
				adc hl,de
				res 7,h
				ld (math.seed+2),hl
				jp m,@+skip
				ld hl,math.seed
	@loop:
				inc (hl)
				inc hl
				jp z,@-loop
	@skip:	
				ld hl,(math.seed)
				ret
;============================================
				