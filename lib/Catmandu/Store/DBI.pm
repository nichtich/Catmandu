package Catmandu::Store::DBI;

use Catmandu::Sane;
use Moo;
use DBI;

with 'Catmandu::Store';

has data_source => (is => 'ro', required => 1);
has username    => (is => 'ro', default => sub { '' });
has password    => (is => 'ro', default => sub { '' });

has dbh => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    builder => '_build_dbh',
);

sub _build_dbh {
    my $self = $_[0];
    my $opts = {
        AutoCommit => 1,
        RaiseError => 1,
    };
    DBI->connect($self->data_source, $self->username, $self->password, $opts);
}

sub transaction {
    my ($self, $sub) = @_;

    my $dbh = $self->dbh;

    unless ($dbh->{AutoCommit}) {
        return $sub->();
    }

    my @res;

    eval {
        $dbh->{AutoCommit} = 0;
        $dbh->begin_work;
        @res = $sub->();
        $dbh->commit;
        $dbh->{AutoCommit} = 1;
    } or do {
        my $err = $@;
        eval {
            $dbh->rollback;
        };
        $dbh->{AutoCommit} = 1;
        confess $err;
    };

    @res;
}

sub DEMOLISH {
    $_[0]->dbh->disconnect;
}

package Catmandu::Store::DBI::Bag;
# TODO address 64kb text limit;try create database;
use Catmandu::Sane;
use Moo;

with 'Catmandu::Bag';
with 'Catmandu::Serializer';

has _sql_get        => (is => 'ro', lazy => 1, builder => '_build_sql_get');
has _sql_delete     => (is => 'ro', lazy => 1, builder => '_build_sql_delete');
has _sql_delete_all => (is => 'ro', lazy => 1, builder => '_build_sql_delete_all');
has _sql_generator  => (is => 'ro', lazy => 1, builder => '_build_sql_generator');
has _add            => (is => 'ro', lazy => 1, builder => '_build_add');

sub BUILD {
    my $self = $_[0];
    my $name = $self->name;
    my $dbh  = $self->store->dbh;
    my $sql  = "create table if not exists $name(id varchar(255) not null primary key, data text not null)";
    $dbh->do($sql) or confess $dbh->errstr;
}

sub _build_sql_get {
    my $name = $_[0]->name; "select data from $name where id=?";
}

sub _build_sql_delete {
    my $name = $_[0]->name; "delete from $name where id=?";
}

sub _build_sql_delete_all {
    my $name = $_[0]->name; "delete from $name";
}

sub _build_sql_generator {
    my $name = $_[0]->name; "select data from $name";
}

sub _build_add_sqlite {
    my $self = $_[0];
    my $name = $self->name;
    my $dbh  = $self->store->dbh;
    my $sql  = "insert or replace into $name(id,data) values(?,?)";
    sub {
        my $sth = $dbh->prepare_cached($sql) or confess $dbh->errstr;
        $sth->execute($_[0], $_[1]) or confess $sth->errstr;
        $sth->finish;
    };
}

sub _build_add_mysql {
    my $self = $_[0];
    my $name = $self->name;
    my $dbh  = $self->store->dbh;
    my $sql  = "insert into $name(id,data) values(?,?) on duplicate key update data = values(data)";
    sub {
        my $sth = $dbh->prepare_cached($sql) or confess $dbh->errstr;
        $sth->execute($_[0], $_[1]) or confess $sth->errstr;
        $sth->finish;
    };
}

sub _build_add_generic {
    my $self = $_[0];
    my $name = $self->name;
    my $dbh  = $self->store->dbh;
    my $sql_update = "update $name set data=? where id=?";
    my $sql_insert = "insert into $name values(?,?) where not exists (select 1 from $name where id=?)";
    sub {
        my $sth = $dbh->prepare_cached($sql_update) or confess $dbh->errstr;
        $sth->execute($_[1], $_[0]) or confess $sth->errstr;
        unless ($sth->rows) {
            $sth->finish;
            $sth = $dbh->prepare_cached($sql_insert) or confess $dbh->errstr;
            $sth->execute($_[0], $_[1], $_[0]) or confess $sth->errstr;
            $sth->finish;
        }
    };
}

sub _build_add {
    my $self = $_[0];
    given ($self->store->dbh->{Driver}{Name}) {
        when (/sqlite/i) { return $self->_build_add_sqlite }
        when (/mysql/i)  { return $self->_build_add_mysql }
        default          { return $self->_build_add_generic }
    }
}

sub get {
    my ($self, $id) = @_;
    my $dbh = $self->store->dbh;
    my $sth = $dbh->prepare_cached($self->_sql_get) or confess $dbh->errstr;
    $sth->execute($id) or confess $sth->errstr;
    my $row = $sth->fetch;
    $sth->finish;
    $row || return;
    $self->deserialize($row->[0]);
}

sub add {
    my ($self, $data) = @_;
    $self->_add->($data->{_id}, $self->serialize($data));
}

sub delete {
    my ($self, $id) = @_;
    my $dbh = $self->store->dbh;
    my $sth = $dbh->prepare_cached($self->_sql_delete) or confess $dbh->errstr;
    $sth->execute($id) or confess $sth->errstr;
    $sth->finish;
}

sub delete_all {
    my ($self) = @_;
    my $dbh = $self->store->dbh;
    my $sth = $dbh->prepare_cached($self->_sql_delete) or confess $dbh->errstr;
    $sth->execute or confess $sth->errstr;
    $sth->finish;
}

sub generator {
    my ($self) = @_;
    my $dbh = $self->store->dbh;
    sub {
        state $sth;
        state $row;
        unless ($sth) {
            $sth = $dbh->prepare($self->_sql_generator) or confess $dbh->errstr;
            $sth->execute;
        }
        if ($row = $sth->fetchrow_arrayref) {
            return $self->deserialize($row->[0]);
        }
        return;
    };
}

1;
