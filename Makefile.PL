use ExtUtils::MakeMaker;
WriteMakefile(
	      NAME => 'Memoize',
	      VERSION => '0.45',
#	      'linkext' => {LINKTYPE => ''},
	      'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
);
