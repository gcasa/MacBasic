' MacBasic welcome program
SUB Banner(title$)
  PRINT "=== " + title$ + " ==="
END SUB

FUNCTION Double(n)
  RETURN n * 2
END FUNCTION

Banner("MacBasic")
PRINT "Structured BASIC for Mac and GNUstep"

FOR i = 1 TO 4
  PRINT "Double", i, "is", Double(i)
NEXT i

WINDOW OPEN 1, "Hello from MacBasic", 480, 240
