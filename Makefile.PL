use ExtUtils::MakeMaker;
WriteMakefile(
	      NAME => 'Memoize',
	      VERSION => '0.06',
#	      'linkext' => {LINKTYPE => ''},
	      'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
);
