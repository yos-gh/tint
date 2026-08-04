# TINT

TINT is a physics-based falling-block puzzle game made with Godot 4.
The familiar tetromino shapes are built from soft, connected stones, so every
drop, collision, and rotation changes the pile in unpredictable ways.

[Play TINT in your browser](https://yos-gh.github.io/tint/)

## How to Play

Guide each falling block into the field and build a continuous, nearly level
line of stones that reaches both side walls. Completing a line clears the
stones along it.

- A pulsing glow appears when a line is only one stone away from clearing.
- Clearing stones higher in the field is riskier and awards a larger score
  multiplier, up to x16.
- The translucent line near the top marks the height limit. The game ends when
  the pile reaches it.
- A block remains controllable briefly after touching the floor or another
  block, then the next block appears.

Rotations are continuous rather than locked to 90-degree steps. The stones are
elastic, but each block will try to retain its original shape.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move left or right | `A` / `D` or arrow keys | D-pad or left stick |
| Drop faster | `S` or down arrow | D-pad down or left stick down |
| Rotate counterclockwise | `N` | `A` or `X` |
| Rotate clockwise | `M` | `B` or `Y` |
| Restart after game over | `R` | — |

Press any keyboard key, gamepad button, or move the left stick to begin from
the title screen.

## Run Locally

TINT requires Godot 4.7 or later. Open `project.godot` in Godot and press
`F6` or `F5`, or run it from a terminal:

```powershell
godot --path .
```

## Build for the Web

Install the official export templates that match your Godot version, then run:

```powershell
godot --headless --path . --export-release Web web/game/index.html
```

The playable build is written to `web/game`. The Sentry monitoring extension
and its Web support files are included in the repository, so no additional SDK
installation is required.
