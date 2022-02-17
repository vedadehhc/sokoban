.section ".text.init"
  .globl _start

_start:
  la 	sp, __stack_top
  call 	game

#+------------------------------------------+
#|				I/O helpers					|
#+------------------------------------------+


#	REVERSE BYTE
#	Reverses a byte's bits
#
#	Inputs:
#	a0 = the byte to reverse
#
#	Outputs:
#	a0 = the reverse byte
#
#	Variables:
#	a1 = temp reverse byte
#	a2 = parity of last bit of a0
#	a3 = counter from 8 to 0 for length of byte
#
reverse_byte:
  li	a1, 0
  li	a3, 8
reverse_byte_loop:
  andi	a2, a0, 0x1
  slli	a1, a1, 1
  add	a1, a1, a2
  srli	a0, a0, 1
  addi	a3, a3, -1
  bgtz	a3, reverse_byte_loop
  mv	a0, a1
  ret


#	GET INT TEN
#	Gets a base-10 integer of input (from a single line)
#
#	Outputs:
#	a0 = received int input
#
#	Variables:
#	s0 = cur built value from input
#	a0 = return from get_char
#
get_int_ten:
# push s0, ra to stack
  addi	sp, sp, -8
  sw	s0, 0(sp)
  sw	ra, 4(sp)
# initialize val
  li	s0, 0
get_int_ten_loop:
  call	get_char
  call	put_char
  li	t0, 13						# carriage return
  beq	a0, t0, get_int_ten_done
  addi	a0, a0, -48					# a0 -= '0'
  li	t0, 10
  mul	s0, s0, t0					# s0 *= 10
  add	s0, s0, a0
  j		get_int_ten_loop
get_int_ten_done:
  call put_ln
  mv	a0, s0
# pop s0, ra from stack
  lw	s0, 0(sp)
  lw	ra, 4(sp)
  addi	sp, sp, 8
  ret
  

#	GET CHAR
#	Gets a character of input
#
#	Outputs:
#	a0 = the received input
#
#	Variables:
#	a1 = UART address
#	a2 = ready status
#
get_char:
  li 	a1, 0x10000000
get_char_loop:
  lb 	a2, 5(a1)
  andi 	a2, a2, 0x01
  beqz 	a2, get_char_loop
get_char_done:
  lb 	a0, 0(a1)
  ret


#	PUT CHAR
#	Prints an ASCII character
#
#	Inputs:
#	a0 = the character to print
#
#	Variables:
#	a1 = UART address
#	a2 = ready status
#
put_char:
  li 	a1, 0x10000000
put_char_loop:
  lb 	a2, 5(a1)
  andi 	a2, a2, 0x40
  beqz 	a2, put_char_loop
put_char_done:
  sb 	a0, 0(a1)
  ret

#	PUT STR
#	Prints a null-terminated string
#
#	Inputs:
#	a0 = the address of the string to print
#
#	Variables:
#	a1 = the current character
#
put_str:
# push a0, ra to stack
  addi	sp, sp, -8
  sw	a0, 0(sp)
  sw	ra, 4(sp)
# load the first byte
  lb	a1, 0(a0)
  beqz	a1, put_str_done
put_str_loop:
# save a0 in stack
  sw	a0, 0(sp)
# put cur char
  mv	a0, a1
  call	put_char
# load a0 from stack
  lw	a0, 0(sp)
  addi	a0, a0, 1
# load next byte, if not zero, continue loop
  lb	a1, 0(a0)
  bnez	a1, put_str_loop
put_str_done:
# pop a0, ra from stack (only store ra)
  lw	ra, 4(sp)
  addi	sp, sp, 8
  ret

#	PUT BYTE
#	Prints a byte (in binary)
#
#	Inputs:
#	a0 = the byte to print
#
put_byte:
  addi	sp, sp, -12
  sw	ra, 0(sp)
  sw	s0, 4(sp)
  sw	s1, 8(sp)
  call	reverse_byte
  mv	s0, a0
  li	s1, 8
put_byte_loop:
  andi	a0, s0, 0x1		# check parity
  addi	a0, a0, 0x30	# get ASCII character
  call	put_char
  srli	s0, s0, 1
  addi	s1, s1, -1
  bgtz	s1, put_byte_loop
# done
  lw	ra, 0(sp)
  lw	s0, 4(sp)
  lw	s1, 8(sp)
  addi	sp, sp, 12
  ret


#	PUT INT TEN
#	Prints an integer in base 10
#
#	Inputs:
#	a0 = the number to print
#
#	Variables:
#	a1 = a0 % 10
#	a0 (second loop) = digit from stack
#
put_int_ten:
# push terminator (0) and ra in stack
  li	t0, 0
  addi	sp, sp, -8
  sw	t0, 0(sp)
  sw	ra, 4(sp)
# while number is positive, get last digit
  li	t0, 10
put_int_ten_loop:
  rem	a1, a0, t0
  addi	a1, a1, 48		# ascii char for digit
# push digit to stack
  addi	sp, sp, -4
  sw	a1, 0(sp)
# divide a0 by ten
  div	a0, a0, t0
  bgtz	a0, put_int_ten_loop
# until we reach 0 (terminator) print chars to output
put_int_ten_print_loop:
# pop next element from stack
  lw	a0, 0(sp)
  addi	sp, sp, 4
# if terminated, exit loop
  beqz	a0, put_int_ten_done
# else, put char and repeat
  call	put_char
  j		put_int_ten_print_loop
put_int_ten_done:
# pop ra from stack
  lw	ra, 0(sp)
  addi	sp, sp, 4
  ret


#	PUT LN
#	Prints a newline
#
put_ln:
  addi	sp, sp, -4
  sw	ra, 0(sp)
  li	a0, 0xa
  call put_char
# done
  lw	ra, 0(sp)
  addi	sp, sp, 4
  ret


#+------------------------------------------+
#|				Game Code					|
#+------------------------------------------+

#	GAME
#	Starts a new game
#
game:
# push s0, ra to stack
  addi	sp, sp, -8
  sw	s0, 0(sp)
  sw	ra, 4(sp)
# load level
game_level_loop:
# print 'Level: '
  addi	sp, sp, -8
  mv	a0, sp
  li	t0, 76
  sb	t0, 0(sp)
  li	t0, 101
  sb	t0, 1(sp)
  li	t0, 118
  sb	t0, 2(sp)
  li	t0, 101
  sb	t0, 3(sp)
  li	t0, 108
  sb	t0, 4(sp)
  li	t0, 58
  sb	t0, 5(sp)
  li	t0, 32
  sb	t0, 6(sp)
  li	t0, 0
  sb	t0, 7(sp)
  call 	put_str
  addi	sp, sp, 8
# get input
  call	get_int_ten
  beqz	a0, game_done
  bltz	a0, game_done
  li	t0, 155
  blt	t0, a0, game_level_loop
# push level number to stack
  addi	sp, sp, -4
  sw	a0, 0(sp)
game_load_level:
# load level
  call	load_level
# start level
  call	interactive
# if press r = status 2, reload level
  li	t0, 2
  bne	a0, t0, game_print
# load level number from stack into a0
  lw	a0, 0(sp)
  j		game_load_level
game_print:
# pop level number from stack into s0
  lw	s0, 0(sp)
  addi	sp, sp, 4
# print status + level number
  beqz	a0, game_print_loss
# print win
  li	a0, 87
  call	put_char
  li	a0, 32
  call	put_char
  mv	a0, s0
  call 	put_int_ten
  call	put_ln
  j		game_level_reloop
game_print_loss:
# print loss
  li	a0, 76
  call	put_char
  li	a0, 32
  call	put_char
  mv	a0, s0
  call 	put_int_ten
  call	put_ln
game_level_reloop:
# reloop
  j		game_level_loop
game_done:
  li	a0, 81
  call	put_char
  call	put_ln
# pop s0, ra from stack
  lw	s0, 0(sp)
  lw	ra, 4(sp)
  addi	sp, sp, 8
  ret
  

#	LOAD LEVEL
#	Loads the given level number
#	Gets the width and height and copies over the 
#	data to the 'current' board (level '0' in 
#	memory).
#
#	Inputs:
#	a0 = level number
#	
#	Outputs:
#	a0 = reference to board array
#	a1 = width
#	a2 = height
#
#	Variables:
#	a3 = width*height*4 (bytes in memory)
#	a3 = width * height (total size of level)
#	a4 = pointer to level
#	a5 = pointer to 'current' board
#
load_level:
  la	a4, levels
load_level_loop:
  lw	a1, 0(a4)
  lw	a2, 4(a4)
  addi	a4, a4, 8
  beqz	a0, load_level_copy
  mul	a3, a1, a2
  slli	a3, a3, 2
  add	a4, a4, a3
  addi	a0, a0, -1
  j		load_level_loop
load_level_copy:
# set a0 to start of "current" game memory
  la	a0, levels
  addi	a0, a0, 8
  mv	a5, a0
# a3 = total size of board
  mul	a3, a1, a2
load_level_copy_loop:
  beqz	a3, load_level_done
  lw	t0, 0(a4)
  sw	t0, 0(a5)
  addi	a3, a3, -1
  addi	a4, a4, 4
  addi	a5, a5, 4
  j		load_level_copy_loop
load_level_done:
  ret


#	INTERACTIVE
#
#	Inputs:  
#	a0 = address of board (int arr)
#	a1 = width
#	a2 = height
#
#	Outputs:
#	a0 = 1 if won, 0 else
#
#	Variables:
# 	a3 = row of player
#	a4 = col of player
#	a5 = delta row
#	a6 = delta column
#	a7 = user inputmul
#
interactive:
# push a0, a1, a2, ra
  addi	sp, sp, -16
  sw	a0, 0(sp)
  sw	a1, 4(sp)
  sw	a2, 8(sp)
  sw	ra, 12(sp)
# find player
  li	a3, 0
  li	a4, 0
interactive_find_player_loop:
# store a3, a4 for func call
  addi	sp, sp, -8
  sw	a3, 0(sp)
  sw	a4, 4(sp)
# get element
  call	get_location_flagless
  mv	t0, a0
# load a3, a4 after func call
  lw	a3, 0(sp)
  lw	a4, 4(sp)
  addi	sp, sp, 8
# load a0, a1, a2 after func call
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
# check if found player
  li	t1, 2 # player value
  beq	t0, t1, interactive_find_player_done
# increment column
  addi	a4, a4, 1
interactive_find_player_loop_compare:
  blt	a4, a1, interactive_find_player_loop
  addi	a3, a3, 1
  li	a4, 0
  blt	a3, a2, interactive_find_player_loop
interactive_find_player_done:
# store a3, a4
  addi	sp, sp, -8
  sw	a3, 0(sp)
  sw	a4, 4(sp)
# print game
  call	dump_game
# load variables after func call
  lw	a3, 0(sp)
  lw	a4, 4(sp)
  lw	a0, 8(sp)
  lw	a1, 12(sp)
  lw	a2, 16(sp)
interactive_game_loop:
# get user move
  call user_input
  li	t0, -2
  beq	a0, t0, interactive_lose
  li	t0, -3
  beq	a0, t0, interactive_reload
  mv	a5, a0
  mv	a6, a1
# load a3, a4, a0, a1, a2 after func call
  lw	a3, 0(sp)
  lw	a4, 4(sp)
  lw	a0, 8(sp)
  lw	a1, 12(sp)
  lw	a2, 16(sp)
# try move
  call	move
# store new player position
  mv	a3, a0
  mv	a4, a1
  sw	a3, 0(sp)
  sw	a4, 4(sp)
# load a0, a1, a2 after func call
  lw	a0, 8(sp)
  lw	a1, 12(sp)
  lw	a2, 16(sp)
# print game
  call dump_game
# load a3, a4, a0, a1, a2 after func call
  lw	a3, 0(sp)
  lw	a4, 4(sp)
  lw	a0, 8(sp)
  lw	a1, 12(sp)
  lw	a2, 16(sp)
# check for win
  call 	check_win
  li	t0, 1
  beq	a0, t0, interactive_win
# load a3, a4, a0, a1, a2 after func call
  lw	a3, 0(sp)
  lw	a4, 4(sp)
  lw	a0, 8(sp)
  lw	a1, 12(sp)
  lw	a2, 16(sp)
# re-loop
  j		interactive_game_loop
interactive_win:
  li	a0, 1
  j		interactive_done
interactive_reload:
  li	a0, 2
  j		interactive_done
interactive_lose:
  li	a0, 0
interactive_done:
# pop a3, a4, a0, a1, a2, ra
  lw	ra, 20(sp)
  addi	sp, sp, 24
  ret


#	USER INPUT
#
#	Outputs:
#	a0 = delta row (-2 = quit)
#	a1 = delta col
#
#	Variables:
#	t1 = user input
#	t2 = compare to valid input
#	
user_input:
# push ra to stack
  addi	sp, sp, -4
  sw	ra, 0(sp)
# get user input
  call	get_char
  mv	t1, a0
# check for valid inputs
  li	t2, 113					# quit value = 'q'
  beq	t1, t2, user_input_quit
  li	t2, 114					# quit value = 'r'
  beq	t1, t2, user_input_reload
  li	t2, 119					# up value = 'w'
  beq	t1, t2, user_input_up
  li	t2, 100					# right value = 'd'
  beq	t1, t2, user_input_right
  li	t2, 115					# down value = 's'
  beq	t1, t2, user_input_down
  li	t2, 97					# left value = 'a'
  beq	t1, t2, user_input_left
# no valid input = dont do anything
  li	a0, 0
  li	a1, 0
  j		user_input_done
user_input_up:
  li	a0, -1
  li	a1, 0
  j		user_input_done
user_input_right:
  li	a0, 0
  li	a1, 1
  j		user_input_done
user_input_down:
  li	a0, 1
  li	a1, 0
  j		user_input_done
user_input_left:
  li	a0, 0
  li	a1, -1
  j		user_input_done
user_input_quit:
  li	a0, -2
  li	a1, -2
  j		user_input_done
user_input_reload:
  li	a0, -3
  li	a1, -3
  j		user_input_done
user_input_done:
# pop ra from stack
  lw	ra, 0(sp)
  addi	sp, sp, 4
  ret

