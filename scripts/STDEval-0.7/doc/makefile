# Makefile for STDEval
# Creation Date: July 7th, 2006
MAKE=make

POD2MAN = pod2man
GROFF = groff
MAN2HTML = man2html

man:
	$(POD2MAN) STDEval.pod -o STDEval.1

html:
	$(GROFF) -man -Tascii STDEval.1 > STDEval.2 && $(MAN2HTML) -compress -pgsize 1023 < STDEval.2 > STDEval.html && rm -f STDEval.2

clean:
	rm -f STDEval.1 STDEval.2 STDEval.html
	
all:
	$(POD2MAN) STDEval.pod -o STDEval.1
	$(GROFF) -man -Tascii STDEval.1 > STDEval.2 && $(MAN2HTML) -compress -pgsize 1023 < STDEval.2 > STDEval.html && rm -f STDEval.2
	