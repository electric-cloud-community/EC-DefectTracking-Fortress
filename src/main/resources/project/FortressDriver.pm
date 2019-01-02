####################################################################
#
# ECDefectTracking::Fortress::Driver  Object to represent interactions with 
#        Fortress.
#
####################################################################
package ECDefectTracking::Fortress::Driver;
@ISA = (ECDefectTracking::Base::Driver);
use ElectricCommander;
use Time::Local;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use File::stat;
use File::Temp;
use FindBin;
use Sys::Hostname;
use lib $ENV {'DEFECT_TRACKING_PERL_LIB'};

if (!defined ECDefectTracking::Base::Driver) {
    require ECDefectTracking::Base::Driver;
}
if (!defined ECDefectTracking::Fortress::Cfg) {
    require ECDefectTracking::Fortress::Cfg;
}
$|=1;

####################################################################
# Object constructor for ECDefectTracking::Fortress::Driver
#
# Inputs
#    cmdr          previously initialized ElectricCommander handle
#    name          name of this configuration
#                 
####################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $cmdr = shift;
    my $name = shift;
    my $cfg = new ECDefectTracking::Fortress::Cfg($cmdr, "$name");
    if ("$name" ne '') {
        my $sys = $cfg->getDefectTrackingPluginName();
        if ("$sys" ne 'EC-DefectTracking-Fortress') { die "DefectTracking config $name is not type ECDefectTracking-Fortress"; }
    }
    my ($self) = new ECDefectTracking::Base::Driver($cmdr,$cfg);
    bless ($self, $class);
    return $self;
}

####################################################################
# isImplemented
####################################################################
sub isImplemented {
    my ($self, $method) = @_;
    if ($method eq 'linkDefects' || 
        $method eq 'updateDefects' ||
        $method eq 'fileDefect' ||
        $method eq 'createDefects') {
        return 1;
    } else {
        return 0;
    }
}

####################################################################
# linkDefects
#  
# Side Effects:
#   
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub linkDefects {
    my ($self, $opts) = @_;
    my $defectIDs_ref = $self->extractDefectIDsFromProperty($opts->{propertyToParse}, 'ID');
    if (! keys % {$defectIDs_ref}) {
        print "No defect IDs found, returning\n";
        return;
    } 
    $self->populatePropertySheetWithDefectIDs($defectIDs_ref);
    my $defectLinks_ref = {};
    my @bugs;
    my $numb;
    @$numb = keys %$defectIDs_ref;
    s/ID// foreach @$numb;
    foreach my $id (@$numb){
        eval {
            my $fortressInstance = $self->getFortressInstance("QueryItem $id");
            if ($@) {
                my $actualErrorMsg = $@;
                my $msg = getReadableErrorMsg($actualErrorMsg, '', '', $id);
                print "Error trying to get Fortress item = ID$id: ";
            }
            else{
                my @bugs = split(';', $fortressInstance);
                my $status = @bugs[2];
                my $summary = @bugs[1];
                my $name = 'Item '.@bugs[0].": $summary, STATUS=$status";
                my $url = @bugs[4] . 'ShowItem.aspx?pid='.@bugs[3].'&itemid=' . @bugs[0];
                
                print "Name: $name\n";
                
                if ($name && $name ne '' && $url && $url ne '') {
                    $defectLinks_ref->{$name} = $url;
                }
            }
        }
    };
    if (keys % {$defectLinks_ref}) {
        $self->populatePropertySheetWithDefectLinks($defectLinks_ref);
        $self->createLinkToDefectReport('Fortress Report');
    }
}

