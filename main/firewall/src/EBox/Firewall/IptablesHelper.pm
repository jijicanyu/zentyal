# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::Firewall::IptablesHelper
#
#   This class is used to build iptables rules based on the data
#   stored in the firewall models, namely:
#
#   <EBox::Firewall::Model::ToInternetRule>
#
#   It uses <EBox::Firewall::IptablesRule> to assit with rules creation
#

package EBox::Firewall::IptablesHelper;

use warnings;
use strict;

use EBox::Model::Manager;
use EBox::Firewall::IptablesRule;
use EBox::Firewall::IptablesRedirectRule;
use EBox::Firewall::IptablesRule::SNAT;
use EBox::Types::IPAddr;
use EBox::Exceptions::Internal;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};
    $self->{'manager'} = EBox::Model::Manager->instance();
    $self->{firewall} = EBox::Global->modInstance('firewall');
    bless($self, $class);
    return $self;
}

# Method: ToInternetRuleTable
#
#   Return iptables rules from <EBox::Firewall::Model::ToInternetRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub ToInternetRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('ToInternetRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Can't get ToInternetRuleTableModel");

    my @rules;
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        if ($self->_isUnsopportedRule($row)) {
            next;
        }

        my $appRule = $self->_isApplicationRule($row);
        my $chain = $appRule ? 'fapplicationglobal' : 'fglobal';
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => $chain);
        $self->_addAddressToRule($rule, $row, 'source');
        $self->_addAddressToRule($rule, $row, 'destination');
        $self->_addServiceToRule($rule, $row);
        $self->_addApplicationToRule($rule, $row);
        $self->_addDecisionToRule($rule, $row, 'faccept');
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

# Method: ExternalToInternalRuleTable
#
#   Return iptables rules from
#   <EBox::Firewall::Model::ExternalToInternalRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub ExternalToInternalRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('ExternalToInternalRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Cant' get ExternalToInternalRuleTableModel");

    my @rules;
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        if ($self->_isUnsopportedRule($row)) {
            next;
        }

        my $appRule = $self->_isApplicationRule($row);
        my $chain = $appRule ? 'fapplicationfwdrules' : 'ffwdrules';
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => 'ffwdrules');
        $self->_addAddressToRule($rule, $row, 'source');
        $self->_addAddressToRule($rule, $row, 'destination');
        $self->_addServiceToRule($rule, $row);
        $self->_addDecisionToRule($rule, $row, 'faccept');
        $self->_addApplicationToRule($rule, $row);
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

# Method: InternalToEBoxRuleTable
#
#   Return iptables rules from <EBox::Firewall::Model::InternalToEBoxRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub InternalToEBoxRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('InternalToEBoxRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Cant' get InternalToEBoxRuleTableModel");

    my @rules;
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        if ($self->_isUnsopportedRule($row)) {
            next;
        }

        my $appRule = $self->_isApplicationRule($row);
        my $chain = $appRule ? 'iapplicationglobal' : 'iglobal';
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => $chain);
        if (not $appRule) {
            $rule->setState('new' => 1);
        }
        $self->_addAddressToRule($rule, $row, 'source');
        $self->_addServiceToRule($rule, $row);
        $self->_addApplicationToRule($rule, $row);
        $self->_addDecisionToRule($rule, $row, 'iaccept');
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

# Method: ExternalToEBoxRuleTable
#
#   Return iptables rules from <EBox::Firewall::Model::ExternalToEBoxRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub ExternalToEBoxRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('ExternalToEBoxRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Cant' get ExternalToEBoxRuleTableModel");

    my @rules;
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        if ($self->_isUnsopportedRule($row)) {
            next;
        }

        my $appRule = $self->_isApplicationRule($row);
        my $chain = $appRule ? 'iapplicationexternal' : 'iexternal';
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => $chain);
        if (not $appRule) {
            $rule->setState('new' => 1);
        }
        $self->_addAddressToRule($rule, $row, 'source');
        $self->_addServiceToRule($rule, $row);
        $self->_addApplicationToRule($rule, $row);
        $self->_addDecisionToRule($rule, $row, 'iaccept');
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

