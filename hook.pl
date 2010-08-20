#!/usr/bin/perl -w
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the VCS Bugzilla Extension.
#
# The Initial Developer of the Original Code is Red Hat, Inc.
# Portions created by the Initial Developer are Copyright (C) 2010 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Max Kanat-Alexander <mkanat@everythingsolved.com>

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use RPC::XML::Client;
use Scalar::Util qw(blessed);

our %switch;

sub trim {
    my ($value) = @_;
    $value =~ s/^\s+//s;
    $value =~ s/\s+$//s;
    return $value;
}

sub _error {
    my ($err) = @_;
    if (blessed $err) {
        die "Bugzilla Error: (" . $err->code . ") " . $err->string . "\n";
    }
    die $err;
}

###############
# Main Script #
###############

GetOptions(\%switch, 'help|h|?', 'config=s', 'repo=s', 'project=s',
                     'bug=s', 'revision=s', 'login=s', 'pass=s', 'bugzilla=s')
    || die $@;
my @required = qw(repo project bug revision login pass bugzilla);

if (my $filename = $switch{'config'}) {
    open(my $fh, '<', $filename) or die "$filename: $!";
    foreach my $line (<$fh>) {
        $line = trim($line);
        next if $line eq '' || $line =~ /^#/;
        my ($field, $value) = split(':', $line, 2);
        $field = lc($field);
        next if $switch{$field};
        $switch{$field} = trim($value);
    }
    close($fh);
}

# Print the help message if --help was set or if the required switches
# weren't provided.
pod2usage({-exitval => 1}) if (!keys %switch or $switch{'help'});
foreach my $item (@required) {
    if (!$switch{$item}) {
        die "You must specify a value for the '$item' switch.\n";
    }
}
if ($switch{'bugzilla'} !~ m{/$}) {
    die "The 'bugzilla' argument must end with a slash (/).\n";
}

my $client = RPC::XML::Client->new($switch{'bugzilla'} . 'xmlrpc.cgi',
                                   combined_handler => \&_error);
my $response = $client->simple_request('VCS.add_commit', {
    Bugzilla_login => $switch{'login'}, Bugzilla_password => $switch{'pass'},
    repo => $switch{'repo'}, project => $switch{'project'},
    bug_id => $switch{'bug'}, revision => $switch{'revision'},
});

__END__

=head1 NAME

hook.pl - A helper for implementing version-control hooks to update Bugzilla
when a checkin is done.

=head1 SYNOPSIS

 hook.pl --bug=<id> --revision=<id> --project=<path> --config=<file>

=head1 OPTIONS

=over

=item B<--config=file>

The path to a file that contains a configuration for this script. The
contents of the file would look something like:

 repo: http://svn.mozilla.org/
 login: user@example.com
 pass: mypass
 bugzilla: https://bugzilla.mozilla.org/

Each line replaces the value of a switch to this script.

=item B<--bug=id>

The id of the bug you're associating this commit to.

=item B<--revision=id>

The "revision id" of the commit that you're associating with a bug.
In some VCSes, this is different from the "revision number".

=item B<--project=path>

The path to the "project" in the VCS that's being updated, relative to
the root of the repository. Usually this is just a path to the branch
being updated.

=item B<--repo=url>

The "repository" that's being updated. The root of your VCS.

=item B<--login=user>

The Bugzilla user that will be used to update the bug.

=item B<--pass=password>

The password for the Bugzilla user.

=item B<--bugzilla=url>

The URL to your Bugzilla installation, ending with a slash.

=item B<--help>

Display this help.

=back
