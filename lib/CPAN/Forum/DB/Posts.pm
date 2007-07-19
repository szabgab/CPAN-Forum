package CPAN::Forum::DB::Posts;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('posts');
__PACKAGE__->columns(All => qw/id gid uid parent subject text date thread hidden/);
__PACKAGE__->columns(Essential => qw/id gid uid parent subject text date thread hidden/);
#__PACKAGE__->has_many(responses => "CPAN::Forum::DB::Posts");
__PACKAGE__->has_a(parent => "CPAN::Forum::DB::Posts");
__PACKAGE__->has_a(uid    => "CPAN::Forum::DB::Users");
__PACKAGE__->has_a(gid    => "CPAN::Forum::DB::Groups");

__PACKAGE__->set_sql(latest         => "SELECT __ESSENTIAL__ FROM __TABLE__ ORDER BY DATE DESC LIMIT %s");

__PACKAGE__->set_sql(count_thread   => "SELECT count(*) FROM __TABLE__ WHERE thread=%s");
__PACKAGE__->set_sql(count_where    => "SELECT count(*) FROM __TABLE__ WHERE %s='%s'");
__PACKAGE__->set_sql(count_like     => "SELECT count(*) FROM __TABLE__ WHERE %s LIKE '%s'");
#__PACKAGE__->add_constraint('subject_too_long', subject => sub { length $_[0] <= 70 and $_[0] !~ /</});
#__PACKAGE__->add_constraint('text_format', text => \&check_text_format);
__PACKAGE__->set_sql(stat_posts_by_group => qq{
            SELECT COUNT(*) cnt, groups.name gname
            FROM posts,groups 
            WHERE posts.gid=groups.id
            GROUP BY gname
            ORDER BY cnt DESC
            LIMIT ?
            });

__PACKAGE__->set_sql(stat_posts_by_user => qq{
            SELECT COUNT(*) cnt, users.username username 
            FROM posts,users
            WHERE posts.uid=users.id
            GROUP BY username
            ORDER BY cnt DESC
            LIMIT ?
            });
my $MORE_SQL = 'groups.name group_name, users.fname user_fname, users.lname user_lname, users.username user_username';

sub get_post {
    my ($self, $post_id) = @_;
    return if not $post_id;
    #Carp::croak("No post_id given") if not $post_id;

    my $sql = "SELECT posts.id, gid, uid, parent, thread, hidden, subject, text, date,
                groups.name group_name, groups.pauseid
                FROM posts, groups
                WHERE posts.id=? AND posts.gid=groups.id";
    return $self->_fetch_single_hashref($sql, $post_id);
}

sub retrieve_latest { 
    my ($self, $limit) = @_;

    $limit ||= 10;
    my $sql = "SELECT posts.id id, posts.subject, 
                $MORE_SQL
                FROM posts, groups, users
                WHERE posts.gid=groups.id AND posts.uid=users.id
                ORDER BY date DESC LIMIT ?";
    #$self->log->debug("SQL: $sql");

    return $self->_fetch_arrayref_of_hashes($sql, $limit);
}

sub search_post_by_groupname {
    my ($self, $groupname, $limit) = @_;

    return [] if not $groupname;
    $limit ||= 10;
    my $sql = qq{SELECT posts.id id, posts.subject,
                        $MORE_SQL
                        FROM posts, groups, users
                        WHERE groups.name=?
                            AND posts.gid=groups.id AND posts.uid=users.id
                        ORDER BY date DESC LIMIT ?};
    return $self->_fetch_arrayref_of_hashes($sql, $groupname, $limit);
}
sub search_post_by_pauseid {
    my ($self, $pauseid, $limit) = @_;

    return [] if not $pauseid;
    $limit ||= 10;
    my $sql = qq{SELECT posts.id id, posts.subject,
                        $MORE_SQL
                        FROM posts, groups, users
                        WHERE gid IN (
                            SELECT DISTINCT groups.id 
                            FROM groups, authors
                            WHERE groups.pauseid=authors.id and authors.pauseid=?)
                            AND posts.gid=groups.id AND posts.uid=users.id
                        ORDER BY date DESC LIMIT ?};
    return $self->_fetch_arrayref_of_hashes($sql, $pauseid, $limit);
}


sub search_latest_threads {
    my ($self, $limit) = @_;

    $limit ||= 10;
    my $sql = "SELECT A.id, A.thread, A.subject subject, A.date,
            $MORE_SQL
            FROM posts A, groups, users
            WHERE 
            thread IN (
                SELECT DISTINCT X.thread FROM posts X WHERE X.thread IN (
                    SELECT B.thread FROM posts B ORDER BY B.date DESC LIMIT ?)) 
            AND 
            A.id IN (SELECT max(id) FROM posts C WHERE C.thread=A.thread)
            AND A.gid=groups.id AND A.uid=users.id
            ORDER BY A.date DESC";

    return $self->_fetch_arrayref_of_hashes($sql, $limit);
}
sub mysearch {
    my ($self, $params) = @_;

    my %where  = %{$params->{where}};
    %where = (1 => 1) if not %where;

    my $pager = __PACKAGE__->pager(
        where         => \%where,
        per_page      => $params->{per_page} || 10,
        page          => $params->{page}     || 1,
        order_by      => $params->{order_by} || "id DESC",
    );
}

sub list_counted_posts {
    my ($self) = @_;
    my $sql = "SELECT groups.name gname, COUNT(*) cnt
               FROM posts, groups
               WHERE posts.gid=groups.id
               GROUP BY gname
               ORDER BY cnt DESC";
    return $self->_fetch_arrayref_of_hashes($sql);
}

1;
 
