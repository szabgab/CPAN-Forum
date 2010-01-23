package CPAN::Forum::DBI;
use strict;
use warnings;

our $VERSION = '0.18';

use Carp qw();
use Data::Dumper ();
use DBI;

my $dbh;

sub myinit {
	my ($class) = @_;

	Carp::croak('myinit now gets only one parameter and that is the class name') if @_ != 1;
	Carp::croak('CPAN_FORUM_DB needs to be configured')                          if not $ENV{CPAN_FORUM_DB};
	Carp::croak('CPAN_FORUM_USER needs to be configured')                        if not $ENV{CPAN_FORUM_USER};

	if ( not $dbh ) {
		$dbh = DBI->connect(
			"dbi:Pg:dbname=$ENV{CPAN_FORUM_DB}",
			$ENV{CPAN_FORUM_USER},
			$ENV{CPAN_FORUM_PW},
			{   RaiseError       => 1,
				PrintError       => 1,
				AutoCommit       => 1,
				FetchHashKeyName => 'NAME_lc',
			}
		);
		$dbh->{HandleError} = sub { Carp::confess(shift); };
	}
	return $dbh;
}

sub db_Main {
	return $dbh;
}


our @group_types = ( "None", "Global", "Field", "Distribution", "Module" );
our %group_types;
$group_types{ $group_types[$_] } = $_ for ( 0 .. $#group_types );

# Initialize the database
sub init_db {
	my ($class) = @_;

	Carp::croak('init_db now gets only one parameter and that is the class name') if @_ != 1;
	Carp::croak('CPAN_FORUM_DB needs to be configured')                           if not $ENV{CPAN_FORUM_DB};
	Carp::croak('CPAN_FORUM_USER needs to be configured')                         if not $ENV{CPAN_FORUM_USER};

	# TODO check result, hide irrelevant output?
	#    system qq(psql $ENV{CPAN_FORUM_DB} -c "GRANT ALL PRIVILEGES ON DATABASE $ENV{CPAN_FORUM_DB} TO $ENV{CPAN_FORUM_USER}" );
	system qq(psql -q -U $ENV{CPAN_FORUM_USER} $ENV{CPAN_FORUM_DB} < schema/drop.sql);
	system qq(psql -q -U $ENV{CPAN_FORUM_USER} $ENV{CPAN_FORUM_DB} < schema/schema.sql);

	return 1;
}


# helper function for plain DBI calls
sub _fetch_arrayref_of_hashes {
	my ( $self, $sql, @args ) = @_;

	my $dbh = CPAN::Forum::DBI::db_Main();
	my $sth = $dbh->prepare($sql);
	$sth->execute(@args);
	my @values;
	while ( my $hr = $sth->fetchrow_hashref ) {
		push @values, $hr;
	}
	return \@values;
}

sub _fetch_single_hashref {
	my ( $self, $sql, @args ) = @_;

	my $dbh = CPAN::Forum::DBI::db_Main();
	my $sth = $dbh->prepare($sql);
	$sth->execute(@args);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	return $hr;
}

sub _fetch_single_value {
	my ( $self, $sql, @args ) = @_;

	my $dbh = CPAN::Forum::DBI::db_Main();
	my $sth = $dbh->prepare($sql);
	$sth->execute(@args);
	my ($value) = $sth->fetchrow_array;
	$sth->finish;
	return $value;
}

sub _dump {
	my ( $self, $sql, %args ) = @_;
	my $dbh = CPAN::Forum::DBI::db_Main();
	return $dbh->selectall_arrayref( $sql, \%args );
}

sub count_rows_in {
	my ( $self, $table ) = @_;
	return $self->_fetch_single_value("SELECT COUNT(*) FROM $table");
}

# TODO this selectall_hashref and the _fetch_hashref seem to server very similar
# purposes
sub _selectall_hashref {
	my ( $self, $sql, $key, @args ) = @_;
	my $dbh = CPAN::Forum::DBI::db_Main();
	return $dbh->selectall_hashref( $sql, $key, undef, @args );
}

sub _select_column {
	my ( $self, $sql, @args ) = @_;
	my $dbh = CPAN::Forum::DBI::db_Main();
	return $dbh->selectcol_arrayref( $sql, undef, @args );
}


# given an SQL statement with two columns selected:
# SELECT key, value FROM table WHERE ...;
# returns a hash reference where the keys are built from
# the first column and the values from the second column
sub _fetch_hashref {
	my ( $self, $sql, @args ) = @_;

	my $dbh = CPAN::Forum::DBI::db_Main();
	my $sth = $dbh->prepare($sql);
	$sth->execute(@args);
	my %h;
	while ( my ( $key, $value ) = $sth->fetchrow_array ) {
		$h{$key} = $value;
	}
	return \%h;
}


# code for the Subscription* tables
sub _complex_update {
	my ( $self, $where, $on, $data, $table ) = @_;
	if ($on) {
		my $s = $self->find_one(%$where);
		if ($s) {
			$self->update( $table, $where, $data );
		} else {
			$self->add( $table, { %$data, %$where } );
		}

	} else {
		$self->delete( $table, $where );
	}
	return;
}

sub add {
	my ( $self, $table, $args ) = @_;

	# check if $table is one of the subscription tables?
	my ( $fields, $placeholders, @values ) = $self->_prep_insert($args);
	my $sql = "INSERT INTO $table ($fields) VALUES($placeholders)";
	my $dbh = CPAN::Forum::DBI::db_Main();

	$dbh->do( $sql, undef, @values );
	return;
}


sub update {
	my ( $self, $table, $args, $data ) = @_;

	# check if $table is one of the subscription tables?
	my ( $where, @where_values ) = $self->_prep_where($args);
	Carp::croak("") if not $where;
	my ( $set, @new_values ) = $self->_prep_set($data);
	my $sql = "UPDATE $table SET $set WHERE $where";
	my $dbh = CPAN::Forum::DBI::db_Main();

	$dbh->do( $sql, undef, @new_values, @where_values );
	return;
}

sub delete {
	my ( $self, $table, $args ) = @_;
	my ( $where, @values ) = $self->_prep_where($args);
	my $sql = "DELETE FROM $table";
	if ($where) {
		$sql .= " WHERE $where";
	}
	my $dbh = CPAN::Forum::DBI::db_Main();
	$dbh->do( $sql, undef, @values );
	return;
}

# _prep_where({ field => value, field2 => value2 });
# _prep_where({ field => [v1, v2, v3]);
# return("field=? AND field2=?",    value, value2);
sub _prep_where {
	my ( $self, $args ) = @_;

	#Carp::cluck (Data::Dumper->Dump([$args], ['args']));

	my @fields = keys %$args;
	my @FIELDS;
	my @values;
	foreach my $f (@fields) {
		if ( not ref $args->{$f} ) {
			push @FIELDS, "$f=?";
			push @values, $args->{$f};
		} elsif ( 'HASH' eq ref $args->{$f} ) {
			my @k = keys %{ $args->{$f} };
			Carp::croak("don't know how to handle more than one keys in $f") if @k != 1;
			if ( $k[0] eq 'LIKE' ) {
				push @FIELDS, "$f LIKE ?";
				push @values, $args->{$f}{ $k[0] };
			} else {
				Carp::croak( "don't know how to handle $k[0] of field $f " . Data::Dumper->Dump( [$args], ['args'] ) );
			}
		} elsif ( 'ARRAY' eq ref $args->{$f} ) {
			push @FIELDS, "$f IN (" . ( join ", ", ( ("?") x @{ $args->{$f} } ) ) . ")";
			push @values, @{ $args->{$f} };
		} else {
			Carp::croak(
				"don't know how to handle $args->{$f} of field $f " . Data::Dumper->Dump( [$args], ['args'] ) );
		}
	}

	my $where = join " AND ", @FIELDS;
	my %args = %$args;
	return ( $where, @values );
}

sub _prep_set {
	my ( $self, $args ) = @_;
	my @fields = keys %$args;

	my $where = join ", ", map {"$_=?"} @fields;
	my %args = %$args;
	return ( $where, @args{@fields} );

	#return ($where, @{ $args->{@fields} });
}


# gets a hash reference of  field names mapped to values
# return
#    a partial SQL statement of the fieldnames
#    a partial SQL statement of the placeholders
#    list of values matching
#
#    $obj->_prep_insert({ fname => "Foo", lname => "Bar" })
#    returns( "fname, lname",   "?, ?",    "Foo", "Bar" );
sub _prep_insert {
	my ( $self, $args ) = @_;

	my @fields       = keys %$args;
	my $fields       = join ", ", @fields;
	my $placeholders = join ", ", ( ("?") x scalar @fields );
	my %args         = %$args;
	return ( $fields, $placeholders, @args{@fields} );

	#return ($fields, $placeholders, @{ $args->{@fields} });
}

sub mypager {
	my ( $self,  %args )   = @_;
	my ( $where, @values ) = $self->_prep_where( $args{where} );

	my $fetch_sql =
		"SELECT posts.id, subject, thread, date, 
			   extract(epoch from date_trunc('seconds', NOW()-date)) AS seconds,
				username, groups.name AS group_name FROM posts, users, groups";
	my $count_sql    = "SELECT COUNT(*) FROM posts";
	my @fetch_values = @values;

	if ($where) {
		$fetch_sql .= " WHERE $where";
		$count_sql .= " WHERE $where";
	}

	if ($where) {
		$fetch_sql .= " AND ";
	} else {
		$fetch_sql .= " WHERE ";
	}
	$fetch_sql .= " users.id=posts.uid AND groups.id=posts.gid";

	my $order_by = $args{order_by};
	$order_by =~ s/^\s*id/posts.id/;
	$fetch_sql .= " ORDER BY $order_by";

	$fetch_sql .= " LIMIT ?";
	my $limit = $args{per_page} || 10;
	push @fetch_values, $limit;

	my $page = $args{page} || 1;
	my $offset = $limit * ( $page - 1 );
	if ( $page > 1 ) {
		$fetch_sql .= " OFFSET ?";
		push @fetch_values, $offset;
	}

	my $total = $self->_fetch_single_value( $count_sql, @values );

	my $results = $self->_fetch_arrayref_of_hashes( $fetch_sql, @fetch_values );

	my $last_page = int( $total / $limit );
	if ( $last_page != $total / $limit ) {
		$last_page++;
	}

	my %pager = (
		total_entries => $total,
		first_entry   => 1 + $offset,
		last_entry    => $offset + @$results,

		results       => $results,
		first_page    => 1,
		last_page     => $last_page,
		previous_page => ( $page > 1 ? $page - 1 : 0 ),
		next_page     => ( $page < $last_page ? $page + 1 : 0 ),
		current_page  => $page,
	);

	return \%pager;
}

1;

