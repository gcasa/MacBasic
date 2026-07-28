OPEN "Tests/macbasic-io-test.tmp" FOR OUTPUT AS #1
WRITE #1, "Ada", 42
CLOSE #1
OPEN "Tests/macbasic-io-test.tmp" FOR INPUT AS #1
INPUT #1, name$, answer
CLOSE #1
KILL "Tests/macbasic-io-test.tmp"
PRINT name$; ":"; answer

integer% = 3.8
PRINT integer%, HEX$(255), CHR$(65), INSTR("MacBasic", "Basic")

POKE 100, 77
PRINT PEEK(100)

OPEN "Tests/macbasic-random-test.tmp" AS #2 LEN = 6
FIELD #2, 4 AS code$, 2 AS number$
LSET code$ = "AB"
LSET number$ = MKI$(7)
PUT #2, 1
code$ = ""
number$ = ""
GET #2, 1
CLOSE #2
KILL "Tests/macbasic-random-test.tmp"
PRINT code$; ":"; CVI(number$)
PRINT USING "##.##"; 3.5

OBJECT.X(1) = 10
OBJECT.Y(1) = 10
OBJECT.W(1) = 20
OBJECT.H(1) = 20
OBJECT.X(2) = 15
OBJECT.Y(2) = 15
OBJECT.W(2) = 10
OBJECT.H(2) = 10
PRINT COLLISION(1, 2)

ON ERROR GOTO Handler
ERROR 42
PRINT "resumed"
END

Handler:
PRINT "error"; ERR
RESUME NEXT
