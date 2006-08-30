package CPAN::Forum::DB::Posts;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('posts');
__PACKAGE__->columns(All => qw/id gid uid parent subject text date thread hidden/);
#__PACKAGE__->has_many(responses => "CPAN::Forum::DB::Posts");
__PACKAGE__->has_a(parent => "CPAN::Forum::DB::Posts");
__PACKAGE__->has_a(uid    => "CPAN::Forum::DB::Users");
__PACKAGE__->has_a(gid    => "CPAN::Forum::DB::Groups");

__PACKAGE__->set_sql(latest         => "SELECT __ESSENTIAL__ FROM __TABLE__ ORDER BY DATE DESC LIMIT %s");
#__PACKAGE__->set_sql(latest_threads => "SELECT A.id, A.thread, A.date FROM posts A WHERE 
#            thread IN (SELECT DISTINCT B.thread FROM posts B ORDER BY B.date DESC LIMIT ?) 
#            AND 
#            id IN (SELECT max(id) FROM posts C WHERE C.thread=A.thread)
#            ORDER BY A.date DESC");

__PACKAGE__->set_sql(latest_threads => "SELECT A.id, A.thread, A.date FROM posts A WHERE 
            thread IN (
                SELECT DISTINCT X.thread FROM posts X WHERE X.thread IN (
                    SELECT B.thread FROM posts B ORDER BY B.date DESC LIMIT ?)) 
            AND 
            id IN (SELECT max(id) FROM posts C WHERE C.thread=A.thread)
            ORDER BY A.date DESC");

__PACKAGE__->set_sql(count_thread   => "SELECT count(*) FROM __TABLE__ WHERE thread=%s");
__PACKAGE__->set_sql(count_where    => "SELECT count(*) FROM __TABLE__ WHERE %s='%s'");
__PACKAGE__->set_sql(count_like     => "SELECT count(*) FROM __TABLE__ WHERE %s LIKE '%s'");
#__PACKAGE__->add_constraint('subject_too_long', subject => sub { length $_[0] <= 70 and $_[0] !~ /</});
#__PACKAGE__->add_constraint('text_format', text => \&check_text_format);
__PACKAGE__->set_sql(post_by_pauseid => qq{
                        SELECT posts.id id
                        FROM posts
                        WHERE gid IN (
                            SELECT DISTINCT groups.id 
                            FROM groups, authors
                            WHERE groups.pauseid=authors.id and authors.pauseid=?)
                        ORDER BY date DESC});
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

sub retrieve_latest { 
    my ($class, $count) = @_;
    
#   $where = $where ? "WHERE $where" : "";
    return $class->sth_to_objects($class->sql_latest($count));
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

1;
 