#	MOVE
#
#	Inputs:
#	a0 = address of board (int arr)
#	a1 = width
#	a2 = height
#	a3 = player row
#	a4 = player col
#	a5 = delta-row
#	a6 = delta-col
#
#	Outputs:
#	a0 = new player row
#	a1 = new player col
#  (should also modify board in place)
#
#	Variables:
#	t0 = candidate row
#	t1 = candidate col
#	t2 = element at candidate
#	t3 = wall value
#
move:
# calculate candidate position
  add	t0, a3, a5
  add	t1, a4, a6
# push a0, a1, a2, a3, a4, t0, t1, ra to stack
  addi	sp, sp, -32
  sw	a0, 0(sp)
  sw	a1, 4(sp)
  sw	a2, 8(sp)
  sw	a3, 12(sp)
  sw	a4,	16(sp)
  sw	t0, 20(sp)
  sw	t1, 24(sp)
  sw	ra, 28(sp)
# copy candidate position
  mv	a3, t0
  mv	a4, t1
# get element
  call	get_location_flagless
  mv	t2, a0
# load a0, a1, a2, a3, a4 (w/o popping)
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
  lw	a3, 12(sp)
  lw	a4,	16(sp)
# check if hit wall
  li	t3, 1				# wall value
  beq	t2, t3, move_done	# if found wall, no move necessary
# check if hit box
  li	t3, 3					  # box value
  bne	t2, t3, move_player_empty # if no box, move simply
# otherwise, check if box can move
# get box position and recalculate deltas
  lw	t0, 20(sp)
  lw	t1, 24(sp)
  sub	a5, t0, a3
  sub	a6, t1, a4
# get next pos for box
  add	a3, t0, a5
  add	a4, t1, a6
# store next pos for box
  addi	sp, sp, -8
  sw	a3, 0(sp)
  sw	a4, 4(sp)
# get element at next pos
  call get_location_flagless
  mv	t2, a0
# pop next pos for box into t4, t5
  lw	t4, 0(sp)
  lw	t5, 4(sp)
  addi	sp, sp, 8
# load a0, a1, a2, a3, a4 (w/o popping)
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
  lw	a3, 12(sp)
  lw	a4,	16(sp)
# check if box hit wall 
  li	t3, 1				# wall value
  beq	t2, t3, move_done
# check if box hit box 
  li	t3, 3				# box value
  beq	t2, t3, move_done
# otherwise, move box
# set next box pos to box
  mv	a3, t4
  mv	a4, t5
  li	a5, 3				# box value
  call set_location
# load a0, a1, a2, a3, a4 (w/o popping)
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
  lw	a3, 12(sp)
  lw	a4,	16(sp)
move_player_empty:
# move player to new position
# set element at old position to empty
  li	a5, 0				# empty value
  call set_location
# load a0, a1, a2, t0, t1 (w/o poppint)
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
  lw	t0, 20(sp)
  lw	t1, 24(sp)
# set element at new position to player
  mv	a3, t0
  mv	a4, t1
  li	a5, 2				# player value
  call set_location
# get return values 
  lw	a3, 20(sp)
  lw	a4, 24(sp)
move_done:
# default return values
  mv	a0, a3
  mv	a1, a4
# pop a0, a1, a2, a3, a4, t0, t1, ra from stack
  lw	ra, 28(sp)
  addi	sp, sp, 32
  ret


#	CHECK WIN
#	checks if game is in a won position
#
#	Inputs:	
#	a0 = address of board
#	a1 = width
#	a2 = height
#
#	Outputs:
#	a0 = 1 if won, 0 if not won
#
#	Variables:
#	a3 = cur row
#	a4 = cur col
#	s0 = flag for won (set to 0 if we find box w/o flag)
#	t0 = cur el
#	t1 = box w/o flag val = 3
#
check_win:
# push a0, a1, a2, s0, ra to stack
  addi	sp, sp, -20
  sw	a0, 0(sp)
  sw	a1, 4(sp)
  sw	a2, 8(sp)
  sw	s0, 12(sp)
  sw	ra, 16(sp)
# loop through board
  li	a3, 0
  li	a4, 0
  li	s0, 1
  j		check_win_loop_compare
check_win_loop:
# store a3, a4 for func call
  addi	sp, sp, -8
  sw	a3, 0(sp)
  sw	a4, 4(sp)
# get element
  call	get_location
  mv	t0, a0
# load a3, a4 after func call
  lw	a3, 0(sp)
  lw	a4, 4(sp)
  addi	sp, sp, 8
# load a0, a1, a2 after func call
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
# check if found box w/o flag
  li	t1, 3		#  box w/o flag value
  beq	t0, t1, check_win_failed
# increment column
  addi	a4, a4, 1
check_win_loop_compare:
  blt	a4, a1, check_win_loop
  addi	a3, a3, 1
  li	a4, 0
  blt	a3, a2, check_win_loop
  j		check_win_done
check_win_failed:
  li	s0, 0
check_win_done:
# move result into a0
  mv	a0, s0
# pop a0, a1, a2, ra from stack (only save s0 + ra)
  lw	s0, 12(sp)
  lw	ra, 16(sp)
  addi	sp, sp, 20
  ret

#	DUMP GAME
#	print board and player position
#
#	Inputs:  
#	a0 = address of board (int arr)
#	a1 = width
#	a2 = height
#	a3 = player row
#	a4 = player col
#	
#	Variables:
#	t0 = console out address
#	t1 = newline
#
dump_game:
# print player position
  # li	t0, 0x40000000
  # li	t1, 0xa
  # sw	a3, 4(t0)
  # sw	a4, 4(t0)
  # sw	t1, 0(t0)
# push ra to stack
  addi	sp, sp, -4
  sw	ra, 0(sp)
# print board
  call	print_board
# print newline
  call	put_ln
# return
  lw	ra, 0(sp)
  addi	sp, sp, 4
  ret

#	PRINT BOARD
#
#	Inputs:  
#	a0 = address of board (int arr)
#	a1 = width
#	a2 = height
#
#	Variables:
#	a3 = row
#	a4 = col
#	t0 = newline
#
print_board:
# push a0, a1, a2, ra to stack
  addi	sp, sp, -16
  sw	a0, 0(sp)
  sw	a1, 4(sp)
  sw	a2, 8(sp)
  sw	ra, 12(sp)
# loop setup
  li	a3, 0
  li	a4, 0
  j		print_board_loop_compare
print_board_loop:
# store a3, a4 for func call
  addi	sp, sp, -8
  sw	a3, 0(sp)
  sw	a4, 4(sp)
# get element
  call	get_location
# if element is wall, do advanced neighbor checking
  li	t0, 1
  bne	a0, t0, print_board_get_display
# load a3, a4 after func call
  lw	a3, 0(sp)
  lw	a4, 4(sp)
# load a0, a1, a2 after func call
  lw	a0, 8(sp)
  lw	a1, 12(sp)
  lw	a2, 16(sp)
# get display based on neighbors
  call	get_wall_display
  j		print_board_put_char
print_board_get_display:
  call 	get_display
print_board_put_char:
  call	put_char		# print ascii char
# load a3, a4 after func call
  lw	a3, 0(sp)
  lw	a4, 4(sp)
  addi	sp, sp, 8
# load a0, a1, a2 after func call
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
# increment column
  addi	a4, a4, 1
print_board_loop_compare:
# compare column
  blt	a4, a1, print_board_loop
# save to stack before printing new line
  addi	sp, sp, -8
  sw	a3, 0(sp)
  sw	a4, 4(sp)
# print new line
  call 	put_ln
# pop from stack after printing new line
  lw	a3, 0(sp)
  lw	a4, 4(sp)
  addi	sp, sp, 8
# load a0, a1, a2 after func call
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
# increment and compare row
  addi	a3, a3, 1
  li	a4, 0
  blt	a3, a2, print_board_loop
# print_board_done
# pop a0, a1, a2, ra from stack (only store ra)
  lw	ra, 12(sp)
  addi	sp, sp, 16
  ret

#	SET LOCATION
#	Sets last 3 bits of location
#
#	Inputs:
#	a0 = address of board (int arr)
#	a1 = width
#	a2 = height
#	a3 = row
#	a4 = col
#	a5 = val
#
#	Variables:
#	a6 = row * width
#	t0 = row*width + col
#	t1 = 4*t0 
#	a7 = a0 + t1 = address of element
#	t2 = current element at location
#
set_location:
# check degenerate cases
  bge	a3, a2, set_location_done
  blt	a3, zero, set_location_done
  bge	a4, a1, set_location_done
  blt	a4, zero, set_location_done
# push a0, a4, a5, ra to stack
  addi	sp, sp, -16
  sw	a0, 0(sp)
  sw	a4, 4(sp)
  sw	a5, 8(sp)
  sw	ra, 12(sp)
# multiply row * width
  mv	a0, a3
  mul	a0, a0, a1
  mv	a6, a0
# pop a0, a4, a5, ra from stack
  lw	a0, 0(sp)
  lw	a4, 4(sp)
  lw	a5, 8(sp)
  lw	ra, 12(sp)
  addi	sp, sp, 16
# index is a6 + a4
  add	t0, a6, a4
  slli	t1, t0, 2
  add	a7, a0, t1
# load prev element and clear last 3 bits
  lw	t2, 0(a7)
  srli	t2, t2, 2
  slli	t2, t2, 2
# save element
  add	a5, a5, t2
  sw	a5, 0(a7)
set_location_done:
  ret


#	GET LOCATION
#
#	Inputs:
#	a0 = address of board (int arr)
#	a1 = width
#	a2 = height
#	a3 = row
#	a4 = col
#
#	Outputs:
#	a0 = element at row, col in arr
#
#	Variables:
#	a5 = row * width
#	t0 = row*width + col
#	t1 = 4*t0 
#	a6 = a0 + t1 = address of element
#
get_location:
# check degenerate cases
  bge	a3, a2, get_location_return_null
  blt	a3, zero, get_location_return_null
  bge	a4, a1, get_location_return_null
  blt	a4, zero, get_location_return_null
# push a0, a4, ra to stack
  addi	sp, sp, -12
  sw	a0, 0(sp)
  sw	a4, 4(sp)
  sw	ra, 8(sp)
# multiply row * width
  mv	a0, a3
  mul	a0, a0, a1
  mv	a5, a0
# pop a0, a4 from stack
  lw	a0, 0(sp)
  lw	a4, 4(sp)
  lw	ra, 8(sp)
  addi	sp, sp, 12
# index is a5 + a4
  add	t0, a5, a4
  slli	t1, t0, 2
  add	a6, a0, t1
# load element
  lw	a0, 0(a6)
  ret
get_location_return_null:
  li	a0, 5		# return wall w flag for out of bounds
  ret

#	GET LOCATION FLAGLESS
#	Returns last 3 bits of location
#
#	Inputs:
#	a0 = address of board (int arr)
#	a1 = width
#	a2 = height
#	a3 = row
#	a4 = col
#
#	Outputs:
#	a0 = last 3 bits of element at row, col in arr
#
get_location_flagless:
  addi	sp, sp, -4
  sw	ra, 0(sp)
  call get_location
  andi	a0, a0, 0x3			# only return the last 3 bits
  lw	ra, 0(sp)
  addi	sp, sp, 4
  ret

#	GET DISPLAY
#	
#	Inputs:
#	a0 = numerical element
#	
#	Outputs:
#	a0 = ASCII code for display
#
#	Variables:
#	a1 = character
#	a2 = current checked value
#
get_display:
# empty
  li	a2, 0						# 0 =
  li	a1, 46						# . character
  beq	a0, a2, get_display_done
# wall
  addi	a2, a2, 1					# 1 = 
  li	a1, 35						# # character
  beq	a0, a2, get_display_done
# player
  addi	a2, a2, 1					# 2 = 
  li	a1, 115						# s character
  beq	a0, a2, get_display_done
# box
  addi	a2, a2, 1					# 3 = 
  li	a1, 111						# o character
  beq	a0, a2, get_display_done
# empty w/ flag
  addi	a2, a2, 1					# 4 = 
  li	a1, 70						# F character
  beq	a0, a2, get_display_done
# wall w/ flag
  addi	a2, a2, 1					# 5 = 
  li	a1, 35						# # character
  beq	a0, a2, get_display_done
# player w/ flag
  addi	a2, a2, 1					# 6 = 
  li	a1, 36						# $ character
  beq	a0, a2, get_display_done
# box w/ flag
  addi	a2, a2, 1					# 7 = 
  li	a1, 42						# * character
  beq	a0, a2, get_display_done
# default
  li	a1, 32						# space character
get_display_done:
  mv	a0, a1
  ret


#	GET WALL DISPLAY
#	Get display char for a wall
#	Uses neighbor checking for prettier walls
#
#	Inputs:
#	a0 = address of board (int arr)
#	a1 = width
#	a2 = height
#	a3 = row
#	a4 = col
#	
#	Outputs:
#	a0 = ASCII code for display
#
# 	Variables:
#	a5 = top or bottom
#	a6 = left or right
#
get_wall_display:
# push a0, a1, a2, a3, a4, a5, ra to stack
  li	a5, 0
  li	a6, 0
  addi	sp, sp, -32
  sw	a0, 0(sp)
  sw	a1, 4(sp)
  sw	a2, 8(sp)
  sw	a3, 12(sp)
  sw	a4, 16(sp)
  sw	a5, 20(sp)
  sw	a6, 24(sp)
  sw	ra, 28(sp)
# check top
  addi	a3, a3, -1
  call	get_location
  xori	a5, a0, 0x1		# a5 = 0 iff a0 = 1 (i.e. wall)
# load a0, a1, a2, a3, a4 after func call
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
  lw	a3, 12(sp)
  lw	a4, 16(sp)
# if found on top, don't need to check bottom
  beqz	a5, get_wall_display_check_left
# store a5 in stack
  sw	a5, 20(sp)
# check bottom
  addi	a3, a3, 1
  call	get_location
  xori	t0, a0, 0x1		# t0 = 0 iff a0 = 1 (i.e. wall)
# load a0, a1, a2, a3, a4, a5 after func call
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
  lw	a3, 12(sp)
  lw	a4, 16(sp)
  lw	a5, 20(sp)
# multiply bottom check to a5
  mul	a5, a5, t0
