package CPAN::Forum::DB::Users;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('users');
__PACKAGE__->columns(All => qw/id username password email fname lname status
                            update_on_new_user/);
__PACKAGE__->has_many(posts => "CPAN::Forum::DB::Posts");


sub add_user {
    my ($self, $args) = @_;
 
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do("INSERT INTO users (username, email, password) VALUES (?, ?, ?)",
              undef,
              lc($args->{username}), lc($args->{email}), _generate_pw(7));

    my $sql = "SELECT id, username, password, email FROM users WHERE username=?";
    return $self->_fetch_single_hashref($sql, lc $args->{username});
}


sub _generate_pw {
    my ($n) = @_;
    my @c = ('a'..'z', 'A'..'Z', 1..9);
    my $pw = "";
    $pw .= $c[rand @c] for 1..$n;
    return $pw;
}

sub info_by {
    my ($self, $field, $value) = @_;
    Carp::croak("Invalid field '$field'") if $field ne "id" and $field ne "username";
    Carp::croak("No value supplied") if not $value;

    my $sql = "SELECT id, email, fname, lname, username
                FROM users
                WHERE $field=?";
    return $self->_fetch_single_hashref($sql, $value);
}

sub info_by_credentials {
    my ($self, $username, $password) = @_;
    Carp::croak("No username supplied") if not $username;
    Carp::croak("No password supplied") if not $password;

    my $sql = "SELECT id, email, fname, lname, username
                FROM users
                WHERE username=? AND password=?";
    return $self->_fetch_single_hashref($sql, $username, $password);
}


sub dump_users {
    my ($self) = @_;
    my $sql = "SELECT id, username FROM users";
    return $self->_dump($sql); 
}

sub update {
    my ($self, $id, %args) = @_;
    my @valid_fields = qw(fname lname password);
    my @fields;
    my @values;

    foreach my $f (@valid_fields) {
        if (exists $args{$f}) {
            push @fields, "$f=?";
            push @values, $args{$f};
        }
    }

    my $sql = "UPDATE users SET " . join(",", @fields) . " WHERE id=?";
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do($sql, undef, @values, $id);
}

1;

