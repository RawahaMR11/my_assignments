#!/usr/local/packages/perl-5.6.1/bin/perl -w
##############################################################################
#
# File: xlink.pl
#
# Copyright 2002, 2004 Oracle. All rights reserved.
#
##############################################################################

=pod

=head1 NAME

xlink.pl -- Resolves cross-book deep links on a doc CD

=head1 SYNOPSIS

 xlink.pl [-(h|m)]

=head1 DESCRIPTION

From the root level of a doc CD, reviews HTML files looking for xlink
destinations and URLs pointing to them. If a URL is pointing to an
xlink destination that exists on the doc CD, the URL is replaced with
a link to the destination. If not, it is replaced with a link to the
no-exist page.

=head1 OPTIONS

=item -h help

=over 4

Print basic use information.

=back

=item -m modification time

=over 4

Preserve time stamps.

=back

=cut

##############################################################################

use strict;
use File::Find;
$|++;

our $NOEXIST = "../../dcommon/html/noexist.htm";
our %targets = ();
our @files_with_xlinks = ();
our @files_with_xlink_comments = ();

my $keeptime = 0; # Boolean: Change file modification time?
my @dirs = ('.'); # Must check current directory

# Get command-line arguments
# To do: use GetOpt
for (@ARGV) {
    if (/^-/ && /[h|?]/) {
        print "Resolves cross-book deep links on a doc CD.\n";
        print "Use perldoc for more information.\n";
        print "Use: xlink.pl [-(h|m)]\n\n";
        exit(0);
    }

    if (/^-/ && /m/) {
        $keeptime = "true";
    }
}

# Find xlinks in current directory
# Doc CD layout is assumed
find({ wanted => \&read,  no_chdir => 1 }, @dirs);

# Reset cursor ("wanted" writes a dot for each searched file)
print "\n";

#
# Create list of file names (without duplicates) containing xlink URIs
# See Perl Cookbook "Extracting Unique Elements From a List" for idiom
#
my %seen1 = (); 
my @unique1 = ();
for (@files_with_xlinks) {
    push(@unique1, $_) unless $seen1{$_}++;
}

my %seen2 = (); 
my @unique2 = ();
for (@files_with_xlink_comments) {
    push(@unique2, $_) unless $seen2{$_}++;
}

#
# Replace xlinks with URIs
#
print "Writing URLs...\n" if @unique1;
for (@unique1) {
    write_hrefs($_, $keeptime);
}

#
# Remove xLink Comments
#
print "Removing XLink Comments...\n" if @unique2;
for (@unique2) {
    remove_xlink_comments($_, $keeptime);
}

#print map {"$_ => $targets{$_}\n"} keys %targets; #print the substitutions

##############################################################################
#
# Function: wanted
#
# Provides an opportunity to do something with every file in the directory
# tree.
#
##############################################################################

sub read {
    if (!/img_text/ && !/javadoc/ && /\.html?$/) {
        gather_names($File::Find::name);
    }
}

##############################################################################
#
# Function: gather_names
#
# Associate xlink destinations with URIs and note files containing links to
# xlink destinations
#
##############################################################################

sub gather_names {
    my $file = shift; # File to search

    print "."; # Let user know something's going on

    open(FILE, "<$file") or warn "Can't open $file: $!";
    $/ = '>'; # Chunk on '>' to make matching elements easier
    while (<FILE>) {

        # if <a name="*valid xlink*">
        if (/<a\b[^>]*\bname\s*=\s*"([A-Z]{5}[0-9]{3,5})/i) {
            # Associate xlink codes with file names
            $targets{$1} = "../." . $file;
        }

        # if <a name="*valid xlink*|*Xlink Comment*">
        if (/"[A-Z]{5}[0-9]{3,5}\s*\|[^"]*"/) {
            # Add the file name to the list of files to edit
            push(@files_with_xlink_comments, $file);
        }

        # if <a href="*to valid xlink*">
        if (/<a\b[^>]*\bhref\s*=\s*"xlinkSRC(?: |%20|_)[A-Z]{5}[0-9]{3,5}/i) {
            # Add the file name to the list of files to change
            # Note: Multiple xlinks in the same file creates multiple entries
            push(@files_with_xlinks, $file);
        }
    }
    close(FILE) or warn "Can't close $file: $!";
}

