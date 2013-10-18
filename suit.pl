#!/usr/bin/env perl

# Name:         suit (Set Up ILOM Tool)
# Version:      0.5.9
# Release:      1
# License:      Open Source
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: UNIX
# Vendor:       Lateral Blast
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Perl script to log into ILOMs and configure them

use strict;
use Expect;
use Getopt::Std;
use Net::FTP;
use File::Slurp;
use File::Basename;
use Net::TFTPd;

# Set up some host configuration variables

my $syslog_1="XXX.XXX.XXX.XXX"; 
my $syslog_2="XXX.XXX.XXX.XXX";
my $ntp_1="XXX.XXX.XXX.XXX"; 
my $ntp_2="XXX.XXX.XXX.XXX";
my $timezone="Australia/Melbourne";
my $expect_prompt="->";
my $tftp_ip="XXX.XXX.XXX.XXX"; 

# General setup

my $ssh_session;
my %option; 
my $verbose;
my @cfg_array; 
my @password_array; 
my @fw_array;
my $pause=10; 
my $os_vers=`uname -a`; 
my $temp_dir;
my $script_info;
my $version_info;
my $packager_info;
my $vendor_info;
my $script_name=$0;
my @script_file;
my $firmware_file="firmware.txt";
my $options="i:m:p:d:T:cneVfgahZtF";

# Check local configuration

check_local_config();

# Get command ling options

getopts($options,\%option) or print_usage();

# Routine to get information from script header

