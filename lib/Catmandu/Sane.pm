package Catmandu::Sane;

use strict;
use warnings;
use feature ();
use utf8;
use IO::File ();
use IO::Handle ();
use Path::Tiny qw(path tempfile tempdir);
use Try::Tiny::ByClass qw(try catch finally catch_case);
use Catmandu::Error;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(try catch finally catch_case path tempfile tempdir);

our @EXPORT = qw(try catch finally catch_case);

our %EXPORT_TAGS = (
    default => [@EXPORT],
    all     => [@EXPORT_OK],
    path    => [qw(path tempfile tempdir)],
);

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

also export C<path>, C<tempfile> and C<tempdir>:

    use Catmandu::Sane qw(:default :path);
    use Catmandu::Sane qw(:all);

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
    # without :all
    use Path::Tiny ();
    # with :all
    use Path::Tiny qw(path tempfile tempdir);

=cut
