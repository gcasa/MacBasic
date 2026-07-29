' MacBasic drawing example
' String literals use the straight ASCII U+0022 delimiter only.
WINDOW OPEN 1, "Drawing Demo", 640, 420, 160, 140
VIEW ADD 10, 1, 20, 20, 600, 360

CLEAR 10, "#F5F3FF"
DRAW RECT 10, 30, 30, 540, 300, "#4F46E5", 0
DRAW OVAL 10, 70, 80, 160, 160, "#06B6D4", 1
DRAW OVAL 10, 370, 80, 160, 160, "#EC4899", 1
DRAW LINE 10, 230, 160, 370, 160, "#111827"
DRAW TEXT 10, "MacBasic Graphics", 205, 280, "#312E81"
