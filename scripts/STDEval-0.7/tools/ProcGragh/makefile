# Makefile for STDEval
# Creation Date: July 7th, 2006
MAKE=make

XMLLINT = xmllint
SCTK =  /slp/raid1/Benchmark/rt/rt06s/software/sctk-cvs/

check: clean
	mkdir test;
	./ProcGraph.pl -c -T -o `pwd`/test -m -- 'cd ../../test_suite; perl -I ../src  STDEval_test.pl'

extendedCheck: clean
	mkdir testSclite

clean:
	rm -rf test testSclite