sub search_script {
  my $search_string=$_[0];
  my $result;
  my $header;
  if ($script_file[0]!~/perl/) {
    @script_file=read_file($script_name);
  }
  my @search_info=grep{/^# $search_string/}@script_file;
  ($header,$result)=split(":",$search_info[0]);
  $result=~s/^\s+//;
  chomp($result);
  return($result);
}

# Check TFTP directory exists

if ($option{'T'}) {
  if (! -d "$option{'T'}") {
    print "TFTP directory $option{'T'} does not exist\n";
    exit;
  }
}

# Check local config
# once you have done the pod work uncomment the command to make the man page

sub check_local_config {
  my $user_id=`id -u`;
  my $home_dir=`echo \$HOME`;
  my $header;
  my $dir_name=basename($script_name);
  $vendor_info=search_script("Vendor");
  $packager_info=search_script("Packager");
  $version_info=search_script("Version");
  chomp($user_id);
  chomp($home_dir);
  if ($user_id=~/^0$/) {
    $temp_dir="/var/log/$dir_name";
  }
  else {
    $temp_dir="$home_dir/.$dir_name";
  }
  if (! -e "$temp_dir") {
    system("mkdir $temp_dir");
  }
}

# If passed -h print help
# Uncomment man command when you have filled out the pod section

if ($option{'h'}) {
  print_usage();
  exit;
}

# If passed -V print version info

if ($option{'V'}) {
  print_version();
  exit
}

sub print_version {
  print "\n";
  print "$script_info v. $version_info [$packager_info]\n";
  print "\n";
  return;
}

# If passed -F print firmware versions

if ($option{'F'}) {
  populate_fw_array();
  print_fw_array();
  exit;
}

sub print_usage {
  print_version();
  print "Usage: $0 -m model -i hostname -p password -[n,e,f,g]\n"; 
  print "\n";
  print "-n: Change Default password\n";
  print "-c: Check hosts keys (default is to ignore)\n";
  print "-e: Enable custom settings\n";
  print "-g: Check firmware version\n";
  print "-f: Update firmware if required\n";
  print "-a: Perform all steps\n"; 
  print "-t: Run in test mode (don't do firmware update)\n";
  print "-F: Print firmware information\n"; 
  print "-d: Specify default delay [$pause sec]\n";
  print "-T: Set TFTP directory and run TFTP daemon\n";
  print "\n";
  return;
}

# Start and SSH session to the ILOM

initiate_ssh_session();

if (($option{'n'})||($option{'a'})) {
  change_ilom_password();
}

if (($option{'f'})||($option{'g'})||($option{'t'})||($option{'e'})) {
  if (!$option{'m'}) {
    $option{'m'}=determine_hardware();
  }
  $option{'m'}=lc($option{'m'});
}

if (($option{'e'})||($option{'a'})) {
  configure_ilom();
}

if (($option{'f'})||($option{'g'})||($option{'a'})||($option{'t'})) {
  handle_firmware();
}

# CLose the session

exit_ilom();

# Output the firmware information

sub print_fw_array {
  my $record;
  foreach $record (@fw_array) {
    $record=~s/,/ /g;
    print "$record";
  }
  return;

} 

sub populate_fw_array {
  # NB. to add support for a new fw version you'll need to:
  # - Update the firmware list
  # - This can be done manually 
  #   http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html#M10-1
  # - or using the goofball tool
  #   https://github.com/richardatlateralblast/goofball
  # - Copy image to a TFTP boot server if you want to automate the update
  @fw_array=read_file($firmware_file);
  return;
}

# Determine what hardware we are running on

sub determine_hardware {
  my $output; 
  my $chassis_test=0;
  my $hardware_type;
  $chassis_test=determine_if_chassis();
  if ($chassis_test eq 1) {
    $hardware_type="/CH";
  }
  else {
    $hardware_type="/SYS";
  }
  $ssh_session->send("show $hardware_type product_name\n");
  $output=$ssh_session->expect($pause,'-re','MOTHERBOARD|Sun Blade|MIDPLANE|BLADE|BD|FIRE|SPARC');
  $output=$ssh_session->after();
  chomp($output);
  $output=~s/SUN BLADE//g;
  $output=~s/SUN FIRE//g;
  $output=~s/SPARC//g;
  $output=~s/Enterprise//g;
  $output=~s/MODULAR SYSTEM//g;
  $output=~s/Server Module//g;
  $output=~s/GEMINI//g;
  $output=~s/SERVER MODULE//g;
  $output=~s/SERVER//g;
  $output=~s/\,//g;
  $output=~s/\s+//g;
  $output=~s/\-//g;
  $output=~s/\>//g;
  if ($output=~/X4270/) {
    $output="X4270";
  }
  print "\n";
  print "Hardware found: $output\n";
  print "\n";
  return($output);
}

# Check the version of firmware
# Need this as some commands changes from version 2 to 3

sub check_firmware_version {
  my $firmware_version=2; 
  my $output;
  my $test_version=" 3.";
  $ssh_session->send("version\n");
  $output=$ssh_session->expect($pause,'-re',$test_version);
  if ($output eq 1) {
    $firmware_version=3;
  }
  return($firmware_version);
}

# Get the actual 

sub get_firmware_version {
  my $lc_model=$_[0]; 
  my $record; 
  my $firmware_version;
  my $firmware_file; 
  my $test_model;
  my $tester=0; 
  my $sp_build_number;
  foreach $record (@fw_array) {
    chomp($record);
    ($test_model,$firmware_version,$firmware_file,$sp_build_number)=split(",",$record);
    if ($test_model=~/^$lc_model$/) {
      $tester=1;
      return($firmware_version,$firmware_file,$sp_build_number);
    }
  }
  if ($tester eq 0) {
    print "Model $lc_model not supported\n";
    exit;
  }
  return;
}

sub do_m2_check {
  my $uc_model=$_[0]; 
  my $m2_string="M2";
  my $test_string1="$uc_model$m2_string"; 
  my $test_string2="$uc_model $m2_string";  
  my $test_string="$test_string1|$test_string2";
  my $lc_model=lc($uc_model); 
  my $output=0;
  $ssh_session->send("show /SYS/MB fru_name\n");
  $output=$ssh_session->expect($pause,'-re',$test_string);
  if ($output eq 1) {
    print "\n";
    print "Detected an M2 mainboard\n";
    print "\n";
    $lc_model=lc($test_string1);
    $uc_model=$test_string1;
  } 
  return($lc_model,$uc_model);
}

sub handle_firmware {
  my $uc_model=uc($option{'m'});
  my $lc_model=lc($option{'m'});
  my $firmware_version; 
  my $firmware_file;
  my $tftp_url;
  my $tftp_command; 
  my $output;
  my $sp_build_number=0;
  my $tftpd_server;
  my $tftpd_session;
  if (($lc_model=~/x4100|x4200|x4600/)&&($uc_model!~/M2/)) {
    ($lc_model,$uc_model)=do_m2_check($uc_model);
  }
  ($firmware_version,$firmware_file,$sp_build_number)=get_firmware_version($lc_model);
  $tftp_url="tftp://$tftp_ip/$firmware_file";
  $tftp_command="load -source $tftp_url";
  $ssh_session->send("version\n");
  $output=$ssh_session->expect($pause,'-re',$firmware_version);
  if ($sp_build_number!~/[0-9][0-9]/) {
    $sp_build_number=1;
  }
  else {
    $sp_build_number=$ssh_session->expect($pause,'-re',$sp_build_number);
  }
  if (($output eq 1)&&($sp_build_number eq 1)) {
    print "\n";
    print "Firmware is up to date\n";
    print "\n";
  }
  else {
    if ($option{'g'}) {
      print "\n";
      print "Firmware needs updating.\n";
      print "\n";
    }
    else {
      if ($option{'t'}) {
        print "\n";
        print "Test mode\n";
        print "\n";
        print "Command: $tftp_command\n";
        print "\n";
      }
      else {
        $ssh_session->send("$tftp_command\n");
        $output=$ssh_session->expect($pause,'-re','y\/n');
        $ssh_session->send("y\n");
        $output=$ssh_session->expect($pause,'-re','y\/n');
        $ssh_session->send("y\n");
        if ($option{'T'}) {
          $tftpd_server=Net::TFTPd->new('RootDir' => $option{'T'});
          $tftpd_session=$tftpd_server->waitRQ(10);
          $tftpd_session->processRQ();
        }
        if ($lc_model=~/x6250/) {
          $output=$ssh_session->expect($pause,'-re','y\/n');
          $ssh_session->send("n\n");
        }
        $output=$ssh_session->expect(600,'-re','Firmware update is complete.');
        $ssh_session->send("\n");
      }
    }
  }
  return;
}

sub initiate_ssh_session {
  my $result=do_known_host_check();
  my $output;
  my $password;
  if ($option{'c'}) {
    $result=do_known_host_check();
    if ($result eq 0) {
      $output=$ssh_session->expect($pause,'-re','yes\/no');
      $ssh_session->send("yes\n");
    }
    $ssh_session=Expect->spawn("ssh root\@$option{'i'}");
  }
  else {
    $ssh_session=Expect->spawn("ssh -o 'StrictHostKeyChecking no' root\@$option{'i'}");
  }
  if (($option{'n'})||($option{'a'})) {
    $output=$ssh_session->expect($pause,'-re','assword: ');
    $ssh_session->send("changeme\n");
  }
  else {
    $output=$ssh_session->expect($pause,'-re','assword: ');
    $ssh_session->send("$option{'p'}\n");
  }
  $output=$ssh_session->expect(15,'-re','->');
  $ssh_session->send("\n");
  return;
} 

sub do_known_host_check {
  my $result=0; 
  my $host_test;
  my $home_dir; 
  my $host_file; 
  $home_dir=`echo \$HOME`;
  chomp($home_dir);
  $host_file="$home_dir/.ssh/known_hosts";  
  $host_test=`cat $host_file |grep -i '$option{'i'}'`;
  chomp($host_test);
  if ($host_test=~/$option{'i'}/) {
    $result=1;
  }
  return($result);
}
  

sub populate_password_array {
  my $chassis_test=$_[0]; 
  if ($chassis_test eq 1) {
    push(@password_array,"$expect_prompt,set /CMM/users/root password");
  }
  else {
    push(@password_array."$expect_prompt,set /SP/users/root password");
  }
  push(@password_array,"Enter new password:,$option{'p'}");
  push(@password_array,"Enter new password again:,$option{'p'}");
  push(@password_array,"$expect_prompt,");
  return;
}

sub exit_ilom {
  my $output;
  $output=$ssh_session->expect($pause,'-re','->');
  $ssh_session->send("exit\n");
  return;
}

sub determine_if_chassis {
  my $chassis_test=0;
  $ssh_session->send("version\n");
  $chassis_test=$ssh_session->expect($pause,'-re','CMM');
  return($chassis_test);
}

sub change_ilom_password {
  my $record; 
  my $match; 
  my $response; 
  my $output; 
  my $chassis_test;
  $chassis_test=determine_if_chassis();
  populate_password_array($chassis_test);
  foreach $record (@password_array) {
    ($match,$response)=split(',',$record);
    if ($option{'V'}) {
      print "Expecting: $match\n";
      print "Sending:   $response\n";
    }
    $output=$ssh_session->expect($pause,'-re',$match);
    $ssh_session->send("$response\n");
  }
  return;
}

sub check_alom_user {
  my $output;
  $ssh_session->send("show /SP/users/admin \n");
  $output=$ssh_session->expect($pause,'-re','Invalid');
  return($output);
}
  

sub populate_cfg_array {
  my $identifier_name=$option{'i'}; 
  my $firmware_version=check_firmware_version();
  my $chassis_test=0; 
  my $hardware_type="SP";
  my $date_string; 
  my $alom_user=0;
  $chassis_test=determine_if_chassis();
  if ($chassis_test eq 1) {
    $hardware_type="CMM";
  }
  $identifier_name=~s/\-mgt$//g;  
  $identifier_name=~s/\-c$//g;  
  push(@cfg_array,"$expect_prompt,set /$hardware_type hostname=$option{'i'}");
  push(@cfg_array,"$expect_prompt,set /$hardware_type system_identifier=$identifier_name");
  if ($firmware_version eq 3) {
    push(@cfg_array,"$expect_prompt,set /$hardware_type/clients/syslog/1 address=$syslog_1");
    push(@cfg_array,"$expect_prompt,set /$hardware_type/clients/syslog/2 address=$syslog_2");
  }
  else {
    push(@cfg_array,"$expect_prompt,set /$hardware_type/clients/syslog destination_ip1=$syslog_1");
    push(@cfg_array,"$expect_prompt,set /$hardware_type/clients/syslog destination_ip2=$syslog_2");
  }
  push(@cfg_array,"$expect_prompt,set /$hardware_type/clock timezone=$timezone");
  push(@cfg_array,"$expect_prompt,set /$hardware_type/clock usentpserver=enabled");
  push(@cfg_array,"$expect_prompt,set /$hardware_type/clients/ntp/server/1 address=$ntp_1");
  push(@cfg_array,"$expect_prompt,set /$hardware_type/clients/ntp/server/2 address=$ntp_2");
  if ($option{'m'}=~/t6340|t6320/) {
    $alom_user=check_alom_user();
    # root for later t series boxes?
    if ($alom_user eq 1) {
      push(@cfg_array,"$expect_prompt,create /SP/users/admin");
      push(@cfg_array,"password:,$option{'p'}");
      push(@cfg_array,"again:,$option{'p'}");
      push(@cfg_array,"$expect_prompt,set /SP/users/admin role=Administrator");
      push(@cfg_array,"$expect_prompt,set /SP/users/admin cli_mode=alom");
    }
  }
  #$cfg_array[$counter]="$expect_prompt,"; $counter++;
  return;
}

sub configure_ilom {
  my $record;
  my $match; 
  my $response;
  my $output; 
  $pause="5";
  populate_cfg_array();
  foreach $record (@cfg_array) {
    ($match,$response)=split(',',$record);
    if ($option{'V'}) {
      print "Expecting: $match\n";
      print "Sending:   $response\n";
    }
    $output=$ssh_session->expect($pause,'-re',$match);
    $ssh_session->send("$response\n");
  }
  return;
}