# store a5 in stack
  sw	a5, 20(sp)
get_wall_display_check_left:
# check left
  addi	a4, a4, -1
  call	get_location
  xori	a6, a0, 0x1		# a6 = 0 iff a0 = 1 (i.e. wall)
# load a0, a1, a2, a3, a4, a5 after func call
  lw	a0, 0(sp)
  lw	a1, 4(sp)
  lw	a2, 8(sp)
  lw	a3, 12(sp)
  lw	a4, 16(sp)
  lw	a5, 20(sp)
# if found on left, skip right check
  beqz	a6, get_wall_display_check
# store a6 in stack
  sw	a6, 24(sp)
# check right
  addi	a4, a4, 1
  call	get_location
  xori	t0, a0, 0x1		# t0 = 0 iff a0 = 1 (i.e. wall)
# load a5, a6 after func call
  lw	a5, 20(sp)
  lw	a6, 24(sp)
# multiply right check to a6
  mul	a6, a6, t0
get_wall_display_check:
  beqz	a5, get_wall_display_vertical
# no vertical
  beqz	a6, get_wall_display_horizontal
# lone
  li	a0, 35				# lone = '#'
  j		get_wall_display_done
get_wall_display_vertical:
  beqz	a6, get_wall_display_corner
# vert only
  li	a0, 124				# vert = '|'
  j		get_wall_display_done
get_wall_display_corner:
# both vert and hor
  li	a0, 43				# corner = '+'
  j		get_wall_display_done
get_wall_display_horizontal:
# hor only
  li	a0, 45				# hor = '-'
get_wall_display_done:
# pop a0, a1, a2, a3, a4, ra from stack
  lw	ra, 28(sp)
  addi	sp, sp, 32
  ret


#+------------------------------------------+
#|				Game Data					|
#+------------------------------------------+


# .section ".data.string"
  # .globl strings

# strings:
  # .byte 76, 101, 118, 101, 108, 32, 99
  # # .byte 111, 109, 112, 108, 101, 116, 101
  # .byte 100, 33

.section ".data.level"
  .globl levels

# 	LEVELS
# 	
#	Data is given in the following order:
#	- width (1 word)
# 	- height (1 word)
# 	- board array (width*height words):
#		- -1 = blank (outside)
# 		- 0 = empty (inside)
# 		- 1 = wall
# 		- 2 = player
# 		- 3 = box
#		- +4 = has flag
#
levels:
# Level '0' used for current game - max size is 30x30
  .word 30, 30
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

# Level 1:
  .word 6, 7
  .word 1, 1, 1, 1, -1, -1
  .word 1, 0, 4, 1, -1, -1
  .word 1, 0, 0, 1, 1, 1
  .word 1, 7, 2, 0, 0, 1
  .word 1, 0, 0, 3, 0, 1
  .word 1, 0, 0, 1, 1, 1
  .word 1, 1, 1, 1, -1, -1

# Level 2:
  .word 6, 7
  .word 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 1
  .word 1, 0, 1, 2, 0, 1
  .word 1, 0, 3, 7, 0, 1
  .word 1, 0, 4, 7, 0, 1
  .word 1, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1

# Level 3:
  .word 9, 6
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 1, 1, 0, 0, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 3, 0, 1
  .word 1, 0, 1, 0, 0, 1, 3, 0, 1
  .word 1, 0, 4, 0, 4, 1, 2, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 4:
  .word 8, 6
  .word 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 4, 7, 7, 3, 2, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 0, 0, 1
  .word -1, -1, -1, -1, 1, 1, 1, 1

# Level 5:
  .word 8, 7
  .word -1, 1, 1, 1, 1, 1, 1, 1
  .word -1, 1, 0, 0, 0, 0, 0, 1
  .word -1, 1, 0, 4, 3, 4, 0, 1
  .word 1, 1, 0, 3, 2, 3, 0, 1
  .word 1, 0, 0, 4, 3, 4, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1

# Level 6:
  .word 12, 6
  .word 1, 1, 1, 1, 1, 1, -1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1
  .word 1, 0, 3, 3, 0, 0, 0, 0, 0, 1, 2, 1
  .word 1, 0, 3, 0, 1, 4, 4, 4, 0, 0, 0, 1
  .word 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1

# Level 7:
  .word 7, 8
  .word 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 1
  .word 1, 0, 4, 3, 4, 0, 1
  .word 1, 0, 3, 4, 3, 0, 1
  .word 1, 0, 4, 3, 4, 0, 1
  .word 1, 0, 3, 4, 3, 0, 1
  .word 1, 0, 0, 2, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1

# Level 8:
  .word 8, 12
  .word -1, -1, 1, 1, 1, 1, 1, 1
  .word -1, -1, 1, 0, 4, 4, 2, 1
  .word -1, -1, 1, 0, 3, 3, 0, 1
  .word -1, -1, 1, 1, 0, 1, 1, 1
  .word -1, -1, -1, 1, 0, 1, -1, -1
  .word -1, -1, -1, 1, 0, 1, -1, -1
  .word 1, 1, 1, 1, 0, 1, -1, -1
  .word 1, 0, 0, 0, 0, 1, 1, -1
  .word 1, 0, 1, 0, 0, 0, 1, -1
  .word 1, 0, 0, 0, 1, 0, 1, -1
  .word 1, 1, 1, 0, 0, 0, 1, -1
  .word -1, -1, 1, 1, 1, 1, 1, -1

# Level 9:
  .word 6, 7
  .word 1, 1, 1, 1, 1, -1
  .word 1, 4, 0, 0, 1, 1
  .word 1, 2, 3, 3, 0, 1
  .word 1, 1, 0, 0, 0, 1
  .word -1, 1, 1, 0, 0, 1
  .word -1, -1, 1, 1, 4, 1
  .word -1, -1, -1, 1, 1, 1

# Level 10:
  .word 11, 8
  .word -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1
  .word -1, -1, -1, -1, -1, -1, 1, 4, 0, 0, 1
  .word -1, -1, -1, -1, -1, -1, 1, 4, 1, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 4, 1, 0, 1
  .word 1, 0, 2, 0, 3, 0, 3, 0, 3, 0, 1
  .word 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 1, -1, -1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1

# Level 11:
  .word 9, 8
  .word -1, -1, 1, 1, 1, 1, 1, 1, -1
  .word -1, -1, 1, 0, 0, 0, 0, 1, -1
  .word -1, -1, 1, 0, 1, 1, 2, 1, 1
  .word 1, 1, 1, 0, 1, 0, 3, 0, 1
  .word 1, 0, 4, 4, 1, 0, 3, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 0, 1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 12:
  .word 9, 8
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 1, -1, -1, -1
  .word 1, 0, 3, 0, 0, 1, -1, -1, -1
  .word 1, 1, 0, 3, 0, 1, 1, 1, 1
  .word -1, 1, 1, 1, 2, 4, 0, 0, 1
  .word -1, -1, 1, 0, 0, 4, 1, 0, 1
  .word -1, -1, 1, 0, 0, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1

# Level 13:
  .word 7, 9
  .word 1, 1, 1, 1, -1, -1, -1
  .word 1, 4, 0, 1, 1, -1, -1
  .word 1, 4, 2, 0, 1, -1, -1
  .word 1, 4, 0, 3, 1, -1, -1
  .word 1, 1, 3, 0, 1, 1, 1
  .word -1, 1, 0, 3, 0, 0, 1
  .word -1, 1, 0, 0, 0, 0, 1
  .word -1, 1, 0, 0, 1, 1, 1
  .word -1, 1, 1, 1, 1, -1, -1

# Level 14:
  .word 7, 6
  .word 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 1
  .word 1, 0, 1, 0, 1, 0, 1
  .word 1, 4, 0, 3, 7, 2, 1
  .word 1, 0, 0, 0, 1, 1, 1
  .word 1, 1, 1, 1, 1, -1, -1

# Level 15:
  .word 9, 7
  .word -1, -1, -1, -1, -1, 1, 1, 1, -1
  .word 1, 1, 1, 1, 1, 1, 2, 1, 1
  .word 1, 0, 0, 0, 0, 4, 7, 0, 1
  .word 1, 0, 0, 0, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 3, 1, 0, 1
  .word -1, -1, -1, -1, 1, 0, 0, 0, 1
  .word -1, -1, -1, -1, 1, 1, 1, 1, 1

# Level 16:
  .word 10, 8
  .word -1, 1, 1, 1, 1, -1, -1, -1, -1, -1
  .word -1, 1, 0, 0, 1, 1, 1, 1, -1, -1
  .word -1, 1, 0, 0, 0, 0, 0, 1, 1, -1
  .word 1, 1, 0, 1, 1, 0, 0, 0, 1, -1
  .word 1, 4, 0, 4, 1, 0, 2, 3, 1, 1
  .word 1, 0, 0, 0, 1, 0, 3, 3, 0, 1
  .word 1, 0, 0, 4, 1, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 17:
  .word 6, 7
  .word 1, 1, 1, 1, 1, -1
  .word 1, 0, 2, 0, 1, -1
  .word 1, 4, 4, 4, 1, -1
  .word 1, 3, 3, 3, 1, 1
  .word 1, 0, 0, 0, 0, 1
  .word 1, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1

# Level 18:
  .word 7, 9
  .word 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 1
  .word 1, 4, 0, 4, 0, 0, 1
  .word 1, 0, 1, 1, 0, 1, 1
  .word 1, 0, 0, 3, 0, 1, -1
  .word 1, 1, 1, 3, 0, 1, -1
  .word -1, -1, 1, 2, 0, 1, -1
  .word -1, -1, 1, 0, 0, 1, -1
  .word -1, -1, 1, 1, 1, 1, -1

# Level 19:
  .word 8, 8
  .word 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 4, 4, 0, 1
  .word 1, 0, 0, 2, 3, 3, 0, 1
  .word 1, 1, 1, 1, 1, 0, 1, 1
  .word -1, -1, -1, 1, 0, 0, 1, -1
  .word -1, -1, -1, 1, 0, 0, 1, -1
  .word -1, -1, -1, 1, 0, 0, 1, -1
  .word -1, -1, -1, 1, 1, 1, 1, -1

# Level 20:
  .word 9, 8
  .word 1, 1, 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 0, 0, 0, 1, 1, 1
  .word 1, 0, 0, 2, 3, 3, 4, 4, 1
  .word 1, 1, 1, 1, 0, 1, 1, 0, 1
  .word -1, -1, 1, 0, 0, 0, 0, 0, 1
  .word -1, -1, 1, 0, 0, 1, 1, 1, 1
  .word -1, -1, 1, 0, 0, 1, -1, -1, -1
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1

# Level 21:
  .word 7, 6
  .word 1, 1, 1, 1, -1, -1, -1
  .word 1, 0, 0, 1, 1, 1, 1
  .word 1, 0, 4, 0, 4, 0, 1
  .word 1, 0, 3, 3, 1, 2, 1
  .word 1, 1, 0, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, 1

# Level 22:
  .word 7, 9
  .word 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 0, 1, 1, 1
  .word 1, 4, 0, 4, 0, 0, 1
  .word 1, 0, 0, 0, 1, 0, 1
  .word 1, 1, 0, 1, 0, 0, 1
  .word -1, 1, 2, 3, 3, 0, 1
  .word -1, 1, 0, 0, 0, 0, 1
  .word -1, 1, 0, 0, 1, 1, 1
  .word -1, 1, 1, 1, 1, -1, -1

# Level 23:
  .word 7, 7
  .word 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 7, 0, 0, 1
  .word 1, 0, 0, 0, 0, 0, 1
  .word 1, 1, 0, 1, 0, 1, 1
  .word -1, 1, 3, 2, 4, 1, -1
  .word -1, 1, 0, 0, 0, 1, -1
  .word -1, 1, 1, 1, 1, 1, -1

# Level 24:
  .word 7, 7
  .word 1, -1, 1, 1, 1, 1, 1
  .word -1, -1, 1, 0, 0, 0, 1
  .word 1, 1, 1, 3, 3, 2, 1
  .word 1, 0, 0, 0, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 1
  .word 1, 0, 4, 0, 4, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1

# Level 25:
  .word 7, 7
  .word -1, 1, 1, 1, 1, -1, -1
  .word -1, 1, 0, 0, 1, 1, 1
  .word -1, 1, 0, 3, 3, 0, 1
  .word 1, 1, 4, 4, 4, 0, 1
  .word 1, 0, 0, 2, 3, 0, 1
  .word 1, 0, 0, 0, 1, 1, 1
  .word 1, 1, 1, 1, 1, -1, -1

# Level 26:
  .word 6, 8
  .word -1, 1, 1, 1, 1, 1
  .word -1, 1, 0, 2, 0, 1
  .word -1, 1, 0, 0, 0, 1
  .word 1, 1, 1, 3, 0, 1
  .word 1, 0, 4, 4, 4, 1
  .word 1, 0, 3, 3, 0, 1
  .word 1, 1, 1, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1

# Level 27:
  .word 7, 7
  .word 1, 1, 1, 1, 1, 1, -1
  .word 1, 0, 0, 0, 4, 1, -1
  .word 1, 0, 1, 1, 0, 1, 1
  .word 1, 0, 0, 3, 3, 2, 1
  .word 1, 0, 1, 0, 0, 0, 1
  .word 1, 4, 0, 0, 1, 1, 1
  .word 1, 1, 1, 1, 1, -1, -1

# Level 28:
  .word 7, 7
  .word 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 0, 1, -1, -1
  .word 1, 0, 2, 0, 1, -1, -1
  .word 1, 0, 3, 3, 1, 1, 1
  .word 1, 1, 4, 0, 4, 0, 1
  .word -1, 1, 0, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, 1

# Level 29:
  .word 11, 9
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, -1
  .word -1, -1, -1, -1, -1, 1, 0, 0, 0, 1, 1
  .word -1, -1, -1, -1, -1, 1, 0, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1
  .word 1, 1, 0, 0, 0, 0, 0, 1, 4, 0, 1
  .word 1, 0, 3, 0, 3, 0, 2, 0, 0, 1, 1
  .word 1, 0, 1, 1, 1, 1, 1, 1, 4, 1, -1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, -1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1

