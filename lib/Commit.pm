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

package Bugzilla::Extension::VCS::Commit;
use strict;
use base qw(Bugzilla::Object);

use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util qw(trick_taint trim);

use VCI;

use constant DB_TABLE => 'vcs_commit';

use constant DB_COLUMNS => qw(
    author
    bug_id
    commit_id
    commit_time
    creator
    id
    project
    repo
    revno
    type
);

use constant LIST_ORDER => 'commit_time';

use constant VALIDATORS => {
    bug_id    => \&_check_bug_id,
    commit_id => \&_check_commit_id,
    creator   => \&_check_creator,
    project   => \&_check_project,
    repo      => \&_check_repo,
};

use constant VALIDATOR_DEPENDENCIES => {
    commit_id => ['project'],
    project   => ['repo'],
};

####################
# Simple Accessors #
####################

sub author    { return $_[0]->{author}      }
sub commit_id { return $_[0]->{commit_id}   }
sub project   { return $_[0]->{project}     }
sub repo      { return $_[0]->{repo}        }
sub revno     { return $_[0]->{revno}       }
sub time      { return $_[0]->{commit_time} }

sub bug {
    my ($self) = @_;
    $self->{bug} ||= Bugzilla::Bug->check({ id => $self->{bug_id} });
    return $self->{bug};
}

#########################
# Database Manipulation #
#########################

sub run_create_validators {
    my $self = shift;
    my ($params) = @_;
    # Callers can't set type--it's always set by _check_repo.
    delete $params->{type};
    $params = $self->SUPER::run_create_validators(@_);
    my $commit = delete $params->{commit_id};
    $params->{commit_id} = $commit->revision;
    $params->{revno} = $commit->revno;
    $params->{commit_time} =
        $commit->time->clone->set_time_zone(Bugzilla->local_timezone);
    $params->{author} = $commit->author;
    # These are all tainted from the VCS, but are safe to insert
    # into the DB.
    foreach my $key (qw(commit_id revno commit_time author)) {
        trick_taint($params->{$key});
    }
    return $params;
}

##############
# Validators #
##############

sub _check_bug_id {
    my ($self, $value) = @_;
    my $bug = Bugzilla::Bug->check($value);
    Bugzilla->user->can_edit_product($bug->product_id)
        || ThrowUserError("product_edit_denied", { product => $bug->product });
    my $privs;
    $bug->check_can_change_field('vcs_commit', 0, 1, \$privs)
        || ThrowUserError('illegal_change', { field => 'vcs_commit',
                                              privs => $privs });
    return $bug->id;
}

sub _check_commit_id {
    my ($invocant, $value, undef, $params) = @_;
    $value = trim($value);
    
    if ($value eq '' or !defined $value) {
        ThrowCodeError('param_required',
                       { function => "$invocant->create",
                         param => 'commit_id' });
    }
    
    local $ENV{PATH} = Bugzilla->params->{'vcs_path'};
    my $repo = VCI->connect(repo => $params->{repo}, type => $params->{type});
    my $project = $repo->get_project(name => $params->{project});
    my $commit = eval { $project->get_commit(revision => $value) };
    if (!$commit) {
        if (my $error = $@) {
            ThrowUserError('vcs_commit_id_error',
                { id => $value, repo => $repo->root,
                  project => $project->name, err => $error });
        }
        else {
            ThrowUserError('vcs_no_such_commit',
                { id => $value, repo => $repo->root,
                  project => $project->name });
        }
    }
    
    return $commit;
}

sub _check_creator {
    my ($self, $args) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    return Bugzilla->user->id;
}

sub _check_project {
    my ($invocant, $value, undef, $params) = @_;
    $value = trim($value);
    
    if ($value eq '' or !defined $value) {
        ThrowCodeError('param_required',
                       { function => "$invocant->create", param => 'project' });
    }
    
    return $value;
}

sub _check_repo {
    my ($invocant, $value, undef, $params) = @_;
    $value = trim($value);

    if ($value eq '' or !defined $value) {
        ThrowCodeError('param_required',
                       { function => "$invocant->create", param => 'repo' });
    }

    my $allowed_repos = Bugzilla::Extension::VCS->_vcs_repos;
    if (!$allowed_repos->{$value}) {
        ThrowUserError('vcs_repo_denied',
                       { repo => $value, allowed => $allowed_repos });
    }
    
    $params->{type} = $allowed_repos->{$value};
    
    return $value;
}

1;