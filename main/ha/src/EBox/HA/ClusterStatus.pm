# Copyright (C) 2014 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

# Class: EBox::HA::ClusterStatus
#
#    This class is responsible to parse and store the crm_mon -X command
#

package EBox::HA::ClusterStatus;

use EBox::Sudo;
use XML::LibXML;

my $_resources = undef;
my $_nodes = undef;
my $_summary = undef;
my $_xml_dom = undef;
my $_errors = undef;

my $_timeCreation = undef;

# If we have parsed the crm_mon commands before 5 seconds we won't
# parse them again
sub new
{
    my ($class, $ha, $xml_dump, $text_dump) = @_;

    my $self = { ha => $ha};
    bless($self, $class);

    if ((!defined $_timeCreation) or (time - $_timeCreation > 5) ) {
        return $self->_parseCrmMonCommands($ha, $xml_dump, $text_dump);
    } else {
        return $self;
    }
}

sub _parseCrmMonCommands
{
    my ($self, $ha, $xml_dump, $text_dump) = @_;

    $_timeCreation = time;
    $self->_parseCrmMon_X($xml_dump);
    $self->_parseCrmMon_1($text_dump);

    return $self;
}

sub designatedController
{
    my ($self) = @_;

    my %summary = %{$_summary};

    return $summary{'designated_controller_name'};
}

# Function: summary
#
# Returns:
#
#   Hash - The cluster status summary attributes
#
sub summary
{
    my ($self) = @_;

    return $_summary;
}

# Function: nodes
#
# Returns:
#
#   Hash ref - The cluster nodes
#
sub nodes
{
    my ($self) = @_;

    return $_nodes;
}

# Function: resources
#
# Returns:
#
#   Hash ref - The cluster resources
#
sub resources
{
    my ($self) = @_;

    return $_resources;
}

# Function: errors
#
# Returns:
#
#   Hash ref - The cluster errors
#
sub errors
{
    my ($self) = @_;

    return $_errors;
}

# Function: resourceByName
#
# Parameters:
#   name - The name of the resource it will return
#
# Returns:
#
#   Hash - The cluster resource
#
# Exceptions:
#
#    <EBox::Exceptions::Internal> - thrown if there is no resource with
#                                   the given name
sub resourceByName
{
    my ($self, $name) = @_;

    my %resources = %{ $_resources };
    if (exists($resources{$name})) {
        return $resources{$name};
    }

    throw EBox::Exceptions::Internal("There is no resource with the name: $name");
}

# Function: nodeByName
#
# Parameters:
#   name - The name of the node it will return
#
# Returns:
#
#   Hash - The cluster node
#
# Exceptions:
#
#    <EBox::Exceptions::Internal> - thrown if there is no node with the given
#                                   name
sub nodeByName
{
    my ($self, $name) = @_;

    if (exists($_nodes->{$name})) {
        return $_nodes->{$name};
    }

    throw EBox::Exceptions::Internal("There is no node with the name: $name");
}

# Function: nodeById
#
# Parameters:
#   id - The id of the node it will return
#
# Returns:
#
#   Hash - The cluster node
#
# Exceptions:
#
#    <EBox::Exceptions::Internal> - thrown if there is no node with the given id
#
sub nodeById
{
    my ($self, $id) = @_;

    my %nodes = %{$_nodes};

    foreach my $key (keys %nodes) {
        if ($nodes{$key}{'id'} == $id) {
            return $nodes{$key};
        }
    }

    throw EBox::Exceptions::Internal("There is no node with the id: $id");
}

# Function: numberOfResources
#
# Returns:
#
#    Int - the number of configured resources
#
sub numberOfResources
{
    my ($self) = @_;

    my @keys = keys %{$_resources};

    return scalar(@keys);
}

# Function: numberOfNodes
#
# Returns:
#
#    Int - the number of configured nodes
#
sub numberOfNodes
{
    my ($self) = @_;

    my @keys = keys %{$_nodes};

    return scalar(@keys);
}

# Function: activeNode
#
# Parameters:
#
#     nodesStatus - Hash ref *(Optional)* Default value: nodesStatus()
#                   is called
#
# Returns:
#
#     String - the node which owns as much resources
#
sub activeNode
{
    my ($self) = @_;

    # sorting the nodes by the number of resources running at it
    my @byRscRunning = sort { $b->{resources_running} <=> $a->{resources_running} } values %{$_nodes};

    return $byRscRunning[0]->{name};
}

# Function: nodeOnline
#
#
# Parameters:
#
#     nodeName    - String the node name to check its status
#
#     nodesStatus - Hash ref *(Optional)* Default value: nodesStatus()
#                   is called
#
# Returns:
#
#     String - the node which owns as much resources
#
sub nodeOnline
{
    my ($self, $nodeName) = @_;

    return 0 unless (exists $_nodes->{$nodeName});
    return $_nodes->{$nodeName}->{online};
}

# Group: Private functions

# Function: _parseCrmMon_X
#
# This function populates the class attributes with the information retrieved
# after invoking the crm_mon -X command (or input string).
#
# Parameters:
#   xml_dump    - XML formated string containing the output of the crm_mon -X
#
#
sub _parseCrmMon_X
{
    my ($self, $xml_dump) = @_;

    $_xml_dom = $self->_getXmlOutput($xml_dump);
    $_nodes = $self->_parseNodesStatus();
    $_summary = $self->_parseSummary();
    $_resources = $self->_parseResources();
}