# Level 30:
  .word 6, 7
  .word 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 1, 1, 1
  .word 1, 0, 3, 3, 0, 1
  .word 1, 4, 4, 4, 0, 1
  .word 1, 0, 2, 3, 0, 1
  .word 1, 0, 0, 0, 1, 1
  .word 1, 1, 1, 1, 1, -1

# Level 31:
  .word 7, 7
  .word -1, -1, 1, 1, 1, 1, -1
  .word -1, 1, 1, 0, 0, 1, -1
  .word 1, 1, 2, 3, 4, 1, 1
  .word 1, 0, 3, 3, 0, 0, 1
  .word 1, 0, 4, 0, 4, 0, 1
  .word 1, 1, 1, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, 1

# Level 32:
  .word 7, 7
  .word -1, 1, 1, 1, 1, -1, -1
  .word 1, 1, 0, 0, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 1
  .word 1, 4, 7, 7, 3, 2, 1
  .word 1, 0, 0, 0, 1, 1, 1
  .word 1, 1, 0, 0, 1, -1, -1
  .word -1, 1, 1, 1, 1, -1, -1

# Level 33:
  .word 7, 7
  .word 1, 1, 1, 1, 1, 1, 1
  .word 1, 4, 0, 1, 0, 0, 1
  .word 1, 0, 0, 3, 0, 0, 1
  .word 1, 4, 0, 3, 1, 2, 1
  .word 1, 0, 0, 3, 0, 0, 1
  .word 1, 4, 0, 1, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1

# Level 34:
  .word 9, 6
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 1, 1, 0, 0, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 2, 3, 7, 7, 7, 4, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 35:
  .word 7, 10
  .word -1, -1, 1, 1, 1, 1, -1
  .word -1, 1, 1, 0, 0, 1, -1
  .word -1, 1, 4, 0, 3, 1, -1
  .word -1, 1, 4, 3, 0, 1, -1
  .word -1, 1, 4, 3, 0, 1, -1
  .word -1, 1, 4, 3, 0, 1, -1
  .word -1, 1, 4, 0, 3, 1, 1
  .word -1, 1, 0, 0, 0, 2, 1
  .word -1, 1, 1, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, 1

# Level 36:
  .word 15, 5
  .word 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 3, 0, 3, 0, 3, 0, 3, 0, 3, 0, 2, 0, 1
  .word 1, 0, 4, 4, 4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 37:
  .word 9, 8
  .word -1, -1, -1, -1, -1, -1, 1, 1, 1
  .word 1, 1, 1, 1, 1, -1, 1, 4, 1
  .word 1, 0, 0, 0, 1, 1, 1, 4, 1
  .word 1, 0, 0, 0, 3, 0, 1, 4, 1
  .word 1, 0, 3, 0, 0, 3, 0, 0, 1
  .word 1, 1, 1, 1, 1, 2, 1, 0, 1
  .word -1, -1, -1, -1, 1, 0, 0, 0, 1
  .word -1, -1, -1, -1, 1, 1, 1, 1, 1

# Level 38:
  .word 10, 7
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 1, 1, 4, 1, 1, 1, 0, 1
  .word 1, 0, 1, 0, 3, 3, 0, 4, 0, 1
  .word 1, 0, 4, 0, 2, 3, 1, 1, 0, 1
  .word 1, 1, 1, 1, 1, 0, 0, 0, 0, 1
  .word -1, -1, -1, -1, 1, 1, 1, 1, 1, 1

# Level 39:
  .word 10, 9
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 1, 1, 1, -1, -1
  .word 1, 0, 1, 0, 1, 0, 4, 1, -1, -1
  .word 1, 0, 0, 0, 0, 3, 0, 1, 1, 1
  .word 1, 1, 1, 0, 1, 3, 4, 0, 0, 1
  .word 1, 0, 0, 0, 1, 2, 0, 0, 0, 1
  .word 1, 0, 1, 0, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 1, -1, -1, -1, -1, -1
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 40:
  .word 7, 6
  .word -1, 1, 1, 1, 1, 1, -1
  .word -1, 1, 0, 0, 0, 1, -1
  .word 1, 1, 0, 0, 0, 1, 1
  .word 1, 0, 3, 3, 3, 0, 1
  .word 1, 0, 4, 6, 4, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1

# Level 41:
  .word 8, 6
  .word 1, 1, 1, 1, 1, 1, 1, -1
  .word 1, 0, 0, 0, 0, 0, 1, -1
  .word 1, 2, 3, 3, 3, 0, 1, 1
  .word 1, 0, 0, 1, 4, 4, 4, 1
  .word 1, 1, 0, 0, 0, 0, 1, 1
  .word -1, 1, 1, 1, 1, 1, 1, -1

# Level 42:
  .word 7, 8
  .word -1, -1, -1, 1, 1, 1, 1
  .word -1, -1, -1, 1, 0, 0, 1
  .word -1, -1, -1, 1, 2, 0, 1
  .word 1, 1, 1, 1, 3, 4, 1
  .word 1, 0, 0, 0, 3, 4, 1
  .word 1, 0, 1, 0, 3, 4, 1
  .word 1, 0, 0, 0, 0, 1, 1
  .word 1, 1, 1, 1, 1, 1, -1

# Level 43:
  .word 9, 9
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1
  .word -1, -1, -1, -1, -1, 1, 0, 2, 1
  .word -1, -1, -1, -1, -1, 1, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 0, 4, 1
  .word 1, 0, 0, 0, 3, 0, 0, 4, 1
  .word 1, 0, 0, 3, 3, 1, 0, 4, 1
  .word 1, 0, 0, 0, 0, 1, 1, 1, 1
  .word 1, 1, 1, 0, 0, 1, -1, -1, -1
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1

# Level 44:
  .word 5, 3
  .word 1, 1, 1, 1, 1
  .word 1, 2, 3, 4, 1
  .word 1, 1, 1, 1, 1

# Level 45:
  .word 6, 7
  .word 1, 1, 1, 1, 1, 1
  .word 1, 4, 4, 4, 0, 1
  .word 1, 0, 0, 3, 0, 1
  .word 1, 0, 1, 3, 1, 1
  .word 1, 0, 0, 3, 0, 1
  .word 1, 0, 0, 2, 0, 1
  .word 1, 1, 1, 1, 1, 1

# Level 46:
  .word 7, 8
  .word -1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 0, 0, 0, 0, 1
  .word 1, 0, 0, 1, 1, 0, 1
  .word 1, 0, 1, 0, 3, 0, 1
  .word 1, 0, 0, 7, 0, 4, 1
  .word 1, 1, 0, 1, 2, 1, 1
  .word -1, 1, 0, 0, 0, 1, -1
  .word -1, 1, 1, 1, 1, 1, -1

# Level 47:
  .word 11, 7
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1, -1, -1
  .word 1, 1, 1, 0, 0, 0, 0, 0, 1, -1, -1
  .word 1, 0, 3, 0, 3, 0, 0, 0, 1, -1, -1
  .word 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1
  .word 1, 0, 2, 0, 4, 0, 4, 0, 0, 0, 1
  .word 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, -1, 1, 1, 1, 1, 1

# Level 48:
  .word 8, 8
  .word 1, 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 2, 0, 1, -1, -1
  .word 1, 0, 0, 1, 0, 1, 1, -1
  .word 1, 0, 4, 1, 0, 0, 1, 1
  .word 1, 0, 4, 3, 3, 3, 0, 1
  .word 1, 0, 4, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 0, 0, 0, 1
  .word -1, -1, -1, 1, 1, 1, 1, 1

# Level 49:
  .word 8, 10
  .word 1, 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 2, 0, 0, 1, -1, -1
  .word 1, 0, 3, 1, 0, 1, -1, -1
  .word 1, 0, 3, 0, 0, 1, -1, -1
  .word 1, 0, 3, 0, 1, 1, -1, -1
  .word 1, 1, 1, 0, 1, 1, 1, 1
  .word -1, 1, 0, 0, 1, 0, 0, 1
  .word -1, 1, 4, 4, 4, 0, 0, 1
  .word -1, 1, 0, 0, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, 1, 1

# Level 50:
  .word 10, 7
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 1, 1, 0, 0, 1, 1, 1, 1, 1
  .word 1, 0, 0, 3, 0, 0, 2, 4, 4, 1
  .word 1, 0, 3, 0, 0, 0, 0, 1, 0, 1
  .word 1, 1, 1, 0, 1, 1, 1, 1, 0, 1
  .word -1, -1, 1, 0, 0, 0, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 51:
  .word 8, 7
  .word 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 0, 0, 1, 1, 1, -1, -1
  .word 1, 0, 0, 0, 0, 1, 1, 1
  .word 1, 0, 0, 3, 7, 2, 0, 1
  .word 1, 1, 1, 0, 4, 1, 0, 1
  .word -1, -1, 1, 0, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, 1, 1

# Level 52:
  .word 6, 8
  .word -1, -1, 1, 1, 1, 1
  .word 1, 1, 1, 0, 2, 1
  .word 1, 0, 0, 3, 0, 1
  .word 1, 0, 0, 7, 4, 1
  .word 1, 0, 0, 7, 4, 1
  .word 1, 0, 0, 3, 0, 1
  .word 1, 1, 1, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1

# Level 53:
  .word 7, 7
  .word -1, 1, 1, 1, 1, 1, -1
  .word 1, 1, 4, 0, 4, 1, 1
  .word 1, 0, 7, 0, 7, 0, 1
  .word 1, 0, 0, 1, 0, 0, 1
  .word 1, 0, 3, 0, 3, 0, 1
  .word 1, 1, 0, 2, 0, 1, 1
  .word -1, 1, 1, 1, 1, 1, -1

# Level 54:
  .word 12, 8
  .word -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1
  .word -1, -1, -1, -1, -1, -1, 1, 0, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, 1, 0, 4, 0, 0, 1
  .word 1, 1, 1, 0, 0, 1, 1, 1, 4, 0, 0, 1
  .word 1, 0, 3, 0, 0, 3, 0, 0, 4, 0, 1, 1
  .word 1, 0, 2, 3, 3, 0, 1, 0, 4, 0, 1, -1
  .word 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, -1
  .word -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 55:
  .word 10, 8
  .word 1, 1, 1, 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 2, 0, 1, 0, 0, 1, -1, -1
  .word 1, 0, 0, 0, 0, 0, 0, 1, -1, -1
  .word 1, 1, 1, 1, 1, 3, 0, 1, -1, -1
  .word -1, -1, -1, -1, 1, 0, 0, 1, 1, 1
  .word -1, 1, 1, -1, 1, 3, 0, 4, 4, 1
  .word -1, 1, 1, -1, 1, 0, 0, 1, 1, 1
  .word -1, -1, -1, -1, 1, 1, 1, 1, -1, -1

# Level 56:
  .word 7, 6
  .word 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 0, 1, 1, 1
  .word 1, 0, 0, 3, 0, 0, 1
  .word 1, 1, 7, 0, 4, 0, 1
  .word -1, 1, 0, 0, 0, 2, 1
  .word -1, 1, 1, 1, 1, 1, 1

# Level 57:
  .word 8, 9
  .word -1, -1, 1, 1, 1, 1, -1, -1
  .word -1, -1, 1, 0, 0, 1, -1, -1
  .word -1, -1, 1, 2, 0, 1, -1, -1
  .word -1, -1, 1, 0, 0, 1, -1, -1
  .word 1, 1, 1, 0, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 7, 0, 1
  .word 1, 0, 0, 3, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 4, 0, 1
  .word -1, -1, -1, -1, 1, 1, 1, 1

# Level 58:
  .word 7, 7
  .word 1, 1, 1, 1, -1, -1, -1
  .word 1, 0, 0, 1, 1, 1, 1
  .word 1, 4, 7, 3, 0, 0, 1
  .word 1, 0, 4, 3, 1, 0, 1
  .word 1, 1, 0, 2, 0, 0, 1
  .word -1, 1, 0, 0, 0, 1, 1
  .word -1, 1, 1, 1, 1, 1, -1

# Level 59:
  .word 13, 9
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, -1
  .word 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 2, 1, 1
  .word 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 1, 0, 0, 3, 0, 0, 0, 1, 0, 0, 1
  .word 1, 0, 3, 3, 0, 1, 1, 1, 1, 1, 0, 0, 1
  .word 1, 1, 1, 0, 0, 1, -1, 1, 0, 4, 4, 4, 1
  .word -1, -1, 1, 1, 1, 1, -1, 1, 0, 0, 0, 0, 1
  .word -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1

# Level 60:
  .word 10, 10
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word -1, 1, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 2, 1, 1, 1, 1, 1, 0, 1
  .word 1, 0, 0, 1, 0, 0, 0, 1, 0, 1
  .word 1, 0, 0, 1, 0, 0, 0, 3, 4, 1
  .word 1, 0, 0, 1, 1, 3, 1, 1, 4, 1
  .word 1, 1, 3, 1, 1, 0, 0, 1, 4, 1
  .word 1, 0, 0, 0, 3, 0, 0, 1, 4, 1
  .word 1, 0, 0, 0, 1, 0, 0, 1, 1, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, -1, -1

# Level 61:
  .word 9, 10
  .word 1, 1, 1, 1, 1, 1, 1, 1, -1
  .word 1, 0, 0, 0, 0, 0, 0, 1, -1
  .word 1, 0, 1, 1, 1, 1, 0, 1, -1
  .word 1, 0, 1, 4, 4, 4, 2, 1, -1
  .word 1, 0, 1, 1, 1, 3, 1, 1, 1
  .word 1, 0, 1, 0, 0, 0, 0, 0, 1
  .word 1, 0, 0, 3, 3, 0, 3, 0, 1
  .word 1, 1, 1, 1, 0, 0, 0, 1, 1
  .word -1, -1, -1, 1, 4, 1, 1, 1, -1
  .word -1, -1, -1, 1, 1, 1, -1, -1, -1

# Level 62:
  .word 13, 6
  .word -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1
  .word 1, 0, 0, 3, 3, 3, 4, 4, 4, 4, 3, 2, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1
  .word 1, 0, 0, 0, 1, 1, 1, 1, -1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1

# Level 63:
  .word 19, 6
  .word 1, 1, 1, 1, 1, -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 4, 1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 4, 3, 0, 0, 0, 0, 2, 0, 1
  .word -1, -1, 1, 0, 0, 1, -1, -1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, -1, -1, 1, 1, 1, 1, -1, -1, 1, 1, 1, 1, 1

