' MacBasic drawing example
WINDOW OPEN "Drawing Demo", 640, 420, 160, 140
VIEW ADD "art", "Drawing Demo", 20, 20, 600, 360

CLEAR "art", "#F5F3FF"
DRAW RECT "art", 30, 30, 540, 300, "#4F46E5", 0
DRAW OVAL "art", 70, 80, 160, 160, "#06B6D4", 1
DRAW OVAL "art", 370, 80, 160, 160, "#EC4899", 1
DRAW LINE "art", 230, 160, 370, 160, "#111827"
DRAW TEXT "art", "MacBasic Graphics", 205, 280, "#312E81"
