#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use JSON ();

my $pkg;
BEGIN {
    $pkg = 'Catmandu::Fix::from_json';
    use_ok $pkg;
}

my $json = JSON->new->utf8(0)->allow_nonref(1);

is_deeply
    $pkg->new('name')->fix({name => $json->encode(["Joe"])}),
    {name => ["Joe"]};

is_deeply
    $pkg->new('names.*')->fix({names => [$json->encode({name => 'Joe'}), $json->encode({name => 'Rick'})]}),
    {names => [{name => 'Joe'}, {name => 'Rick'}]};

done_testing 3;

