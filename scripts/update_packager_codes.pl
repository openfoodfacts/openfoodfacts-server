#!/usr/bin/perl


use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Tags qw/:all/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use LWP::Simple;


print STDERR "loading geocoded addresses\n";

if (opendir (DH, "$data_root/packager-codes")) {
	foreach my $file (readdir(DH)) {
		print STDERR "$file\n";
		if ($file =~ /geocode-(\w+).json/) {
			my $country = lc($1);
			print "loading geocode for country $country\n";
			open (my $IN, "<:encoding(windows-1252)", "$data_root/packager-codes/$file") or die("Could not open $data_root/packager-codes/$file: $!");
			my $json = join("", (<$IN>));
			close ($IN);
			my $json_ref =  decode_json($json) or print "could not decode json: $!\n";
			
			my $addresses_ref = $json_ref->{data};
			foreach my $item_ref (@{$addresses_ref}) {
				$geocode_addresses{$country . '.' . $item_ref->{item}{address}} = [$item_ref->{item}{latitude},$item_ref->{item}{longitude}];
				#print STDERR $country . '.' . $item_ref->{item}{address} . '--> ' . $item_ref->{item}{latitude} . ", " . $item_ref->{item}{longitude} . "\n";
			}
		}
		elsif ($file =~ /openlylocal/) {
			my $country = 'uk';
			print "loading geocode for country $country - $file\n";
			open (my $IN, "<:encoding(windows-1252)", "$data_root/packager-codes/$file") or die("Could not open $data_root/packager-codes/$file: $!");
			my $json = join("", (<$IN>));
			close ($IN);
			my $json_ref =  decode_json($json) or print "could not decode json: $!\n";
			
			my $addresses_ref = $json_ref->{councils};
			foreach my $item_ref (@{$addresses_ref}) {
				my $canon_local_authority = get_canon_local_authority($item_ref->{name});
				$geocode_addresses{$country . '.' . $canon_local_authority} = [$item_ref->{lat},$item_ref->{lng}];
				#print  "Name: " . $item_ref->{name} . " canon: " . $country . '.' . $canon_local_authority . '--> ' . $item_ref->{lat} . ", " . $item_ref->{item}{lng} . "\n";
			}			
		}
	}
	close DH;
}
else {
	print STDERR "could not open $data_root/packager-codes: $!\n";
}


# Load packager codes data

my %packager_code_key = ('fr' => 'numero_agrement', 'uk' => 'approval_number');

print STDERR "loading packager codes\n";

my $found = 0;
my $notfound = 0;

if (opendir (DH, "$data_root/packager-codes")) {
	foreach my $file (readdir(DH)) {
		if ($file =~ /(\w+)-merge(-UTF-8)?.csv/i) {
			my $country = lc($1);
			my $encoding = "windows-1252";
			if (defined $2) {
				$encoding = $2;
				$encoding =~ s/^-//;
			}
			my $key = $packager_code_key{$country};
			
			open (my $IN, "<:encoding($encoding)", "$data_root/packager-codes/$file") or die("Could not open $data_root/packager-codes/$file: $!");
			my @fields = split(/;|\t/, <$IN>);
			my @headers = ();
			my %headers = ();
			foreach my $field (@fields) {
				$field =~ s/\/.*//;
				$field = get_fileid($field);
				$field =~ s/-/_/g;
				($field eq 'latitude') and $field = 'lat';
				($field eq 'longitude') and $field = 'lng';
				push @headers, $field;
				$headers{$field} = $#headers;
				# print STDERR "Tags.pm - packaging_codes - load - country: $country - header: $field\n";
			}	
			
			while (<$IN>) {
				chomp;
				my @fields = split(/;|\t/);
				
				my $code = '';
				if ($country eq 'fr') {
					$code = $fields[$headers{numero_agrement}];
					$code = normalize_packager_codes("FR $code CE");
				}
				elsif ($country eq 'uk') {
					$code = $fields[$headers{approval_number}];
					$code =~ s/(\s|\/)*ec$//i;
					$code =~ s/^uk//i;
					#print STDERR "uk - code: $code\n";
					$code = normalize_packager_codes("UK $code EC");
					
				}
				elsif ($country eq 'es') {
					# Nº RGSEAA; Razón Social;Provincia/Localidad;lat;lon;Actividades;Especies;Otros Detalles
					$code = $fields[$headers{n_rgseaa}];
					$code = normalize_packager_codes("ES $code CE");
				}
				elsif ($country eq 'ch') {
					$code = $fields[$headers{bew_nr}];
					$code = normalize_packager_codes("CH-$code");
				}
				elsif ($country eq 'de') {
					$code = $fields[$headers{code}];
					$code = normalize_packager_codes("DE $code EC");
				}
				
				$code = get_fileid($code);
				$code =~ s/-(eg|ce|ew|we|eec)$/-ec/i;
				
				if ($country eq 'de') {
					print STDERR "$code: $code\n";
				}
				
				#print "country: $country - code: $code\n";
		
				# if we already have some info for the packager
				# code from a previous line, keep it	
				if (not defined $packager_codes{$code}) {	
					$packager_codes{$code} = { cc => $country};
				}
					
				foreach (my $f = 0; $f <= $#headers; $f++) {
					# do not overwrite with empty values
					# in case we already have some info
					# from another line with the same code
					# e.g. current CH file contains
					# multiple lines for CH 336 with geo
					# info missing on last line. bug #781
					if ((defined $fields[$f]) and ( $fields[$f] ne '')) {
						$packager_codes{$code}{$headers[$f]} = $fields[$f];
					}
					if (not defined $packager_codes{$code}{$headers[$f]}) {
						$packager_codes{$code}{$headers[$f]} = '';
					}
					#print "$code - f:$f - $headers[$f] - $packager_codes{$code}{$headers[$f]}\n";
				}
				
				# Normalize local authority
				
				if ($country eq 'uk') {
				
					my $debug = "local_authority: " . $packager_codes{$code}{local_authority} . "\ndistrict: " . $packager_codes{$code}{district} . " \n";
					
					foreach my $local_authority (split (/,|\//, $packager_codes{$code}{local_authority} . ', ' . $packager_codes{$code}{district})) {
						my $canon_local_authority = get_canon_local_authority($local_authority);
						$debug .= "$local_authority --> $canon_local_authority\n";
						if (defined $geocode_addresses{$country . '.' . $canon_local_authority}) {
							$packager_codes{$code}{canon_local_authority} = $canon_local_authority;
							last;
						}
					}
					
					if (not defined $packager_codes{$code}{canon_local_authority}) {
						$notfound++;
						# print "code: $code - could not find canon local authority for local authority: $packager_codes{$code}{local_authority} - district: $packager_codes{$code}{district}\ndebug: $debug\n";
					}
					else {
						$found++;
					}
				
				}
				
			}
			close ($IN);
			
			print "UK - found $found local authorities, not found: $notfound\n";
		}
	}
	close DH;
}
else {
	print STDERR "could not open $data_root/packager-codes: $!\n";
}


store("$data_root/packager-codes/packager_codes.sto", \%packager_codes);
store("$data_root/packager-codes/geocode_addresses.sto", \%geocode_addresses);
