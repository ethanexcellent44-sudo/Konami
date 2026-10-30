# Ethan

An original 3D football game prototype in Godot 4. It uses generated primitive meshes and procedural textures as visuals, with no third-party assets.

## Requirements

- Godot Engine 4.3 or newer (Forward+/Compatibility renderer; Compatibility is selected for broad desktop support).
- The VS Code Godot extension is useful for editing GDScript, but it does not replace the Godot Engine/editor executable.

## Open and run

1. Open this project folder in VS Code or Godot.
2. In the Godot extension settings, point the editor executable setting at your installed Godot binary if it is not detected automatically.
3. Open `project.godot` in Godot, allow the initial import to finish, and press F6/F5 or use **Run Project**.
4. To run from a terminal with Godot installed: `godot --path .` (or `godot4 --path .`, depending on the executable name).
5. To run the automated test suite headlessly:
  - `godot --headless -s tests/pitch_2d_test.gd`
  - `godot --headless -s tests/player_controller_2d_test.gd`
  - `godot --headless -s tests/team_ai_2d_test.gd`
  - `godot --headless -s tests/match_rules_2d_test.gd`
  - `godot --headless -s tests/team_management_test.gd`
  - `godot --headless -s tests/progression_test.gd`
   - `godot --headless -s tests/player_controls_test.gd`
   - `godot --headless -s tests/features_test.gd`
   - `godot --headless -s tests/positioning_test.gd`
   - `godot --headless -s tests/match_flow_test.gd`
   - `godot --headless -s tests/football_realism_test.gd`
   - `godot --headless -s tests/advanced_features_test.gd`

## Controls


Matches pause at half-time and full-time. Choose **START 2ND HALF** to resume or **PLAY AGAIN** to start a fresh match with the score and match stats reset.

## Football Laws and Team Size


## Football Laws and Team Size

- The active 3D match fields eleven per side: ten outfield players in a 4-3-3 plus one goalkeeper. Each side now has a full formation shape rather than a small-sided lineup.
- The home match bench provides five substitutions, with a maximum of five changes per match.
- Offside position compares the attacker with the second-last opponent, counting the goalkeeper among defenders; an attacker is not penalized merely for being in an offside position unless the through-ball action involves them.
- Goal kicks and corner kicks are awarded by the team that last touched the ball before it crossed the goal line. Throw-ins go to the opposing side when the ball crosses a touchline.
- This prototype implements a focused subset of the IFAB Laws of the Game. It is not a complete referee simulation: advantage, cards, handball interpretation, goalkeeper handling restrictions, and every restart detail are not yet modeled.

## Visual Kit Corrections

- The 2D pitch now uses the corrected 1050x680 playing rectangle at origin (60, 60) within the 1280x720 match arena, matching the reference layout from the Ethan pitch kit.
- Goal width follows the 73.2px reference frame, and the pitch includes stadium run-off, crowd stands, ad boards, and a more realistic grass stripe and marking layout.
- This keeps the prototype aligned with the original pitch and card art brief while preserving the existing keyboard controls and match flow.

## Features & Realism Details