# Function: _parseCrmMon_1
#
# This function populates the class attributes with the information retrieved
# after invoking the crm_mon -1 command (or input string).
#
# Parameters:
#   text_dump    - String containing the output of the crm_mon -1
#
#
sub _parseCrmMon_1
{
    my ($self, $text_dump) = @_;

    my @reversedText = ();

    if (! $text_dump) {
        @reversedText = reverse(@{EBox::Sudo::root('crm_mon -1')});
    } else {
        @reversedText = reverse(split(/^/, $text_dump));
    }

    my $fullText = join(';', @reversedText);
    if (index($fullText, "Failed actions") != -1) {
        $_errors = $self->_parseErrors(\@reversedText);
    }
}

sub _parseErrors
{
    my ($self, $text) = @_;

    my @errors;
    my @text = @{ $text };

    while (my $error = shift(@text)) {
        if (index($error, "Failed actions") == -1) {
            my $info;
            if (index(shift(@text), "Failed actions") != -1) { return \@errors };
            if (index($info = shift(@text), "Failed actions") != -1) { return \@errors };

            $info =~ s/ //g;
            my @info = split(/=|\(|,/, $info);
            $error = substr($error, 3);
            $error = $info[0] . " - "  . $error;
            push(@errors, { info => $error, node => $info[2]});
        } else {
            return \@errors;
        }
    }

    return \@errors;
}

# Function: _getXmlOutput
#
#    Invokes the crm_mon -X command and returns the output
#
# Returns:
#
#    "XML::LibXML->load_xml" output
#
sub _getXmlOutput
{
    my ($self, $xml) = @_;

    my $outputString;
    if ($xml) {
        $outputString = $xml;
    } else {
        my $crmOutput = EBox::Sudo::root('crm_mon -X');
        $outputString = join('', @{$crmOutput});
    }

    return XML::LibXML->load_xml(string => $outputString);
}

# Function: _parseNodesStatus
#
#     Get the current node status
#
# Returns:
#
#     Hash ref - containing the node indexed by name with the current
#     status in a hash ref with the following keys:
#
sub _parseNodesStatus
{
    my ($self) = @_;

    my $xmlNodes = $_xml_dom->findnodes('//nodes/node');
    my %status;
    foreach my $xmlNode (@{$xmlNodes}) {
        my $name = $xmlNode->getAttribute('name');
        $status{$name} = { name    => $name,
                           id      => $xmlNode->getAttribute('id'),
                           online  => ($xmlNode->getAttribute('online') eq 'true'),
                           standby => ($xmlNode->getAttribute('standby') eq 'true'),
                           standby_onfail => ($xmlNode->getAttribute('standby_onfail') eq 'true'),
                           resources_running => $xmlNode->getAttribute('resources_running') + 0,
                           is_designated_controller   => ($xmlNode->getAttribute('is_dc') eq 'true'),
                           maintenance => ($xmlNode->getAttribute('maintenance') eq 'true'),
                           unclean => ($xmlNode->getAttribute('unclean') eq 'true'),
                           shutdown => ($xmlNode->getAttribute('shutdown') eq 'true'),
                           expected_up => ($xmlNode->getAttribute('expected_up') eq 'true'),
                           type      => $xmlNode->getAttribute('type'),
                         };
    }

    return \%status;
}

# Function: _parseSummary
#
#     Get the current cluster status summary
#
# Returns:
#
#     Hash ref
#
sub _parseSummary
{
    my ($self) = @_;

    my %summary;

    #We extract, one by one, every summary attribute

    my @tempNode = @{$_xml_dom->findnodes('//summary/last_update')};
    $summary{'last_update'} = $tempNode[0]->getAttribute('time');

    @tempNode = @{$_xml_dom->findnodes('//summary/last_change')};
    $summary{'last_change'} = $tempNode[0]->getAttribute('time');
    $summary{'last_change_origin'} = $tempNode[0]->getAttribute('origin');

    @tempNode = @{$_xml_dom->findnodes('//summary/stack')};
    $summary{'stack_type'} = $tempNode[0]->getAttribute('type');

    @tempNode = @{$_xml_dom->findnodes('//summary/nodes_configured')};
    $summary{'number_of_nodes'} = $tempNode[0]->getAttribute('number') + 0;
    $summary{'expected_votes'} = $tempNode[0]->getAttribute('expected_votes');

    @tempNode = @{$_xml_dom->findnodes('//summary/resources_configured')};
    $summary{'number_of_resources'} = $tempNode[0]->getAttribute('number') + 0;

    @tempNode = @{$_xml_dom->findnodes('//summary/current_dc')};
    $summary{'designated_controller_name'} = $tempNode[0]->getAttribute('name');
    $summary{'designated_controller_id'} = $tempNode[0]->getAttribute('id');
    $summary{'quorum'} = ($tempNode[0]->getAttribute('with_quorum') eq 'true');

    return \%summary;
}

# Function: _parseResources
#
#     Get the resources available in the cluster
#
# Returns:
#
#     Hash ref - containing the node indexed by name with the current
#     status in a hash ref with the following keys:
#
sub _parseResources
{
    my ($self) = @_;

    my $xmlResources = $_xml_dom->findnodes('//resources/resource');

    my %resources;
    foreach my $xmlResource (@{$xmlResources}) {
        my $name = $xmlResource->getAttribute('id');
        $resources{$name} = { id => $name,
                           resource_agent => $xmlResource->getAttribute('resource_agent'),
                           role => $xmlResource->getAttribute('role'),
                           active  => ($xmlResource->getAttribute('active') eq 'true'),
                           orphaned => ($xmlResource->getAttribute('orphaned') eq 'true'),
                           managed => ($xmlResource->getAttribute('managed') eq 'true'),
                           failed => ($xmlResource->getAttribute('failed') eq 'true'),
                           failure_ignored => ($xmlResource->getAttribute('failure_ignored') eq 'true'),
                           nodes_running_on => $xmlResource->getAttribute('nodes_running_on'),
                         };
    }

    return \%resources;
}

1;