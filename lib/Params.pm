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
# Portions created by the Initial Developer are Copyright (C) 2010
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Max Kanat-Alexander <mkanat@everythingsolved.com>

package Bugzilla::Extension::VCS::Params;
use strict;

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Install::Util qw(install_string);
use Bugzilla::Util;

use Bugzilla::Extension::VCS::Commit;

our $sortkey = 5000;

use constant get_param_list => (
  {
   name => 'vcs_repos',
   type => 'l',
   default => 'Bzr bzr://bzr.mozilla.org/',
   checker => \&_check_vcs_repos,
  },
  {
    name => 'vcs_web',
    type => 'l',
    default => 'bzr://bzr.mozilla.org/ http://bzr.mozilla.org/%project%/revision/%revno%',
    checker => \&_check_vcs_web,
  },
  {
    name => 'vcs_path',
    type => 't',
    default => ON_WINDOWS ? "C/Windows/System32;C:/Windows"
               : '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
  },
);

sub _check_vcs_repos {
    my ($value) = @_;
    
    foreach my $line (split "\n", $value) {
        $line = trim($line);
        next if !$line;
        my ($type, $repo) = split(/\s+/, $value, 2);
        if (!$repo) {
            return "You must specify both a type and a repo for this line: $line";
        }
        my $error_mode = Bugzilla->error_mode;
        Bugzilla->error_mode(ERROR_MODE_DIE);
        my $success = eval {
            _check_type($type);
            trick_taint($type);
            _check_repo($repo, $type);
            1;
        };
        Bugzilla->error_mode($error_mode);
        return $@ if !$success;
    }
    
    return "";
}

sub _check_type {
    my ($value) = @_;
    $value = trim($value);
    
    $value =~ /^(\w+)$/i
        or ThrowUserError('vcs_type_bad_chars', { type => $value });
    # Detaint $value.
    $value = $1;
    
    if (!eval { require "VCI/VCS/$value.pm" }) {
        my $error = $@;
        ThrowUserError('vcs_type_invalid', { type => $value, err => $error });
    }
    return $value;
}

sub _check_repo {
    my ($repo, $type) = @_;
    local $ENV{PATH} = Bugzilla->params->{'vcs_path'};
    # We have to trust the admin, at this point.
    trick_taint($repo);
    my $object = eval { VCI->connect(repo => $repo, type => $type) };
    if (!$object) {
        ThrowUserError('vcs_repo_invalid', { repo => $repo, err => $@,
                                             type => $type });
    }
}

sub _check_vcs_web {
    my ($value) = @_;

    my @db_columns = Bugzilla::Extension::VCS::Commit->DB_COLUMNS;
    foreach my $line (split "\n", $value) {
        $line = trim($line);
        next if !$line;
        my (undef, $url) = split(/\s+/, $line, 2);
        if (!$url) {
            return "You must specify both a repository and a URL on this line: $line";
        }
        my @match_fields = ($url =~ /\%(.+?)\%/g);
        foreach my $field (@match_fields) {
            if (!grep { $field eq $_ } @db_columns) {
                return install_string('vcs_web_invalid', { field => $field });
            }
        }
    }
    
    return "";
}

1;
