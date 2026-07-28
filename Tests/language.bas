FUNCTION Square(x)
  RETURN x * x
END FUNCTION
SUB Say(s$)
  PRINT s$
END SUB
Say("ready")
total = 0
FOR i = 1 TO 4
  total = total + Square(i)
NEXT i
IF total = 30 THEN
  PRINT "math ok"
ELSE
  PRINT "math bad"
END IF
n = 3
WHILE n > 0
  PRINT n
  n = n - 1
WEND
Names:
DATA "Ada", "Grace", 42
READ first$, second$, answer
PRINT first$, second$, answer
RESTORE Names
READ again$
PRINT again$
OPTION BASE 1
DIM squares(3), grid(2, 2)
FOR i = 1 TO 3
  squares(i) = i * i
NEXT i
grid(2, 1) = 21
PRINT LBOUND(squares), UBOUND(squares), squares(3), grid(2, 1)
ERASE squares
PRINT ABS(-3), INT(2.9), SQR(16), LEFT$("MacBasic", 3), MID$("MacBasic", 4, 5)
IF 2 ^ 3 = 8 AND 7 MOD 4 = 3 THEN PRINT "operators ok"
GOSUB Legacy
GOTO AfterLegacy
Legacy:
PRINT "gosub ok"
RETURN
AfterLegacy:
IF 0 THEN
  PRINT "wrong"
ELSEIF 1 THEN
  PRINT "elseif ok"
ELSE
  PRINT "wrong"
END IF
