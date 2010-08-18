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

use Bugzilla::Extension::VCS::CommitFile;

use Scalar::Util qw(blessed);
use VCI;

use constant DB_TABLE   => 'vcs_commit';
use constant LIST_ORDER => 'commit_time';

use constant DB_COLUMNS => qw(
    author
    bug_id
    commit_time
    creator
    id
    message
    project
    repo
    revision
    revno
    type
);

use constant DATE_COLUMNS => qw(commit_time);

use constant VALIDATORS => {
    bug_id    => \&_check_bug_id,
    revision  => \&_check_revision,
    creator   => \&_check_creator,
    project   => \&_check_project,
    repo      => \&_check_repo,
};

use constant VALIDATOR_DEPENDENCIES => {
    revision  => ['project'],
    project   => ['repo'],
};

use constant CF_CLASS =>  'Bugzilla::Extension::VCS::CommitFile';

####################
# Simple Accessors #
####################

sub author    { return $_[0]->{author}      }
sub message   { return $_[0]->{message}     }
sub project   { return $_[0]->{project}     }
sub repo      { return $_[0]->{repo}        }
sub revision  { return $_[0]->{revision}    }
sub revno     { return $_[0]->{revno}       }
sub time      { return $_[0]->{commit_time} }

sub files {
    my ($self) = @_;
    $self->{files} ||= CF_CLASS->match({ commit_id => $self->id });
    return $self->{files};
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
    my $commit = delete $params->{revision};
    $params->{commit_time} =
        $commit->time->clone->set_time_zone(Bugzilla->local_timezone);
    # These are all tainted from the VCS, but are safe to insert
    # into the DB.
    foreach my $key qw(revision revno author message) {
        $params->{$key} = $commit->$key;
        trick_taint($params->{$key});
    }
    
    my @file_rows;
    foreach my $file (@{ $commit->as_diff->files }) {
        my $path = $file->path;
        my ($added, $removed) = (0, 0);
        foreach my $change (@{ $file->changes }) {
            my $type = $change->type;
            if ($type eq 'ADD') {
                $added += $change->size;
            }
            elsif ($type eq 'REMOVE') {
                $removed += $change->size;
            }
        }
        my $file_params = { name => $path, added => $added,
                            removed => $removed };

        CF_CLASS->check_required_create_fields($file_params);
        $file_params = CF_CLASS->run_create_validators($file_params);
        push(@file_rows, $file_params);
    }
    
    $params->{files} = \@file_rows;
    
    return $params;
}

sub create {
    my $self = shift;
    $self->check_required_create_fields(@_);
    my $params = $self->run_create_validators(@_);
    
    my $files = delete $params->{files};
    
    my $object = $self->insert_create_data($params);
    foreach my $file (@$files) {
        $file->{commit_id} = $object->id;
        CF_CLASS->insert_create_data($file);
    }
    
    return $object;
}

# Creates a Commit from a VCI::Abstract::Commit
sub create_from_commit {
    my ($class, $commit, $bug) = @_;
    my $project = $commit->project;
    my $repo    = $project->repository;
    return $class->create({
        project => $project->name, repo => $repo->root, bug_id => $bug,
        revision => $commit,
    });
}

sub exists {
    my ($class, $commit, $bug) = @_;
    my $project = $commit->project;
    my $repo    = $project->repository;
    my $results = $class->match({
        project => $project->name, repo => $repo->root, bug_id => $bug->id,
        revision => $commit->revision,
    });
    return @$results ? 1 : 0;
}

##############
# Validators #
##############

sub _check_bug_id {
    my ($self, $value) = @_;
    my $bug = blessed($value) ? $value : Bugzilla::Bug->check($value);
    Bugzilla->user->can_edit_product($bug->product_id)
        || ThrowUserError("product_edit_denied", { product => $bug->product });
    my $privs;
    $bug->check_can_change_field('vcs_commit', 0, 1, \$privs)
        || ThrowUserError('illegal_change', { field => 'vcs_commit',
                                              privs => $privs });
    return $bug->id;
}

sub _check_revision {
    my ($invocant, $value, undef, $params) = @_;
    
    # This allows us to pass a VCI::Abstract::Commit object directly
    # as the revision argument.
    return $value if blessed $value;
    
    $value = trim($value);
    
    if (!defined $value or $value eq '') {
        ThrowCodeError('param_required',
                       { function => "$invocant->create",
                         param => 'revision' });
    }
    
    local $ENV{PATH} = Bugzilla->params->{'vcs_path'};
    my $repo = VCI->connect(repo => $params->{repo}, type => $params->{type});
    my $project = $repo->get_project(name => $params->{project});
    my $commit = eval { $project->get_commit(revision => $value) };
    if (!$commit) {
        if (my $error = $@) {
            ThrowUserError('vcs_revision_error',
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