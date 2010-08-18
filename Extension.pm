# -*- Mode: perl; indent-tabs-mode: nil -*-
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

package Bugzilla::Extension::VCS;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::Bug;
use Bugzilla::Install::Util qw(install_string);
use Bugzilla::Util;

our $VERSION = '0.01';

BEGIN{ *Bugzilla::Bug::vcs_commits = \&_bug_vcs_commits; }

# VCI uses Moose, and so takes a long time to load. When we don't need
# VCI, we don't want it to load, under mod_cgi. However, under mod_perl,
# we want VCI to be loaded into Apache during mod_perl.pl.
use if $ENV{MOD_PERL}, 'Bugzilla::Extension::VCS::Commit';

###########################
# Database & Installation #
###########################

sub db_schema_abstract_schema {
    my ($class, $args) = @_;
    my $schema = $args->{schema};
    $schema->{vcs_commit} = {
        FIELDS => [
            id          => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                            PRIMARYKEY => 1},
            bug_id      => {TYPE => 'INT3', NOTNULL => 1,
                            REFERENCES => {TABLE  => 'bugs',
                                           COLUMN => 'bug_id',
                                           DELETE => 'CASCADE'}},
            commit_id   => {TYPE => 'varchar(255)', NOTNULL => 1},
            creator     => {TYPE => 'INT3', NOTNULL => 1,
                            REFERENCES => {TABLE  => 'profiles',
                                           COLUMN => 'userid'}},
            revno       => {TYPE => 'varchar(255)', NOTNULL => 1},
            commit_time => {TYPE => 'DATETIME', NOTNULL => 1},
            author      => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            message     => {TYPE => 'LONGTEXT', NOTNULL => 1},
            project     => {TYPE => 'MEDIUMTEXT',  NOTNULL => 1},
            repo        => {TYPE => 'MEDIUMTEXT',  NOTNULL => 1},
            type        => {TYPE => 'varchar(16)', NOTNULL => 1},
        ],
        INDEXES => [
            vcs_commit_bug_id_idx    => ['bug_id'],
            vcs_commit_time_idx      => ['commit_time'],
            vcs_commit_commit_id_idx => {
                FIELDS => [qw(commit_id bug_id repo project)],
                TYPE   => 'UNIQUE'
            },
        ],
    };
}

sub install_update_db {
    my ($self, $args) = @_;
    my $field = new Bugzilla::Field({ name => 'vcs_commits' });
    if (!$field) {
        Bugzilla::Field->create({
            name => 'vcs_commits', description => 'Commits',
        });
    }
}

sub install_before_final_checks {
    my ($self, $args) = @_;
    return if $args->{silent};
    
    my $vcs_repos = Bugzilla->params->{'vcs_repos'};
    return if trim($vcs_repos) ne 'Bzr bzr://bzr.mozilla.org/';
    
    print "\n", install_string('vcs_repos_empty', { urlbase => correct_urlbase() });
}

####################
# Global Accessors #
####################

sub _vcs_repos {
    my ($class) = @_;
    my $vcs_repos = Bugzilla->params->{'vcs_repos'};
    my %repos;
    foreach my $line (split "\n", $vcs_repos) {
        $line = trim($line);
        next if !$line;
        my ($type, $repo) = split(/\s+/, $line, 2);
        $repos{$repo} = $type;
    }
    return \%repos;
}

###############
# Bug Methods #
###############

sub _bug_vcs_commits {
    my ($self) = @_;
    require Bugzilla::Extension::VCS::Commit;
    $self->{vcs_commits} ||= Bugzilla::Extension::VCS::Commit->match(
                                 { bug_id => $self->id });
    return $self->{vcs_commits};
}

##########
# Config #
##########

sub config_add_panels {
    my ($self, $args) = @_;
    my $modules = $args->{'panel_modules'};
    $modules->{'VCS'} = 'Bugzilla::Extension::VCS::Params';
}

sub webservice {
    my ($self, $args) = @_;
    $args->{dispatch}->{VCS} = 'Bugzilla::Extension::VCS::WebService';
}

#############
# Templates #
#############

sub template_before_create {
    my ($self, $args) = @_;
    my $variables = $args->{config}->{VARIABLES};
    $variables->{vcs_commit_link} = \&_create_commit_link;
}

sub _create_commit_link {
    my ($commit) = @_;
    
    my $web_view = Bugzilla->params->{'vcs_web'};
    my $web_url;
    foreach my $line (split "\n", $web_view) {
        $line = trim($line);
        next if !$line;
        my ($repo, $url) = split(/\s+/, $line, 2);
        if (lc($repo) eq lc($commit->repo)) {
            $web_url = $url;
            last;
        }
    }
   
    my $revno = html_quote($commit->revno);
    return $revno if !$web_url;
    
    # We don't url_quote the replacements because they might be used
    # in the URL path in an important way (like with %project%).
    my @replace_fields = ($web_url =~ /\%(.+?)\%/g);
    foreach my $field (@replace_fields) {
        my $value = $commit->$field;
        $web_url =~ s/\%\Q$field\E\%/$value/g;
    }
    $web_url = html_quote($web_url);
    return "<a class=\"vcs_commit_link\" href=\"$web_url\">$revno</a>";
}

__PACKAGE__->NAME;