# Level 64:
  .word 10, 9
  .word -1, 1, 1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 1, 0, 0, 0, 0, 1, -1, -1, -1
  .word 1, 0, 0, 0, 3, 0, 1, -1, -1, -1
  .word 1, 0, 0, 3, 3, 0, 1, -1, -1, -1
  .word 1, 1, 1, 0, 4, 1, 1, 1, 1, 1
  .word -1, -1, 1, 1, 4, 1, 0, 2, 0, 1
  .word -1, -1, -1, 1, 4, 0, 0, 3, 0, 1
  .word -1, -1, -1, 1, 4, 0, 1, 1, 1, 1
  .word -1, -1, -1, 1, 1, 1, 1, -1, -1, -1

# Level 65:
  .word 9, 9
  .word -1, -1, 1, 1, 1, 1, 1, 1, -1
  .word -1, -1, 1, 0, 0, 0, 0, 1, -1
  .word -1, -1, 1, 0, 0, 3, 0, 1, -1
  .word -1, 1, 1, 1, 1, 3, 0, 1, -1
  .word 1, 1, 0, 3, 0, 3, 0, 1, -1
  .word 1, 4, 4, 4, 4, 1, 0, 1, 1
  .word 1, 0, 0, 0, 0, 0, 2, 0, 1
  .word 1, 1, 0, 0, 1, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 66:
  .word 9, 14
  .word -1, -1, -1, 1, 1, 1, -1, -1, -1
  .word -1, -1, -1, 1, 2, 1, -1, -1, -1
  .word -1, 1, 1, 1, 3, 1, 1, 1, -1
  .word 1, 1, 0, 0, 4, 0, 0, 1, 1
  .word 1, 0, 0, 1, 0, 1, 0, 0, 1
  .word 1, 0, 1, 0, 0, 0, 1, 0, 1
  .word 1, 0, 1, 0, 0, 0, 1, 0, 1
  .word 1, 0, 1, 0, 0, 0, 1, 0, 1
  .word 1, 0, 0, 1, 0, 1, 0, 0, 1
  .word 1, 1, 0, 3, 0, 3, 0, 1, 1
  .word -1, 1, 1, 4, 0, 4, 1, 1, -1
  .word -1, -1, 1, 0, 0, 0, 1, -1, -1
  .word -1, -1, 1, 0, 0, 0, 1, -1, -1
  .word -1, -1, 1, 1, 1, 1, 1, -1, -1

# Level 67:
  .word 7, 8
  .word 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 0, 1, 1, -1
  .word 1, 0, 1, 0, 0, 1, -1
  .word 1, 2, 3, 7, 4, 1, 1
  .word 1, 1, 0, 0, 4, 0, 1
  .word -1, 1, 0, 3, 1, 0, 1
  .word -1, 1, 1, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, 1

# Level 68:
  .word 10, 7
  .word -1, 1, 1, 1, 1, -1, -1, -1, -1, -1
  .word -1, 1, 0, 0, 1, 1, 1, 1, 1, 1
  .word 1, 1, 0, 0, 0, 0, 3, 0, 0, 1
  .word 1, 0, 4, 1, 0, 3, 0, 0, 0, 1
  .word 1, 0, 4, 1, 3, 1, 1, 1, 1, 1
  .word 1, 0, 4, 2, 0, 1, -1, -1, -1, -1
  .word 1, 1, 1, 1, 1, 1, -1, -1, -1, -1

# Level 69:
  .word 11, 8
  .word 1, 1, 1, 1, -1, -1, 1, 1, 1, 1, -1
  .word 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, -1
  .word 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, -1
  .word 1, 0, 0, 1, 0, 0, 0, 0, 3, 1, 1
  .word 1, 0, 0, 4, 0, 4, 1, 3, 0, 0, 1
  .word 1, 2, 0, 1, 1, 0, 1, 0, 3, 0, 1
  .word 1, 0, 0, 0, 4, 0, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 70:
  .word 8, 10
  .word 1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 0, 2, 0, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 3, 0, 3, 3, 0, 1
  .word 1, 1, 3, 1, 1, 0, 0, 1
  .word 1, 0, 0, 0, 1, 1, 1, 1
  .word 1, 0, 4, 4, 0, 0, 1, -1
  .word 1, 1, 4, 4, 0, 0, 1, -1
  .word -1, 1, 1, 1, 0, 0, 1, -1
  .word -1, -1, -1, 1, 1, 1, 1, -1

# Level 71:
  .word 13, 9
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1
  .word 1, 0, 3, 2, 3, 0, 1, 0, 4, 0, 0, 4, 1
  .word 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1
  .word 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1
  .word 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1
  .word 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 72:
  .word 10, 11
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1, -1
  .word -1, 1, 1, 0, 0, 1, 1, 1, 1, 1
  .word -1, 1, 0, 0, 3, 0, 0, 2, 0, 1
  .word -1, 1, 0, 0, 3, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 0, 1, 1, 1, 1, 1
  .word 1, 0, 0, 1, 0, 0, 0, 1, -1, -1
  .word 1, 0, 0, 0, 0, 3, 0, 1, -1, -1
  .word 1, 0, 4, 4, 1, 0, 0, 1, -1, -1
  .word 1, 0, 0, 4, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 1, 1, -1, -1, -1, -1, -1
  .word 1, 1, 1, 1, -1, -1, -1, -1, -1, -1

# Level 73:
  .word 8, 10
  .word 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 0, 0, 1, 1, 1, 1, 1
  .word 1, 0, 3, 3, 0, 3, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 0, 1, 1, 0, 1, 1
  .word 1, 4, 4, 4, 1, 2, 1, -1
  .word 1, 0, 1, 1, 1, 0, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 0, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1

# Level 74:
  .word 11, 8
  .word -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1
  .word -1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
  .word -1, 1, 3, 0, 2, 1, 0, 0, 0, 4, 1
  .word 1, 1, 0, 1, 3, 3, 0, 0, 0, 4, 1
  .word 1, 0, 0, 3, 0, 0, 1, 1, 4, 4, 1
  .word 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1
  .word 1, 1, 1, 0, 0, 0, 1, -1, -1, -1, -1
  .word -1, -1, 1, 1, 1, 1, 1, -1, -1, -1, -1

# Level 75:
  .word 10, 7
  .word -1, 1, 1, 1, 1, 1, 1, 1, -1, -1
  .word 1, 1, 0, 4, 4, 4, 4, 1, 1, -1
  .word 1, 0, 0, 0, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 3, 0, 3, 0, 2, 1
  .word 1, 1, 1, 0, 0, 3, 0, 3, 0, 1
  .word -1, -1, 1, 1, 1, 0, 0, 0, 0, 1
  .word -1, -1, -1, -1, 1, 1, 1, 1, 1, 1

# Level 76:
  .word 10, 11
  .word -1, 1, 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 1, 0, 0, 0, 1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 0, 1, 1, 1, 1, 1
  .word 1, 0, 0, 1, 4, 1, 0, 0, 0, 1
  .word 1, 2, 0, 1, 4, 1, 0, 3, 0, 1
  .word 1, 0, 0, 1, 4, 1, 0, 0, 1, 1
  .word 1, 0, 0, 0, 0, 1, 0, 0, 1, -1
  .word 1, 1, 0, 0, 1, 1, 3, 3, 1, -1
  .word -1, 1, 1, 0, 0, 0, 0, 0, 1, -1
  .word -1, -1, 1, 0, 0, 1, 1, 1, 1, -1
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1, -1

# Level 77:
  .word 11, 7
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1
  .word 1, 0, 2, 0, 4, 4, 4, 4, 0, 1, -1
  .word 1, 0, 0, 0, 1, 1, 1, 1, 3, 1, 1
  .word 1, 1, 0, 1, 0, 0, 3, 0, 3, 0, 1
  .word -1, 1, 0, 3, 0, 0, 0, 0, 0, 0, 1
  .word -1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1
  .word -1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 78:
  .word 11, 8
  .word -1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 1, 0, 0, 0, 0, 0, 1, 1, -1, -1
  .word 1, 0, 0, 3, 0, 3, 0, 0, 1, -1, -1
  .word 1, 0, 3, 0, 3, 0, 3, 0, 1, -1, -1
  .word 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1
  .word -1, 1, 2, 0, 0, 4, 4, 4, 4, 4, 1
  .word -1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1, -1, -1

# Level 79:
  .word 10, 6
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word -1, 1, 0, 0, 0, 0, 1, 0, 0, 1
  .word 1, 1, 0, 3, 1, 3, 1, 0, 0, 1
  .word 1, 0, 0, 4, 3, 4, 2, 0, 0, 1
  .word 1, 0, 0, 4, 1, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 80:
  .word 10, 11
  .word 1, 1, 1, 1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 4, 0, 1, 1, 0, 4, 1
  .word 1, 0, 3, 1, 0, 0, 0, 0, 4, 1
  .word 1, 1, 0, 1, 1, 0, 1, 0, 4, 1
  .word -1, 1, 0, 0, 0, 0, 1, 0, 0, 1
  .word -1, 1, 1, 1, 1, 0, 1, 0, 0, 1
  .word -1, -1, 1, 0, 2, 3, 0, 1, 1, 1
  .word -1, -1, 1, 0, 3, 3, 0, 1, -1, -1
  .word -1, -1, 1, 0, 0, 0, 0, 1, -1, -1
  .word -1, -1, 1, 1, 1, 1, 1, 1, -1, -1

# Level 81:
  .word 6, 9
  .word -1, 1, 1, 1, 1, 1
  .word -1, 1, 0, 0, 0, 1
  .word -1, 1, 0, 4, 0, 1
  .word 1, 1, 0, 7, 0, 1
  .word 1, 0, 0, 7, 1, 1
  .word 1, 0, 0, 2, 1, 1
  .word 1, 1, 0, 3, 0, 1
  .word -1, 1, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1

# Level 82:
  .word 8, 8
  .word 1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 1, 1, -1
  .word 1, 0, 4, 0, 0, 0, 1, 1
  .word 1, 1, 7, 1, 3, 0, 0, 1
  .word 1, 0, 4, 1, 0, 3, 0, 1
  .word 1, 0, 2, 1, 1, 0, 1, 1
  .word 1, 0, 0, 0, 0, 0, 1, -1
  .word 1, 1, 1, 1, 1, 1, 1, -1

# Level 83:
  .word 8, 10
  .word 1, 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 0, 0, 1, 1, -1
  .word 1, 0, 3, 0, 3, 0, 1, 1
  .word 1, 1, 0, 3, 3, 0, 0, 1
  .word -1, 1, 0, 1, 0, 0, 0, 1
  .word -1, 1, 0, 1, 1, 0, 1, 1
  .word -1, 1, 0, 0, 4, 0, 4, 1
  .word -1, 1, 0, 2, 4, 0, 4, 1
  .word -1, 1, 0, 0, 1, 1, 1, 1
  .word -1, 1, 1, 1, 1, -1, -1, -1

# Level 84:
  .word 12, 10
  .word 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 0, 0, 4, 4, 4, 0, 1, -1, -1, -1, -1
  .word 1, 0, 0, 1, 1, 1, 0, 1, 1, -1, -1, -1
  .word 1, 0, 0, 1, 0, 3, 0, 0, 1, -1, -1, -1
  .word 1, 1, 0, 1, 2, 3, 0, 0, 1, -1, -1, -1
  .word -1, 1, 0, 1, 0, 3, 0, 0, 1, -1, -1, -1
  .word -1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1
  .word -1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word -1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, -1, 1, 1, 1, 1, 1

# Level 85:
  .word 11, 11
  .word -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1
  .word -1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1
  .word -1, 1, 0, 3, 0, 0, 0, 0, 0, 0, 1
  .word -1, 1, 0, 0, 0, 3, 0, 3, 0, 0, 1
  .word -1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 0, 1, 0, 4, 0, 0, 1, -1, -1
  .word 1, 0, 0, 1, 0, 1, 0, 0, 1, -1, -1
  .word 1, 0, 0, 2, 0, 4, 0, 1, 1, -1, -1
  .word 1, 1, 0, 1, 0, 1, 0, 1, -1, -1, -1
  .word -1, 1, 0, 0, 0, 4, 0, 1, -1, -1, -1
  .word -1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1

# Level 86:
  .word 9, 8
  .word -1, -1, -1, -1, 1, 1, 1, 1, -1
  .word -1, -1, 1, 1, 1, 0, 0, 1, 1
  .word -1, 1, 1, 0, 3, 0, 0, 0, 1
  .word 1, 1, 0, 3, 0, 0, 1, 0, 1
  .word 1, 0, 2, 1, 3, 3, 0, 0, 1
  .word 1, 0, 4, 4, 0, 0, 1, 1, 1
  .word 1, 0, 4, 4, 1, 1, 1, -1, -1
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1

# Level 87:
  .word 9, 10
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 1, 1, 0, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 0, 4, 4, 4, 0, 4, 1
  .word 1, 1, 3, 1, 1, 1, 1, 1, 1
  .word 1, 0, 3, 0, 0, 1, -1, -1, -1
  .word 1, 0, 0, 0, 3, 1, 1, 1, -1
  .word 1, 1, 0, 0, 3, 0, 0, 1, -1
  .word -1, 1, 1, 0, 2, 0, 0, 1, -1
  .word -1, -1, 1, 1, 1, 1, 1, 1, -1

# Level 88:
  .word 11, 12
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1, -1, -1
  .word -1, 1, -1, 1, 1, 1, 0, 0, 1, -1, -1
  .word -1, 1, -1, 1, 0, 0, 0, 0, 1, -1, -1
  .word -1, 1, -1, 1, 0, 0, 1, 0, 1, -1, -1
  .word -1, 1, -1, 1, 3, 0, 1, 4, 1, -1, -1
  .word -1, 1, -1, 1, 0, 0, 1, 0, 1, -1, 1
  .word -1, 1, -1, 1, 3, 0, 1, 4, 1, -1, 1
  .word -1, -1, -1, 1, 0, 0, 1, 0, 1, -1, 1
  .word 1, 1, 1, 1, 3, 0, 1, 4, 1, -1, 1
  .word 1, 0, 2, 0, 0, 0, 0, 0, 1, -1, 1
  .word 1, 0, 0, 0, 1, 0, 0, 1, 1, -1, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1