# Method: EBoxOutputRuleTable
#
#   Return iptables rules from <EBox::Firewall::Model::EBoxOutputRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub EBoxOutputRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('EBoxOutputRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Cant' get EBoxOutputRuleTableModel");

    my @rules;
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        if ($self->_isUnsopportedRule($row)) {
            next;
        }

        my $appRule = $self->_isApplicationRule($row);
        my $chain = $appRule ? 'oapplicationglobal' : 'oglobal';
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => $chain);
        if (not $appRule) {
            $rule->setState('new' => 1);
        }

        $self->_addAddressToRule($rule, $row, 'destination');
        $self->_addServiceToRule($rule, $row);
        $self->_addApplicationToRule($rule, $row);
        $self->_addDecisionToRule($rule, $row, 'oaccept');
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

# Method: RedirectsRuleTable
#
#   Return iptables rules from <EBox::Firewall::Model::RedirectsTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub RedirectsRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('RedirectsTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Can't get RedirectsTable Model");

    my @rules;
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $rule = new EBox::Firewall::IptablesRedirectRule();
        $rule->setState('new' => 1);
        $self->_addIfaceToRule($rule, $row);
        $self->_addOrigAddressToRule($rule, $row);
        $self->_addCustomServiceToRule($rule, $row);
        $self->_addAddressToRule($rule, $row, 'source');
        $self->_addDestinationToRule($rule, $row);
        $self->_addSNATToRule($rule, $row);
        $self->_addLoggingToRule($rule, $row);
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

sub SNATRules
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('SNAT');
    defined($model) or throw EBox::Exceptions::Internal(
            "Can't get RedirectsTable Model");

    my @rules;
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $rule = new EBox::Firewall::IptablesRule::SNAT();
        $rule->setState('new' => 1);
        $self->_addIfaceToRule($rule, $row);
        $self->_addServiceToRule($rule, $row);
        $self->_addAddressToRule($rule, $row, 'source');
        $self->_addAddressToRule($rule, $row, 'destination');
        $self->_addSNATToRule($rule, $row);
        $self->_addLoggingToRule($rule, $row);
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

sub _isApplicationRule
{
    my ($self, $row) = @_;
    my $service = $row->valueByName('application');
    return ($service ne 'ndpi_none');
}

sub _isUnsopportedRule
{
    my ($self, $row) = @_;
    my $service = $row->valueByName('service');
    return ($service eq 'ndpi_unsupported');
}

sub _addOrigAddressToRule
{
    my ($self, $rule, $row) = @_;

    my %params;
    my $addr = $row->elementByName('origDest');
    my $type = $addr->selectedType();
    if ($type  eq 'origDest_ebox') {
        my $iface = $row->valueByName('interface');
        my $netModule = EBox::Global->modInstance('network');

        my $extaddr;
        my $method = $netModule->ifaceMethod($iface);
        if (($method eq 'dhcp') or ($method eq 'ppp')) {
            $extaddr = $netModule->DHCPAddress($iface);
        } elsif ($method eq 'static'){
            $extaddr =  $netModule->ifaceAddress($iface);
        }

        unless (defined($extaddr) and length($extaddr) > 0) {
            return;
        }

        my $addr = new EBox::Types::IPAddr( fieldName => 'ip');
        $addr->setValue("$extaddr/32");
        $params{'destinationAddress'} = $addr;
    } else {
        if ($type eq 'origDest_ipaddr') {
            $params{'destinationAddress'} = $addr->subtype();
        } elsif ($type eq 'origDest_object') {
            $params{'destinationObject'} = $addr->value();
        }
        if ($addr->isa('EBox::Types::InverseMatchUnion')) {
            $params{'inverseMatch'} = $addr->inverseMatch();
        }
    }

    $rule->setDestinationAddress(%params);
}

