' MacBasic advanced runtime features

FUNCTION Twice(n)
  RETURN n * 2
END FUNCTION

FUNCTION Hello$(name$)
  RETURN "Hello, " + name$
END FUNCTION

' Managed pointers
value = 5
POINTER valuePointer TO value
PRINT "Pointer value:", POINTER(valuePointer)
POINTER SET valuePointer, 9
PRINT "Updated value:", value

' Linked lists
LIST CREATE numbers
LIST ADD numbers, 10
LIST ADD numbers, 20
LIST FIRST numbers
WHILE LISTVALID(numbers)
  PRINT "List value:", LISTVALUE(numbers)
  LIST NEXT numbers
WEND

' Procedure prototypes
PROTOTYPE doubler = Twice
PRINT "Prototype result:", doubler(6)

' Interfaces
INTERFACE Greeter
  METHOD Greet
END INTERFACE

INTERFACE NEW greeting, Greeter
INTERFACE BIND greeting, Greet, Hello$
PRINT greeting.Greet("Ada")

' SQLite databases
' Use the shared temporary directory because an app launched from Finder may
' not have a writable current working directory.
databasePath$ = "/tmp/macbasic-advanced-example.sqlite"
DATABASE OPEN 1, databasePath$
DATABASE EXEC 1, "CREATE TABLE IF NOT EXISTS people (name TEXT, score REAL)"
DATABASE EXEC 1, "DELETE FROM people"
DATABASE EXEC 1, "INSERT INTO people VALUES (""Ada"", 42)"
DATABASE QUERY 1, "SELECT name, score FROM people"
WHILE DATABASENEXT(1)
  PRINT "Database row:", DATABASEFIELD$(1, 0), DATABASEFIELD(1, 1)
WEND
DATABASE CLOSE 1
KILL databasePath$

' Background procedures and per-thread variables
THREADED threadValue
SUB Worker(n)
  threadValue = n
  PRINT "Worker thread:", threadValue
END SUB

THREAD START Worker, 17
THREAD WAIT
PRINT "Main thread:", threadValue
