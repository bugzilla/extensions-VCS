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

use constant LIST_ORDER => 'id';

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

sub _check_repo {
    my ($self, $value) = @_;
    
}



1;