##############################################################################
#
# Function: write_hrefs
#
# Replace links to xlink destinations with URIs
#
##############################################################################

sub write_hrefs {
    my $file = shift; # File to modify
    my $keeptime = shift; # Restore previous modification time?
    my $atime = 0; # Time file was last accessed
    my $mtime = 0; # Time file was last modified
    my $before_element = ""; # Text before the element
    my $aname = ""; # Value of name attribute of an 'a' element

    print "$file\n";
    ($atime, $mtime) = (stat($file))[8,9];  # get timestamp

    rename($file, "$file~") or die "Can't rename $file: $!";
    open(OLD, "<$file~")    or warn "Can't open $file~: $!";
    open(NEW, ">$file")     or warn "Can't create $file: $!";
    $/ = '>'; # Chunk on '>' to make matching elements easier
    while (<OLD>) {

        #
        # WebWorks writes invalid URIs as 'xlinkSRC XXXXX123' -- space
        # DocArch changes it to 'xlinkSRC_XXXXX123' -- underscore
        # Standard fix (from, say HTML-Tidy) is 'xlinkSRC%20XXXXX123' -- %20
        #
        if (/(.*?)<a\b[^>]*\bhref\s*=\s*"xlinkSRC(?: |%20|_)([A-Z]{5}[0-9]{3,5})"[^>]*>/i) {
            $before_element = $1;
            $aname = $2; # collect xlink destination code

            #
            # Note that 'xlinkSRC' and the xlink code are written into the
            # class attribute for the a element
            # The value of a class element is a space-separated list of
            # user-defined identifiers
            # This way, CSS could highlight all xlinks or certain xlinks
            # Writing this information into a comment would be wrong and
            # wasteful, since the info can't be used in any standard way
            #
            if ($targets{$aname}) {
                print NEW "$before_element<a class=\"xlinkSRC $aname\" href=\"$targets{$aname}#$aname\">";
            }
            else {
                print NEW "$before_element<a class=\"xlinkSRC $aname\" href=\"$NOEXIST\">";
            }
        }
        else {
            print NEW;
        }
    }
    close(NEW)              or warn "Can't close $file: $!";
    close(OLD)              or warn "Can't close $file~: $!";
    unlink("$file~")        or warn "Can't delete $file~: $!";

    utime($atime, $mtime, $file) if $keeptime; # restore timestamp
}

##############################################################################
#
# Function: remove_xlink_comments
#
# Remove xLink Comments.
#
##############################################################################

sub remove_xlink_comments {
    my $file = shift; # File to modify
    my $keeptime = shift; # Restore previous modification time?
    my $atime = 0; # Time file was last accessed
    my $mtime = 0; # Time file was last modified

    print "$file\n";
    ($atime, $mtime) = (stat($file))[8,9];  # get timestamp

    rename($file, "$file~") or die "Can't rename $file: $!";
    open(OLD, "<$file~")    or warn "Can't open $file~: $!";
    open(NEW, ">$file")     or warn "Can't create $file: $!";
    $/ = '>'; # Chunk on '>' to make matching elements easier
    while (<OLD>) {
        s{"([A-Z]{5}[0-9]{3,5})\s*\|[^"]*?"}{"$1"}g;
        print NEW $_;
    }
    close(NEW)              or warn "Can't close $file: $!";
    close(OLD)              or warn "Can't close $file~: $!";
    unlink("$file~")        or warn "Can't delete $file~: $!";

    utime($atime, $mtime, $file) if $keeptime; # restore timestamp
}

__END__

#=head1 RETURN VALUE
#=head1 ERRORS
#=head1 EXAMPLES
#=head1 ENVIRONMENT
#=head1 FILES
#=head1 SEE ALSO
#=head1 NOTES
#=head1 CAVEATS
#=head1 DIAGNOSTICS
#=head1 BUGS
#=head1 RESTRICTIONS

=pod

=head1 AUTHOR

Robert Crews <robert.crews@oracle.com>

=cut

#=head1 HISTORY

=pod

=head1 COPYRIGHT

Copyright 2002 by Oracle, Inc. All rights reserved

=cut
