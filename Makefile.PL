use ExtUtils::MakeMaker;
WriteMakefile(
	      NAME => 'Memoize',
	      VERSION => '0.47',
#	      'linkext' => {LINKTYPE => ''},
	      'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
);
