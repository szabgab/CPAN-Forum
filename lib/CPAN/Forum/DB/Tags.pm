package CPAN::Forum::DB::Tags;
use strict;
use warnings;

use CPAN::Forum::DBI;

use Carp qw();

sub get_tags_of {
    my ($self, $group_id, $uid) = @_;
    if (not defined $uid) {
        return $self->get_tags_of_module($group_id);
    }
    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sql = "SELECT tags.name name 
                             FROM tag_cloud, tags
                             WHERE tag_cloud.tag_id=tags.id AND tag_cloud.uid=? AND tag_cloud.group_id=?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($uid, $group_id);
    my $ar = $sth->fetchrow_arrayref;
    my @names = map { {name => $_->[0]} } @$ar;
    return \@names;
}

sub get_tags_of_module {
    my ($self, $group_id) = @_;
    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sql = "SELECT tags.name name 
                             FROM tag_cloud, tags
                             WHERE tag_cloud.tag_id=tags.id AND tag_cloud.group_id=?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($group_id);
    my $ar = $sth->fetchrow_arrayref;
    my @names = map { {name => $_->[0]} } @$ar;
    return \@names;
}

sub attach_tag {
    my ($self, $group_id, $text) = @_;
    Carp::croak("Invalid tag") if not defined $text or $text !~ /^\w+$/;

    $text = lc $text;

    my $tag_id = $self->_get_tag_id($text);
    if (not $tag_id) {
        $tag_id = $self->_add_tag($text);
    }
    return if not $tag_id;

    my $dbh = CPAN::Forum::DBI::db_Main();
    return $dbh->do("INSERT INTO tags_on_groups (tag_id, group_id) VALUES (?, ?)",
            undef, $tag_id, $group_id);
}

# assume valid text
sub _add_tag {
    my ($self, $text) = @_;
    
    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sth->do("INSERT INTO tags (name) VALUES (?)", undef, $text);
    return $self->_get_tag_id($text);
}

# assume valid text
sub _get_tag_id {
    my ($self, $text) = @_;

    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sth = $dbh->prepare("SELECT id FROM tags WHERE name=?");
    $sth->execute($text);
    my ($id) = $sth->fetchrow_array;
    $sth->finish;
    return $id;
}


=head1 Design

Every person can put any tage on any module

On the page of every module we will list my tags and show a button to change
get_tags_of(module, person)
get_tags_of(module)
get_modules(tag, person)
get_modules(tag)

set_tag_on(module, person)


=cut

1;
