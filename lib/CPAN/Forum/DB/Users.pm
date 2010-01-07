package CPAN::Forum::DB::Users;
use strict;
use warnings;
use 5.008;

use Carp;
use Digest::SHA    qw(sha1_base64);
use List::MoreUtils qw(none);

use base 'CPAN::Forum::DBI';

sub add_user {
    my ($self, $args) = @_;

    foreach my $field (qw(username email)) {
	Carp::croak("No $field") if not $args->{$field};
    }
    my $dbh = CPAN::Forum::DBI::db_Main();
    my $pw = _generate_pw(7);
    $dbh->do("INSERT INTO users (username, email, sha1) VALUES (?, ?, ?)",
              undef,
              lc($args->{username}), lc($args->{email}), sha1_base64($pw));

    my $sql = "SELECT id, username, email FROM users WHERE username=?";

    my $user = $self->_fetch_single_hashref($sql, lc $args->{username});
    $user->{password} = $pw;
    return $user;
}

sub add_usergroup {
    my ($self, $args) = @_;
 
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do("INSERT INTO usergroups (id, name) VALUES (?, ?)",
              undef,
              lc($args->{id}), lc($args->{name}));

#    my $sql = "SELECT id, username, email FROM users WHERE username=?";
#    return $self->_fetch_single_hashref($sql, lc $args->{username});
    return;
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
    my @FIELDS = qw(id username email);
    Carp::croak("Invalid field '$field'") if none {$field eq $_} @FIELDS;
    Carp::croak("No value supplied") if not $value;

    my $sql = "SELECT id, email, fname, lname, username, fname || ' ' || lname fullname
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
                WHERE username=? AND sha1=?";
    return $self->_fetch_single_hashref($sql, $username, sha1_base64($password));
}

sub dump_users {
    my ($self) = @_;
    my $sql = "SELECT id, username FROM users";
    return $self->_dump($sql); 
}

sub update {
    my ($self, $id, %args) = @_;
    my @valid_fields = qw(fname lname sha1 email); #TODO no password field any more!
    my @fields;
    my @values;
#	Carp::confess('here') if exists $args{sha1};

    foreach my $f (@valid_fields) {
        if (exists $args{$f}) {
            push @fields, "$f=?";
            if ($f eq 'email') {
                push @values, lc $args{$f};
            } else {
                push @values, $args{$f};
            }
        }
    }

    my $sql = "UPDATE users SET " . join(",", @fields) . " WHERE id=?";
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do($sql, undef, @values, $id);
}

sub list_users_like {
    my ($self, $username) = @_;
    $username = "%" . $username . "%";
    my $sql = "SELECT username FROM users WHERE username LIKE ? ORDER BY username";
    
    return $self->_fetch_arrayref_of_hashes($sql, $username);
}

sub is_admin {
    my ($self, $id) = @_;

    my $sql = "SELECT id FROM usergroups, user_in_group
               WHERE 
               usergroups.name='admin' AND
               user_in_group.uid = ? AND
               user_in_group.gid=usergroups.id
               ";
    $self->_fetch_single_value($sql, $id);
}

sub add_user_to_group {
	my ($self, %args) = @_;
	my $sql = "INSERT INTO user_in_group (uid, gid) VALUES(?, ?)";

    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do($sql, undef, $args{uid}, $args{gid});
}

sub retrieve_all {
	my $self = shift;
    my $sql = "SELECT username FROM users ORDER BY username";
    return $self->_fetch_arrayref_of_hashes($sql);
}

sub count_all {
	my $self = shift;
    my $sql = "SELECT COUNT(username) FROM users";
	return $self->_fetch_single_value($sql);
}

1;

