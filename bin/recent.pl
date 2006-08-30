#!/usr/bin/perl
use strict;
use warnings;


# client for processing the most recent
# PAUSE uploads ftp://www.cpan.org/modules/01modules.mtime.rss
#


use FindBin qw ($Bin);
use LWP::Simple qw(getstore);
use XML::RSS;
use CPAN::DistnameInfo;
use Getopt::Long qw(GetOptions);
use lib "lib";
use CPAN::Forum::INC;

my $dir          = "$Bin/../db";
my $dbfile       = "$dir/forum.db";

my %opts;

CPAN::Forum::DBI->myinit($dbfile);

GetOptions(\%opts, "sendmail", "file=s");


my $remote_file = "http://www.cpan.org/modules/01modules.mtime.rss";
my $local_file = $opts{file};

if (not $local_file or not -e $local_file) {
	$local_file = "db/01modules.mtime.rss";
	print "Fetching $remote_file\n";
	getstore $remote_file, $local_file;
}


my $rss = XML::RSS->new();
$rss->parsefile($local_file);

my %message = (
	version => "",
	pauseid => "",
	news    => "",
);

foreach my $item (reverse @{$rss->{items}}) {
	my $link = $item->{link};
	$link =~ s{^http://www.cpan.org/modules/by-authors/}{authors/};
	my $d = CPAN::DistnameInfo->new($link);
	#print $link, "\n";
	#print $d->dist, "\n";
	#print $d->version, "\n";
	#print $d->cpanid(), "\n";
	
	my $name = $d->dist();
	my %new = (
		version => ($d->version() || ""),
		pauseid => ($d->cpanid()  || ""),
	);

	my ($g) = CPAN::Forum::DB::Groups->search(name => $name);
	if ($g) {
		my $changed;
		foreach my $field (qw(version pauseid)) {
			#print "$name\n";
			#print "NEW: $new{$field}\n";
			#print "OLD: " . $g->$field, "\n";
			#<STDIN>;
			$new{version} =~ s/\.?0*$//; # so it won't try to update numbers with 00 or . endings.
			if (not defined $g->$field or $g->$field ne $new{$field}) {
				#print "change\n";
				$message{$field} .= sprintf "The %s of %s has changed from %s to %s\n",
								$field, $name, ($g->$field || ""), $new{$field};
				$g->$field($new{$field});
				$changed++;
			}
		}

		$g->update if $changed;
		next;
	}

	$message{news} .= sprintf "%s   %s\n", $name, $new{version}, $new{pauseid};
	eval {
		my $g = CPAN::Forum::DB::Groups->create({
			name    => $name,
			gtype   => $CPAN::Forum::DBI::group_types{Distribution}, 
			version => $new{version},
			pauseid => $new{pauseid},
		});
	};
	if ($@) {
		warn "$name\n";
		warn $@;
	}
}

my %mail = (
	To       => 'gabor@pti.co.il',
	From     => 'cpanforum@cpanforum.com',
	Subject  => 'CPAN Version Update',
	Message  => $message{version},
);
if ($opts{sendmail}) {
	sendmail(%mail);
} else {
	open my $fh, ">", "$Bin/../cpan_version_update";
	print $fh $message{version};
}

%mail = (
	To       => 'gabor@pti.co.il',
	From     => 'cpanforum@cpanforum.com',
	Subject  => 'New CPAN Distros',
	Message  => $message{news},
);
if ($opts{sendmail}) {
	sendmail(%mail);
} else {
	open my $fh, ">", "$Bin/../cpan_new_distros";
	print $fh $message{news};
}



