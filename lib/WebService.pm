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

package Bugzilla::Extension::VCS::WebService;
use strict;
use warnings;
use base qw(Bugzilla::WebService);
use Bugzilla::Error;
use Bugzilla::Extension::VCS::Commit;

sub add_commit {
    my ($self, $params) = @_;
    
    # Don't let people set the "id" field.
    delete $params->{id};
    my $created = Bugzilla::Extension::VCS::Commit->create($params);
    return { commits => [
                { id => $created->id }
             ]
           };
}

1;
