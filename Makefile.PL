use ExtUtils::MakeMaker;
WriteMakefile(
	      NAME => 'Memoize',
	      VERSION => '0.48',
#	      'linkext' => {LINKTYPE => ''},
	      'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
);
