package CPAN::Forum::Posts;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('posts');
__PACKAGE__->columns(All => qw/id gid uid parent subject text date thread hidden/);
#__PACKAGE__->has_many(responses => "CPAN::Forum::Posts");
__PACKAGE__->has_a(parent => "CPAN::Forum::Posts");
__PACKAGE__->has_a(uid => "CPAN::Forum::Users");
__PACKAGE__->has_a(gid => "CPAN::Forum::Groups");
__PACKAGE__->set_sql(latest => "SELECT __ESSENTIAL__ FROM __TABLE__ ORDER BY DATE DESC LIMIT %s");
__PACKAGE__->set_sql(count_thread => "SELECT count(*) FROM __TABLE__ WHERE thread=%s");
__PACKAGE__->set_sql(count_where  => "SELECT count(*) FROM __TABLE__ WHERE %s='%s'");
__PACKAGE__->set_sql(count_like   => "SELECT count(*) FROM __TABLE__ WHERE %s LIKE '%s'");
#__PACKAGE__->add_constraint('subject_too_long', subject => sub { length $_[0] <= 70 and $_[0] !~ /</});
#__PACKAGE__->add_constraint('text_format', text => \&check_text_format);

sub retrieve_latest { 
	my ($class, $count) = @_;
	
#	$where = $where ? "WHERE $where" : "";
	return $class->sth_to_objects($class->sql_latest($count));
}

sub mysearch {
	my ($self, $params, $page, $per_page) = @_;

	my %where;

	my $pager = __PACKAGE__->pager(
		where         => \%where,
		per_page      => $per_page || 10,
		page          => $page || 1,
#		order_by      => $order_by,
	);
}

1;
 

