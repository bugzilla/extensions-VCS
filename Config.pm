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

use constant NAME => 'VCS';
use constant REQUIRED_MODULES => [
    {
        package => 'VCI',
        module  => 'VCI',
        # 0.6.1 is the first stable version to have "revno" and
        # "missing_requirements".
        version => '0.7.0',
    },
];

use constant OPTIONAL_MODULES => [
    {
        package => 'Alien-SVN',
        module  => 'SVN::Core',
        version => '1.2.0',
        feature => ['vcs_svn'],
    },
    {
        package => 'Git',
        module  => 'Git',
        version => 0,
        feature => ['vcs_git'],
    },
];

__PACKAGE__->NAME;