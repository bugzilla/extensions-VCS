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

%strings = (
    feature_vcs_git => 'VCS: Git Support',
    feature_vcs_svn => 'VCS: Subversion Support',
    vcs_repos_empty => <<END,
Now that you have installed the VCS extension, you will have to edit
its configuration on the "VCS" section of the "Parameters" Administration
panel:

  ##urlbase##editparams.cgi?section=VCS
END
    vcs_web_invalid =>
        "'##field##' is an invalid field to use in a URL for vcs_web",
);