# Level 89:
  .word 10, 9
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 1, 1, 0, 0, 0, 1
  .word 1, 0, 3, 0, 0, 3, 2, 1, 0, 1
  .word 1, 1, 1, 1, 0, 1, 0, 3, 0, 1
  .word -1, -1, -1, 1, 4, 1, 0, 0, 1, 1
  .word -1, 1, -1, 1, 4, 1, 0, 3, 1, -1
  .word -1, 1, -1, 1, 4, 0, 0, 0, 1, -1
  .word -1, 1, -1, 1, 4, 0, 0, 0, 1, -1
  .word -1, -1, -1, 1, 1, 1, 1, 1, 1, -1

# Level 90:
  .word 10, 7
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, -1
  .word -1, 1, 0, 0, 2, 0, 0, 0, 1, -1
  .word -1, 1, 0, 3, 0, 0, 3, 0, 1, -1
  .word 1, 1, 1, 0, 1, 1, 0, 1, 1, 1
  .word 1, 0, 0, 3, 4, 4, 3, 0, 0, 1
  .word 1, 0, 0, 0, 4, 4, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 91:
  .word 11, 5
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 4, 1, 1, 0, 0, 1
  .word 1, 0, 3, 3, 2, 4, 4, 3, 3, 0, 1
  .word 1, 0, 0, 0, 1, 1, 4, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 92:
  .word 15, 10
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1
  .word -1, -1, 1, 0, 0, 1, -1, -1, -1, -1, 1, 1, 1, 1, 1
  .word -1, -1, 1, 0, 0, 1, -1, -1, -1, -1, 1, 0, 0, 0, 1
  .word -1, -1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 4, 1, 0, 1
  .word 1, 1, 1, 1, 0, 0, 3, 0, 0, 0, 0, 4, 0, 0, 1
  .word 1, 0, 0, 0, 3, 3, 1, 0, 1, 1, 1, 4, 1, 0, 1
  .word 1, 0, 0, 0, 1, 0, 0, 0, 1, -1, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, 1, 2, 0, 1, 1
  .word -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 0, 0, 1, -1
  .word -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, -1

# Level 93:
  .word 11, 11
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1
  .word 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1
  .word 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1
  .word 1, 0, 0, 3, 0, 1, 0, 3, 0, 0, 1
  .word 1, 0, 0, 0, 7, 4, 7, 0, 0, 0, 1
  .word 1, 1, 1, 1, 4, 2, 4, 1, 1, 1, 1
  .word 1, 0, 0, 0, 7, 4, 7, 0, 0, 0, 1
  .word 1, 0, 0, 3, 0, 1, 0, 3, 0, 0, 1
  .word 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1
  .word 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1

# Level 94:
  .word 9, 8
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 2, 0, 1, 0, 0, 0, 1
  .word 1, 0, 3, 0, 3, 0, 0, 0, 1
  .word 1, 1, 3, 1, 1, 1, 0, 1, 1
  .word 1, 0, 0, 4, 4, 4, 0, 0, 1
  .word 1, 0, 0, 0, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 0, 0, 1
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1

# Level 95:
  .word 8, 8
  .word 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 2, 0, 0, 0, 0, 0, 1
  .word 1, 0, 4, 3, 3, 4, 0, 1
  .word 1, 0, 3, 4, 4, 3, 0, 1
  .word 1, 0, 3, 4, 4, 3, 0, 1
  .word 1, 0, 4, 3, 3, 4, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1

# Level 96:
  .word 11, 11
  .word -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1
  .word -1, -1, 1, 0, 0, 0, 0, 1, -1, -1, -1
  .word -1, -1, 1, 0, 0, 0, 0, 1, -1, -1, -1
  .word 1, 1, 1, 1, 1, 0, 0, 1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 4, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 3, 2, 3, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 4, 1, 0, 0, 0, 1
  .word -1, -1, -1, 1, 1, 0, 1, 1, 0, 1, 1
  .word -1, -1, -1, 1, 0, 0, 0, 3, 4, 1, -1
  .word -1, -1, -1, 1, 0, 0, 0, 1, 1, 1, -1
  .word -1, -1, -1, 1, 1, 1, 1, 1, -1, -1, -1

# Level 97:
  .word 14, 10
  .word -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1
  .word -1, -1, -1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 0, 3, 0, 3, 4, 4, 4, 4, 4, 1
  .word 1, 0, 0, 0, 3, 0, 0, 0, 1, 1, 1, 1, 1, 1
  .word 1, 2, 1, 1, 1, 0, 1, 1, 1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 3, 0, 0, 1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 3, 0, 1, 0, 1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 1, 0, 1, 0, 0, 1, -1, -1, -1, -1, -1, -1, -1
  .word -1, 1, 0, 0, 0, 0, 1, -1, -1, -1, -1, -1, -1, -1
  .word -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1

# Level 98:
  .word 16, 10
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 3, 0, 1, 1, 1, 0, 4, 1, -1, -1, -1, -1, -1
  .word 1, 0, 3, 0, 0, 0, 3, 0, 0, 4, 1, -1, -1, -1, -1, -1
  .word 1, 1, 0, 3, 1, 1, 1, 1, 1, 4, 1, -1, 1, 1, 1, 1
  .word 1, 0, 3, 0, 0, 1, -1, 1, 0, 4, 1, 1, 1, 0, 0, 1
  .word 1, 0, 0, 0, 0, 1, -1, 1, 0, 4, 1, 0, 0, 2, 0, 1
  .word 1, 1, 1, 0, 0, 1, -1, 1, 0, 0, 0, 0, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, -1, 1, 1, 0, 0, 0, 0, 0, 1, 1
  .word -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, -1

# Level 99:
  .word 22, 10
  .word -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, -1, -1
  .word -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 0, 0, 0, 1, -1, -1
  .word 1, 1, 1, 1, 1, 1, 1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, -1, -1
  .word 1, 0, 0, 0, 0, 0, 1, -1, -1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, -1, -1
  .word 1, 0, 0, 2, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1
  .word 1, 0, 0, 1, 0, 0, 0, 0, 4, 4, 4, 4, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1
  .word 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 3, 3, 0, 3, 0, 3, 0, 1
  .word 1, 1, 1, 1, 1, 1, -1, -1, -1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1

# Level 100:
  .word 8, 8
  .word 1, 1, 1, 1, 1, 1, 1, -1
  .word 1, 0, 2, 1, 0, 0, 1, -1
  .word 1, 4, 3, 0, 0, 0, 1, -1
  .word 1, 4, 0, 1, 0, 3, 1, 1
  .word 1, 4, 3, 1, 0, 0, 0, 1
  .word 1, 4, 0, 1, 0, 3, 0, 1
  .word 1, 0, 0, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1

# Level 101:
  .word 13, 13
  .word -1, -1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1
  .word -1, -1, 1, 0, 0, 0, 1, -1, -1, -1, -1, -1, -1
  .word -1, -1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1
  .word -1, -1, 1, 0, 0, 7, 0, 0, 1, 0, 0, 0, 1
  .word -1, -1, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1
  .word -1, -1, 1, 0, 0, 0, 0, 0, 1, 7, 0, 0, 1
  .word 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1
  .word 1, 0, 0, 7, 1, 3, 6, 0, 0, 0, 1, -1, -1
  .word 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, -1, -1
  .word 1, 0, 0, 0, 1, 0, 0, 7, 0, 0, 1, -1, -1
  .word 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, -1, -1
  .word -1, -1, -1, -1, -1, -1, 1, 0, 0, 0, 1, -1, -1
  .word -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, -1, -1

# Level 102:
  .word 11, 8
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 4, 4, 4, 4, 1, 0, 0, 0, 0, 1
  .word 1, 0, 0, 1, 0, 0, 0, 3, 3, 0, 1
  .word 1, 0, 0, 2, 0, 0, 1, 1, 0, 0, 1
  .word 1, 0, 0, 0, 0, 0, 1, 1, 3, 0, 1
  .word 1, 1, 1, 1, 1, 1, 0, 0, 3, 0, 1
  .word -1, -1, -1, -1, -1, 1, 0, 0, 0, 0, 1
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1

# Level 103:
  .word 8, 8
  .word -1, -1, 1, 1, 1, 1, 1, -1
  .word -1, -1, 1, 0, 4, 0, 1, 1
  .word 1, 1, 1, 0, 3, 0, 0, 1
  .word 1, 0, 4, 0, 3, 1, 2, 1
  .word 1, 0, 1, 3, 0, 4, 0, 1
  .word 1, 0, 0, 3, 0, 1, 1, 1
  .word 1, 1, 0, 4, 0, 1, -1, -1
  .word -1, 1, 1, 1, 1, 1, -1, -1

# Level 104:
  .word 9, 9
  .word -1, -1, -1, -1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 1, 0, 0, 0, 1
  .word 1, 0, 0, 0, 0, 3, 0, 0, 1
  .word 1, 0, 0, 3, 1, 3, 1, 2, 1
  .word 1, 1, 1, 0, 1, 0, 0, 0, 1
  .word -1, -1, 1, 0, 4, 4, 4, 0, 1
  .word -1, -1, 1, 1, 1, 0, 0, 1, 1
  .word -1, -1, -1, -1, 1, 0, 0, 1, -1
  .word -1, -1, -1, -1, 1, 1, 1, 1, -1

# Level 105:
  .word 11, 11
  .word -1, 1, 1, 1, 1, -1, 1, 1, 1, 1, -1
  .word 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1
  .word 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1
  .word 1, 0, 0, 7, 4, 0, 4, 7, 0, 0, 1
  .word 1, 1, 1, 3, 0, 0, 0, 3, 1, 1, 1
  .word -1, 1, 0, 0, 0, 2, 0, 0, 0, 1, -1
  .word 1, 1, 1, 3, 0, 0, 0, 3, 1, 1, 1
  .word 1, 0, 0, 7, 4, 0, 4, 7, 0, 0, 1
  .word 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1
  .word 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1
  .word -1, 1, 1, 1, 1, -1, 1, 1, 1, 1, -1

# Level 106:
  .word 10, 9
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, -1
  .word -1, 1, 0, 0, 0, 0, 0, 0, 1, -1
  .word -1, 1, 2, 0, 0, 0, 3, 0, 1, -1
  .word 1, 1, 0, 1, 1, 1, 3, 0, 1, -1
  .word 1, 0, 4, 4, 4, 4, 4, 1, 1, 1
  .word 1, 0, 3, 0, 3, 0, 3, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 0, 1, 0, 1
  .word -1, -1, -1, -1, -1, 1, 0, 0, 0, 1
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1, 1

# Level 107:
  .word 8, 8
  .word 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 3, 7, 7, 7, 0, 1
  .word 1, 0, 7, 0, 0, 7, 0, 1
  .word 1, 0, 7, 0, 0, 7, 0, 1
  .word 1, 0, 7, 7, 7, 4, 0, 1
  .word 1, 0, 0, 0, 0, 0, 2, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1

# Level 108:
  .word 15, 8
  .word 1, 1, 1, 1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, -1
  .word 1, 0, 0, 1, 1, 1, -1, -1, -1, 1, 0, 0, 0, 1, 1
  .word 1, 0, 0, 0, 0, 1, -1, -1, -1, 1, 3, 0, 3, 0, 1
  .word 1, 4, 4, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1
  .word 1, 0, 0, 2, 0, 0, 0, 0, 1, 0, 3, 0, 3, 0, 1
  .word 1, 4, 4, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1
  .word 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1
  .word -1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1

# Level 109:
  .word 9, 13
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1
  .word 1, -1, 1, 0, 0, 0, 0, 0, 1
  .word 1, -1, 1, 0, 1, 0, 1, 0, 1
  .word -1, -1, 1, 0, 2, 0, 3, 0, 1
  .word 1, 1, 1, 0, 1, 1, 1, 0, 1
  .word 1, 0, 0, 0, 1, 1, 1, 0, 1
  .word 1, 0, 3, 0, 0, 1, 1, 4, 1
  .word 1, 1, 0, 3, 0, 0, 1, 4, 1
  .word -1, 1, 1, 0, 3, 0, 0, 4, 1
  .word 1, -1, 1, 1, 0, 3, 1, 4, 1
  .word 1, 1, -1, 1, 1, 0, 1, 4, 1
  .word 1, 1, 1, -1, 1, 0, 0, 0, 1
  .word 1, 1, 1, -1, 1, 1, 1, 1, 1

# Level 110:
  .word 9, 9
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1
  .word -1, -1, 1, 0, 0, 1, -1, -1, -1
  .word -1, -1, 1, 0, 3, 1, 1, 1, 1
  .word 1, 1, 1, 4, 0, 4, 0, 0, 1
  .word 1, 0, 3, 0, 1, 0, 3, 0, 1
  .word 1, 0, 0, 4, 0, 4, 1, 1, 1
  .word 1, 1, 1, 1, 3, 0, 1, -1, -1
  .word -1, -1, -1, 1, 0, 2, 1, -1, -1
  .word -1, -1, -1, 1, 1, 1, 1, -1, -1

# Level 111:
  .word 9, 12
  .word 1, 1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 0, 0, 0, 0, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 4, 4, 4, 1
  .word 1, 0, 0, 0, 0, 4, 4, 4, 1
  .word 1, 1, 1, 1, 1, 1, 0, 0, 1
  .word -1, -1, 1, 0, 0, 1, 0, 0, 1
  .word -1, -1, 1, 0, 3, 3, 0, 1, 1
  .word -1, -1, 1, 0, 2, 3, 0, 0, 1
  .word -1, -1, 1, 0, 3, 3, 0, 0, 1
  .word -1, -1, 1, 1, 0, 3, 1, 0, 1
  .word -1, -1, -1, 1, 0, 0, 0, 0, 1
  .word -1, -1, -1, 1, 1, 1, 1, 1, 1

