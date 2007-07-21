package CPAN::Forum::DB::Tags;
use strict;
use warnings;

use base 'CPAN::Forum::DBI';
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
    #return $self->_fetch_arrayref_of_hashes($sql, $uid, $group_id);
}

sub get_tags_of_module {
    my ($self, $group_id) = @_;
    #my $dbh = CPAN::Forum::DBI::db_Main();
    my $sql = "SELECT tags.name name, COUNT(tags.name) cnt 
                             FROM tag_cloud, tags
                             WHERE tag_cloud.tag_id=tags.id AND tag_cloud.group_id=?
                             GROUP BY name";
    return $self->_fetch_arrayref_of_hashes($sql, $group_id);

    #my $sth = $dbh->prepare($sql);
    #$sth->execute($group_id);
    #my $ar = $sth->fetchall_arrayref;
    #my @names = map { {name => $_->[0]} } @$ar;
    #return \@names;
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

    return $self->_fetch_single_value("SELECT id FROM tags WHERE name=?", $text);
}

# list tags currently in use, along with frequency
sub get_all_tags {
    my ($self) = @_;

    my $sql = "SELECT tags.name name, COUNT(name) total
                FROM tags, tag_cloud 
                WHERE tag_cloud.tag_id=tags.id
                GROUP BY name
                ORDER BY name ASC
                ";
    return $self->_fetch_arrayref_of_hashes($sql);
}

sub get_modules_with_tag {
    my ($self, $tag_name) = @_;

    my $sql = "SELECT groups.name, COUNT(*) cnt
               FROM groups, tags, tag_cloud
               WHERE groups.id=tag_cloud.group_id AND tag_cloud.tag_id=tags.id AND tags.name=?
               GROUP BY groups.name";
    return $self->_fetch_arrayref_of_hashes($sql, $tag_name);
}

sub list_modules_and_tags {
    my ($self) = @_;
    my $sql = "SELECT groups.name module, tags.name tag 
               FROM groups, tags, tag_cloud 
               WHERE tag_cloud.group_id=groups.id AND tag_cloud.tag_id=tags.id";
    return $self->_fetch_arrayref_of_hashes($sql);
}

sub dump_tags {
    my ($self) = @_;
    my $sql = "SELECT id, name FROM tags ORDER BY id";
    return $self->_dump($sql); 
}
sub dump_tag_cloud {
    my ($self) = @_;
    my $sql = "SELECT uid, tag_id, group_id FROM tag_cloud";
    return $self->_dump($sql); 
}

sub retrieve_latest {
    my ($self, $limit) = @_;

    my $sql = qq{SELECT tags.name tag, tag_cloud.stamp stamp, groups.name dist
                 FROM tags,tag_cloud,groups
                 WHERE tags.id=tag_cloud.tag_id AND tag_cloud.group_id=groups.id
                 ORDER BY tag_cloud.stamp DESC
                 LIMIT ?};
    return $self->_fetch_arrayref_of_hashes($sql, $limit);
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