####################################################################
# updateDefects
#  
# Side Effects:
#   
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub updateDefects {
    my ($self, $opts) = @_;
    my $property = $opts->{property};
    if (!$property || $property eq '') {
        print "Error: Property does not exist or is empty\n";
        exit 1;
    }
    my ($success, $xpath, $msg) = $self->InvokeCommander({SupressLog=>1,IgnoreError=>1}, 'getProperty', "$property");
    if ($success) {
        my $value = $xpath->findvalue('//value')->string_value;
        $property = $value;
    } else {
        print "Error querying for $property as a property\n";
        exit 1;
    }
    print "Property : $property\n";
    my @pairs = split(',', $property);
    my $errors;
    my $updateddefectLinks_ref = {};
    foreach my $val (@pairs) {
        print "Current Pair: $val\n";
        my @iDAndValue = split('=', $val);
        my $idDefect = $iDAndValue[0];
        my $valueDefect = $iDAndValue[1]; 
        s/ID// for $idDefect;
        print "Current idDefect: ID$idDefect\n";
        print "Current valueDefect: $valueDefect\n";
        
        if (!$idDefect || $idDefect eq '' || !$valueDefect || $valueDefect eq '' ) {
            print "Error: Property format error\n";
        }else{
            my $message = '';
            eval{
                my $idvalue;
                if ($valueDefect eq 'Open') {$idvalue = '2';}
                elsif ($valueDefect eq 'Completed') {$idvalue = '3';}
                elsif ($valueDefect eq 'Verified') {$idvalue = '4';}
                elsif ($valueDefect eq 'Invalid') {$idvalue = '5';}
                elsif ($valueDefect eq 'Disregard') {$idvalue = '6';}
                elsif ($valueDefect eq 'Duplicate') {$idvalue = '7';}
                else {$idvalue = 1;}        
                my $fortressInstance = $self->getFortressInstance("UpdateItem $idDefect $idvalue");
                $message = "ID$idDefect was successfully updated to $valueDefect status\n";
                if ($@) {
                    $message = "Error: failed trying to udpate ID$idDefect to $valueDefect status, with error: $@ \n";
                    $errors = 1;            
                }
                else{
                    my @bugs = split(';', $fortressInstance);
                    my $status = @bugs[2];
                    my $summary = @bugs[1];
                    my $name = 'Item '.@bugs[0].": $summary, STATUS=$status";
                    my $url = @bugs[4] . 'ShowItem.aspx?pid='.@bugs[3].'&itemid=' . @bugs[0];
                    if ($name && $name ne '' && $url && $url ne ''){
                        $updateddefectLinks_ref->{$name} = $url; 
                    }
                }
                print "$message";
                my $bugs;
            
            };
        }
    }
    if (keys % {$updateddefectLinks_ref}) {
        $propertyName_ref = 'updatedDefectLinks'; 
        $self->populatePropertySheetWithDefectLinks($updateddefectLinks_ref, $propertyName_ref);
        $self->createLinkToDefectReport('Fortress Report');
    }
    if($errors && $errors ne ''){
        print "Defects update completed with some Errors\n"
    }
}

