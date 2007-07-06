package CPAN::Forum::DB::Users;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('users');
__PACKAGE__->columns(All => qw/id username password email fname lname status
                            update_on_new_user/);
__PACKAGE__->has_many(posts => "CPAN::Forum::DB::Posts");
#__PACKAGE__->has_many(usergroups => "CPAN::Forum::DB::UserInGroup");


__PACKAGE__->add_trigger(before_create => sub { 
    $_[0]->{password} = _generate_pw(7);
    $_[0]->{email}    = lc $_[0]->{email};
    $_[0]->{username} = lc $_[0]->{username};
    });


sub _generate_pw {
    my ($n) = @_;
    my @c = ('a'..'z', 'A'..'Z', 1..9);
    my $pw = "";
    $pw .= $c[rand @c] for 1..$n;
    return $pw;
}

sub get_user {
    my ($self, $user_id) = @_;
    return if not $user_id;

    my $sql = "SELECT id, email, fname, lname, username
                FROM users
                WHERE id=?";
    return $self->_fetch_single_hashref($sql, $user_id);
}


1;

