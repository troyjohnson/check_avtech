#!/usr/bin/perl

# check_avtech.pl

# modules
use Getopt::Long;
use LWP::UserAgent;
use strict;

# variables
my $host = '';
my $warning_default = 85;
my $warning = $warning_default;
my $critical_default = 90;
my $critical = $critical_default;
my $sensor_default = "Sensor 2-1";
my $sensor = $sensor_default;
my $unit_default = 'F';
my $unit = $unit_default;
my $need_help = 0;
my $web_page = '';
my $good_code = 200;
my $temp_label = 'tempf';
my $nagios_status = "OK";
my $nagios_label = "AVTECH";

# create things
my $ua = LWP::UserAgent->new(
	env_proxy => 0,
	keep_alive => 1,
	timeout => 60,
);

# get options
my $good_options = GetOptions(
	'H=s' => \$host, # string
	'w=i' => \$warning, # numeric
	'c=i' => \$critical, # numeric
	'sensor|s=s' => \$sensor, # string
	'unit|u=s' => \$unit, # string
	'help' => \$need_help, #boolean
);
#print "good_options=\"${good_options}\"\n";
#print "need_help=\"${need_help}\"\n";
#print "host=\"${host}\"\n";
if ((not $good_options) or ($need_help) or (not $host)) {
	help_message();
	exit;
}
$unit = uc($unit);
if ($unit eq 'C') {
	$temp_label = 'tempc';
}
if ($critical !~ m/^[\d]+$/) {
        # error message for nagios
        print "${nagios_label} WARNING - critical value not an int (${critical})\n";
        exit 1;
}
if ($warning !~ m/^[\d]+$/) {
        # error message for nagios
        print "${nagios_label} WARNING - warning value not an int (${warning})\n";
        exit 1;
}

# get web page
$web_page = 'http://' . $host . '/getData.htm';
#print "URL: ${web_page}   ";
my $response = $ua->get($web_page);
my $success = $response->is_success;
my $status = $response->status_line;
my ($code, $message) = $status =~ m/^(\d{3})\s(.+)$/;
my $content = $response->content;
my $len = length($content);
my $age = $response->current_age;
#print "\nSuccess:${success} Length:${len} Age:${age} Code:${code} Message:${message}\n";

# check response
if (not $success) {
	# error message for nagios
	print "${nagios_label} UNKNOWN - http response unsuccessful\n";
	exit 3;
}
if ($code != $good_code) {
	# error message for nagios
	print "${nagios_label} UNKNOWN - http response code not 200 (was ${code})\n";
	exit 3; 
}
 
# parse content
my $pattern = "{label:\"${sensor}\",[^}]*${temp_label}:\"([\\d.]+)\"";
my ($temp) = $content =~ m/$pattern/;
#print "pattern=${pattern}\n";
#print "content=${content}\n";
#print "temp=${temp}\n";

if (not defined $temp) {
        # error message for nagios
        print "${nagios_label} UNKNOWN - temp not defined\n";
        exit 3;
}
if ($temp !~ m/^[\d.]+$/) {
        # error message for nagios
        print "${nagios_label} UNKNOWN - temp not a float\n";
        exit 3;
}

# display nagios output
if ($temp >= $critical) {
	$nagios_status = "CRITICAL";
	print "${nagios_label} ${nagios_status} - ${temp} ${unit} on ${sensor}\n";
	exit 2;
}
elsif ($temp >= $warning) {
	$nagios_status = "WARNING";
	print "${nagios_label} ${nagios_status} - ${temp} ${unit} on ${sensor}\n";
	exit 1;
}
else {
	print "${nagios_label} ${nagios_status} - ${temp} ${unit} on ${sensor}\n";
	exit 0;

}

# subroutines
sub help_message {
	print "\nUsage: check_avtech.pl -H hostname [OPTION]...\n\n";
	print "  -H			hostname (Default: none, required)\n";
	print "  -w, --warning		warning threshold (Default: $warning_default)\n";
	print "  -c, --critical	output file name (Default: $critical_default)\n";
	print "  -s, --sensor		sensor label (Default: $sensor_default)\n";
	print "  -u, --unit		unit of temperature measure (Default: $unit_default)\n";
	print "  --help		print this help message\n\n";
	print "Example: check_avtech.pl -H fre-dc-temp1 -w 85 -c 90 -s \"Sensor 3-1\" -u F\n\n";
}