- **2D Match Foundation**: `scenes/pitch_2d.tscn` is a standalone top-down pitch prototype with field markings, goal openings, and collision-backed touchlines/posts. `scenes/football_ball_2d.tscn` provides a friction-driven `RigidBody2D` ball with an impulse-based `kick(direction, power)` API. This foundation is not yet connected to the current 3D match; player control and AI are later build steps.
- **2D Player Controller Prototype**: `scenes/pitch_2d.tscn` now includes a keyboard/virtual-joystick controlled player, stamina meter, charged-shot meter, and mobile Shoot/Pass/Through/Sprint buttons. Pass, through-ball, and tackle intent are exposed as signals for later team-AI integration. Run `tests/player_controller_2d_test.gd` to verify controller behavior headlessly.
- **2D Team AI Prototype**: `TeamAI2D` loads fictional team formations and kit colors from `data/teams.json`, creates 11-player 4-3-3 or 4-4-2 sides, shifts off-ball shape toward play, sends the nearest defender to press, tracks the goalkeeper laterally, and chooses forward passes or shots. Use the pitch's formation button to switch the home team between 4-3-3 and 4-4-2. Run `tests/team_ai_2d_test.gd` for formation, press, and passing checks. This remains separate from the existing 3D match.
- **2D Match Rules Prototype**: `MatchRules2D` adds a score/clock HUD, kickoff and goal restarts, throw-ins, corners, goal kicks, foul/free-kick signaling, pause, halftime, and full-time flow to `scenes/pitch_2d.tscn`. Out-of-bounds detection uses ball position and last nearby touch; touchlines are intentionally open so the ball can leave play. Run `tests/match_rules_2d_test.gd` to verify events and match flow. This remains separate from the existing 3D match.
- **2D Match HUD and Pause Menu**: The broadcast score strip includes team color markers, match clock, period, and possession/restart status. The pause panel shows the current score, music and SFX sliders, touch-controls toggle, resume, restart, and return-home actions. The halftime/full-time panel includes the score and a contextual continue/replay action. Run `tests/match_rules_2d_test.gd` for HUD state and pause interactions.
- **Team Management**: The My Team menu opens a 16-player Ethan FC squad with 11 starters, five reserves, rarity, overall, and PAC/SHO/PAS/DRI/DEF/PHY card attributes. Switch between 4-3-3 and 4-4-2, select a player and slot to swap starters or promote a reserve, and save the formation/starting XI in the profile. The 2D pitch reads the saved formation. Run `tests/team_management_test.gd` to verify squad data, formation persistence, and substitutions.
- **Progression and Shop**: The Shop and Events menu routes open the progression screen with a once-daily coin claim, three match missions, a persistent owned-card list, and duplicate-free fictional player packs. Starter and premium packs cost 800 and 1,800 coins and award up to three unique players; premium rare pulls earn a small coin bonus. Completed matches grant coins and XP, wins advance missions, and level-ups award bonus coins. Run `tests/progression_test.gd` to verify rewards, mission claims, daily limits, pack prices, and ownership.

- **Polished Match Presentation**: The scoreboard, pause menu, settings, lineup, and full-time report share a layered dark-green and gold visual theme with rounded borders, subtle shadows, clearer typography, and improved control contrast.
- **Refined Player Presentation**: Player animation now swings limbs from shoulder and hip pivots, with hands and boots following the gait. Warm stadium fill lighting and a filmic tone mapper give the procedural kits, skin, and pitch more dimensional shading without external assets.
- **Intelligent Tactical Positioning & Passing Triangles**:
  - **Dynamic Tactical Roles**: The off-ball teammates organize into passing triangles around the ball carrier rather than following behind in a single file.
  - **Flank & Width Adaptation**: When the carrier attacks down a flank, one teammate moves into a central pivot pocket for support/reset passes, while the other stretches the weak-side wing for a cross or diagonal switch.
  - **Anti-Clumping Repulsion**: Teammates enforce a minimum 4.2m personal space separation from each other and a 5.0m buffer around the ball carrier, preventing bunching or crowding.
  - **Defensive Tracking & Cover**: When the opponent gains possession, the closest teammate presses the ball while the other drops back into central goal-side cover.
  - **Seamless Control Handoff**: When a pass is made, the previous carrier smoothly drops into an open tactical supporting role instead of shadowing the new receiver.
- **Opponent Decision-Making**:
  - Opponents shoot based on distance to goal and nearby defensive pressure instead of fixed field coordinates.
  - Passes favor forward teammates with open receiving space and avoid lanes blocked by defenders.
  - Passes lead moving teammates and vary in speed with distance.
