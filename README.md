<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
</head>
<body>

<h1>Pry Door Advanced</h1>

<p>
A lightweight <strong>Project Zomboid</strong> mod that allows players to forcibly open
locked doors, garage doors, and vehicle doors using a keybind.
</p>

<h2>Overview</h2>
<p>
This mod introduces a prying mechanic for locked objects.
When the player is near a valid locked target and has an appropriate tool,
a timed prying action can be initiated via a keybind.
Animations, sound effects, and multiplayer synchronization are handled automatically.
</p>

<p>
Window support exists in the codebase but is currently disabled.
</p>

<h2>Features</h2>
<ul>
  <li>Force open locked doors, including standard doors and <code>IsoThumpable</code> objects</li>
  <li>Garage door support with animations and sound effects</li>
  <li>Vehicle door prying with nearest-door detection</li>
  <li>Locked-state validation to prevent unintended interactions</li>
  <li>Multiplayer-safe state synchronization</li>
  <li>Compatible tools:
    <ul>
      <li>Crowbar</li>
      <li>Axe</li>
      <li>Screwdriver</li>
      <li>Hammer</li>
      <li>Wrench</li>
    </ul>
  </li>
  <li>Context-aware XP rewards (Strength, Woodwork, Mechanics)</li>
  <li>Keybind-based activation using the <code>`</code> (backtick) key</li>
</ul>

<h2>Usage</h2>
<ol>
  <li>Move close to a locked door, garage door, or vehicle</li>
  <li>Ensure a supported prying tool is present in the inventory</li>
  <li>Press the <code>`</code> key to start the prying action</li>
  <li>Wait for the action to complete</li>
</ol>

<h2>Notes</h2>
<ul>
  <li>Window prying is currently disabled</li>
  <li>Only locked objects can be pried open</li>
  <li>No context menu interaction is used</li>
</ul>

<h2>Compatibility</h2>
<ul>
  <li>Project Zomboid (singleplayer and multiplayer)</li>
  <li>Designed for keybind-only interaction</li>
</ul>

<h2>Copyright</h2>
<p>
© 2026 Dhevaio
</p>

</body>
</html>
