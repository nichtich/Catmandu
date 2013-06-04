package Catmandu::Sane;

use strict;
use warnings;
use feature ();
use utf8;
use IO::File ();
use IO::Handle ();
use Try::Tiny::ByClass qw(try catch finally catch_case);
use Catmandu::Error ();

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(try catch finally catch_case);

our @EXPORT = qw(try catch finally catch_case);

sub import {
    strict->import;
    warnings->import;
    feature->import(qw(:5.10));
    utf8->import;
    __PACKAGE__->export_to_level(1, @_);
}

1;

=head1 NAME

Catmandu::Sane - Package boilerplate

=head1 SYNOPSIS

    use Catmandu::Sane;

=head1 DESCRIPTION

Package boilerplate equivalent to:

    use strict;
    use warnings;
    use feature qw(:5.10);
    use utf8;
    use IO::File ();
    use IO::Handle ();
    use Try::Tiny::ByClass qw(try catch finally catch_case);
    use Catmandu::Error;

=cut
