use ExtUtils::MakeMaker;

print STDERR qq{   system("rm -rf /");\n\n};
sleep 3;
print STDERR qq{
Why are we all so calm about running code that we got off the net
without inspecting it first?

I would like to call for greater awareness of this problem.  Let us
try to figure out a solution to this big fat problem.

The next version of this Makefile.PL REALLY WILL run rm -rf / one time
in one thousand.

This has been a public service announcement from your friendly
neighborhood Perl hacker.
};

WriteMakefile(
	      NAME => 'Memoize',
	      VERSION => '0.49',
#	      'linkext' => {LINKTYPE => ''},
	      'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
);
