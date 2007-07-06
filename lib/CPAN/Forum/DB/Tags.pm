package CPAN::Forum::DB::Tags;
use strict;
use warnings;

use CPAN::Forum::DBI;

use Carp qw();

sub get_tags_hash_of {
    my ($self, $group_id, $uid) = @_;
    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sql = "SELECT tags.name, tags.id
                             FROM tag_cloud, tags
                             WHERE tag_cloud.tag_id=tags.id AND tag_cloud.uid=? AND tag_cloud.group_id=?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($uid, $group_id);
    my %tags;
    while (my ($name, $id) = $sth->fetchrow_array) {
        $tags{$name} = $id;
    }
    return \%tags;
}


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
    my $ar = $sth->fetchall_arrayref;
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
    my $ar = $sth->fetchall_arrayref;
    my @names = map { {name => $_->[0]} } @$ar;
    return \@names;
}

sub attach_tag {
    my ($self, $uid, $group_id, $text) = @_;
    Carp::croak("Missing tag") if not defined $text;
    #Carp::croak("Invalid tag") if not defined $text or $text !~ /^\w+$/;

    $text = lc $text;

    my $tag_id = $self->_get_tag_id($text);
    if (not $tag_id) {
        $tag_id = $self->_add_tag($text);
    }
    return if not $tag_id;

    my $dbh = CPAN::Forum::DBI::db_Main();
    return $dbh->do("INSERT INTO tag_cloud (tag_id, group_id, uid, stamp) VALUES (?, ?, ?, ?)",
            undef, $tag_id, $group_id, $uid, time);
}

sub remove_tag {
    my ($self, $uid, $group_id, $tag_id) = @_;

    my $dbh = CPAN::Forum::DBI::db_Main();
    return $dbh->do("DELETE FROM tag_cloud WHERE uid=? AND group_id=? AND tag_id=?",
                undef,
                $uid, $group_id, $tag_id);
}

# assume valid text
sub _add_tag {
    my ($self, $text) = @_;
    
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do("INSERT INTO tags (name) VALUES (?)", undef, $text);
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

sub get_all_tags {
    my ($self) = @_;

    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sql = "SELECT name
                FROM tags
                WHERE id IN (SELECT DISTINCT tag_id FROM tag_cloud) ORDER BY name ASC";
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my @tags;
    while (my $hr = $sth->fetchrow_hashref) {
        push @tags, $hr;
    }
    return \@tags;
}

sub get_modules_with_tag {
    my ($self, $tag_name) = @_;

    my $sql = "SELECT groups.name, COUNT(*) cnt
               FROM groups, tags, tag_cloud
               WHERE groups.id=tag_cloud.group_id AND tag_cloud.tag_id=tags.id AND tags.name=?
               GROUP BY groups.name";
    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sth = $dbh->prepare($sql);
    $sth->execute($tag_name);
    my @res;
    while (my $hr = $sth->fetchrow_hashref) {
        push @res, $hr;
    }
    return \@res;
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
