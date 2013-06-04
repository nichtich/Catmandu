package Catmandu::Env;

use namespace::clean;
use Catmandu::Sane;
use Catmandu::Util qw(require_package :is :check);
use Catmandu::Fix;
use File::Spec;
use Config::Onion;
use lib;
use Moo;

with 'MooX::Log::Any';

has load_paths => (
    is      => 'ro',
    default => sub { [] },
    coerce  => sub {
        [map { File::Spec->rel2abs($_) }
            split /,/, join ',', ref $_[0] ? @{$_[0]} : $_[0]];
    },
);

has config => (is => 'rwp', default => sub { +{} });
has stores => (is => 'ro', default => sub { +{} });
has fixers => (is => 'ro', default => sub { +{} });
has default_store => (is => 'ro', default => sub { 'default' });
has default_fixer => (is => 'ro', default => sub { 'default' });
has default_importer => (is => 'ro', default => sub { 'default' });
has default_exporter => (is => 'ro', default => sub { 'default' });
has default_importer_package => (is => 'ro', default => sub { 'JSON' });
has default_exporter_package => (is => 'ro', default => sub { 'JSON' });
has store_namespace => (is => 'ro', default => sub { 'Catmandu::Store' });
has fixes_namespace => (is => 'ro', default => sub { 'Catmandu::Fix' });
has importer_namespace => (is => 'ro', default => sub { 'Catmandu::Importer' });
has exporter_namespace => (is => 'ro', default => sub { 'Catmandu::Exporter' });

sub BUILD {
    my ($self) = @_;

    my @config_dirs = @{$self->load_paths};
    my @lib_dirs;

    for my $dir (@config_dirs) {
        if (! -d $dir) {
            Catmandu::Error->throw("load path $dir doesn't exist");
        }

        my $lib_dir = File::Spec->catdir($dir, 'lib');

        if (-d -r $lib_dir) {
            push @lib_dirs, $lib_dir;
        }
    }

    if (@config_dirs) {
        my $config = Config::Onion->new;
        $config->load_glob(map { File::Spec->catfile($_, 'catmandu*') } reverse @config_dirs);
        $self->_set_config($config->get);
    }

    if (@lib_dirs) {
        lib->import(@lib_dirs);
    }
}

sub load_path {
    $_[0]->load_paths->[0];
}

sub roots {
    goto &load_paths;
}

sub root {
    goto &load_path;
}

sub store {
    my $self = shift;
    my $name = shift;

    my $stores = $self->stores;

    my $key = $name || $self->default_store;

    $stores->{$key} || do {
        my $ns = $self->store_namespace;
        if (my $c = $self->config->{store}{$key}) {
            check_hash_ref($c);
            check_string(my $package = $c->{package});
            my $opts = $c->{options} || {};
            if (@_ > 1) {
                $opts = {%$opts, @_};
            } elsif (@_ == 1) {
                $opts = {%$opts, %{$_[0]}};
            }
            return $stores->{$key} = require_package($package, $ns)->new($opts);
        }
        if ($name) {
            return require_package($name, $ns)->new(@_);
        }
        Catmandu::BadArg->throw("unknown store ".$self->default_store);
    }
}

sub fixer {
    my $self = shift;
    if (ref $_[0]) {
        return Catmandu::Fix->new(fixes => $_[0]);
    }

    my $key = $_[0] || $self->default_fixer;

    my $fixers = $self->fixers;

    $fixers->{$key} || do {
        if (my $fixes = $self->config->{fixer}{$key}) {
            return $fixers->{$key} = Catmandu::Fix->new(fixes => $fixes);
        }
        return Catmandu::Fix->new(fixes => \@_);
    }
}

sub importer {
    my $self = shift;
    my $name = shift;
    my $ns = $self->importer_namespace;
    if (my $c = $self->config->{importer}{$name || $self->default_importer}) {
        check_hash_ref($c);
        my $package = $c->{package} || $self->default_importer_package;
        my $opts    = $c->{options} || {};
        if (@_ > 1) {
            $opts = {%$opts, @_};
        } elsif (@_ == 1) {
            $opts = {%$opts, %{$_[0]}};
        }
        return require_package($package, $ns)->new($opts);
    }
    require_package($name ||
        $self->default_importer_package, $ns)->new(@_);
}

sub exporter {
    my $self = shift;
    my $name = shift;
    my $ns = $self->exporter_namespace;
    if (my $c = $self->config->{exporter}{$name || $self->default_exporter}) {
        check_hash_ref($c);
        my $package = $c->{package} || $self->default_exporter_package;
        my $opts    = $c->{options} || {};
        if (@_ > 1) {
            $opts = {%$opts, @_};
        } elsif (@_ == 1) {
            $opts = {%$opts, %{$_[0]}};
        }
        return require_package($package, $ns)->new($opts);
    }
    require_package($name ||
        $self->default_exporter_package, $ns)->new(@_);
}

1;
