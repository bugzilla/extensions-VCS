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

use VCI;

use constant LIST_ORDER => 'id';
use constant VALIDATOR_DEPENDENCIES => {
    commit_id => ['project'],
    project   => ['repo'],
    repo      => ['type'],
};

####################
# Simple Accessors #
####################

sub commit_id { return $_[0]->{commit_id} }
sub project   { return $_[0]->{project}   }
sub repo      { return $_[0]->{repo}      }

sub bug {
    my ($self) = @_;
    $self->{bug} ||= Bugzilla::Bug->check({ id => $self->{bug_id} });
    return $self->{bug};
}

##############
# Validators #
##############

sub _check_commit_id {
    my ($invocant, $value, undef, $params) = @_;
    $value = trim($value);
    
    if ($value eq '' or !defined $value) {
        ThrowCodeError('param_required',
                       { function => "$invocant->create",
                         param => 'commit_id' });
    }
    
    my $repo = VCI->connect(repo => $params->{repo}, type => $params->{type});
    my $project = $repo->get_project($params->{project});
    my $commit = eval { $project->get_commit($value) };
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
    
    my $type = $params->{type};
    my $object = eval { VCI->connect(repo => $value, type => $type) };
    if (!$object) {
        ThrowUserError('vcs_repo_invalid', { repo => $value, err => $@,
                                             type => $type });
    }
    
    # VCI normalizes the URI, so we want to use the normalized URI.
    $value = $object->root;
    
    # Repo may be tainted, and VCI dies with tainted repos, because they
    # can be used in dangerous ways. So we restrict repos to ones
    # listed in vcs_repos.
    my @allowed_repos = split("\n", Bugzilla->params->{'vcs_repos'});
    if (!grep { lc($_) eq lc($value) } @allowed_repos) {
        ThrowUserError('vcs_repo_denied',
                       { repo => $value, allowed => \@allowed_repos });
    }
    
    return $value;
}

sub _check_type {
    my ($invocant, $value) = @_;
    $value = trim($value);

    if ($value eq '' or !defined $value) {
        ThrowCodeError('param_required',
                       { function => "$invocant->create", param => 'type' });
    }
    
    $value =~ /^\w+$/i
        or ThrowUserError('vcs_type_bad_chars', { type => $value });
        
    if (!eval { require "VCI/VCS/$value.pm" }) {
        my $error = $@;
        ThrowUserError('vcs_type_invalid', { type => $value, err => $error });
    }
    return $value;
}

1;