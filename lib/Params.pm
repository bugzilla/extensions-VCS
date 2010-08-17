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

use Bugzilla::Install::Util qw(install_string);
use Bugzilla::Util;

use Bugzilla::Extension::VCS::Commit;

our $sortkey = 5000;

use constant get_param_list => (
  {
   name => 'vcs_repos',
   type => 'l',
   default => 'bzr://bzr.mozilla.org/'
  },
  {
    name => 'vcs_web',
    type => 'l',
    default => 'bzr://bzr.mozilla.org/ http://bzr.mozilla.org/%project%/revision/%revno%',
    checker => \&_check_vcs_web,
  },
);

sub _check_vcs_web {
    my ($value) = @_;

    my @db_columns = Bugzilla::Extension::VCS::Commit->DB_COLUMNS;
    foreach my $line (split "\n", $value) {
        $line = trim($line);
        my (undef, $url) = split(/\s+/, $line, 2);
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