####################################################################
# createDefects
#  
# Side Effects:
#   
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub createDefects {
    my ($self, $opts) = @_;
    my $projectName = $opts->{fortressProjectName};    
    if (!$projectName || $projectName eq '') {
        print "Error: fortressProjectName does not exist or is empty\n";
        exit 1;
    }
    my ($success, $xpath, $msg) = $self->InvokeCommander({SuppressLog=>1,IgnoreError=>1}, 'setProperty', '/myJob/fortressProjectName', "$projectName");
    my ($success, $xpath, $msg) = $self->InvokeCommander({SuppressLog=>1,IgnoreError=>1}, 'setProperty', '/myJob/config', "$opts->{config}");
    my $mode = $opts->{mode};
    if (!$mode || $mode eq '') {
        print "Error: mode does not exist or is empty\n";
        exit 1;
    }
    ($success, $xpath, $msg) = $self->InvokeCommander({SupressLog=>1,IgnoreError=>1}, 'getProperties', {recurse => '0', path => '/myJob/ecTestFailures'});
    if (!$success) {
        print "No Errors, so no Defects to create\n";
        return 0;
    }
    my $results = $xpath->find('//property');    
    if (!$results->isa('XML::XPath::NodeSet')) {
        print "Didn't get a NodeSet when querying for property: ecTestFailures \n";
        return 0;
    }
    my @propsNames = ();
    foreach my $context ($results->get_nodelist) {
        my $propertyName = $xpath->find('./propertyName', $context);
        push(@propsNames,$propertyName);
    }
    my $createdDefectLinks_ref = {};
    my $errors;
    foreach my $prop (@propsNames) {
        print "Trying to get Property /myJob/ecTestFailures/$prop \n";
        my ($jSuccess, $jXpath, $jMsg) = $self->InvokeCommander({SupressLog=>1,IgnoreError=>1}, 'getProperties', {recurse => '0', path => "/myJob/ecTestFailures/$prop"});
        my %testFailureProps = {};
        my $stepID = 'N/A';
        my $testSuiteName = 'N/A';
        my $testCaseResult = 'N/A';
        my $testCaseName = 'N/A';
        my $logs = 'N/A';
        my $stepName = 'N/A';
        my $jResults = $jXpath->find('//property');
        foreach my $jContext ($jResults->get_nodelist) {
            my $subPropertyName = $jXpath->find('./propertyName', $jContext)->string_value;
            my $value = $jXpath->find('./value', $jContext)->string_value;
            if ($subPropertyName eq 'stepId'){$stepID = $value;}
            if ($subPropertyName eq 'testSuiteName'){$testSuiteName = $value;}
            if ($subPropertyName eq 'testCaseResult'){$testCaseResult = $value;}
            if ($subPropertyName eq 'testCaseName'){$testCaseName = $value;}
            if ($subPropertyName eq 'logs'){$logs = $value;}
            if ($subPropertyName eq 'stepName'){$stepName = $value;}
        }
        my $message = ''; 
        my $comment = "Step ID: $stepID " . "Step Name: $stepName " . "Test Case Name: $testCaseName ";
        if($mode eq 'automatic'){
            eval{
                my $cfg = $self->getCfg();
                my $project = $cfg->get('project');
                my $fortressInstance = $self->getFortressInstance("AddItem $project $comment");
                my @bugs = split(';', $fortressInstance);
                $message = 'Issue Created with ID: '.@bugs[0]."\n";
                my $defectUrl = @bugs[4] . 'ShowItem.aspx?pid='.@bugs[3].'&itemid=' . @bugs[0];
                $createdDefectLinks_ref->{"$comment"} = "$message?url=$defectUrl"; 
            };
            if ($@) {
                $message = "Error: failed trying to create issue, with error: $@ \n";
                print "$message";
                $errors = 1;
                $createdDefectLinks_ref->{"$comment"} = "$message?prop=$prop";
            };
        }else{
            $createdDefectLinks_ref->{"$comment"} = "Needs to File Defect?prop=$prop";
        }
    }
    if (keys % {$createdDefectLinks_ref}){
        $propertyName_ref = 'createdDefectLinks';
        $self->populatePropertySheetWithDefectLinks($createdDefectLinks_ref, $propertyName_ref);
        $self->createLinkToDefectReport('Fortress Report');
    }
      if($errors && $errors ne ''){
        print "Created Defects completed with some Errors\n"
    }
}

