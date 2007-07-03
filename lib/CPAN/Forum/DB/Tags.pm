package CPAN::Forum::DB::Tags;
use strict;
use warnings;

use CPAN::Forum::DBI;

use Carp qw();

sub list_tags {
    my ($self, $group_id) = @_;
    my $dbh = CPAN::Forum::DBI::db_Main();
    #my $sth = $dbh->prepare("SELECT tags.name name FROM tags_on_groups, tags 
    #               WHERE tags_on_groups.tag_id=tags.id AND tags_on_groups.group_id=?");

    #$sth->execute($group_id);
    #my $ar = $sth->fetchrow_arrayref;
    #my @names = map { {name => $_->[0]} } @$ar;
    #my @names = map { $_->[0] } @$ar;
    #return @names;
    return qw(qqrq perl);
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

1;
