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
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Install::Util qw(indicate_progress);
use Bugzilla::User;
use Bugzilla::Util;

BEGIN { Bugzilla->extensions }
use Bugzilla::Extension::VCS::Commit;

use Getopt::Long;
use Pod::Usage;
use VCI;

our (%switch, $bug_re);

###############
# Subroutines #
###############

sub sync_project {
    my ($project) = @_;
    my $commits = $project->history->commits;
    my $total = scalar(@$commits);
    my $count = 0;
    foreach my $commit (@$commits) {
        sync_commit($commit);
        indicate_progress({ total => $total, current => ++$count, every => 20 });
    }
}

sub sync_commit {
    my ($commit) = @_;
    my @bug_ids = ($commit->message =~ /$bug_re/g);
    foreach my $bug_id (@bug_ids) {
        my $bug = new Bugzilla::Bug($bug_id);
        if ($bug->{error}) {
            my $rev = $commit->revision;
            my $as = $switch{'as'};
            warn "Bug $bug_id was mentioned in commit $rev but does not exist"
                 . " or cannot be accessed by $as.\n";
            next;
        }
        next if Bugzilla::Extension::VCS::Commit->exists($commit, $bug);
        Bugzilla::Extension::VCS::Commit->create_from_commit($commit, $bug);
    }
}

###############
# Main Script #
###############

GetOptions(\%switch, 'help|h|?', 'type=s', 'as=s', 'verbose|v+', 'project=s',
                     'bug-word=s@', 'dry-run|n') || die $@;

# Print the help message if that switch was selected or if --type
# wasn't specified.
if (!$switch{'as'} or !$switch{'type'} or !$ARGV[0] or $switch{'help'}) {
    pod2usage({-exitval => 1});
}

my $as = Bugzilla::User->check($switch{'as'});
Bugzilla->set_user($as);

my $bug_word = template_var('terms')->{bug};
my @bug_words = ($bug_word, @{ $switch{'bug-word'} || [] });
my @re_words = map { quotemeta($_) } @bug_words;
my $bug_word_re = join('|', @re_words);
$bug_re = qr/\b(?:$bug_word_re)\s+(\d+)/is;

my $repo = VCI->connect(repo => $ARGV[0], type => $switch{'type'},
                        debug => $switch{'verbose'});
my @projects;
if ($switch{'project'}) {
    my $project = $repo->get_project(name => $switch{'project'});
    if (!$project) {
        die "No such project: " . $switch{'project'};
    }
    @projects = ($project);
    
}
else {
    @projects = @{ $repo->projects };
}

my $dbh = Bugzilla->dbh;

$dbh->bz_start_transaction();
foreach my $project (@projects) {
    my $name = $project->name;
    print "Syncing $name...\n";
    sync_project($project);
}

if ($switch{'dry-run'}) {
    $dbh->bz_rollback_transaction();
    $dbh->bz_set_next_serial_value('vcs_commit', 'id');
    $dbh->bz_set_next_serial_value('vcs_commit_file', 'id');
}
else {
    $dbh->bz_commit_transaction();
}

__END__

=head1 NAME

sync.pl - Synchronize commit data between a VCS repository and Bugzilla.

=head1 SYNOPSIS

 sync.pl --type=<type> --as=<user> [options] repo

=head1 OPTIONS

=over

=item B<--type=name>

B<(Required)> The type of version control system that you are syncing with.
Svn, Hg, Bzr, Git, or Cvs.

=item B<--as=user>

B<(Required)> The Bugzilla username who will be recorded in the database
as the person syncing these commits.

=item B<--project=name>

If you want to sync only one project from the repo, specify it here.

=item B<--bug-word=word>

If you want to match other words than "bug", you can specify another
word here. This can be specified multiple times.

=item B<--dry-run>

Specify this to test out the sync without actually modifying the database
permanently.

=item B<--verbose>

Print out more info about what the script is doing. Specify multiple times
to get even more verbose.

=back

=head1 DESCRIPTION

This script can be used to initialize Bugzilla's data about which commits
are associated to particular bugs. It searches the text of commit messages
in a repository for strings that look like "bug 1234" and assocates the
commit with that bug in your Bugzilla.

If any given commit has already been synced to this Bugzilla, it won't be
re-synced. Existing commits will not be modified.