## Project Flow
1. Read DIP switch inputs through the microcontroller
2. Perform binary addition in assembly
3. Display the result on the LCD screen

## Hardware Used
- Dragon12-Light board
- DIP switches
- LCD screen

## How It Works
The program continuously polls the DIP switches, reads the binary inputs, performs bitwise addition, and
updates the LCD screen in real time.

## Error Evaluation
An issue occurred when I attempted to drive the LEDs to show the binary representation of each DIP nibble
writing to Port B interfered with the LCD timing and caused unpredictable behavior. Because this LED output 
conflicted with the logic of the addition, I ultimately removed the LED feature to maintain system reliability.