- **Stadium & Pitch**:
  - 10 alternating lawn mowing grass stripes across the pitch (light/dark green broadcast turf).
  - Full field markings: halfway line, circular center and penalty spots, center circle, penalty boxes, goal areas, penalty D-arcs, and corner arcs.
  - Three selectable Follow, Broadcast sideline, and elevated Tactical camera views.
  - 4 Corner Flags with poles and fluttering red/gold flags.
  - Perimeter LED Sponsor Advertising Boards along both touchlines and behind the goal nets.
  - 4 Stadium Floodlight Pylons at the pitch corners with angled light banks and realistic stadium lighting.
  - Stadium apron perimeter track surrounding the turf.
- **Match Ball & Physics**:
  - Procedurally generated classic black pentagon-panel football texture with red match trim.
  - 3D rolling spin and angular velocity: see the iconic patches spin realistically as the ball rolls, curves, or dips.
  - Dribbling touches move the ball farther ahead at speed and vary with the player's running gait.
- **Player Models & Animations**:
  - Football boots/cleats on all players with sole studs.
  - Player hairstyles and distinct hair colors to identify teammates.
  - Back squad number plates (#10 captain, #7, #9, #1 keeper, #11 opponent).
  - Captain's yellow armband on player #10.
  - Running lean: players bank into curves when sprinting and steering, with momentum through turns.
  - Kicking animation: right leg draws back during shot charging and snaps forward upon strike.
- **Physical 3D Goal Nets & Framing**:
  - Full 3D goal framing and translucent net mesh backed by static colliders that catch the ball and cushion shots inside the net.
- **Dedicated Goalkeepers**:
  - Home GK (Emerald Green) and Away GK (Neon Yellow) with 3D goalkeeper gloves and stance.
  - Goal-line lateral tracking, incoming shot trajectory anticipation, diving saves, parries, catches, and clearances back upfield.
- **Procedural Stadium Audio System**:
  - Built-in GDScript procedural audio synthesis (zero external audio files needed).
  - Procedural referee whistle for kickoff, goals, and out-of-bounds.
  - Punchy ball kick impacts scaled with shot power.
  - Goalkeeper glove save impact sounds.
  - Goal net rustle / ripple sound when scoring.
  - Metallic goal post / crossbar clang.
  - Crowd cheer roar on goals and subtle ambient stadium murmur.
- **Additional Match Modes & Settings**:
  - Bench substitutions exchange active players while keeping squad and radar references up to date.
  - Opponent styles include aggressive pressing, balanced play, and patient defensive shape.
  - Free kicks and penalties include an aiming phase; corners display receiving targets, while throw-ins and goal kicks let the player select a pass or long kick.
  - Sixty-second shooting, passing, and defending challenges keep personal best scores.
  - Six-match league and six-fixture career seasons persist results, standings, and player upgrades.
  - Optional local versus mode puts Player 2 on the away striker, using WASD and U/O/I/P or a second controller.
  - Goal replay controls support slow playback, three camera views, and skipping.
  - Clear, evening, and rain settings adjust lighting and particle weather; crowds react to near misses.
  - Accessibility options include game speed, larger text, high-contrast HUD, touch layout, and remappable gameplay keys.
- **Broadcast Follow Camera & HUD**:
  - Dynamic camera elevation in the penalty box to frame the goal and goalkeeper.
  - HUD match clock, score board, possession status, live shot power bar, and sprint stamina meter.
  - End-of-match report with possession, shots, tackles, previous result, and cup progress.
- **Tactical & Competition Features**:
  - Attacking tactics widen and advance support runs; defensive tactics compact the team and deepen cover positions.
  - Three-match cup progress and up to ten saved match summaries persist in the local profile.
  - Basic offside calls and foul-based direct free-kick/penalty restarts add set-piece decisions.
  - Automatic goal replays sample player, ball, and camera positions from the preceding few seconds.
- **Input Options**:
  - Keyboard and standard joypad inputs are supported together.
  - Remap pass, shoot, sprint, and slide tackle from the pause menu; the custom keys persist in the local profile.

## Next useful milestones

1. Expand local versus to full team selection and configurable controller profiles.
2. Add more opponent and player animations for substitutions and weather conditions.
3. Replace placeholder geometry with original or properly licensed models and animations.
# Konami