####################################################################
# fileDefect
#  
# Side Effects:
#   
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub fileDefect {
    my ($self, $opts) = @_;
    my $prop = $opts->{prop}; 
    if (!$prop || $prop eq '') {
        print "Error: prop does not exist or is empty\n";
        exit 1;
    }
    my $jobIdParam = $opts->{jobIdParam};
    if (!$jobIdParam || $jobIdParam eq ''){
        print "Error: jobIdParam does not exist or is empty\n";
        exit 1;
    }
    my $projectNameParam;
    my ($success, $xpath, $msg) = $self->InvokeCommander({SupressLog=>1,IgnoreError=>1}, 'getProperty', 'fortressProjectName', {jobId => "$jobIdParam"});
    if ($success) {
        $projectNameParam = $xpath->findvalue('//value')->string_value;
    } else {
        print "Error: projectNameParam does not exist or is empty\n";
        exit 1;
    }
    my $fortressInstance = $self->getFortressInstance();
    if (!$fortressInstance) {
        exit 1;
    }
    print "Trying to get Property /$jobIdParam/ecTestFailures/$prop \n";    
    my ($jSuccess, $jXpath, $jMsg) = $self->InvokeCommander({SupressLog=>1,IgnoreError=>1}, 'getProperties', {recurse => '0', jobId => "$jobIdParam", path => "/myJob/ecTestFailures/$prop"});
    my $stepID = 'N/A';
    my $testSuiteName = 'N/A';
    my $testCaseResult = 'N/A';
    my $testCaseName = 'N/A';
    my $logs = 'N/A';
    my $stepName = 'N/A';
    my $jResults = $jXpath->find('//property');
    foreach my $jContext ($jResults->get_nodelist) {
        my $subPropertyName = $jXpath->find('./propertyName', $jContext)->string_value;
        my $value = $jXpath->find('./value', $jContext)->string_value;
        if ($subPropertyName eq 'stepId'){$stepID = $value;}
        if ($subPropertyName eq 'testSuiteName'){$testSuiteName = $value;}
        if ($subPropertyName eq 'testCaseResult'){$testCaseResult = $value;}
        if ($subPropertyName eq 'testCaseName'){$testCaseName = $value;}
        if ($subPropertyName eq 'logs'){$logs = $value;}
        if ($subPropertyName eq 'stepName'){$stepName = $value;}
    }
    my $message = '';
    my $comment = "Step ID: $stepID " . "Step Name: $stepName " . "Test Case Name: $testCaseName ";
    eval{
        my $cfg = $self->getCfg();
        my $project = $cfg->get('project');
        my $fortressInstance = $self->getFortressInstance("AddItem $project $comment");
        my @bugs = split(';', $fortressInstance);
        $message = 'Issue Created with ID: '.@bugs[0]."\n";
        my ($success, $xpath, $msg) = $self->InvokeCommander({SuppressLog=>1,IgnoreError=>1}, 'setProperty', "/myJob/ecTestFailures/$prop/defectId", "$message?url=$newissue", {jobId => "$jobIdParam"});
        my $defectUrl = @bugs[4] . 'ShowItem.aspx?pid='.@bugs[3].'&itemid=' . @bugs[0];
        my ($success, $xpath, $msg) = $self->InvokeCommander({SuppressLog=>1,IgnoreError=>1}, 'setProperty', "/myJob/createdDefectLinks/$comment", "$defectUrl", {jobId => "$jobIdParam"});
    };
    if ($@) {
        print "Project Name: $projectNameParam\n";
        $message = "Error: failed trying to create issue, with error: $@ \n";
        print "$message \n";
        print "setProperty name: /$jobIdParam/createdDefectLinks/$comment value:$message?prop=$prop \n";
        my ($success, $xpath, $msg) = $self->InvokeCommander({SuppressLog=>1,IgnoreError=>1}, 'setProperty', "/myJob/createdDefectLinks/$comment", "$message?prop=$prop", {jobId => "$jobIdParam"});
    };
}

####################################################################
# getFortressInstance
#
# Side Effects:
#   
# Arguments:
#   self -              the object reference
#
# Returns:
#   A Fortress instance used to do operations on a Fortress server.
####################################################################
sub getFortressInstance
{
    my ($self, $command) = @_;
    my $cfg = $self->getCfg();
    my $url = $cfg->get('url');
    my $server = $cfg->get('server');
    my $credentialName = $cfg->getCredential();
    my $credentialLocation = q{/projects/$[/plugins/EC-DefectTracking/project]/credentials/}.$credentialName;
    my ($success, $xPath, $msg) = $self->InvokeCommander({SupressLog=>1,IgnoreError=>1}, 'getFullCredential', $credentialLocation);
    if (!$success) {
        print "\nError getting credential\n";
        return;
    }
    my $fortressuser = $xPath->findvalue('//userName')->value();
    my $passwd = $xPath->findvalue('//password')->value();
    if (!$fortressuser || !$passwd) {
        print "User name and or password in credential $credentialLocation is not set\n";
        return;
    }
    $command = "WSConsoleClient $fortressuser $passwd $url/$server/dragnetwebservice.asmx ".$command;
    my $instance;
    eval {
        $instance = $self->RunCommand($command, 
            {LogCommand => 1, LogResult => 1, HidePassword => 0,
            passwordStart => 0, 
            passwordLength => 0});
    };
    
    return $instance."$url/$server/";
}

