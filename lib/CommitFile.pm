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

package Bugzilla::Extension::VCS::CommitFile;
use strict;
use base qw(Bugzilla::Object);

use Bugzilla::Error;
use Bugzilla::Util qw(detaint_natural);

use constant DB_TABLE => 'vcs_commit_file';

use constant DB_COLUMNS => qw(
    added
    commit_id
    id
    name
    removed
);

use constant VALIDATORS => {
    added     => \&_check_int,
    removed   => \&_check_int,
    name      => \&_check_required,
};

use constant REQUIRED_CREATE_FIELDS => qw(name);

####################
# Simple Accessors #
####################

sub added   { $_[0]->{added}   }
sub removed { $_[0]->{removed} }

##############
# Validators #
##############

sub _check_int {
    my ($invocant, $value, $field) = @_;
    my $original_value = $value;

    detaint_natural($value)
        || ThrowCodeError('param_must_be_numeric',
                          { function => "$invocant->create",
                            param => "$field: $original_value" });
    return $value;
}

sub _check_required {
    my ($invocant, $value, $field) = @_;
    if (!$value) {
        ThrowCodeError('param_required',
                       { function => "$invocant->create",
                         param => $field });
    }
    return $value;
}

1;
