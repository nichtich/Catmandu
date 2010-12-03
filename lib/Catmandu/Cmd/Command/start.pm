use MooseX::Declare;

class Catmandu::Cmd::Command::start extends Catmandu::Cmd::Command {
    use Plack::Runner;
    use Plack::Util;

    has host => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 'o',
        documentation => "The interface a TCP based server daemon binds to. Defaults to any (*).",
    );

    has port => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Int',
        lazy => 1,
        cmd_aliases => 'p',
        default => 5000,
        documentation => "The port number a TCP based server daemon listens on. Defaults to 5000.",
    );

    has socket => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 'S',
        documentation => "UNIX domain socket path to listen on. Defaults to none.",
    );

    has daemonize => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Bool',
        cmd_aliases => 'D',
        documentation => "Makes the process go background. Not all servers respect this option.",
    );

    has loader => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 'L',
        documentation => "Reloads on every request if 'Shotgun'. " .
                        "Delays compilation until the first request if 'Delayed'.",
    );

    has server => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 's',
        documentation => "Server to run on.",
    );

    has psgi_app => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        lazy => 1,
        cmd_flag => 'app',
        cmd_aliases => 'a',
        default => 'app.psgi',
        documentation => "Either a .psgi script to run or a Catmandu::App. Defaults to app.psgi.",
    );

    method execute ($opts, $args) {
        my $psgi_eval;
        my $psgi_file;

        my $psgi_app = $self->psgi_app || $args->[0];

        if ($psgi_app =~ /::/) {
            $psgi_eval = "use $psgi_app; $psgi_app->to_app;";
        } else {
            $psgi_file = Catmandu->find_psgi($psgi_app) or die "Can't find psgi app '$psgi_app'";
        }

        my @argv;
        push @argv, map { ('-I', $_) } Catmandu->lib;
        push @argv, '-E', Catmandu->env;
        push @argv, '-p', $self->port   if $self->port;
        push @argv, '-o', $self->host   if $self->host;
        push @argv, '-S', $self->socket if $self->socket;
        push @argv, '-D'                if $self->daemonize;
        push @argv, '-L', $self->loader if $self->loader;
        push @argv, '-s', $self->server if $self->server;
        push @argv, '-a', $psgi_file    if $psgi_file;
        push @argv, '-e', $psgi_eval    if $psgi_eval;
        push @argv, '-Moose';
        Plack::Runner->run(@argv);
    }
}

1;
