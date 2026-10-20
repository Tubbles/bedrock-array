# 0109: The black block under a low light

Status: todo (2026-10-20)

Goal: no fragment shades to an invalid value. A shot of the smelter's right face from straight on with the camera light (`--view 1.5708,0.1,0.2,0.4410,0.8151,0.2686 --camera-light`, in both painted steel and the false colour scene) shows a crisp black rectangle at the same place on screen for two targets 55 cm apart, and none without the camera light. No shadow pass exists, so the suspect is a fragment that shades to a NaN or an infinity, which the bloom's down and up sampling spreads over a block before the tone map turns it black.

Since 0116 the same fifteen spot shots of different meshes show the block in other tiles (3, 5, 7 instead of 4, 5), so it depends on more than the view: an uninitialised value or state left from an earlier frame is as likely as a shading term.

Verify:
- That shot has no black block; a test or a debug check that finds the fragment's cause (the shading term at the light and normal of that view) and the guard against it.

## Specification

Written after finding which shading term goes invalid.