####################################################################
# translateFieldIdsToNames
# 
# Side Effects:
#   
# Arguments:
#   id -           The id for which we need a name        
#   fields -       An array or hash that map ids to names.
#
# Returns:
#   The field name.
####################################################################
sub translateFieldIdsToNames($$) {
    my($id, $fields) = @_;

    if (ref($fields) eq 'HASH') {
        foreach my $outerhashkey (keys % $fields) {
            my $inner_hash_ref = $fields->{$outerhashkey};   
            if ($id eq $inner_hash_ref->{'id'}) {
                return $inner_hash_ref->{'name'};
            }
        }
    } elsif (ref($fields) eq 'ARRAY'){
        foreach my $a (@$fields) {
            if ($id eq $a->{'id'}) {
                return $a->{'name'};
            }
        }
    }
    return $id;
}

####################################################################
# validateConfig
# 
# Side Effects:
#   
# Arguments:
#   self -              the object reference
#   opts -              hash of options   
#   userName -          the userName to validate
#   password -          the password to validate
#
# Returns:
#   On error, returns the error message.  Otherwise returns ''.
####################################################################
sub validateConfig {
    my ($self, $opts, $userName, $password) = @_;
    my $url = $opts->{'url'};
    if ($url !~ m/^http/) {
    return 'Please specify a valid url, starting with http:// or https://';
    }
    my $instance = $self->getFortressInstance('QueryItem 1');;
    eval {
    };
    if ($@) {
        my $actualErrorMsg = $@;
        my $moreDetailedErrorMsg = "Error validating Fortress configuration for url=$url, user=$userName: $actualErrorMsg";
        my $msg = getReadableErrorMsg($actualErrorMsg, $url, $userName, '');
        print "$moreDetailedErrorMsg\n";
        if ($msg eq '') {
            return $moreDetailedErrorMsg;
        }
        else {
            return $msg;
        }
    }
    return '';
}

####################################################################
# getReadableErrorMsg
# 
# Side Effects:
#   
# Arguments:
#   actualErrorStr -
#   url -
#   userName -
#   issue - 
#
# Returns:
#   If the error matches one we know about, return a more readable 
#   error messsage.  Otherwise return ''.
####################################################################
sub getReadableErrorMsg {
    my ($actualErrorStr, $url, $username, $issue) = @_;
    if ($actualErrorStr =~ m/(500 read failed|500 Can't connect)/) {
        return "Unable to connect to $url.  Please make sure both the hostname and port are valid.";
    }
    if ($actualErrorStr =~ m/com.atlassian.fortress.rpc.exception.RemoteAuthenticationException/) {
        return "Invalid user name or password.";
    }
    if ($actualErrorStr =~ m/com.atlassian.fortress.rpc.exception.RemotePermissionException/) {
        return "Issue $issue does not exist or you do not have permission to view it.";
    }

    # this is something else
    return '';
}

####################################################################
# addConfigItems
# 
# Side Effects:
#   
# Arguments:
#   self -              the object reference
#   opts -              hash of options   
#
# Returns:
#   nothing
####################################################################
sub addConfigItems{
    my ($self, $opts) = @_;
    $opts->{'linkDefects_label'} = 'Fortress Report';
    $opts->{'linkDefects_description'} = 'Generates a report of Fortress IDs found in the build.';

}

1;
