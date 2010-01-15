#!/usr/bin/perl
use strict;
use warnings;

# check if there are versions in every module and if they are in the same
# allow updating version numbers to one specific version.

use File::Find::Rule;
use File::Slurp qw(read_file write_file);

my $version = shift;
die "Usage: $0 VERSION\n" if not $version or $version !~ /^\d\.\d\.?\d$/;
print "Setting VERSION $version\n";

my @files = File::Find::Rule->file->name('*.pm')->in('lib');
foreach my $file (@files) {
    my @data = read_file($file);
    if (grep {$_ =~ /^our \$VERSION\s*=\s*'\d+\.\d\.?\d';/ } @data ) {
       my @new = map {$_ =~ s/^(our \$VERSION\s*=\s*)'\d+\.\d\.?\d';/$1'$version';/; $_ } @data;
       write_file($file, @new);
    } else {
       warn "No VERSION in $file\n";
    }
}

