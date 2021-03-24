# Makefile for STDEval
# Creation Date: July 7th, 2006
MAKE=make

XMLLINT = xmllint

all:
	(cd doc; make all)

check:
	(cd test_suite; rm -f test?.output.*; perl STDEval_test.pl)

validate:
	@ $(XMLLINT) --schema doc/stdlist.xsd $(STDLIST) 1> /dev/null; $(XMLLINT) --schema doc/tlist.xsd $(TERMLIST) 1> /dev/null; $(XMLLINT) --schema doc/ecf.xsd $(ECF) 1> /dev/null

doc:
	(cd doc; make all)

clean:
	(cd test_suite; rm -f test?.output.*)

clean-doc:
	(cd doc; make clean)

clean-all:
	(cd test_suite; rm -f test?.output.*)
	(cd doc; make clean)

dist:
	@ echo "Make the distribution"
	@ echo "STDEval-"`grep Version: README | head -1 | perl -pe 's/.*Version:\s+//; s/\s+\$$//; s/\s+/_/g'` > .fname	
	@ echo "Building a release version" `cat .fname`
	@ echo "Verifying and up-to-date CVS copy"
	@ cvs -d gaston:/home/sware/cvs up
	@ cvs -d gaston:/home/sware/cvs co -d `cat .fname` STDEval
	@ echo "Building the TAR file"
	@ echo `cat .fname`"-"`date +%Y%m%d-%H%M`.tgz > .distname
	@ tar zcf `cat .distname` --exclude CVS --exclude .DS_Store `cat .fname` 
	(cd `cat .fname`; make all check)
	@ echo "Release ready:" `cat .distname`
	@ rm -rf `cat .fname` .fname .distname
