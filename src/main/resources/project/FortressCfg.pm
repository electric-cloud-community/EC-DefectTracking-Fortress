####################################################################
#
# ECDefectTracking::Fortress::Cfg: Object definition of a Fortress Defect Tracking configuration.
#
####################################################################
package ECDefectTracking::Fortress::Cfg;
@ISA = (ECDefectTracking::Base::Cfg);
if (!defined ECDefectTracking::Base::Cfg) {
    require ECDefectTracking::Base::Cfg;
}

####################################################################
# Object constructor for ECDefectTracking::Fortress::Cfg
#
# Inputs
#   cmdr  = a previously initialized ElectricCommander handle
#   name  = a name for this configuration
####################################################################
sub new {
    my $class = shift;
    my $cmdr = shift;
    my $name = shift;
    my($self) = ECDefectTracking::Base::Cfg->new($cmdr,"$name");
    bless ($self, $class);
    return $self;
}

####################################################################
# FortressPORT
####################################################################
sub getFortressPORT {
    my ($self) = @_;
    return $self->get('FortressPORT');
}

sub setFortressPORT {
    my ($self, $name) = @_;
    print "Setting FortressPORT to $name\n";
    return $self->set('FortressPORT', "$name");
}

####################################################################
# Credential
####################################################################
sub getCredential {
    my ($self) = @_;
    return $self->get('Credential');
}
sub setCredential {
    my ($self, $name) = @_;
    print "Setting Credential to $name\n";
    return $self->set('Credential', "$name");
}

####################################################################
# validateCfg
####################################################################
sub validateCfg {
    my ($class, $pluginName, $opts) = @_;
    foreach my $key (keys % {$opts}) {
        print "\nkey=$key, val=$opts->{$key}\n";
    }
}

1;