# Level 112:
  .word 10, 13
  .word -1, 1, 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 1, 0, 0, 0, 1, 1, 1, 1, -1
  .word 1, 0, 0, 3, 3, 3, 0, 0, 1, -1
  .word 1, 0, 1, 0, 0, 0, 3, 0, 1, -1
  .word 1, 0, 0, 0, 3, 1, 1, 0, 1, 1
  .word 1, 1, 1, 0, 0, 1, 4, 0, 0, 1
  .word -1, -1, 1, 0, 0, 1, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, 0, 1, 1, 1
  .word -1, 1, 0, 0, 0, 1, 0, 1, 1, -1
  .word -1, 1, 0, 2, 4, 4, 4, 4, 1, -1
  .word -1, 1, 0, 0, 0, 0, 0, 0, 1, -1
  .word -1, 1, 0, 0, 0, 1, 0, 0, 1, -1
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, -1

# Level 113:
  .word 14, 13
  .word -1, -1, -1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1
  .word -1, -1, 1, 1, 0, 0, 0, 1, -1, -1, -1, -1, -1, -1
  .word 1, 1, 1, 0, 0, 1, 0, 1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 0, 4, 0, 1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 0, 0, 4, 0, 4, 0, 1, 0, 0, 1, 1, -1, -1
  .word 1, 0, 0, 1, 0, 2, 0, 3, 0, 0, 0, 1, 1, 1
  .word 1, 1, 1, 1, 1, 4, 0, 1, 0, 0, 3, 0, 0, 1
  .word -1, -1, -1, -1, 1, 1, 1, 1, 0, 0, 3, 0, 0, 1
  .word -1, -1, -1, -1, -1, -1, -1, 1, 1, 0, 3, 0, 1, 1
  .word -1, -1, -1, -1, -1, -1, -1, -1, 1, 0, 0, 1, 1, -1
  .word -1, -1, -1, -1, -1, -1, -1, -1, 1, 0, 0, 1, -1, -1
  .word -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, -1, -1

# Level 114:
  .word 11, 9
  .word 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 0, 1, 1, 1, -1, -1, -1
  .word 1, 0, 0, 1, 0, 3, 0, 1, -1, -1, -1
  .word 1, 0, 0, 3, 0, 2, 0, 1, -1, -1, -1
  .word 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1
  .word 1, 0, 0, 1, 4, 4, 4, 4, 4, 4, 1
  .word 1, 0, 3, 0, 3, 0, 3, 0, 3, 0, 1
  .word 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1
  .word -1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 115:
  .word 12, 8
  .word -1, -1, -1, -1, 1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1
  .word 1, 0, 0, 1, 4, 4, 4, 4, 4, 0, 0, 1
  .word 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1
  .word -1, 1, 3, 3, 2, 3, 3, 3, 0, 1, -1, -1
  .word -1, 1, 0, 0, 0, 0, 0, 1, 1, 1, -1, -1
  .word -1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1

# Level 116:
  .word 10, 7
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1, 1
  .word -1, -1, -1, 1, 1, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 4, 4, 4, 4, 4, 1
  .word 1, 0, 2, 3, 3, 3, 3, 3, 0, 1
  .word 1, 0, 0, 0, 0, 0, 1, 0, 1, 1
  .word 1, 1, 1, 1, 1, 0, 0, 0, 1, -1
  .word -1, -1, -1, -1, 1, 1, 1, 1, 1, -1

# Level 117:
  .word 11, 10
  .word -1, 1, 1, 1, 1, -1, 1, 1, 1, 1, -1
  .word -1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1
  .word -1, 1, 0, 0, 0, 0, 0, 0, 2, 0, 1
  .word 1, 1, 4, 4, 1, 1, 1, 0, 0, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1
  .word 1, 4, 4, 4, 1, 3, 0, 0, 1, 0, 1
  .word 1, 0, 1, 1, 0, 3, 3, 0, 3, 0, 1
  .word 1, 0, 0, 3, 0, 0, 0, 0, 1, 1, 1
  .word 1, 1, 1, 1, 0, 0, 1, 1, 1, -1, -1
  .word -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1

# Level 118:
  .word 10, 10
  .word -1, 1, 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 1, 0, 0, 0, 1, 1, -1, -1, -1
  .word 1, 0, 0, 3, 0, 0, 1, 1, -1, -1
  .word 1, 0, 3, 0, 3, 0, 0, 1, 1, -1
  .word 1, 1, 1, 3, 1, 0, 4, 0, 1, 1
  .word -1, -1, 1, 0, 1, 0, 4, 0, 0, 1
  .word -1, 1, 1, 0, 1, 1, 4, 0, 0, 1
  .word -1, 1, 0, 2, 0, 0, 4, 0, 1, 1
  .word -1, 1, 0, 0, 0, 1, 0, 0, 1, -1
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, -1

# Level 119:
  .word 9, 10
  .word -1, -1, 1, 1, 1, 1, 1, 1, -1
  .word -1, -1, 1, 0, 0, 0, 0, 1, 1
  .word -1, 1, 1, 0, 1, 1, 0, 0, 1
  .word -1, 1, 0, 3, 3, 0, 1, 0, 1
  .word -1, 1, 0, 2, 3, 0, 1, 0, 1
  .word -1, 1, 0, 0, 0, 0, 1, 0, 1
  .word 1, 1, 1, 1, 0, 1, 0, 0, 1
  .word 1, 0, 0, 4, 4, 4, 0, 1, 1
  .word 1, 0, 0, 0, 0, 0, 1, 1, -1
  .word 1, 1, 1, 1, 1, 1, 1, -1, -1

# Level 120:
  .word 11, 11
  .word -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, -1
  .word 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, -1
  .word 1, 0, 3, 0, 0, 0, 0, 0, 0, 1, 1
  .word 1, 0, 3, 1, 1, 1, 1, 1, 0, 0, 1
  .word 1, 0, 0, 2, 1, 0, 0, 1, 0, 0, 1
  .word 1, 1, 0, 1, 1, 4, 4, 0, 0, 0, 1
  .word 1, 0, 0, 1, 0, 4, 4, 1, 1, 1, 1
  .word 1, 0, 3, 0, 0, 1, 1, 1, -1, -1, -1
  .word 1, 0, 3, 1, 1, 1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1

# Level 121:
  .word 11, 11
  .word -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1
  .word -1, 1, 0, 4, 0, 0, 1, -1, -1, -1, -1
  .word 1, 1, 3, 4, 1, 0, 1, -1, -1, -1, -1
  .word 1, 0, 0, 7, 0, 0, 1, -1, -1, -1, -1
  .word 1, 0, 4, 4, 1, 1, 1, -1, -1, -1, -1
  .word 1, 1, 3, 0, 1, -1, 1, 1, 1, 1, 1
  .word 1, 1, 0, 1, 1, -1, 1, 0, 0, 0, 1
  .word 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 1
  .word 1, 0, 0, 0, 2, 0, 3, 0, 3, 0, 1
  .word 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 122:
  .word 11, 12
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 1, 1, -1, -1, -1, -1
  .word 1, 0, 1, 3, 0, 0, 1, -1, -1, -1, -1
  .word 1, 0, 3, 0, 0, 0, 1, -1, -1, -1, -1
  .word 1, 0, 3, 0, 3, 0, 1, -1, -1, -1, -1
  .word 1, 0, 3, 1, 0, 0, 1, -1, -1, -1, -1
  .word 1, 0, 0, 2, 1, 1, 1, -1, -1, -1, -1
  .word 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 4, 4, 4, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 4, 4, 1
  .word -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1

# Level 123:
  .word 15, 11
  .word 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 0, 0, 0, 1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 3, 0, 3, 3, 0, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 1, 0, 2, 1, 1, 4, 0, 4, 0, 0, 1
  .word -1, -1, -1, -1, 1, 3, 0, 0, 1, 0, 4, 0, 0, 0, 1
  .word -1, -1, -1, -1, 1, 0, 0, 0, 1, 4, 0, 4, 0, 1, 1
  .word -1, -1, -1, -1, 1, 3, 1, 0, 1, 1, 0, 1, 0, 1, -1
  .word -1, -1, -1, -1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, -1
  .word -1, -1, -1, -1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, -1
  .word -1, -1, -1, -1, 1, 0, 0, 1, -1, 1, 1, 1, 1, -1, -1
  .word -1, -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1

# Level 124:
  .word 14, 9
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1
  .word 1, 0, 3, 2, 3, 3, 0, 1, 0, 4, 0, 4, 4, 1
  .word 1, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1
  .word -1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1
  .word -1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1
  .word -1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 125:
  .word 13, 8
  .word -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, -1, -1
  .word -1, -1, -1, -1, -1, -1, 1, 0, 0, 0, 1, 1, -1
  .word -1, -1, -1, -1, -1, -1, 1, 0, 3, 0, 0, 1, -1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 2, 1, 1
  .word 1, 0, 4, 0, 0, 1, 0, 3, 0, 3, 0, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 0, 3, 1, 0, 1
  .word 1, 4, 4, 4, 1, 1, 1, 1, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, -1, -1, -1, 1, 1, 1, 1, 1

# Level 126:
  .word 12, 7
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 4, 4, 4, 4, 4, 4, 4, 0, 0, 1
  .word 1, 0, 3, 3, 3, 3, 3, 3, 3, 2, 0, 1
  .word 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1
  .word 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, -1
  .word 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, -1
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1

# Level 127:
  .word 10, 9
  .word 1, 1, -1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 1, 1, 1, 0, 0, 1, 1, 1, 1
  .word -1, 1, 0, 3, 0, 3, 4, 0, 0, 1
  .word 1, 1, 0, 1, 0, 0, 4, 3, 0, 1
  .word 1, 0, 0, 0, 1, 1, 4, 1, 1, 1
  .word 1, 0, 0, 3, 0, 0, 4, 0, 1, -1
  .word 1, 0, 2, 0, 1, 0, 0, 0, 1, -1
  .word 1, 0, 0, 1, 1, 1, 1, 1, 1, -1
  .word 1, 1, 1, 1, -1, -1, -1, -1, -1, -1

# Level 128:
  .word 11, 8
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1
  .word 1, 0, 7, 0, 3, 0, 4, 0, 4, 0, 1
  .word 1, 0, 0, 0, 3, 0, 1, 1, 0, 1, 1
  .word 1, 1, 1, 1, 7, 1, 0, 0, 0, 1, -1
  .word -1, 1, 0, 0, 2, 0, 0, 1, 1, 1, -1
  .word -1, 1, 0, 0, 0, 1, 1, 1, -1, -1, -1
  .word -1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 129:
  .word 11, 8
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 0, 2, 0, 1, 0, 0, 0, 1
  .word 1, 0, 7, 0, 3, 0, 7, 4, 4, 0, 1
  .word 1, 0, 0, 0, 3, 0, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 7, 1, 0, 0, 1, 1, 1
  .word -1, 1, 0, 0, 0, 0, 0, 1, 1, -1, -1
  .word -1, 1, 0, 0, 0, 1, 1, 1, -1, -1, -1
  .word -1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 130:
  .word 12, 7
  .word 1, 1, 1, 1, 1, -1, -1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 0, 1, 1, 1, 1, 4, 4, 0, 1
  .word 1, 0, 3, 3, 3, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 0, 0, 3, 1, 0, 0, 4, 4, 0, 1
  .word 1, 1, 1, 0, 2, 1, 0, 0, 1, 1, 0, 1
  .word -1, -1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 131:
  .word 7, 11
  .word 1, 1, 1, 1, 1, -1, -1
  .word 1, 0, 0, 0, 1, -1, -1
  .word 1, 0, 4, 0, 1, -1, -1
  .word 1, 4, 2, 4, 1, 1, 1
  .word 1, 1, 4, 1, 0, 0, 1
  .word 1, 0, 0, 3, 0, 0, 1
  .word 1, 0, 3, 0, 0, 0, 1
  .word 1, 1, 3, 3, 0, 0, 1
  .word -1, 1, 0, 0, 1, 1, 1
  .word -1, 1, 0, 0, 1, -1, -1
  .word -1, 1, 1, 1, 1, -1, -1

# Level 132:
  .word 10, 8
  .word 1, 1, 1, 1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 2, 1, 1, 1, -1, -1, -1, -1
  .word 1, 4, 7, 0, 0, 1, 1, 1, 1, 1
  .word 1, 4, 4, 1, 3, 3, 0, 3, 0, 1
  .word 1, 1, 0, 0, 0, 0, 0, 0, 0, 1
  .word -1, 1, 0, 1, 0, 1, 1, 0, 0, 1
  .word -1, 1, 0, 0, 0, 1, 1, 1, 1, 1
  .word -1, 1, 1, 1, 1, 1, -1, -1, -1, -1

# Level 133:
  .word 10, 8
  .word -1, 1, 1, 1, 1, 1, 1, 1, -1, -1
  .word -1, 1, 0, 0, 4, 0, 4, 1, 1, 1
  .word -1, 1, 0, 4, 0, 4, 0, 4, 0, 1
  .word 1, 1, 1, 0, 1, 1, 1, 1, 0, 1
  .word 1, 0, 0, 2, 3, 0, 0, 3, 0, 1
  .word 1, 0, 0, 3, 3, 0, 0, 3, 0, 1
  .word 1, 1, 1, 1, 0, 0, 0, 1, 1, 1
  .word -1, -1, -1, 1, 1, 1, 1, 1, -1, -1

# Level 134:
  .word 12, 10
  .word -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1
  .word 1, 0, 0, 0, 1, 1, 0, 3, 0, 0, 0, 1
  .word 1, 0, 0, 3, 0, 0, 0, 1, 1, 0, 0, 1
  .word 1, 1, 1, 0, 1, 4, 0, 4, 1, 0, 1, 1
  .word -1, -1, 1, 0, 1, 4, 0, 4, 1, 3, 1, 1
  .word -1, -1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1
  .word -1, -1, 1, 0, 2, 0, 3, 0, 0, 0, 0, 1
  .word -1, -1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1

