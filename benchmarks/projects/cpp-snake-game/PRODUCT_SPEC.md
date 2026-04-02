# Product Specification

## Overview

A classic snake game with smooth controls, collision detection, scoring, and rendering. Desktop window app using SDL2.

## Features

### Feature 1: Game Loop

**User Story:** As a player, I want the game to run at a consistent frame rate, so that gameplay feels smooth.

**Success Criteria:**
1. Game window opens at a fixed resolution (e.g., 640x480)
2. Game runs at ~60 FPS with consistent frame timing
3. Game loop handles input, update, and render phases
4. Window can be closed cleanly

**Eval Rubric:**
- **Pass:** Window opens, game runs smoothly at consistent frame rate, closes cleanly.
- **Fail:** Window doesn't open, frame rate stutters badly, or crashes on close.
- **Weight:** 5

### Feature 2: Snake Movement and Input

**User Story:** As a player, I want to control the snake with arrow keys, so that I can navigate the game board.

**Success Criteria:**
1. Arrow keys change snake direction (up/down/left/right)
2. Snake moves continuously in the current direction
3. Snake cannot reverse direction (e.g., going left while moving right)
4. Movement feels responsive (no input lag)

**Eval Rubric:**
- **Pass:** All 4 directions work. Reverse prevention works. Movement is smooth.
- **Fail:** Direction keys don't work, snake can reverse into itself, or movement is choppy.
- **Weight:** 5

### Feature 3: Collision Detection

**User Story:** As a player, I want the game to detect when the snake hits walls or itself, so that the game has challenge.

**Success Criteria:**
1. Game ends when snake hits a wall boundary
2. Game ends when snake head collides with its own body
3. Game over screen shows with final score
4. Player can restart with a key press

**Eval Rubric:**
- **Pass:** Both wall and self-collision detected correctly. Game over + restart works.
- **Fail:** Collision not detected, false positives, or can't restart.
- **Weight:** 4

### Feature 4: Food and Scoring

**User Story:** As a player, I want to eat food to grow the snake and earn points, so that I have a goal.

**Success Criteria:**
1. Food item appears at random position on the board
2. Snake grows by one segment when it eats food
3. New food spawns immediately after eating (not on snake body)
4. Score increases by 10 points per food eaten
5. Current score displayed during gameplay

**Eval Rubric:**
- **Pass:** Food spawns correctly, snake grows, score increases, display works.
- **Fail:** Food doesn't spawn, snake doesn't grow, or score is wrong.
- **Weight:** 4

### Feature 5: Rendering

**User Story:** As a player, I want the game to look clean with distinct colors for snake, food, and background, so that I can see what's happening.

**Success Criteria:**
1. Game board has a visible background color
2. Snake segments are a distinct color, head is different from body
3. Food is a contrasting color from snake
4. Grid lines or borders visible for the game area
5. Score text is readable

**Eval Rubric:**
- **Pass:** All game elements visually distinct. Score readable. No rendering glitches.
- **Fail:** Elements blend together, rendering artifacts, or score not visible.
- **Weight:** 3

## Cross-Cutting Requirements

- Game board is a grid (e.g., 20x15 cells)
- Clean exit on window close or Escape key
- No memory leaks (clean SDL2 resource management)

## Out of Scope

- No high score persistence
- No sound effects or music
- No difficulty levels
- No multiplayer
- No menu screen (game starts immediately)
