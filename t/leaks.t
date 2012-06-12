#!/usr/bin/perl

use strict;
use Data::Dumper;
use Memoize qw(memoize flush_cache unmemoize);
use Test::More tests => 2;
use Test::LeakTrace;

no_leaks_ok { 
   # make memoized methods
   memoize('test1', INSTALL => 'fast_test1', LIST_CACHE => 'MERGE');
   memoize('test2', INSTALL => 'fast_test2', LIST_CACHE => 'MERGE');

   # call memoized methods a few times
   my (@result, $result);
   $result = fast_test1('one');
   @result = fast_test1('one');
   $result = fast_test1('one');
   $result = fast_test1('two');
   @result = fast_test1('two');
   $result = fast_test1('two');

   $result = fast_test2('one');
   @result = fast_test2('one');
   $result = fast_test2('one');
   $result = fast_test2('two');
   @result = fast_test2('two');
   $result = fast_test2('two');

   # flush cache
   flush_cache('fast_test1');
   flush_cache('fast_test2');

   # unmemoize
   unmemoize('fast_test1');
   unmemoize('fast_test2');
} 'no leaks after flush + unmemo';

no_leaks_ok { 
   # memoize again, and add two more items to cache
   memoize('test1', INSTALL => 'fast_test1', LIST_CACHE => 'MERGE');
   memoize('test2', INSTALL => 'fast_test2', LIST_CACHE => 'MERGE');

   my (@result, $result);
   $result = fast_test1('three');
   @result = fast_test1('three');
   $result = fast_test1('three');
   $result = fast_test1('four');
   @result = fast_test1('four');
   $result = fast_test1('four');

   # finally, let's unmemoize again.
   unmemoize('fast_test1');
   unmemoize('fast_test2');
} 'no leaks after unmemoize';

sub test1 {
   my @opts = @_;
   return "test1:".join(',', map { "[$_]" } @opts)."\n";
}

sub test2 {
    my @opts = @_;
    return "test2:".join(',', map { "[$_]" } @opts)."\n";
}
