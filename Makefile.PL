use ExtUtils::MakeMaker;
WriteMakefile(
	      NAME => 'Memoize',
	      VERSION => '0.46',
#	      'linkext' => {LINKTYPE => ''},
	      'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
);