# Level 135:
  .word 11, 7
  .word 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1
  .word 1, 0, 3, 3, 1, 2, 1, 1, 4, 4, 1
  .word 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 0, 3, 0, 1, 0, 1, 0, 0, 1
  .word 1, 1, 1, 1, 0, 3, 0, 0, 4, 4, 1
  .word -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 136:
  .word 9, 8
  .word -1, 1, 1, 1, 1, 1, 1, 1, -1
  .word -1, 1, 0, 0, 0, 0, 0, 1, -1
  .word 1, 1, 0, 1, 1, 1, 3, 1, 1
  .word 1, 4, 3, 0, 0, 0, 2, 0, 1
  .word 1, 0, 4, 4, 0, 1, 3, 0, 1
  .word 1, 4, 1, 1, 0, 0, 3, 0, 1
  .word 1, 0, 0, 0, 0, 1, 1, 1, 1
  .word 1, 1, 1, 1, 1, 1, -1, -1, -1

# Level 137:
  .word 13, 10
  .word -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, -1, -1
  .word -1, -1, -1, -1, -1, -1, 1, 1, 0, 0, 1, 1, 1
  .word 1, 1, 1, 1, -1, -1, 1, 0, 0, 3, 0, 0, 1
  .word 1, 0, 0, 1, 1, 1, 1, 0, 3, 0, 3, 0, 1
  .word 1, 0, 0, 0, 4, 4, 1, 0, 1, 3, 0, 0, 1
  .word 1, 0, 0, 1, 0, 0, 0, 2, 0, 0, 1, 1, 1
  .word 1, 1, 0, 1, 4, 4, 1, 0, 1, 1, 1, -1, -1
  .word -1, 1, 0, 1, 1, 0, 1, 0, 1, -1, -1, -1, -1
  .word -1, 1, 0, 0, 0, 0, 0, 0, 1, -1, -1, -1, -1
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1

# Level 138:
  .word 12, 11
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1
  .word 1, 1, 1, 0, 0, 1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 0, 1, 1, 1, -1, -1, -1, -1
  .word 1, 0, 1, 0, 4, 0, 4, 1, -1, -1, -1, -1
  .word 1, 0, 2, 0, 4, 4, 4, 1, 1, 1, 1, -1
  .word 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 1
  .word 1, 0, 0, 0, 1, 0, 3, 3, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 0, 0, 3, 0, 3, 0, 1
  .word -1, -1, -1, -1, 1, 1, 3, 0, 1, 0, 1, 1
  .word -1, -1, -1, -1, -1, 1, 0, 0, 0, 0, 1, -1
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, -1

# Level 139:
  .word 16, 12
  .word -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 1, 0, 0, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 4, 4, 4, 1, -1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 4, 4, 4, 1, -1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 0, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 2, 0, 1, 1, 1, 1, -1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 1, 0, 3, 0, 0, 0, 1, 1, 1, 0, 0, 1
  .word -1, -1, -1, -1, 1, 0, 0, 1, 1, 3, 0, 3, 0, 0, 0, 1
  .word -1, -1, -1, 1, 1, 1, 0, 0, 0, 0, 0, 3, 3, 0, 0, 1
  .word -1, -1, -1, 1, 0, 3, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1
  .word -1, -1, -1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, -1, -1
  .word -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1

# Level 140:
  .word 14, 9
  .word 1, 1, 1, 1, 1, 1, 1, 1, -1, 1, 1, 1, 1, 1
  .word 1, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 3, 0, 0, 1
  .word 1, 4, 1, 0, 2, 0, 1, 1, 0, 3, 0, 0, 1, 1
  .word 1, 4, 1, 0, 0, 0, 1, 0, 3, 0, 0, 1, 1, -1
  .word 1, 4, 1, 0, 0, 0, 0, 3, 0, 0, 1, 1, -1, -1
  .word 1, 4, 0, 1, 1, 0, 1, 1, 1, 1, 1, -1, -1, -1
  .word 1, 1, 0, 0, 0, 0, 1, -1, -1, -1, -1, -1, -1, -1
  .word -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1

# Level 141:
  .word 10, 9
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1, 1
  .word -1, -1, 1, 0, 0, 1, 0, 4, 0, 1
  .word -1, -1, 1, 0, 0, 0, 4, 7, 4, 1
  .word -1, -1, 1, 0, 0, 1, 0, 7, 0, 1
  .word 1, 1, 1, 1, 3, 1, 1, 4, 1, 1
  .word 1, 0, 0, 0, 0, 0, 0, 3, 0, 1
  .word 1, 0, 3, 0, 1, 1, 0, 3, 0, 1
  .word 1, 0, 0, 0, 2, 1, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 142:
  .word 9, 9
  .word -1, -1, 1, 1, 1, 1, -1, -1, -1
  .word -1, -1, 1, 0, 0, 1, -1, -1, -1
  .word -1, -1, 1, 0, 0, 1, 1, 1, 1
  .word 1, 1, 1, 3, 4, 3, 0, 0, 1
  .word 1, 0, 0, 4, 2, 4, 0, 0, 1
  .word 1, 0, 0, 3, 4, 3, 1, 1, 1
  .word 1, 1, 1, 1, 0, 0, 1, -1, -1
  .word -1, -1, -1, 1, 0, 0, 1, -1, -1
  .word -1, -1, -1, 1, 1, 1, 1, -1, -1

# Level 143:
  .word 9, 15
  .word 1, 1, 1, 1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 1, 1, 1, 1, -1, -1
  .word 1, 0, 3, 0, 0, 0, 1, -1, -1
  .word 1, 0, 4, 1, 0, 0, 1, -1, -1
  .word 1, 0, 3, 1, 0, 1, 1, -1, -1
  .word 1, 0, 4, 0, 0, 1, -1, -1, -1
  .word 1, 1, 1, 1, 0, 1, -1, -1, -1
  .word -1, -1, -1, 1, 0, 1, -1, -1, -1
  .word -1, 1, 1, 1, 0, 1, 1, 1, -1
  .word -1, 1, 0, 0, 3, 0, 0, 1, -1
  .word 1, 1, 0, 1, 3, 1, 0, 1, 1
  .word 1, 0, 3, 0, 2, 0, 3, 0, 1
  .word 1, 0, 4, 4, 1, 4, 4, 0, 1
  .word 1, 1, 1, 0, 0, 0, 1, 1, 1
  .word -1, -1, 1, 1, 1, 1, 1, -1, -1

# Level 144:
  .word 12, 12
  .word -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1
  .word -1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, -1
  .word -1, 1, 0, 3, 3, 0, 1, 0, 0, 0, 1, -1
  .word -1, 1, 0, 3, 0, 4, 0, 4, 3, 3, 1, 1
  .word -1, 1, 0, 4, 4, 0, 1, 4, 0, 3, 0, 1
  .word 1, 1, 1, 0, 1, 7, 7, 0, 4, 0, 0, 1
  .word 1, 0, 0, 4, 0, 7, 7, 1, 0, 1, 1, 1
  .word 1, 0, 3, 0, 4, 1, 0, 4, 4, 0, 1, -1
  .word 1, 1, 3, 3, 4, 2, 4, 0, 3, 0, 1, -1
  .word -1, 1, 0, 0, 0, 1, 0, 3, 3, 0, 1, -1
  .word -1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, -1
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1, -1, -1, -1

# Level 145:
  .word 11, 11
  .word -1, -1, -1, 1, 1, 1, 1, 1, -1, -1, -1
  .word -1, -1, -1, 1, 0, 2, 0, 1, -1, -1, -1
  .word -1, -1, 1, 1, 0, 0, 0, 1, 1, -1, -1
  .word 1, 1, 1, 4, 3, 3, 3, 4, 1, 1, 1
  .word 1, 0, 0, 3, 4, 4, 4, 3, 0, 0, 1
  .word 1, 0, 0, 3, 4, 1, 4, 3, 0, 0, 1
  .word 1, 0, 0, 3, 4, 4, 4, 3, 0, 0, 1
  .word 1, 1, 1, 4, 3, 3, 3, 4, 1, 1, 1
  .word -1, -1, 1, 1, 0, 0, 0, 1, 1, -1, -1
  .word -1, -1, -1, 1, 0, 0, 0, 1, -1, -1, -1
  .word -1, -1, -1, 1, 1, 1, 1, 1, -1, -1, -1

# Level 146:
  .word 9, 9
  .word -1, 1, 1, 1, 1, 1, 1, 1, -1
  .word 1, 1, 0, 0, 4, 0, 0, 1, 1
  .word 1, 0, 4, 3, 3, 3, 4, 0, 1
  .word 1, 0, 3, 4, 0, 4, 3, 0, 1
  .word 1, 4, 3, 0, 2, 0, 3, 4, 1
  .word 1, 0, 3, 4, 0, 4, 3, 0, 1
  .word 1, 0, 4, 3, 3, 3, 4, 0, 1
  .word 1, 1, 0, 0, 4, 0, 0, 1, 1
  .word -1, 1, 1, 1, 1, 1, 1, 1, -1

# Level 147:
  .word 12, 10
  .word -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1
  .word 1, 4, 0, 0, 0, 4, 0, 0, 2, 1, 4, 1
  .word 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1
  .word 1, 1, 0, 3, 0, 0, 1, 0, 0, 0, 0, 1
  .word -1, 1, 0, 3, 0, 0, 0, 1, 1, 1, 1, 1
  .word -1, 1, 0, 3, 1, 0, 0, 1, -1, -1, -1, -1
  .word -1, 1, 1, 0, 1, 0, 0, 1, -1, -1, -1, -1
  .word -1, -1, 1, 0, 0, 0, 1, 1, -1, -1, -1, -1
  .word -1, -1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 148:
  .word 15, 7
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 0, 0, 4, 0, 0, 1, 0, 0, 0, 1, -1, -1, -1, -1
  .word 1, 0, 1, 4, 0, 0, 2, 0, 0, 0, 1, -1, -1, -1, -1
  .word 1, 0, 0, 1, 4, 4, 1, 0, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 0, 0, 1, 1, 0, 3, 3, 0, 3, 0, 3, 0, 1
  .word -1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 149:
  .word 10, 12
  .word -1, 1, 1, 1, 1, -1, -1, -1, -1, -1
  .word 1, 1, 0, 0, 1, 1, 1, -1, -1, -1
  .word 1, 2, 3, 0, 0, 0, 1, -1, -1, -1
  .word 1, 1, 1, 0, 3, 0, 1, -1, -1, -1
  .word -1, 1, 0, 0, 1, 1, 1, 1, 1, 1
  .word -1, 1, 0, 0, 3, 4, 4, 4, 4, 1
  .word -1, 1, 0, 0, 1, 0, 1, 1, 1, 1
  .word -1, 1, 1, 0, 1, 0, 1, -1, -1, -1
  .word -1, 1, 0, 3, 1, 0, 1, -1, -1, -1
  .word -1, 1, 0, 0, 0, 0, 1, -1, -1, -1
  .word -1, 1, 0, 0, 1, 1, 1, -1, -1, -1
  .word -1, 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 150:
  .word 15, 8
  .word -1, -1, -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1
  .word -1, 1, 1, 1, 1, 1, 0, 0, 1, -1, -1, -1, -1, -1, -1
  .word -1, 1, 0, 0, 0, 0, 0, 3, 1, 1, 1, 1, 1, 1, 1
  .word 1, 1, 0, 1, 1, 0, 4, 4, 1, 0, 0, 4, 4, 4, 1
  .word 1, 0, 3, 0, 3, 3, 1, 3, 0, 0, 2, 0, 0, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, -1, 1, 1, 1, 1
  .word -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1

# Level 151:
  .word 12, 10
  .word -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1, -1
  .word -1, -1, -1, 1, 0, 0, 1, -1, -1, -1, -1, -1
  .word -1, 1, 1, 1, 0, 0, 1, -1, -1, -1, -1, -1
  .word 1, 1, 0, 0, 3, 0, 1, -1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 1, 0, 1, -1, -1, -1, -1, -1
  .word 1, 0, 1, 3, 3, 0, 1, 1, 1, 1, 1, 1
  .word 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 4, 1
  .word 1, 0, 0, 3, 0, 0, 2, 0, 0, 0, 4, 1
  .word 1, 1, 1, 0, 0, 1, 1, 1, 1, 4, 4, 1
  .word -1, -1, 1, 1, 1, 1, -1, -1, 1, 1, 1, 1

# Level 152:
  .word 15, 9
  .word 1, 1, 1, 1, 1, 1, -1, 1, 1, 1, 1, -1, -1, -1, -1
  .word 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -1, -1, -1
  .word 1, 4, 1, 1, 0, 0, 1, 3, 1, 1, 0, 0, 1, -1, -1
  .word 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, -1
  .word 1, 3, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1
  .word 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1
  .word 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 1
  .word 1, 4, 0, 2, 0, 0, 0, 0, 3, 0, 7, 0, 4, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 153:
  .word 13, 10
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word 1, 4, 1, 0, 2, 1, 0, 0, 1, 0, 0, 0, 1
  .word 1, 4, 1, 3, 3, 0, 0, 0, 1, 0, 3, 0, 1
  .word 1, 4, 1, 0, 0, 1, 0, 3, 1, 0, 0, 0, 1
  .word 1, 4, 1, 0, 3, 1, 0, 0, 1, 0, 3, 1, 1
  .word 1, 4, 1, 0, 0, 1, 0, 3, 1, 0, 0, 1, -1
  .word 1, 4, 1, 0, 3, 1, 0, 0, 1, 0, 3, 1, -1
  .word 1, 4, 4, 0, 0, 1, 0, 3, 0, 0, 0, 1, -1
  .word 1, 4, 4, 0, 0, 1, 0, 0, 1, 0, 0, 1, -1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1

# Level 154:
  .word 29, 17
  .word -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .word -1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word -1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1
  .word -1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1
  .word -1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1
  .word 1, 1, 3, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1
  .word 1, 4, 0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

# Level 155:
  .word 30, 17
  .word -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, -1
  .word 1, 1, 1, 1, 1, 7, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1
  .word 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
  .word 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1
  .word 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1
  .word 1, 7, 1, 0, 1, 0, 4, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1
  .word 1, 7, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1
  .word 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1
  .word -1, 1, 0, 0, 0, 1, 0, 1, 7, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1
  .word -1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1
  .word -1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1
  .word -1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 7, 7, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, -1
  .word 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 7, 7, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, -1
  .word 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1
  .word 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 1, 7, 1
  .word 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 2, 1, 1, 1, 1, 1, 0, 0, 1, 7, 1
  .word 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, -1, 1, 1, 1, 1, -1, -1, -1, 1, 1, 1, 1, 1, 1



