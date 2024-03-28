# find out which imported symbols are used by each source file
use 5.24.0;
use utf8;
use strict;
use warnings;
use Path::Tiny;
use YAML qw/DumpFile/;
use Excel::ValueWriter::XLSX;
use File::Find::Rule; # because glob() does not walk through recursive directories


# files to inspect
my @pm_files  	 = glob "../../lib/ProductOpener/*.pm";
my @cgi_files 	 = ("../../lib/startup_apache2.pl", glob "../../cgi/*.pl");
my @script_files = grep {!/obsolete/} File::Find::Rule->name(qr/\.pl$/)->in("../../scripts");
my @test_files   = File::Find::Rule->name(qr/\.t$/)->in("../../tests");

# output files
my $yaml_file = "off_symbols.yaml";
my $xlsx_file = "off_symbols.xlsx";

my %source;
my %symbol;


# load and inspect ProductOpener modules, finding the exported symbols
foreach my $file (@pm_files) {
	my $source_code = path($file)->slurp;
	my ($package)   = $source_code =~ /^package\h+ProductOpener::([\w:]+)/m;
	my ($export)    = $source_code =~ /EXPORT_OK\s=\s*qw\((.*?)\)/s;
	my @symbols     = grep {$_} split /\s+/, $export // ""; 

	$source{$package} = {kind  => 'pm',
						 lines => [split /\n/, $source_code]};

	foreach my $sym (@symbols) {
		not exists $symbol{$sym}
		  or warn "SYMBOL '$sym' in $package: WAS ALREADY EXPORTED BY $symbol{$sym}{from}!\n";
		$symbol{$sym}{from} = $package 
	}
}



# load pl files
my %to_load = (cgi => \@cgi_files, script => \@script_files, test => \@test_files);
while (my ($kind, $files) = each %to_load) {
	foreach my $file (@$files) {
		my $source_code = path($file)->slurp;
		$file =~ s[^.*/][];
		$source{$file} = {kind  => $kind,
						  lines => [split /\n/, $source_code]};
	}
}


# find which symbol is used in which package
foreach my $sym (keys %symbol) {
	warn "inspecting $sym\n";

	my ($sigil, $name) = $sym =~ /^([&\@%\$*])?(\w+)$/
	  or warn "can't parse '$sym' from $symbol{$sym}{from}\n";
	$sigil ||= '&'; # according to Exporter convention, a symbol without sigil is implicitly a sub

	# regex to find where this symbol is used. For ex. if $sym is '%foobar' the regex will search for '%foobar' or '$foobar{'
	my $regex = $sigil eq '$' ? qr/\$$name\b/
         	  : $sigil eq '@' ? qr/[@\$]$name\b/
         	  : $sigil eq '%' ? qr/[%\$]$name\b/
         	  : $sigil eq '&' ? qr/(&$name\b|$name\()/
         	  : $sigil eq '*' ? qr/\*$name/
              :                 die "unexpected sigil";

	# search for the regex in all sources
	while (my ($src_name, $src_data) = each %source) {
		warn "  on $src_name\n";

		my $line_nb = 0;
		foreach my $line ($src_data->{lines}->@*) {
			++$line_nb;
			push $symbol{$sym}{used_in}{$src_data->{kind}}{$src_name}->@*, $line_nb if $line =~ $regex;
		}
	}
}


# YAML output
DumpFile $yaml_file, \%symbol;

# Excel output
my @headers = qw/symbol from cli_kind cli_name nb_refs/;
my @rows;
while (my ($sym, $tree1) = each %symbol) {
	while (my ($kind, $tree2) = each $tree1->{used_in}->%*) {
		while (my ($name, $refs) = each $tree2->%*) {
			next if $tree1->{from} eq $name; # no need to report when the exporter is its own client
			push @rows, [$sym, $tree1->{from}, $kind, $name, scalar @$refs];
		}
	}
}
my $xl = Excel::ValueWriter::XLSX->new;
$xl->add_sheet(F_Symbols => Symbols => \@headers => \@rows);
$xl->save_as($xlsx_file);
