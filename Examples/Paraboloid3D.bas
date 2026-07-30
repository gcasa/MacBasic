' 3D wireframe plot of z = x^2 + y^2
'
' The surface is projected onto the drawing view with:
'   screenX = 320 + (x - y) * 52
'   screenY = 70 + (x + y) * 16 + z * 11

WINDOW OPEN 1, "3D Plot: z = x^2 + y^2", 680, 500, 140, 100
VIEW ADD 10, 1, 20, 20, 640, 440
CLEAR 10, "#F8FAFC"

' Coordinate axes
DRAW LINE 10, 320, 70, 476, 118, "#DC2626"
DRAW LINE 10, 320, 70, 164, 118, "#16A34A"
DRAW LINE 10, 320, 70, 320, 367, "#2563EB"
DRAW TEXT 10, "x", 486, 114, "#DC2626"
DRAW TEXT 10, "y", 146, 114, "#16A34A"
DRAW TEXT 10, "z", 328, 370, "#2563EB"

' Curves with x held constant
FOR x = -3 TO 3
  y = -3
  z = x * x + y * y
  oldX = 320 + (x - y) * 52
  oldY = 70 + (x + y) * 16 + z * 11

  FOR yi = -5 TO 6
    y = yi / 2
    z = x * x + y * y
    newX = 320 + (x - y) * 52
    newY = 70 + (x + y) * 16 + z * 11
    DRAW LINE 10, oldX, oldY, newX, newY, "#7C3AED"
    oldX = newX
    oldY = newY
  NEXT yi
NEXT x

' Curves with y held constant
FOR y = -3 TO 3
  x = -3
  z = x * x + y * y
  oldX = 320 + (x - y) * 52
  oldY = 70 + (x + y) * 16 + z * 11

  FOR xi = -5 TO 6
    x = xi / 2
    z = x * x + y * y
    newX = 320 + (x - y) * 52
    newY = 70 + (x + y) * 16 + z * 11
    DRAW LINE 10, oldX, oldY, newX, newY, "#0891B2"
    oldX = newX
    oldY = newY
  NEXT xi
NEXT y

DRAW TEXT 10, "z = x^2 + y^2", 24, 410, "#0F172A"