sub _addAddressToRule
{
    my ($self, $rule, $row, $address) = @_;

    my %params;
    my $addr = $row->elementByName($address);

    # TODO: It would be nice to have another class to translate
    # eBox types to iptables params to avoid these checks
    if ($addr->isa('EBox::Types::Union')) {
        my $type = $addr->selectedType();

        if ($type eq $address . '_ipaddr') {
            $params{$address .'Address'} = $addr->subtype();
        } elsif ($type eq $address . '_macaddr') {
#            $params{$address . 'MAC'} = $addr->subtype();
            $params{$address . 'Address'} = $addr->subtype();
        } elsif ($type eq $address . '_object') {
            $params{$address . 'Object'} = $addr->value();
        }

        if ($addr->isa('EBox::Types::InverseMatchUnion')) {
            $params{'inverseMatch'} = $addr->inverseMatch();
        }
    } else {
        $params{$address .'Address'} = $addr;
    }

    if ($address eq 'source') {
        $rule->setSourceAddress(%params);
    } else {
        $rule->setDestinationAddress(%params);
    }
}

sub _addServiceToRule
{
    my ($self, $rule, $row) = @_;

    my $service = $row->elementByName('service');
    my $inverseMatch = $service->can('inverseMatch') ? $service->inverseMatch() : undef;
    $rule->setService($service->value(), $inverseMatch);
}

sub _addApplicationToRule
{
    my ($self, $rule, $row) = @_;
    my $app = $row->valueByName('application');
    $rule->setNDPIApplication($app)
}

sub _addIfaceToRule
{
    my ($self, $rule, $row) = @_;

    my $interface = $row->elementByName('interface');
    $rule->setInterface($interface->value());
}

sub _addCustomServiceToRule
{
    my ($self, $rule, $row) = @_;

    my ($extPort, $extPortValue, $dstPort, $dstPortValue, $dstPortFilter);

    $extPort = $row->elementByName('external_port');
    $extPortValue = $extPort->value();

    $dstPort = $row->elementByName('destination_port');
    if ($dstPort->selectedType() eq 'destination_port_same') {
        if ($extPort->rangeType() eq 'range') {
            $dstPortValue = $extPort->from();
            $dstPortFilter = $extPort->from() . ':' . $extPort->to();
        } else {
            $dstPortValue = $extPort->value(); # 'any' or single()
            $dstPortFilter = $extPort->value();
        }
    } else {
        $dstPortValue = $dstPort->value();
        if ($extPort->rangeType() eq 'range') {
            my $endValue = $dstPortValue + ($extPort->to() - $extPort->from());
            $dstPortFilter = "$dstPortValue:$endValue";
        } else {
            $dstPortFilter = $dstPortValue;
        }
    }

    my $protocol = $row->elementByName('protocol')->value();
    $rule->setCustomService($extPortValue, $dstPortValue, $protocol, $dstPortFilter);
}

sub _addDestinationToRule
{
    my ($self, $rule, $row) = @_;

    my $dstAddr = $row->elementByName('destination')->value();

    my $dstPort = undef;
    my $dstPortElement = $row->elementByName('destination_port');
    if ($dstPortElement->selectedType() eq 'destination_port_other') {
        $dstPort = $dstPortElement->value();
    }
    $rule->setDestination($dstAddr, $dstPort);
}

sub _addDecisionToRule
{
    my ($self, $rule, $row, $acceptChain) = @_;

    my $decision = $row->valueByName('decision');
    if ($decision eq 'accept') {
        $rule->setDecision($acceptChain);
    } elsif ($decision eq 'deny') {
        if ($self->_isApplicationRule($row)) {
            $rule->setDecision('REJECT');
        } else {
            $rule->setDecision('drop');
        }
    } elsif ($decision eq 'log') {
        $rule->setDecision('log');
    }

}

sub _addSNATToRule
{
    my ($self, $rule, $row) = @_;

    my $snat = $row->elementByName('snat');
    $rule->setSNAT($snat->value());
}

# Logging for redirect rules
sub _addLoggingToRule
{
    my ($self, $rule, $row) = @_;

    my $log = $row->valueByName('log');
    $rule->setLog( $self->{firewall}->logging() && $log );
    $rule->setLogLevel( EBox::Iptables->SYSLOG_LEVEL );
}

1;
