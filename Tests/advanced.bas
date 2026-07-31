FUNCTION Twice(n)
  RETURN n * 2
END FUNCTION

FUNCTION Hello$(name$)
  RETURN "Hello, " + name$
END FUNCTION

INTERFACE Greeter
  METHOD Greet
END INTERFACE

value = 5
POINTER valuePointer TO value
PRINT POINTER(valuePointer)
POINTER SET valuePointer, 9
PRINT value

LIST CREATE numbers
LIST ADD numbers, 10
LIST ADD numbers, 20
LIST FIRST numbers
PRINT LISTSIZE(numbers), LISTVALUE(numbers)
LIST NEXT numbers
PRINT LISTVALID(numbers), LISTVALUE(numbers)
LIST SET numbers, 25
PRINT LISTVALUE(numbers)

PROTOTYPE doubler = Twice
PRINT doubler(6)

INTERFACE NEW greeting, Greeter
INTERFACE BIND greeting, Greet, Hello$
PRINT greeting.Greet("Ada")

DATABASE OPEN 1, "Tests/macbasic-database-test.sqlite"
DATABASE EXEC 1, "CREATE TABLE people (name TEXT, score REAL)"
DATABASE EXEC 1, "INSERT INTO people VALUES (""Ada"", 42)"
DATABASE QUERY 1, "SELECT name, score FROM people"
WHILE DATABASENEXT(1)
  PRINT DATABASEFIELD$(1, 0), DATABASEFIELD(1, 1)
WEND
DATABASE CLOSE 1
KILL "Tests/macbasic-database-test.sqlite"

THREADED threadValue
SUB Worker(n)
  threadValue = n
  PRINT "thread", threadValue
END SUB
THREAD START Worker, 17
THREAD WAIT
PRINT "main", threadValue
