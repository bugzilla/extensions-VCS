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
use base qw(Bugzilla::Extension);

our $VERSION = '0.01';

# VCI uses Moose, and so takes a long time to load. When we don't need
# VCI, we don't want it to load, under mod_cgi. However, under mod_perl,
# we want VCI to be loaded into Apache during mod_perl.pl.
use if $ENV{MOD_PERL}, 'VCI';

############
# Database #
############

sub db_schema_abstract_schema {
    my ($class, $args) = @_;
    my $schema = $args->{schema};
    $schema->{vcs_commit} = {
        id        => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                      PRIMARYKEY => 1},
        bug_id    => {TYPE => 'INT3', NOTNULL => 1,
                      REFERENCES => {TABLE  => 'bugs',
                                     COLUMN => 'bug_id',
                                     DELETE => 'CASCADE'}},
        commit_id => {TYPE => 'INT3', NOTNULL => 1},
        project   => {TYPE => 'MEDIUMTEXT',  NOTNULL => 1},
        repo      => {TYPE => 'MEDIUMTEXT',  NOTNULL => 1},
        type      => {TYPE => 'varchar(16)', NOTNULL => 1},
    };
}

##########
# Config #
##########


sub config_add_panels {
    my ($self, $args) = @_;
    my $modules = $args->{'panel_modules'};
    $modules->{'VCS'} = 'Bugzilla::Extension::VCS::Params';
}

__PACKAGE__->NAME;